import XCTest
@testable import IRCKit

/// Tests for the hand-rolled IRC wire parser in `IRCMessage`.
final class IRCMessageParsingTests: XCTestCase {
    func testParsesPrefixCommandAndParameters() {
        let message = IRCMessage(line: ":nick!user@host PRIVMSG #channel :hello world", client: IRCTestSupport.client())
        XCTAssertEqual(message?.command, .PRIVMSG)
        XCTAssertEqual(message?.sender?.nickname, "nick")
        XCTAssertEqual(message?.sender?.username, "user")
        XCTAssertEqual(message?.sender?.hostmask, "host")
        XCTAssertEqual(message?.sender?.isServer, false)
        XCTAssertEqual(message?.parameters, ["#channel", "hello world"])
    }

    func testParsesServerPrefix() {
        let message = IRCMessage(line: ":irc.example.org 001 tester :Welcome to the network", client: IRCTestSupport.client())
        XCTAssertEqual(message?.command, .RPL_WELCOME)
        XCTAssertEqual(message?.sender?.isServer, true)
        XCTAssertEqual(message?.sender?.nickname, "irc.example.org")
        XCTAssertNil(message?.sender?.username)
        XCTAssertEqual(message?.parameters, ["tester", "Welcome to the network"])
    }

    func testParsesMessageWithoutPrefix() {
        let message = IRCMessage(line: "PING :LAG1234567", client: IRCTestSupport.client())
        XCTAssertEqual(message?.command, .PING)
        XCTAssertNil(message?.sender)
        XCTAssertEqual(message?.parameters, ["LAG1234567"])
    }

    func testTrailingParameterPreservesSpacesAndColons() {
        let message = IRCMessage(line: ":n!u@h PRIVMSG #c :see http://x/y :end", client: IRCTestSupport.client())
        XCTAssertEqual(message?.parameters, ["#c", "see http://x/y :end"])
    }

    func testParsesMultipleMiddleParameters() {
        let message = IRCMessage(
            line: ":irc.example.org 353 tester = #channel :alice bob carol",
            client: IRCTestSupport.client()
        )
        XCTAssertEqual(message?.command, .RPL_NAMEREPLY)
        XCTAssertEqual(message?.parameters, ["tester", "=", "#channel", "alice bob carol"])
    }

    func testParsesTagsPrefixAndCommandTogether() {
        let message = IRCMessage(line: "@id=42;account=alice :n!u@h PRIVMSG #c :hi", client: IRCTestSupport.client())
        XCTAssertEqual(message?.messageTags["id"], "42")
        XCTAssertEqual(message?.account, "alice")
        XCTAssertEqual(message?.command, .PRIVMSG)
        XCTAssertEqual(message?.sender?.nickname, "n")
        XCTAssertEqual(message?.parameters, ["#c", "hi"])
    }

    func testMessageIdAndLabelFromTags() {
        let message = IRCMessage(line: "@msgid=abc123;label=req-1 :n!u@h PRIVMSG #c :hi", client: IRCTestSupport.client())
        XCTAssertEqual(message?.messageId, "abc123")
        XCTAssertEqual(message?.label, "req-1")
        XCTAssertEqual(message?.id, "req-1")
    }

    func testLabelDefaultsToRandomWhenAbsent() {
        let message = IRCMessage(line: ":n!u@h PRIVMSG #c :hi", client: IRCTestSupport.client())
        XCTAssertEqual(message?.label.isEmpty, false)
        XCTAssertNil(message?.messageId)
    }

    func testDetectsCTCPActionMessage() {
        let message = IRCMessage(line: ":n!u@h PRIVMSG #c :\u{01}ACTION waves\u{01}", client: IRCTestSupport.client())
        XCTAssertEqual(message?.isCTCPRequest, true)
        XCTAssertEqual(message?.isActionMessage, true)
    }

    func testPlainMessageIsNotCTCP() {
        let message = IRCMessage(line: ":n!u@h PRIVMSG #c :just text", client: IRCTestSupport.client())
        XCTAssertEqual(message?.isCTCPRequest, false)
        XCTAssertEqual(message?.isActionMessage, false)
    }

    func testUnknownCommandReturnsNil() {
        XCTAssertNil(IRCMessage(line: ":n!u@h FLOOOP #c :hi", client: IRCTestSupport.client()))
    }

    func testServerTimeTagIsParsedRatherThanNow() {
        let message = IRCMessage(
            line: "@time=2021-01-15T12:30:45.000Z :n!u@h PRIVMSG #c :hi",
            client: IRCTestSupport.client()
        )
        let expected = ISO8601DateFormatter().date(from: "2021-01-15T12:30:45Z")
        XCTAssertEqual(message?.time.timeIntervalSince1970, expected?.timeIntervalSince1970)
    }
}
