/*
 Copyright 2020 The Fuel Rats Mischief
 
 Redistribution and use in source and binary forms, with or without modification,
 are permitted provided that the following conditions are met:
 
 1. Redistributions of source code must retain the above copyright notice,
 this list of conditions and the following disclaimer.
 
 2. Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following
 disclaimer in the documentation and/or other materials provided with the distribution.
 
 3. Neither the name of the copyright holder nor the names of its contributors may be used to endorse or promote
 products derived from this software without specific prior written permission.
 
 THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES,
 INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
 DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
 SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
 SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY,
 WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
 OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

import Foundation
import Logging
#if canImport(Combine)
    import Combine
#endif

public typealias ConnectCommand = (IRCClient) -> Void

open class IRCClient: IRCConnectionDelegate, @unchecked Sendable {
    public let id: UUID
    public let logger: Logger
    internal let connection: IRCConnection
    public var configuration: IRCClientConfiguration
    public internal(set) var serverInfo = IRCServerInfo() {
        willSet {
            #if os(Linux)
            #else
            DispatchQueue.main.async { [self] in
                self.objectWillChange.send()
            }
            #endif
        }
    }
    private let channelStorage = LockedValue<[IRCChannel]>([])
    public internal(set) var channels: [IRCChannel] {
        get { self.channelStorage.withValue({ $0 }) }
        set {
            self.channelsWillChange()
            self.channelStorage.withValue({ $0 = newValue })
        }
    }

    private func channelsWillChange() {
        #if os(Linux)
        #else
        DispatchQueue.main.async { [self] in
            self.objectWillChange.send()
        }
        #endif
    }
    public internal(set) var currentNick: String
    public internal(set) var currentSender: IRCSender?
    public var connectCommands: [ConnectCommand] = []

    nonisolated(unsafe) static var supportedHandlers: [SASLHandler.Type] = [
        PlainTextSASLHandler.self,
        ExternalSASLHandler.self,
        Sha256SASLHandler.self
    ]
    var activeAuthenticationHandler: SASLHandler?
    var isExpectingWhoisResponse = false

    // Accumulates capability tokens across a multi-line `CAP LS 302` reply, which the
    // server sends when the capability list exceeds one IRC message.
    var capabilityLSBuffer: String = ""

    // True once the initial capability handshake has finished (CAP END sent). Used to distinguish a
    // mid-session CAP ACK/NAK (from a cap-notify CAP NEW) from the registration handshake.
    var capabilityNegotiationComplete = false

    public var monitor: Set<String> = [] {
        didSet {
            if self.connection.connected && self.serverInfo.supportsMonitor {
                let addItems = self.monitor.subtracting(oldValue)
                let removeItems = oldValue.symmetricDifference(self.monitor).subtracting(self.monitor)

                if self.monitor.count == 0 {
                    self.sendMonitorClear()
                    return
                }

                if addItems.count > 0 {
                    self.sendMonitor(addTargets: addItems)
                }

                if removeItems.count > 0 {
                    self.sendMonitor(removeTargets: removeItems)
                }
            }
        }
    }

    public init (configuration: IRCClientConfiguration, logger: Logger? = nil) {
        self.id = UUID()
        self.logger = logger ?? Logger(label: "IRCKit")
        self.configuration = configuration
        self.currentNick = configuration.nickname

        guard let connection = try? IRCConnection(configuration: configuration, logger: self.logger) else {
            fatalError("Failed to initialize IRC connection")
        }
        self.connection = connection
        self.connection.delegate = self

        if self.configuration.autoConnect {
            self.connection.connect()
        }
    }

    public func connect() {
        self.connection.connect()
    }

    public func didConnectToHost() {
        logger.info("Connected")

        self.sendRegistration()
        IRCClientConnectionNotification().encode(payload:
            IRCClientConnectionNotification.IRCConnectionChange(client: self)
        ).post()

    }

    public func didDisconnectFromHost() {
        logger.info("Disconnected")

        // Membership and account state is only valid for the session that observed it; keeping it across a
        // reconnect would attribute accounts to whoever holds those nicknames in the new session.
        self.channels = []
        IRCClientDisconnectionNotification().encode(payload:
            IRCClientConnectionNotification.IRCConnectionChange(client: self)
        ).post()
    }

    public func didReceiveDataFromConnection(data: String) {
        guard let message = IRCMessage(line: data, client: self) else {
            return
        }

        guard message.parameters.count >= message.command.minimumParameterCount else {
            let command = message.command.rawValue
            let minimum = message.command.minimumParameterCount
            logger.trace("Ignoring \(command): expected at least \(minimum) parameters, got \(message.parameters.count)")
            return
        }

        switch message.command {
            case .ERROR:
                logger.warning("Disconnecting due to error")
                self.connection.disconnect()

            case .PING:
                guard let token = message.parameters[safe: 0] else {
                    break
                }
                self.send(command: .PONG, parameters: [token])

            case .RPL_WELCOME:
                if
                    let senderString = message.parameters.last?.components(separatedBy: " ").last,
                    let sender = IRCSender(fromString: senderString) {
                    self.currentSender = sender
                }
                if self.configuration.channels.count > 0 {
                    self.sendJoin(channels: self.configuration.channels)
                }
                for command in self.connectCommands {
                    command(self)
                }

            case .RPL_MYINFO:
                serverInfo.setServerInfo(parameters: message.parameters)

            case .RPL_ISUPPORT:
                serverInfo.setSupported(parameters: message.parameters)

            case .RPL_NAMEREPLY:
                handleNameReply(message: message)

            case .RPL_WHORELY, .RPL_WHOSPCRPL:
                handleWhoReply(message: message)

            case .RPL_TOPIC, .RPL_NOTOPIC, .RPL_TOPICWHOTIME:
                handleTopicInformation(message: message)

            case .RPL_CHANNELMODEIS:
                handleChannelModeInformation(message: message)

            case .RPL_CREATIONTIME:
                handleChannelCreatedInformation(message: message)

            case .CAP:
                handleIRCv3CapabilityReply(message: message)

            case .AUTHENTICATE:
                handleAuthenticationResponse(message: message)

            case .RPL_SASLSUCCESS, .ERR_SASLFAIL, .ERR_SASLTOOLONG, .ERR_SASLABORTED, .ERR_SASLALREADY:
                handleAuthenticationCompleted(message: message)

            case .JOIN:
                handleJoinChannelEvent(message: message)

            case .PART:
                handlePartChannelEvent(message: message)

            case .QUIT:
                handleQuitServerEvent(message: message)

            case .NICK:
                handleNickChangeServerEvent(message: message)

            case .AWAY:
                handleAwayChangeEvent(message: message)

            case .SETNAME:
                handleRealNameChange(message: message)

            case .ACCOUNT:
                handleAccountChangeServerEvent(message: message)

            case .PRIVMSG:
                handlePrivmsgEvent(message: message)

            case .NOTICE:
                handleNoticeEvent(message: message)

            case .KICK:
                handleChannelKickEvent(message: message)

            case .INVITE:
                handleChannelInviteEvent(message: message)

            case .MODE:
                handleChannelModeChangeEvent(message: message)

            case .TOPIC:
                handleChannelTopicEvent(message: message)

            case .CHGHOST:
                handleHostnameChange(message: message)

            case .RPL_HOSTISHIDDEN:
                handleHostHidden(message: message)

            case .RPL_MONONLINE:
                handleMonitorOnlineEvent(message: message)

            case .RPL_MONOFFLINE:
                handleMonitorOfflineEvent(message: message)

            default:
                break
        }
    }

    /// Folds a nickname or channel name using the server's CASEMAPPING, for case-insensitive
    /// comparison of the two.
    func caseFold(_ name: String) -> String {
        return name.ircCaseFolded(mapping: self.serverInfo.caseMapping)
    }

    /// Whether two nicknames or channel names refer to the same entity under the server's CASEMAPPING.
    func isSameName(_ lhs: String, _ rhs: String) -> Bool {
        return self.caseFold(lhs) == self.caseFold(rhs)
    }

    func getChannel(named channelName: String) -> IRCChannel? {
        let target = self.caseFold(channelName)
        return self.channels.first(where: { self.caseFold($0.name) == target })
    }

    func addChannel(channel: IRCChannel) {
        let target = self.caseFold(channel.name)
        self.channelsWillChange()
        self.channelStorage.withValue({ channels in
            guard channels.contains(where: { self.caseFold($0.name) == target }) == false else {
                return
            }
            channels.append(channel)
        })
    }

    func removeChannel(named channelName: String) {
        let target = self.caseFold(channelName)
        self.channelsWillChange()
        self.channelStorage.withValue({ channels in
            channels.removeAll(where: { self.caseFold($0.name) == target })
        })
    }

    public func send(command: IRCCommand, parameters: String...) {
        self.send(command: command, parameters: parameters)
    }
    
    public func send(command: IRCCommand, parameters: [String], tags: [String: String?] = [:]) {
        send(command.rawValue, parameters: parameters, tags: tags)
    }

    public func send(_ command: String, parameters: [String], tags: [String: String?] = [:]) {
        var tags = tags
        // Strip NUL/CR/LF so caller-supplied text cannot inject additional commands into the stream.
        var params = parameters.map({ $0.ircParameterSanitized() })
        // Only the trailing parameter may be empty, contain spaces or begin with ':'. In any other position each would
        // shift the parameters that follow, so refuse to send the line rather than send something the caller didn't mean.
        if let malformed = params.dropLast().first(where: { $0.isEmpty || $0.contains(" ") || $0.hasPrefix(":") }) {
            logger.error("Refusing to send \(command): parameter \"\(malformed)\" is not valid outside the trailing position")
            return
        }
        if self.hasIRCv3Capability(.labeledResponses) && tags["label"] == nil {
            tags["label"] = String.random(length: 10)
        }

        /* The last argument is the "trailing" parameter and must be prefixed with ':' when it is
         empty, contains a space, or itself begins with ':', otherwise the server would misparse it
         (for example a one-word message ":)" would be read as an empty trailing parameter). */
        if let lastParam = params.last, lastParam.isEmpty || lastParam.contains(" ") || lastParam.hasPrefix(":") {
            params[params.count - 1] = ":" + lastParam
        }

        let paramString = params.joined(separator: " ")

        if tags.count > 0 && self.hasIRCv3Capability(.messageTags) {
            let tagString = tags.map({ (key, value) -> String in
                if let value = value {
                    return "\(key)=\(value.ircTagValueEscaped())"
                }
                return key
            }).joined(separator: ";")
            self.connection.send(message: "@\(tagString) \(command) \(paramString)")
        } else {
            self.connection.send(message: "\(command) \(paramString)")
        }
    }
}

#if os(Linux)
#else
@available(iOS 13, macOS 10.15, *)
extension IRCClient: ObservableObject {

}
#endif
