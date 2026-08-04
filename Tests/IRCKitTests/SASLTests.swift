import Foundation
import XCTest
@testable import IRCKit

/// Tests for SASL mechanism selection and the PLAIN authentication payload.
final class SASLTests: XCTestCase {
    /// Setting the flood-control ceiling to zero forces every outbound line into
    /// `IRCConnection.sendQueue` (rather than being written to a socket that isn't connected), so a
    /// test can inspect exactly what the client would have sent.
    private func queueingClient(configure: (inout IRCClientConfiguration) -> Void = { _ in }) -> IRCClient {
        var configuration = IRCTestSupport.configuration()
        configuration.floodControlMaximumMessages = 0
        configure(&configuration)
        return IRCClient(configuration: configuration)
    }

    func testExternalIsPreferredWhenClientCertificateConfigured() {
        let client = queueingClient { $0.clientCertificatePath = "/path/to/cert.pem" }
        client.serverInfo.supportedSASLMechanisms = [PlainTextSASLHandler.self, ExternalSASLHandler.self]

        XCTAssertTrue(client.saslNegotiation())
        XCTAssertTrue(client.activeAuthenticationHandler is ExternalSASLHandler)
    }

    func testScramIsPreferredOverPlainWhenBothOffered() {
        let client = queueingClient { $0.authenticationPassword = "s3cr3t" }
        client.serverInfo.supportedSASLMechanisms = [PlainTextSASLHandler.self, Sha256SASLHandler.self]

        XCTAssertTrue(client.saslNegotiation())
        XCTAssertTrue(client.activeAuthenticationHandler is Sha256SASLHandler)
    }

    func testPlainIsSelectedWhenOnlyMechanismOffered() {
        let client = queueingClient { $0.authenticationPassword = "s3cr3t" }
        client.serverInfo.supportedSASLMechanisms = [PlainTextSASLHandler.self]

        XCTAssertTrue(client.saslNegotiation())
        XCTAssertTrue(client.activeAuthenticationHandler is PlainTextSASLHandler)
    }

    func testNegotiationFailsWithoutCredentials() {
        let client = queueingClient()
        client.serverInfo.supportedSASLMechanisms = [PlainTextSASLHandler.self]

        XCTAssertFalse(client.saslNegotiation())
        XCTAssertNil(client.activeAuthenticationHandler)
    }

    func testPlainProducesCorrectAuthenticatePayload() {
        let client = queueingClient {
            $0.authenticationUsername = "alice"
            $0.authenticationPassword = "s3cr3t"
        }
        client.serverInfo.supportedSASLMechanisms = [PlainTextSASLHandler.self]

        XCTAssertTrue(client.saslNegotiation())
        // The server acknowledges the mechanism with an empty challenge; the client responds with the
        // base64-encoded `authzid\0authcid\0passwd` credential.
        client.didReceiveDataFromConnection(data: "AUTHENTICATE +")

        let payloadLine = client.connection.sendQueue.last(where: {
            $0.hasPrefix("AUTHENTICATE ") && $0 != "AUTHENTICATE PLAIN"
        })
        let base64 = payloadLine.map { String($0.dropFirst("AUTHENTICATE ".count)) }
        let decoded = base64
            .flatMap { Data(base64Encoded: $0) }
            .flatMap { String(data: $0, encoding: .utf8) }
        XCTAssertEqual(decoded, "alice\u{0}alice\u{0}s3cr3t")
    }
}
