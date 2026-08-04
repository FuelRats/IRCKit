import XCTest
@testable import IRCKit

/// Regression tests for parameter-bounds hardening: a malformed or hostile server must not be able
/// to crash the client by sending messages with missing parameters. A Swift out-of-bounds access is
/// a fatal trap, so these tests "pass" by the process surviving the dispatch of each malformed line.
final class MalformedMessageTests: XCTestCase {
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

    /// Every branch of the command dispatcher, fed a message that is missing the parameters its
    /// handler previously indexed unconditionally. None of these may trap.
    func testMalformedMessagesDoNotCrash() {
        let client = makeClient()

        let malformedLines = [
            // Registration / server info
            ":irc.example.org 004 tester",                       // RPL_MYINFO, missing 4 params
            ":irc.example.org 005",                              // RPL_ISUPPORT, no params
            ":irc.example.org 005 tester PREFIX=badvalue :ok",   // PREFIX without parentheses
            ":irc.example.org 005 tester PREFIX=)( :ok",         // PREFIX parens reversed
            // Capability negotiation
            ":irc.example.org CAP",                              // missing subcommand
            ":irc.example.org CAP * LS",                         // LS with no capability list
            ":irc.example.org CAP * ACK",                        // ACK with no capability list
            // Channel lifecycle
            ":n!u@h JOIN",                                       // JOIN with no channel
            ":n!u@h PART",                                       // PART with no channel
            ":n!u@h KICK #channel",                              // KICK with no target
            ":n!u@h INVITE tester",                              // INVITE with no channel
            ":n!u@h TOPIC #channel",                             // TOPIC with no text
            "MODE #channel",                                     // MODE with no modes and no prefix
            ":n!u@h MODE #channel",                              // MODE with no mode string
            // Messaging
            ":n!u@h PRIVMSG",                                    // PRIVMSG with no target/text
            ":n!u@h PRIVMSG #channel",                           // PRIVMSG with no text
            ":n!u@h NOTICE",                                     // NOTICE with no target/text
            ":n!u@h NOTICE tester",                              // NOTICE with no text
            ":irc.example.org PRIVMSG tester :from a server",    // server source lacks user!host
            ":irc.example.org NOTICE tester :from a server",     // server source lacks user!host
            // User events
            ":n!u@h NICK",                                       // NICK with no new nick
            ":n!u@h SETNAME",                                    // SETNAME with no realname
            ":n!u@h CHGHOST newuser",                            // CHGHOST with no host
            ":n!u@h ACCOUNT",                                    // ACCOUNT with no account
            // Ping / topic info numerics
            "PING",                                              // PING with no token
            ":irc.example.org 332 tester",                       // RPL_TOPIC missing channel/text
            ":irc.example.org 333 tester #channel",              // RPL_TOPICWHOTIME missing fields
            ":irc.example.org 329 tester #channel",              // RPL_CREATIONTIME missing timestamp
            ":irc.example.org 353 tester",                       // RPL_NAMEREPLY wrong arity
            ":irc.example.org 352 tester",                       // RPL_WHOREPLY wrong arity
            // Authentication
            "AUTHENTICATE",                                      // AUTHENTICATE with no payload
            // Total garbage
            "",
            ":",
            "@tag",
            "@=;= :n!u@h"
        ]

        for line in malformedLines {
            client.didReceiveDataFromConnection(data: line)
        }

        // If we reached here the dispatcher survived every malformed line; sanity-check the client
        // is still usable by processing a well-formed self-JOIN.
        client.didReceiveDataFromConnection(data: ":tester!u@host JOIN #welformed")
        XCTAssertTrue(client.channels.contains(where: { $0.name == "#welformed" }))
    }

    /// A private message whose source is a server (no `user@host`) must be dropped, not crash, now
    /// that `IRCUser(fromPrivateMessage:)` is failable.
    func testServerSourcedPrivateMessageIsIgnored() {
        let client = makeClient()
        client.didReceiveDataFromConnection(data: ":services. PRIVMSG tester :hello from services")
        // No channel is created for an unusable sender.
        XCTAssertTrue(client.channels.isEmpty)
    }

    /// A duration-only STS capability (valid: no `port=`) must not trap on a forced unwrap.
    func testStrictTransportSecurityWithoutPortDoesNotCrash() {
        let client = makeClient()
        client.didReceiveDataFromConnection(data: ":irc.example.org CAP * LS :sts=duration=2592000")
    }
}
