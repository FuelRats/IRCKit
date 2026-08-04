import Foundation
import XCTest
@testable import IRCKit

/// Tests for channel metadata numerics whose timestamps are Unix epoch seconds (not ISO8601).
final class ChannelInfoTests: XCTestCase {
    private let epochSeconds: TimeInterval = 1_609_459_200  // 2021-01-01T00:00:00Z

    private func clientJoinedTo(_ channelName: String) -> IRCClient {
        let client = IRCTestSupport.client()
        client.didReceiveDataFromConnection(data: ":tester!u@host JOIN \(channelName)")
        return client
    }

    private func channel(_ client: IRCClient, _ name: String) -> IRCChannel? {
        return client.channels.first(where: { $0.name == name })
    }

    func testTopicWhoTimeParsesUnixTimestamp() {
        let client = clientJoinedTo("#chan")
        client.didReceiveDataFromConnection(data: ":irc.example.org 332 tester #chan :The topic")
        client.didReceiveDataFromConnection(data: ":irc.example.org 333 tester #chan setterNick 1609459200")

        let topic = channel(client, "#chan")?.topic
        XCTAssertEqual(topic?.author, "setterNick")
        XCTAssertEqual(topic?.date, Date(timeIntervalSince1970: epochSeconds))
    }

    func testCreationTimeParsesUnixTimestamp() {
        let client = clientJoinedTo("#chan")
        client.didReceiveDataFromConnection(data: ":irc.example.org 329 tester #chan 1609459200")

        XCTAssertEqual(channel(client, "#chan")?.createdAt, Date(timeIntervalSince1970: epochSeconds))
    }

    func testNonNumericTimestampIsIgnored() {
        let client = clientJoinedTo("#chan")
        client.didReceiveDataFromConnection(data: ":irc.example.org 332 tester #chan :The topic")
        client.didReceiveDataFromConnection(data: ":irc.example.org 333 tester #chan setterNick notanumber")

        // The topic survives, but the unparseable set-time is dropped rather than crashing.
        XCTAssertEqual(channel(client, "#chan")?.topic?.contents, "The topic")
        XCTAssertNil(channel(client, "#chan")?.topic?.date)
    }
}
