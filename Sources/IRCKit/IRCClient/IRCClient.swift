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
#if canImport(Combine)
    import Combine
#endif

public typealias ConnectCommand = (IRCClient) -> Void

open class IRCClient: IRCConnectionDelegate {
    public let id: UUID
    internal let connection: IRCConnection
    public var configuration: IRCClientConfiguration
    public internal(set) var serverInfo = IRCServerInfo() {
        willSet {
            #if os(Linux)
            #else
            if #available(iOS 13, macOS 10.15, *) {
                DispatchQueue.main.async {
                    self.objectWillChange.send()
                }
            }
            #endif
        }
    }
    public internal(set) var channels: [IRCChannel] = [] {
        willSet {
            #if os(Linux)
            #else
            if #available(iOS 13, macOS 10.15, *) {
                DispatchQueue.main.async {
                    self.objectWillChange.send()
                }
            }
            #endif
        }
    }
    public private(set) var currentNick: String
    public var connectCommands: [ConnectCommand] = []

    static var supportedHandlers: [SASLHandler.Type] = [
        PlainTextSASLHandler.self,
        ExternalSASLHandler.self,
        Sha256SASLHandler.self
    ]
    var activeAuthenticationHandler: SASLHandler?
    var isExpectingWhoisResponse = false

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

    public init (configuration: IRCClientConfiguration) {
        self.id = UUID()
        self.configuration = configuration
        self.currentNick = configuration.nickname

        self.connection = try! IRCConnection(configuration: configuration)!
        self.connection.delegate = self

        if self.configuration.autoConnect {
            self.connection.connect()
        }
    }

    public func connect () {
        self.connection.connect()
    }

    public func didConnectToHost () {
        print("Connected")

        self.sendRegistration()
        IRCClientConnectionNotification().encode(payload:
            IRCClientConnectionNotification.IRCConnectionChange(client: self)
        ).post()

    }

    public func didReceiveDataFromConnection (data: String) {
        guard let message = IRCMessage(line: data, client: self) else {
            return
        }

        switch message.command {
            case .ERROR:
                print("Disconnecting due to error")
                self.connection.disconnect()

            case .PING:
                self.send(command: .PONG, parameters: [":\(message.parameters[0])"])

            case .RPL_WELCOME:
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
                handleChannelKickEvent(message: message)

            case .MODE:
                handleChannelModeChangeEvent(message: message)

            case .TOPIC:
                handleChannelTopicEvent(message: message)

            case .CHGHOST:
                handleHostnameChange(message: message)

            default:
                break
        }
    }

    func getChannel (named channelName: String) -> IRCChannel? {
        return self.channels.first(where: { $0.name == channelName })
    }

    func addChannel (channel: IRCChannel) {
        guard self.channels.first(where: { $0.name == channel.name }) == nil else {
            return
        }
        self.channels.append(channel)
    }

    func removeChannel (named channelName: String) {
        self.channels.removeAll(where: { $0.name == channelName })
    }

    public func send (command: IRCCommand, parameters: String...) {
        self.send(command: command, parameters: parameters)
    }

    public func send (command: IRCCommand, parameters: [String], tags: [String: String?] = [:]) {
        var tags = tags
        var params = parameters
        if self.hasIRCv3Capability(.labeledResponses) && tags["label"] == nil {
            tags["label"] = String.random(length: 10)
        }

        /* In IRC if a command has more than one argument,
         the last argument can contain spaces if it is prefixed with : */
        let lastParam = params.last ?? ""
        if params.count > 1 && lastParam.components(separatedBy: .whitespaces).count > 1 {
            params[params.count - 1] = ":" + lastParam
        }

        let paramString = params.joined(separator: " ")

        if tags.count > 0 && self.hasIRCv3Capability(.messageTags) {
            let tagString = tags.map({ (key, value) -> String in
                if let value = value {
                    return "\(key)=\(value)"
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
