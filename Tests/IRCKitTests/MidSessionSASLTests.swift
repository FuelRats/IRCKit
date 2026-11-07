import XCTest
@testable import IRCKit

/// Tests for SASL that becomes available after registration: services link late and the server announces
/// `sasl` with a cap-notify `CAP NEW`.
final class MidSessionSASLTests: XCTestCase {
    /// Returns a client that completed registration without SASL (the server did not offer it), joined
    /// `#ratchat` and was refused `#rat-ops`. Outbound lines are captured in `IRCConnection.sendQueue`.
    private func registeredClient(configure: (inout IRCClientConfiguration) -> Void = { _ in }) -> IRCClient {
        var configuration = IRCTestSupport.configuration()
        configuration.floodControlMaximumMessages = 0
        configuration.authenticationUsername = "tester"
        configuration.authenticationPassword = "s3cr3t"
        configuration.channels = ["#RatChat", "#rat-ops"]
        configure(&configuration)
        let client = IRCClient(configuration: configuration)
        client.didReceiveDataFromConnection(data: ":irc.example.org CAP * LS :cap-notify")
        client.didReceiveDataFromConnection(data: ":irc.example.org CAP * ACK :cap-notify")
        client.didReceiveDataFromConnection(
            data: ":irc.example.org 001 tester :Welcome to the Fuel Rats IRC Network tester!tester@rat.example.org"
        )
        client.didReceiveDataFromConnection(data: ":tester!tester@rat.example.org JOIN #ratchat")
        client.didReceiveDataFromConnection(
            data: ":irc.example.org 477 tester #rat-ops :You need a registered nick to join that channel."
        )
        return client
    }

    /// The lines the client queued after `mark` lines had already been queued.
    private func sent(_ client: IRCClient, since mark: Int) -> [String] {
        return Array(client.connection.sendQueue.dropFirst(mark))
    }

    func testCapNewSaslAuthenticatesAndJoinsMissingChannels() {
        let client = registeredClient()
        XCTAssertTrue(client.capabilityNegotiationComplete)
        let mark = client.connection.sendQueue.count

        client.didReceiveDataFromConnection(data: ":irc.example.org CAP tester NEW :sasl=PLAIN,EXTERNAL")
        XCTAssertTrue(sent(client, since: mark).contains("CAP REQ sasl"))

        client.didReceiveDataFromConnection(data: ":irc.example.org CAP tester ACK :sasl")
        XCTAssertTrue(sent(client, since: mark).contains("AUTHENTICATE PLAIN"))

        client.didReceiveDataFromConnection(data: "AUTHENTICATE +")
        client.didReceiveDataFromConnection(
            data: ":irc.example.org 900 tester tester!tester@rat.example.org tester :You are now logged in as tester"
        )
        client.didReceiveDataFromConnection(data: ":irc.example.org 903 tester :SASL authentication successful")

        let lines = sent(client, since: mark)
        // #RatChat is already joined (as #ratchat), so only the refused channel is retried.
        XCTAssertEqual(lines.filter({ $0.hasPrefix("JOIN ") }), ["JOIN #rat-ops"])
        XCTAssertFalse(lines.contains("CAP END"))
        XCTAssertTrue(client.isLoggedIn)
    }

    func testCapNewSaslWithoutMechanismListFallsBackToPlain() {
        let client = registeredClient()
        let mark = client.connection.sendQueue.count

        client.didReceiveDataFromConnection(data: ":irc.example.org CAP tester NEW :sasl")
        client.didReceiveDataFromConnection(data: ":irc.example.org CAP tester ACK :sasl")

        XCTAssertTrue(sent(client, since: mark).contains("AUTHENTICATE PLAIN"))
    }

