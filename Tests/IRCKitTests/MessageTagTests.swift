import XCTest
@testable import IRCKit

/// Tests for IRCv3 message-tag value escaping/unescaping (message-tags spec) and its integration
/// into inbound message parsing.
final class MessageTagTests: XCTestCase {
    private func makeClient() -> IRCClient {
        let configuration = IRCClientConfiguration(
            serverName: "test",
            serverAddress: "irc.example.org",
            serverPort: 6697,
            nickname: "tester",
            username: "tester",
            realName: "Integration Tester"
        )
        return IRCClient(configuration: configuration)
    }

    func testUnescapeKnownSequences() {
        XCTAssertEqual("a\\:b".ircTagValueUnescaped(), "a;b")
        XCTAssertEqual("a\\sb".ircTagValueUnescaped(), "a b")
        XCTAssertEqual("a\\\\b".ircTagValueUnescaped(), "a\\b")
        XCTAssertEqual("a\\rb".ircTagValueUnescaped(), "a\rb")
        XCTAssertEqual("a\\nb".ircTagValueUnescaped(), "a\nb")
    }

    func testUnescapeEdgeCases() {
        // Unrecognised escapes resolve to the escaped character itself.
        XCTAssertEqual("a\\xb".ircTagValueUnescaped(), "axb")
        // A trailing lone backslash is dropped.
        XCTAssertEqual("abc\\".ircTagValueUnescaped(), "abc")
        // A value with no escapes is unchanged.
        XCTAssertEqual("plain".ircTagValueUnescaped(), "plain")
    }

    func testEscapeKnownSequences() {
        XCTAssertEqual("a;b".ircTagValueEscaped(), "a\\:b")
        XCTAssertEqual("a b".ircTagValueEscaped(), "a\\sb")
        XCTAssertEqual("a\\b".ircTagValueEscaped(), "a\\\\b")
        XCTAssertEqual("a\rb".ircTagValueEscaped(), "a\\rb")
        XCTAssertEqual("a\nb".ircTagValueEscaped(), "a\\nb")
    }

    func testEscapeUnescapeRoundTrip() {
        let originals = [
            "simple",
            "has spaces and ; semicolons",
            "back\\slash and \r\n newlines",
            "\\:\\s\\\\",
            ""
        ]
        for original in originals {
            XCTAssertEqual(original.ircTagValueEscaped().ircTagValueUnescaped(), original)
        }
    }

    func testEscapingHappensBeforeSeparatorMeaning() {
        // A raw semicolon and space must survive a round trip without being read as tag/word
        // separators once escaped.
        let value = "key1=val1;key2=val2 trailing"
        XCTAssertEqual(value.ircTagValueEscaped().ircTagValueUnescaped(), value)
        XCTAssertFalse(value.ircTagValueEscaped().contains(";"))
        XCTAssertFalse(value.ircTagValueEscaped().contains(" "))
    }

    func testInboundParsingUnescapesTagValues() {
        let client = makeClient()
        let message = IRCMessage(
            line: "@account=a\\sb;+example/tag=x\\:y :nick!user@host PRIVMSG #channel :hi",
            client: client
        )
        XCTAssertEqual(message?.messageTags["account"], "a b")
        XCTAssertEqual(message?.messageTags["+example/tag"], "x;y")
    }
}
