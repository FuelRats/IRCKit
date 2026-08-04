import XCTest
@testable import IRCKit

/// Tests that inbound commands reach the correct handler and produce the expected notification.
/// Guards two previously-broken advertised features: invite-notify (INVITE was routed to the KICK
/// handler with swapped parameters) and MONITOR (730/731 replies were never dispatched).
final class EventDispatchTests: XCTestCase {
    /// Collects payloads delivered on the notification (main) queue so the test thread can read them
    /// after `wait(for:)`. Mutated only on the main queue; read only after the wait completes.
    private final class Collector<Value>: @unchecked Sendable {
        private(set) var values: [Value] = []
        func append(_ value: Value) {
            values.append(value)
        }
    }

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

    func testInviteIsDispatchedWithCorrectFields() {
        let client = makeClient()
        let received = expectation(description: "invite notification")
        let collector = Collector<IRCChannelInviteNotification.IRCChannelInvite>()
        let token = NotificationCenter.default.addObserver(
            descriptor: IRCChannelInviteNotification(),
            queue: .main
        ) { payload in
            collector.append(payload)
            received.fulfill()
        }

        // `<inviter> INVITE <invited nick> <channel>` — the channel is not one we are in.
        client.didReceiveDataFromConnection(data: ":inviter!u@host INVITE tester #secret")

        wait(for: [received], timeout: 2.0)
        withExtendedLifetime(token) {}
        let invite = collector.values.first
        XCTAssertEqual(invite?.invitedNick, "tester")
        XCTAssertEqual(invite?.channel.name, "#secret")
        XCTAssertEqual(invite?.sender.nickname, "inviter")
    }

    func testMonitorOnlineReplyIsDispatchedPerTarget() {
        let client = makeClient()
        let received = expectation(description: "online notifications")
        received.expectedFulfillmentCount = 2
        let collector = Collector<String>()
        let token = NotificationCenter.default.addObserver(
            descriptor: IRCUserOnlineNotification(),
            queue: .main
        ) { target in
            collector.append(target)
            received.fulfill()
        }

        client.didReceiveDataFromConnection(data: ":irc.example.org 730 tester :Alice!a@host,Bob!b@host")

        wait(for: [received], timeout: 2.0)
        withExtendedLifetime(token) {}
        XCTAssertEqual(collector.values.sorted(), ["Alice!a@host", "Bob!b@host"])
    }

    func testMonitorOfflineReplyIsDispatched() {
        let client = makeClient()
        let received = expectation(description: "offline notification")
        let collector = Collector<String>()
        let token = NotificationCenter.default.addObserver(
            descriptor: IRCUserOfflineNotification(),
            queue: .main
        ) { target in
            collector.append(target)
            received.fulfill()
        }

        client.didReceiveDataFromConnection(data: ":irc.example.org 731 tester :Alice")

        wait(for: [received], timeout: 2.0)
        withExtendedLifetime(token) {}
        XCTAssertEqual(collector.values, ["Alice"])
    }
}