    func testCapNewSaslSkippedWhenAlreadyLoggedIn() {
        let client = registeredClient()
        client.didReceiveDataFromConnection(
            data: ":irc.example.org 900 tester tester!tester@rat.example.org tester :You are now logged in as tester"
        )
        let mark = client.connection.sendQueue.count

        client.didReceiveDataFromConnection(data: ":irc.example.org CAP tester NEW :sasl=PLAIN,EXTERNAL")
        client.didReceiveDataFromConnection(data: ":irc.example.org CAP tester ACK :sasl")

        XCTAssertTrue(client.serverInfo.enabledIRCv3Capabilities.contains(.sasl))
        XCTAssertFalse(sent(client, since: mark).contains(where: { $0.hasPrefix("AUTHENTICATE") }))
    }

    func testCapNewSaslSkippedWithoutCredentials() {
        let client = registeredClient { $0.authenticationPassword = nil }
        let mark = client.connection.sendQueue.count

        client.didReceiveDataFromConnection(data: ":irc.example.org CAP tester NEW :sasl=PLAIN,EXTERNAL")
        client.didReceiveDataFromConnection(data: ":irc.example.org CAP tester ACK :sasl")

        XCTAssertFalse(sent(client, since: mark).contains(where: { $0.hasPrefix("AUTHENTICATE") }))
    }

    func testMidSessionSaslFailureSendsNeitherCapEndNorJoin() {
        let client = registeredClient()
        let mark = client.connection.sendQueue.count

        client.didReceiveDataFromConnection(data: ":irc.example.org CAP tester NEW :sasl=PLAIN,EXTERNAL")
        client.didReceiveDataFromConnection(data: ":irc.example.org CAP tester ACK :sasl")
        client.didReceiveDataFromConnection(data: "AUTHENTICATE +")
        client.didReceiveDataFromConnection(data: ":irc.example.org 904 tester :SASL authentication failed")

        let lines = sent(client, since: mark)
        XCTAssertTrue(lines.contains("AUTHENTICATE PLAIN"))
        XCTAssertFalse(lines.contains("CAP END"))
        XCTAssertFalse(lines.contains(where: { $0.hasPrefix("JOIN ") }))
        XCTAssertFalse(client.isLoggedIn)
    }

    func testLoggedOutAndDisconnectClearLoginState() {
        let client = registeredClient()
        client.didReceiveDataFromConnection(
            data: ":irc.example.org 900 tester tester!tester@rat.example.org tester :You are now logged in as tester"
        )
        XCTAssertTrue(client.isLoggedIn)

        client.didReceiveDataFromConnection(
            data: ":irc.example.org 901 tester tester!tester@rat.example.org :You are now logged out"
        )
        XCTAssertFalse(client.isLoggedIn)

        client.didReceiveDataFromConnection(
            data: ":irc.example.org 900 tester tester!tester@rat.example.org tester :You are now logged in as tester"
        )
        client.didDisconnectFromHost()
        XCTAssertFalse(client.isLoggedIn)
    }

    func testInitialHandshakeSaslEndsNegotiationOnce() {
        var configuration = IRCTestSupport.configuration()
        configuration.floodControlMaximumMessages = 0
        configuration.authenticationPassword = "s3cr3t"
        configuration.channels = ["#ratchat"]
        let client = IRCClient(configuration: configuration)

        client.didReceiveDataFromConnection(data: ":irc.example.org CAP * LS :cap-notify sasl=PLAIN,EXTERNAL")
        client.didReceiveDataFromConnection(data: ":irc.example.org CAP * ACK :cap-notify sasl")
        XCTAssertTrue(client.connection.sendQueue.contains("AUTHENTICATE PLAIN"))
        XCTAssertFalse(client.connection.sendQueue.contains("CAP END"))

        client.didReceiveDataFromConnection(data: "AUTHENTICATE +")
        client.didReceiveDataFromConnection(data: ":irc.example.org 903 * :SASL authentication successful")

        XCTAssertEqual(client.connection.sendQueue.filter({ $0 == "CAP END" }).count, 1)
        // Channels are joined on RPL_WELCOME, not on SASL completion during registration.
        XCTAssertFalse(client.connection.sendQueue.contains(where: { $0.hasPrefix("JOIN ") }))
    }
}
