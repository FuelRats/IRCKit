import XCTest
@testable import IRCKit

/// Tests for cap-notify: `CAP NEW` and `CAP DEL` handling after the initial capability handshake.
final class CapNotifyTests: XCTestCase {
    /// Runs the initial capability handshake to completion (LS → REQ → ACK → CAP END) and returns the
    /// client, whose outbound lines are captured in `IRCConnection.sendQueue`.
    private func negotiatedClient(offered: String, acked: String) -> IRCClient {
        var configuration = IRCTestSupport.configuration()
        configuration.floodControlMaximumMessages = 0
        let client = IRCClient(configuration: configuration)
        client.didReceiveDataFromConnection(data: ":irc.example.org CAP * LS :\(offered)")
        client.didReceiveDataFromConnection(data: ":irc.example.org CAP * ACK :\(acked)")
        return client
    }

    private func capEndCount(_ client: IRCClient) -> Int {
        return client.connection.sendQueue.filter({ $0 == "CAP END" }).count
    }

    func testInitialHandshakeSendsOneCapEnd() {
        let client = negotiatedClient(offered: "message-tags server-time", acked: "message-tags server-time")
        XCTAssertEqual(capEndCount(client), 1)
        XCTAssertTrue(client.capabilityNegotiationComplete)
        XCTAssertTrue(client.serverInfo.enabledIRCv3Capabilities.contains(.messageTags))
        XCTAssertTrue(client.serverInfo.enabledIRCv3Capabilities.contains(.serverSentTimestamps))
    }

    func testCapDelDisablesCapability() {
        let client = negotiatedClient(offered: "message-tags server-time", acked: "message-tags server-time")
        client.didReceiveDataFromConnection(data: ":irc.example.org CAP * DEL :server-time")

        XCTAssertFalse(client.serverInfo.enabledIRCv3Capabilities.contains(.serverSentTimestamps))
        XCTAssertFalse(client.serverInfo.supportedIRCv3Capabilities.contains(.serverSentTimestamps))
        XCTAssertTrue(client.serverInfo.enabledIRCv3Capabilities.contains(.messageTags))
    }

    func testCapNewRequestsNewlyOfferedCapability() {
        let client = negotiatedClient(offered: "message-tags", acked: "message-tags")
        client.didReceiveDataFromConnection(data: ":irc.example.org CAP * NEW :echo-message")

        XCTAssertTrue(client.serverInfo.supportedIRCv3Capabilities.contains(.messageConfirmation))
        XCTAssertTrue(client.connection.sendQueue.contains(where: {
            $0.hasPrefix("CAP REQ") && $0.contains("echo-message")
        }))
    }

    func testMidSessionAckEnablesWithoutAnotherCapEnd() {
        let client = negotiatedClient(offered: "message-tags", acked: "message-tags")
        let endsBefore = capEndCount(client)

        client.didReceiveDataFromConnection(data: ":irc.example.org CAP * NEW :echo-message")
        client.didReceiveDataFromConnection(data: ":irc.example.org CAP * ACK :echo-message")

        XCTAssertTrue(client.serverInfo.enabledIRCv3Capabilities.contains(.messageConfirmation))
        XCTAssertEqual(capEndCount(client), endsBefore)
    }
}
