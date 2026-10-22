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

/// Tests for splitting long messages into protocol-sized chunks, and for the outbound checks that keep caller text
/// from changing the shape of a line.
final class MessageSplittingTests: XCTestCase {
    private func queueingClient() -> IRCClient {
        var configuration = IRCTestSupport.configuration()
        configuration.floodControlMaximumMessages = 0
        return IRCClient(configuration: configuration)
    }

    private func assertChunks(_ chunks: [String], of original: String, fitIn maxBytes: Int,
                              file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertFalse(chunks.isEmpty, file: file, line: line)
        for chunk in chunks {
            XCTAssertFalse(chunk.isEmpty, "no empty chunks", file: file, line: line)
            XCTAssertLessThanOrEqual(chunk.utf8.count, maxBytes, file: file, line: line)
        }
        let rejoinedScalars = chunks.joined().unicodeScalars.filter({ $0.properties.isWhitespace == false })
        let originalScalars = original.unicodeScalars.filter({ $0.properties.isWhitespace == false })
        XCTAssertEqual(String(String.UnicodeScalarView(rejoinedScalars)),
                       String(String.UnicodeScalarView(originalScalars)),
                       "only whitespace at split points may be dropped", file: file, line: line)
    }

    func testShortMessageIsSentWhole() {
        XCTAssertEqual(IRCClient.splitMessage("hello there", maxBytes: 100), ["hello there"])
    }

    func testSplitsAtLastWhitespaceBeforeLimit() {
        let chunks = IRCClient.splitMessage("aaaa bbbb cccc dddd", maxBytes: 32)
        XCTAssertEqual(chunks, ["aaaa bbbb cccc dddd"])
        let long = Array(repeating: "word", count: 30).joined(separator: " ")
        let split = IRCClient.splitMessage(long, maxBytes: 40)
        assertChunks(split, of: long, fitIn: 40)
        XCTAssertTrue(split.dropLast().allSatisfy({ $0.hasSuffix("word") }), "splits fall on word boundaries")
        XCTAssertFalse(split.contains(where: { $0.hasPrefix(" ") }), "continuation chunks don't start with a space")
    }

    func testLeadingWhitespaceFollowedByUnbrokenRunTerminates() {
        // Previously the split landed on the leading space, emitted an empty chunk and never advanced.
        let text = " " + String(repeating: "x", count: 600)
        let chunks = IRCClient.splitMessage(text, maxBytes: 100)
        assertChunks(chunks, of: text, fitIn: 100)
        XCTAssertEqual(chunks.count, 7)
    }

    func testUnbrokenRunSplitsOnCharacterBoundaries() {
        let text = String(repeating: "é", count: 400)
        let chunks = IRCClient.splitMessage(text, maxBytes: 101)
        assertChunks(chunks, of: text, fitIn: 101)
    }

    func testSingleClusterLargerThanLimitSplitsOnScalarBoundaries() {
        // One grapheme cluster of ~481 bytes; previously this trapped on index(before: startIndex).
        let text = "e" + String(repeating: "\u{0301}", count: 240)
        let chunks = IRCClient.splitMessage(text, maxBytes: 100)
        XCTAssertGreaterThan(chunks.count, 1)
        for chunk in chunks {
            XCTAssertFalse(chunk.isEmpty)
            XCTAssertLessThanOrEqual(chunk.utf8.count, 100)
        }
        XCTAssertEqual(chunks.map({ $0.unicodeScalars.count }).reduce(0, +), text.unicodeScalars.count)
    }

    func testNonPositiveBudgetIsClampedSoSplittingTerminates() {
        let text = String(repeating: "abc ", count: 50)
        let chunks = IRCClient.splitMessage(text, maxBytes: -20)
        assertChunks(chunks, of: text, fitIn: IRCClient.minimumSplitBytes)
    }

    func testSendMessageStripsCTCPDelimiterFromText() {
        let client = queueingClient()
        client.sendMessage(toTarget: "#channel", contents: "\u{001}VERSION\u{001}")
        XCTAssertEqual(client.connection.sendQueue.last, "PRIVMSG #channel VERSION")
    }

    func testSendNoticeStripsCTCPDelimiterFromText() {
        let client = queueingClient()
        client.sendNotice(toTarget: "someone", contents: "\u{001}PING 1\u{001}")
        XCTAssertEqual(client.connection.sendQueue.last, "NOTICE someone :PING 1")
    }

    func testActionMessageStillUsesCTCP() {
        let client = queueingClient()
        client.sendActionMessage(toChannelName: "#channel", contents: "waves")
        XCTAssertEqual(client.connection.sendQueue.last, "PRIVMSG #channel :\u{001}ACTION waves\u{001}")
    }

    func testNonTrailingParameterWithSpaceIsRefused() {
        let client = queueingClient()
        client.send("CNOTICE", parameters: ["someone", "#fuelrats :spoofed", "text"])
        XCTAssertTrue(client.connection.sendQueue.isEmpty)
    }

    func testEmptyNonTrailingParameterIsRefused() {
        let client = queueingClient()
        client.send("KICK", parameters: ["", "victim", "bye"])
        XCTAssertTrue(client.connection.sendQueue.isEmpty)
    }

    func testActionMessageTextCannotCloseTheCTCPEarly() {
        let client = queueingClient()
        client.sendActionMessage(toChannelName: "#channel", contents: "waves\u{001} \u{001}VERSION")
        XCTAssertEqual(client.connection.sendQueue.last, "PRIVMSG #channel :\u{001}ACTION waves VERSION\u{001}")
    }

    func testNonTrailingParameterStartingWithColonIsRefused() {
        let client = queueingClient()
        client.send("PRIVMSG", parameters: [":#fuelrats", "text"])
        XCTAssertTrue(client.connection.sendQueue.isEmpty)
    }

    func testNewlineInNonTrailingParameterCannotInjectCommand() {
        let client = queueingClient()
        client.send("PRIVMSG", parameters: ["#channel\r\nQUIT", "hi"])
        XCTAssertEqual(client.connection.sendQueue.last, "PRIVMSG #channelQUIT hi")
    }
}
