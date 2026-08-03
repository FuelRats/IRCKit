/*
 Copyright 2020 The Fuel Rats Mischief

 Redistribution and use in source and binary forms, with or without modification,
 are permitted provided that the following conditions are met:

 1. Redistributions of source code must retain the above copyright notice,
 this list of conditions and the following disclaimer.

 2. Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following
 disclaimer in the documentation and/or other materials provided with the distribution.

 3. Neither the name of the copyright holder nor the names of its contributors may be used to endorse or promote
 products derived from this software without specific prior written permission.

 THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES,
 INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
 DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
 SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
 SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY,
 WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
 OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

import Foundation
import CryptoSwift

/// SCRAM-SHA-256 SASL authentication, per RFC 5802 (SCRAM) and RFC 7677 (SHA-256 profile).
///
/// The exchange is: client-first (`n,,n=user,r=nonce`) → server-first (`r=,s=,i=`) →
/// client-final (`c=,r=,p=proof`) → server-final (`v=signature`). The client derives its proof from
/// the salted password and verifies the server's signature before completing.
class Sha256SASLHandler: SASLHandler {
    static let mechanism = "SCRAM-SHA-256"
    var client: IRCClient

    /// Overrides the randomly generated client nonce. This is a test-only seam for reproducing the
    /// fixed RFC 7677 vector; it is nil in normal operation.
    var clientNonceOverride: String?

    private var clientNonce: String?
    private var clientFirstMessageBare: String?
    private var expectedServerSignature: [UInt8]?

    required init(client: IRCClient) {
        self.client = client
        client.send(command: .AUTHENTICATE, parameters: [Sha256SASLHandler.mechanism])
    }

    func handleResponse(message: IRCMessage) {
        guard let response = message.parameters[safe: 0] else {
            return
        }
        if response == "+" {
            self.sendClientFirstMessage()
        } else {
            self.handleServerMessage(response)
        }
    }

    private func sendClientFirstMessage() {
        let username = Sha256SASLHandler.encodeUsername(
            self.client.configuration.authenticationUsername ?? self.client.configuration.username
        )
        let clientNonce = self.clientNonceOverride ?? String.random(length: 32)
        self.clientNonce = clientNonce

        let clientFirstMessageBare = "n=\(username),r=\(clientNonce)"
        self.clientFirstMessageBare = clientFirstMessageBare

        // gs2-header "n,," — no channel binding, no authzid.
        let clientFirstMessage = "n,,\(clientFirstMessageBare)"
        guard let encoded = clientFirstMessage.data(using: .utf8)?.base64EncodedString() else {
            self.client.abortSaslAuthentication()
            return
        }
        self.client.sendAuthenticate(message: encoded)
    }

    private func handleServerMessage(_ response: String) {
        guard
            let data = Data(base64Encoded: response),
            let message = String(data: data, encoding: .utf8)
        else {
            self.client.abortSaslAuthentication()
            return
        }

        let attributes = Sha256SASLHandler.parseAttributes(message)

        guard attributes["e"] == nil else {
            self.client.abortSaslAuthentication()
            return
        }

        if let verifier = attributes["v"] {
            self.verifyServerSignature(verifier)
            return
        }

        guard
            let fullNonce = attributes["r"],
            let encodedSalt = attributes["s"],
            let salt = Data(base64Encoded: encodedSalt),
            let iterationString = attributes["i"],
            let iterations = Int(iterationString), iterations > 0,
            let clientNonce = self.clientNonce,
            fullNonce.hasPrefix(clientNonce)
        else {
            self.client.abortSaslAuthentication()
            return
        }

        self.sendClientFinalMessage(
            serverFirstMessage: message,
            fullNonce: fullNonce,
            salt: Array(salt),
            iterations: iterations
        )
    }

    private func sendClientFinalMessage(
        serverFirstMessage: String,
        fullNonce: String,
        salt: [UInt8],
        iterations: Int
    ) {
        guard
            let password = self.client.configuration.authenticationPassword,
            let clientFirstMessageBare = self.clientFirstMessageBare,
            let saltedPassword = Sha256SASLHandler.pbkdf2(password: password, salt: salt, iterations: iterations),
            let clientKey = try? HMAC(key: saltedPassword, variant: .sha2(.sha256))
                .authenticate(Array("Client Key".utf8)),
            let serverKey = try? HMAC(key: saltedPassword, variant: .sha2(.sha256))
                .authenticate(Array("Server Key".utf8))
        else {
            self.client.abortSaslAuthentication()
            return
        }

        let storedKey = Digest.sha256(clientKey)

        // The gs2-header "n,," base64-encoded is the constant "biws".
        let channelBinding = Data("n,,".utf8).base64EncodedString()
        let clientFinalMessageWithoutProof = "c=\(channelBinding),r=\(fullNonce)"
        let authMessage = "\(clientFirstMessageBare),\(serverFirstMessage),\(clientFinalMessageWithoutProof)"

        guard
            let clientSignature = try? HMAC(key: storedKey, variant: .sha2(.sha256))
                .authenticate(Array(authMessage.utf8)),
            let serverSignature = try? HMAC(key: serverKey, variant: .sha2(.sha256))
                .authenticate(Array(authMessage.utf8)),
            let clientProof = clientKey.xor(with: clientSignature)
        else {
            self.client.abortSaslAuthentication()
            return
        }

        self.expectedServerSignature = serverSignature

        let clientFinalMessage = "\(clientFinalMessageWithoutProof),p=\(clientProof)"
        guard let encoded = clientFinalMessage.data(using: .utf8)?.base64EncodedString() else {
            self.client.abortSaslAuthentication()
            return
        }
        self.client.sendAuthenticate(message: encoded)
    }

    private func verifyServerSignature(_ verifier: String) {
        guard
            let expected = self.expectedServerSignature,
            let decoded = Data(base64Encoded: verifier)
        else {
            self.client.abortSaslAuthentication()
            return
        }

        if Sha256SASLHandler.constantTimeEquals(Array(decoded), expected) {
            self.client.sendAuthenticate(message: "+")
        } else {
            self.client.abortSaslAuthentication()
        }
    }

    /// Parses a SCRAM message into its single-letter attributes. Values may themselves contain `=`
    /// (e.g. base64 salt padding), so only the first `=` separates key from value.
    private static func parseAttributes(_ message: String) -> [String: String] {
        var attributes: [String: String] = [:]
        for token in message.split(separator: ",") {
            let key = String(token.prefix(1))
            let afterKey = token.dropFirst()
            guard afterKey.first == "=" else {
                continue
            }
            attributes[key] = String(afterKey.dropFirst())
        }
        return attributes
    }

    /// Escapes a SASL username for the `n=` attribute, per RFC 5802: `=` → `=3D`, `,` → `=2C`.
    /// The `=` substitution runs first so it does not corrupt the escapes it introduces.
    private static func encodeUsername(_ username: String) -> String {
        return username
            .replacingOccurrences(of: "=", with: "=3D")
            .replacingOccurrences(of: ",", with: "=2C")
    }

    private static func pbkdf2(password: String, salt: [UInt8], iterations: Int) -> [UInt8]? {
        return try? PKCS5.PBKDF2(
            password: Array(password.utf8),
            salt: salt,
            iterations: iterations,
            variant: .sha2(.sha256)
        ).calculate()
    }

    private static func constantTimeEquals(_ lhs: [UInt8], _ rhs: [UInt8]) -> Bool {
        guard lhs.count == rhs.count else {
            return false
        }
        var difference: UInt8 = 0
        for (left, right) in zip(lhs, rhs) {
            difference |= left ^ right
        }
        return difference == 0
    }
}
