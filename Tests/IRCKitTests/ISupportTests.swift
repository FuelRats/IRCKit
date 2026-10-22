import XCTest
@testable import IRCKit

/// Tests for RPL_ISUPPORT (005) parsing in `IRCServerInfo.setSupported`.
final class ISupportTests: XCTestCase {
    func testParsesCommonTokens() {
        let client = IRCTestSupport.client()
        let line = ":irc.example.org 005 tester PREFIX=(ov)@+ CHANTYPES=# NETWORK=TestNet "
            + "CASEMAPPING=rfc1459 WHOX AWAYLEN=200 NICKLEN=30 MONITOR=100 :are supported by this server"
        client.didReceiveDataFromConnection(data: line)

        let info = client.serverInfo
        XCTAssertEqual(info.networkName, "TestNet")
        XCTAssertEqual(info.caseMapping, "rfc1459")
        XCTAssertTrue(info.supportsExtendedWhoQuery)
        XCTAssertTrue(info.supportsMonitor)
        XCTAssertEqual(info.maximumMonitorTargets, 100)
        XCTAssertEqual(info.maximumAwayMessageLength, 200)
        XCTAssertEqual(info.maximumNicknameLength, 30)
        XCTAssertEqual(info.prefixMapping[.operator], "@")
        XCTAssertEqual(info.prefixMapping[.voice], "+")
    }

    func testValuelessTokenIsRecognised() {
        let client = IRCTestSupport.client()
        XCTAssertFalse(client.serverInfo.supportsExtendedWhoQuery)
        client.didReceiveDataFromConnection(data: ":irc.example.org 005 tester WHOX :are supported by this server")
        XCTAssertTrue(client.serverInfo.supportsExtendedWhoQuery)
    }

    func testPrefixMappingReplacesDefault() {
        let client = IRCTestSupport.client()
        // Default mapping includes owner/admin/halfop; a server offering only o/v should narrow it.
        client.didReceiveDataFromConnection(data: ":irc.example.org 005 tester PREFIX=(ov)@+ :are supported")
        let mapping = client.serverInfo.prefixMapping
        XCTAssertEqual(mapping[.operator], "@")
        XCTAssertEqual(mapping[.voice], "+")
        XCTAssertNil(mapping[.owner])
    }

    func testMalformedPrefixYieldsEmptyMapping() {
        let client = IRCTestSupport.client()
        client.didReceiveDataFromConnection(data: ":irc.example.org 005 tester PREFIX=noparens :are supported")
        XCTAssertTrue(client.serverInfo.prefixMapping.isEmpty)
    }

    func testInvalidNumericValuesAreIgnored() {
        let client = IRCTestSupport.client()
        client.didReceiveDataFromConnection(data: ":irc.example.org 005 tester AWAYLEN=notanumber :are supported")
        XCTAssertNil(client.serverInfo.maximumAwayMessageLength)
    }
}
