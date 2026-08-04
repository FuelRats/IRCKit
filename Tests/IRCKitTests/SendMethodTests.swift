import XCTest
@testable import IRCKit

/// Tests for outbound line construction in `IRCClient.send`: trailing-parameter quoting and
/// sanitisation of forbidden characters.
final class SendMethodTests: XCTestCase {
    /// A client whose outbound lines accumulate in `IRCConnection.sendQueue` rather than being
    /// written to a socket that isn't connected.
    private func queueingClient() -> IRCClient {
        var configuration = IRCTestSupport.configuration()
        configuration.floodControlMaximumMessages = 0
        return IRCClient(configuration: configuration)
    }

    private func lastLine(_ client: IRCClient) -> String? {
        return client.connection.sendQueue.last
    }

    func testTrailingParameterWithSpaceIsColonPrefixed() {
        let client = queueingClient()
        client.send("PRIVMSG", parameters: ["#channel", "hello world"])
        XCTAssertEqual(lastLine(client), "PRIVMSG #channel :hello world")
    }

    func testTrailingParameterStartingWithColonIsColonPrefixed() {
        let client = queueingClient()
        // A one-word message that begins with ':' must still be quoted, or it reads as empty.
        client.send("PRIVMSG", parameters: ["#channel", ":)"])
        XCTAssertEqual(lastLine(client), "PRIVMSG #channel ::)")
    }

    func testEmptyTrailingParameterIsColonPrefixed() {
        let client = queueingClient()
        client.send("PART", parameters: ["#channel", ""])
        XCTAssertEqual(lastLine(client), "PART #channel :")
    }

    func testSingleWordTrailingParameterIsNotColonPrefixed() {
        let client = queueingClient()
        client.send("PRIVMSG", parameters: ["#channel", "hello"])
        XCTAssertEqual(lastLine(client), "PRIVMSG #channel hello")
    }

    func testSingleParameterIsNotColonPrefixed() {
        let client = queueingClient()
        client.send("JOIN", parameters: ["#channel"])
        XCTAssertEqual(lastLine(client), "JOIN #channel")
    }

    func testForbiddenCharactersAreStrippedToPreventInjection() {
        let client = queueingClient()
        client.send("PRIVMSG", parameters: ["#channel", "hi there\r\nJOIN #evil"])
        let line = lastLine(client)
        XCTAssertEqual(line, "PRIVMSG #channel :hi thereJOIN #evil")
        XCTAssertEqual(line?.contains("\r"), false)
        XCTAssertEqual(line?.contains("\n"), false)
    }

    func testPongEchoesTokenWithoutDoubleColon() {
        let client = queueingClient()
        client.didReceiveDataFromConnection(data: ":irc.example.org PING :LAG1234567")
        XCTAssertEqual(lastLine(client), "PONG LAG1234567")
    }

    func testPongQuotesTokenContainingSpace() {
        let client = queueingClient()
        client.didReceiveDataFromConnection(data: ":irc.example.org PING :tok en")
        XCTAssertEqual(lastLine(client), "PONG :tok en")
    }
}
