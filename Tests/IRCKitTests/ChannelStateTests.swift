import XCTest
@testable import IRCKit

/// Tests that channel and membership state only reflects the current session.
final class ChannelStateTests: XCTestCase {
    private func joinedClient() -> IRCClient {
        let client = IRCTestSupport.client()
        client.addChannel(channel: IRCChannel(channelName: "#fuelrats", onClient: client))
        client.didReceiveDataFromConnection(data: ":alice!alice@rat.fuelrats.com JOIN #fuelrats")
        return client
    }

    func testDisconnectClearsChannelState() {
        let client = joinedClient()
        XCTAssertNotNil(client.getChannel(named: "#fuelrats")?.member(named: "alice"))

        client.didDisconnectFromHost()

        XCTAssertTrue(client.channels.isEmpty, "stale members must not survive into the next session")
    }

    func testBeingKickedRemovesTheChannel() {
        let client = joinedClient()
        client.didReceiveDataFromConnection(data: ":op!op@host KICK #fuelrats tester :bye")
        XCTAssertNil(client.getChannel(named: "#fuelrats"))
    }

    func testKickingSomeoneElseKeepsTheChannel() {
        let client = joinedClient()
        client.didReceiveDataFromConnection(data: ":tester!tester@host KICK #fuelrats alice :bye")
        let channel = client.getChannel(named: "#fuelrats")
        XCTAssertNotNil(channel)
        XCTAssertNil(channel?.member(named: "alice"))
    }

    func testMembershipIsSafeUnderConcurrentAccess() {
        let client = joinedClient()
        let channel = client.getChannel(named: "#fuelrats")!
        DispatchQueue.concurrentPerform(iterations: 2000) { iteration in
            let nick = "rat\(iteration % 50)"
            if iteration % 2 == 0 {
                channel.add(member: IRCUser(
                    onClient: client, nickname: nick, username: nick, hostmask: "host", realName: nil, account: nil))
            } else {
                channel.remove(named: nick)
            }
            _ = channel.member(named: "alice")
            _ = client.channels.count
        }
        XCTAssertNotNil(channel.member(named: "alice"))
    }

    func testServerNameIndicationIsOmittedForIPLiterals() {
        XCTAssertNil(IRCConnection.serverNameIndication(for: "203.0.113.7"))
        XCTAssertNil(IRCConnection.serverNameIndication(for: "2001:db8::1"))
        XCTAssertEqual(IRCConnection.serverNameIndication(for: "irc.fuelrats.com"), "irc.fuelrats.com")
    }
}
