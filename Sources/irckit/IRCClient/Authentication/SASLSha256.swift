/*
 Copyright 2020 The Fuel Rats Mischief
 
 Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:
 
 1. Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.
 
 2. Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.
 
 3. Neither the name of the copyright holder nor the names of its contributors may be used to endorse or promote products derived from this software without specific prior written permission.
 
 THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

import Foundation
import CryptoSwift

class Sha256SASLHandler: SASLHandler {
    static let mechanism = "SCRAM-SHA-256"
    var client: IRCClient
    var nonce: String?
    var serverSignature: Array<UInt8>?
    
    required init(client: IRCClient) {
        self.client = client
        client.send(command: .AUTHENTICATE, parameters: [Sha256SASLHandler.mechanism])
    }
    
    
    func handleResponse(message: IRCMessage) {
        if message.parameters[0] == "+" {
            self.sendAuthenticationChallenge()
        } else {
            parseSASLScramResponse(message: message)
        }
    }
    
    func sendAuthenticationChallenge () {
        let username = self.client.configuration.authenticationUsername ?? self.client.configuration.username
        let nonce = String.random(length: 32)
        self.nonce = nonce
        
        let challenge = "n,,n=\(username),r=\(nonce)"
        guard let encodedChallenge = challenge.data(using: .utf8)?.base64EncodedString() else {
            self.client.abortSaslAuthentication()
            return
        }
        
        self.client.sendAuthenticate(message: encodedChallenge)
    }
    
    func parseSASLScramResponse (message: IRCMessage) {
        guard
            let scramData = Data(base64Encoded: message.parameters[0]),
            let scramMessage = String(data: scramData, encoding: .utf8)
        else {
            return
        }
        
        let scramParams = scramMessage.keyValuePairs(separatedBy: ",")
        
        guard scramParams["e"] == nil else {
            self.client.abortSaslAuthentication()
            return
        }
        
        if let verification = scramParams["v"] as? String {
            scramSha256Verify(verification: verification)
            return
        }
        
        
        guard
            let nonce = scramParams["r"] as? String,
            let salt = scramParams["s"] as? String,
            let iterationCount = Int(scramParams["i"] as? String ?? "")
        else {
            return
        }
        
        scramSha256Authenticate(salt: salt, nonce: nonce, iterationCount: iterationCount, message: scramMessage)
    }
    
    /* Thank you to github.com/moortens for documenting how this works in their "yoil" IRC Library
     because the people who made the specification sure didn't bother to. */
    func scramSha256Authenticate (salt: String, nonce: String, iterationCount: Int, message: String) {
        guard
            let password = self.client.configuration.authenticationPassword,
            let saltedPassword = pbkdf2(password: password, salt: salt, iteration: iterationCount),
            let clientKey = try? HMAC(key: saltedPassword, variant: .sha256).authenticate(Array("Client Key".utf8)),
            let serverKey = try? HMAC(key: saltedPassword, variant: .sha256).authenticate(Array("Server Key".utf8)),
            let base64Message = message.data(using: .utf8)?.base64EncodedString()
        else {
            self.client.abortSaslAuthentication()
            return
        }
        
        let storedKey = Digest.sha256(clientKey)
        let username = self.client.configuration.authenticationUsername ?? self.client.configuration.username
        let authMessage = [
            "n": username,
            "r": nonce,
            base64Message: nil,
            "c": "biws"
        ].keyValueString(joinedBy: ",")
        
        guard
            let clientSignature = try? HMAC(key: storedKey, variant: .sha256).authenticate(Array(authMessage.utf8)),
            let serverSignature = try? HMAC(key: serverKey, variant: .sha256).authenticate(Array(authMessage.utf8)),
            let clientXor = clientKey.xor(with: clientSignature)
        else {
            self.client.abortSaslAuthentication()
            return
        }
        
        self.serverSignature = serverSignature
        
        let final = [
            "c": "biws",
            "r": nonce,
            "p": clientXor
        ].keyValueString(joinedBy: ",")
        
        guard let base64Final = final.data(using: .utf8)?.base64EncodedString() else {
            self.client.abortSaslAuthentication()
            return
        }
        
        self.client.sendAuthenticate(message: base64Final)
    }
    
    func scramSha256Verify (verification: String) {
        if verification.bytes == self.serverSignature {
            self.client.sendAuthenticate(message: "+")
        } else {
            self.client.abortSaslAuthentication()
        }
    }
}
