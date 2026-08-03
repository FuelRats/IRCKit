import Foundation
import XCTest
@testable import IRCKit

/// SCRAM-SHA-256 tests driven by the canonical RFC 7677 test vector (username `user`,
/// password `pencil`, client nonce `rOprNGfwEbeRWgbNEkqO`).
final class SCRAMTests: XCTestCase {
    private let clientNonce = "rOprNGfwEbeRWgbNEkqO"
    private let serverFirstMessage =
        "r=rOprNGfwEbeRWgbNEkqO%hvYDpWUa2RaTCAfuxFIlj)hNlF$k0,s=W22ZaJ0SNY7soEsUEjb6gQ==,i=4096"
    private let expectedClientFinalMessage =
        "c=biws,r=rOprNGfwEbeRWgbNEkqO%hvYDpWUa2RaTCAfuxFIlj)hNlF$k0,"
        + "p=dHzbZapWIk4jUhN+Ute9ytag9zjfMHgsqmmiz7AndVQ="
    private let serverFinalMessage = "v=6rriTRBi23WpRR/wtup+mMhUZUn/dB5nLTJRsjl95G4="

    /// A client whose outbound lines accumulate in `IRCConnection.sendQueue` (flood ceiling zero),
    /// with the RFC vector's credentials.
    private func makeClient() -> IRCClient {
        var configuration = IRCTestSupport.configuration()
        configuration.floodControlMaximumMessages = 0
        configuration.authenticationUsername = "user"
        configuration.authenticationPassword = "pencil"
        return IRCClient(configuration: configuration)
    }

    private func makeHandler(_ client: IRCClient) -> Sha256SASLHandler {
        let handler = Sha256SASLHandler(client: client)
        handler.clientNonceOverride = clientNonce
        return handler
    }

    private func authenticate(_ payload: String, client: IRCClient) -> IRCMessage {
        return IRCMessage(line: "AUTHENTICATE \(payload)", client: client)!
    }

    private func base64(_ text: String) -> String {
        return Data(text.utf8).base64EncodedString()
    }

    private func lastSentLine(_ client: IRCClient) -> String? {
        return client.connection.sendQueue.last
    }

    private func lastDecodedAuthenticate(_ client: IRCClient) -> String? {
        guard let line = lastSentLine(client), line.hasPrefix("AUTHENTICATE ") else {
            return nil
        }
        return Data(base64Encoded: String(line.dropFirst("AUTHENTICATE ".count)))
            .flatMap { String(data: $0, encoding: .utf8) }
    }

    func testClientFirstMessageMatchesVector() {
        let client = makeClient()
        let handler = makeHandler(client)

        handler.handleResponse(message: authenticate("+", client: client))

        XCTAssertEqual(lastDecodedAuthenticate(client), "n,,n=user,r=\(clientNonce)")
    }

    func testClientFinalMessageMatchesVector() {
        let client = makeClient()
        let handler = makeHandler(client)

        handler.handleResponse(message: authenticate("+", client: client))
        handler.handleResponse(message: authenticate(base64(serverFirstMessage), client: client))

        XCTAssertEqual(lastDecodedAuthenticate(client), expectedClientFinalMessage)
    }

    func testValidServerSignatureCompletesAuthentication() {
        let client = makeClient()
        let handler = makeHandler(client)

        handler.handleResponse(message: authenticate("+", client: client))
        handler.handleResponse(message: authenticate(base64(serverFirstMessage), client: client))
        handler.handleResponse(message: authenticate(base64(serverFinalMessage), client: client))

        // The client acknowledges a valid server signature with an empty response.
        XCTAssertEqual(lastSentLine(client), "AUTHENTICATE +")
    }

    func testInvalidServerSignatureAborts() {
        let client = makeClient()
        let handler = makeHandler(client)

        handler.handleResponse(message: authenticate("+", client: client))
        handler.handleResponse(message: authenticate(base64(serverFirstMessage), client: client))
        // Flip a byte of the server signature.
        let tampered = "v=7rriTRBi23WpRR/wtup+mMhUZUn/dB5nLTJRsjl95G4="
        handler.handleResponse(message: authenticate(base64(tampered), client: client))

        XCTAssertEqual(lastSentLine(client), "AUTHENTICATE *")
    }

    func testServerNonceNotPrefixedByClientNonceAborts() {
        let client = makeClient()
        let handler = makeHandler(client)

        handler.handleResponse(message: authenticate("+", client: client))
        let forgedFirst = "r=totallyDifferentNonce,s=W22ZaJ0SNY7soEsUEjb6gQ==,i=4096"
        handler.handleResponse(message: authenticate(base64(forgedFirst), client: client))

        XCTAssertEqual(lastSentLine(client), "AUTHENTICATE *")
    }

    func testServerErrorAttributeAborts() {
        let client = makeClient()
        let handler = makeHandler(client)

        handler.handleResponse(message: authenticate("+", client: client))
        handler.handleResponse(message: authenticate(base64("e=invalid-proof"), client: client))

        XCTAssertEqual(lastSentLine(client), "AUTHENTICATE *")
    }
}
