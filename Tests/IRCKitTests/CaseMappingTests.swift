import XCTest
@testable import IRCKit

/// Tests for CASEMAPPING-aware folding of nicknames and channel names (RFC 2812 §2.2) and its use in
/// channel/member lookups.
final class CaseMappingTests: XCTestCase {
    func testAsciiFoldingOnlyLowercasesLetters() {
        XCTAssertEqual("Nick[]\\~".ircCaseFolded(mapping: "ascii"), "nick[]\\~")
    }

    func testRfc1459FoldsBracketsAndTilde() {
        XCTAssertEqual("Nick[]\\~".ircCaseFolded(mapping: "rfc1459"), "nick{}|^")
    }

    func testRfc1459StrictFoldsBracketsButNotTilde() {
        XCTAssertEqual("Nick[]\\~".ircCaseFolded(mapping: "rfc1459-strict"), "nick{}|~")
    }

    func testDefaultsToRfc1459WhenMappingUnspecified() {
        XCTAssertEqual("A[".ircCaseFolded(mapping: nil), "a{")
    }

    func testChannelLookupIsCaseInsensitive() {
        let client = IRCTestSupport.client()
        client.didReceiveDataFromConnection(data: ":tester!u@host JOIN #Channel")
        // A later reference using different case must resolve to the same channel.
        XCTAssertNotNil(client.getChannel(named: "#channel"))
        XCTAssertNotNil(client.getChannel(named: "#CHANNEL"))
    }

    func testChannelLookupHonoursRfc1459BracketEquivalence() {
        let client = IRCTestSupport.client()
        client.didReceiveDataFromConnection(data: ":tester!u@host JOIN #foo[bar]")
        // Under rfc1459 (the default), '[' == '{' and ']' == '}'.
        XCTAssertNotNil(client.getChannel(named: "#foo{bar}"))
    }

    func testMemberLookupIsCaseInsensitive() {
        let client = IRCTestSupport.client()
        client.didReceiveDataFromConnection(data: ":tester!u@host JOIN #chan")
        client.didReceiveDataFromConnection(data: ":Alice!a@host JOIN #chan")

        let channel = client.getChannel(named: "#chan")
        XCTAssertNotNil(channel?.member(named: "alice"))
        XCTAssertNotNil(channel?.member(named: "ALICE"))
    }

    func testPartRemovesMemberRegardlessOfCase() {
        let client = IRCTestSupport.client()
        client.didReceiveDataFromConnection(data: ":tester!u@host JOIN #chan")
        client.didReceiveDataFromConnection(data: ":Alice!a@host JOIN #chan")
        // Server refers to the same user with different case on PART.
        client.didReceiveDataFromConnection(data: ":ALICE!a@host PART #chan")

        XCTAssertNil(client.getChannel(named: "#chan")?.member(named: "alice"))
    }
}
