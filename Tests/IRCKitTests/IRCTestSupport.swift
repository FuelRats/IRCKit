@testable import IRCKit

/// Shared factories for building an offline `IRCClient` in tests. `autoConnect` defaults to false, so
/// no network connection is opened.
enum IRCTestSupport {
    static func configuration() -> IRCClientConfiguration {
        IRCClientConfiguration(
            serverName: "test",
            serverAddress: "irc.example.org",
            serverPort: 6697,
            nickname: "tester",
            username: "tester",
            realName: "Integration Tester"
        )
    }

    static func client() -> IRCClient {
        IRCClient(configuration: configuration())
    }
}
