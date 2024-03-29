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

public struct IRCChannelEvent: IRCNotification {
    public enum ChannelEvent {
        case Join
        case Part
    }

    public let id: String
    public let user: IRCUser
    public let channel: IRCChannel
    public let message: String?
    public let event: ChannelEvent
    public let raw: IRCMessage
}

extension IRCClient {
    func handleJoinChannelEvent (message: IRCMessage) {
        guard let sender = message.sender, let username = sender.username, let hostmask = sender.hostmask else {
            return
        }

        let user = IRCUser(
            onClient: self,
            nickname: sender.nickname,
            username: username,
            hostmask: hostmask,
            realName: nil,
            account: nil
        )

        if self.hasIRCv3Capability(.extendedJoin) {
            let account = message.parameters[1]
            if account != "*" {
                user.account = account
            }

            user.realName = message.parameters[2]
        }

        if sender.isCurrentUser(client: self) {
            let channel = IRCChannel(channelName: message.parameters[0], onClient: self)
            channel.add(member: user)
            self.addChannel(channel: channel)

            self.send(command: .MODE, parameters: channel.name)

            if self.serverInfo.supportsExtendedWhoQuery {
                self.send(command: .WHO, parameters: channel.name, "+%cnauhrfs")
            } else {
                self.send(command: .WHO, parameters: channel.name)
            }

            IRCUserJoinedChannelNotification().encode(payload: IRCChannelEvent(
                id: message.label,
                user: user,
                channel: channel,
                message: nil,
                event: .Join,
                raw: message
            )).post()
        } else {
            guard let channel = self.getChannel(named: message.parameters[0]) else {
                return
            }
            channel.set(member: user)

            IRCUserJoinedChannelNotification().encode(payload: IRCChannelEvent(
                id: message.label,
                user: user,
                channel: channel,
                message: nil,
                event: .Join,
                raw: message
            )).post()
        }
    }

    func handlePartChannelEvent (message: IRCMessage) {
        guard let sender = message.sender else {
            return
        }

        guard let channel = self.getChannel(named: message.parameters[0]) else {
            return
        }
        guard let user = channel.member(fromSender: sender) else {
            return
        }
        channel.remove(member: user)

        if sender.isCurrentUser(client: self) {
            self.removeChannel(named: message.parameters[0])
        }

        IRCUserLeftChannelNotification().encode(payload: IRCChannelEvent(
            id: message.label,
            user: user,
            channel: channel,
            message: message.parameters[safe: 0],
            event: .Part,
            raw: message
        )).post()
    }

    func handleChannelKickEvent (message: IRCMessage) {
        guard let sender = message.sender else {
            return
        }

        guard let channel = self.getChannel(named: message.parameters[0]) else {
            return
        }

        guard let kickUser = channel.member(named: message.parameters[1]) else {
            return
        }

        channel.remove(member: kickUser)

        if sender.isCurrentUser(client: self) {
            self.removeChannel(named: message.parameters[0])
        }

        IRCChannelKickNotification().encode(payload: IRCChannelKickNotification.IRCChannelKick(
            sender: sender,
            channel: channel,
            kickedUser: kickUser,
            message: message.parameters[safe: 2],
            raw: message
        )).post()
    }

    func handleChannelInviteEvent (message: IRCMessage) {
        guard let sender = message.sender else {
            return
        }

        guard let channel = self.getChannel(named: message.parameters[0]) else {
            return
        }

        IRCChannelInviteNotification().encode(payload: IRCChannelInviteNotification.IRCChannelInvite(
            sender: sender,
            channel: channel,
            invitedNick: message.parameters[1],
            raw: message
        )).post()
    }

    func handleChannelTopicEvent (message: IRCMessage) {
        guard let sender = message.sender else {
            return
        }

        guard let channel = self.getChannel(named: message.parameters[0]) else {
            return
        }
        channel.topic = IRCChannel.Topic(contents: message.parameters[1], author: sender.nickname, date: message.time)

        let user = channel.member(fromSender: sender)

        IRCChannelTopicChangeNotification().encode(payload: IRCChannelTopicChangeNotification.IRCChannelTopicChange(
            user: user,
            channel: channel,
            contents: message.parameters[1],
            raw: message
        )).post()
    }

    func handleChannelModeChangeEvent (message: IRCMessage) {
        guard let channel = self.getChannel(named: message.parameters[0]) else {
            return
        }

        let modes = message.parameters[1]
        var modeArgs = message.parameters[2...]
        var revoking = false
        let user = channel.member(fromSender: message.sender!)

        for modeChar in Array(modes) {
            if modeChar == "+" {
                revoking = false
                continue
            }

            if modeChar == "-" {
                revoking = true
                continue
            }

            if let userMode = IRCChannelUserMode(rawValue: modeChar) {
                guard let memberName = modeArgs.first, let member = channel.member(named: memberName) else {
                    continue
                }
                if revoking {
                    member.channelUserModes.remove(userMode)
                } else {
                    member.channelUserModes.insert(userMode)
                }
                modeArgs.removeFirst()
                IRCChannelUserModeChangeNotification().encode(payload: IRCChannelUserModeChangeNotification.IRCChannelUserModeChange(
                    user: user,
                    channel: channel,
                    mode: userMode,
                    state: revoking ? .minus : .plus,
                    target: member,
                    raw: message)
                ).post()
                continue
            }

            if let channelMode = IRCChannelMode(rawValue: modeChar) {
                IRCChannelModeChangeNotification().encode(payload: IRCChannelModeChangeNotification.IRCChannelModeChange(
                    user: user,
                    channel: channel,
                    mode: channelMode,
                    state: revoking ? .minus : .plus,
                    raw: message)
                ).post()
                if revoking {
                    channel.channelModes.removeValue(forKey: channelMode)
                    continue
                }
                switch channelMode {
                    case .floodProtection,
                         .playsChannelHistory,
                         .requiresPassword,
                         .limitUserCount:
                        channel.channelModes[channelMode] = modeArgs.first
                        modeArgs.removeFirst()

                    default:
                        channel.channelModes[channelMode] = nil
                }
            }
        }
    }
}

public struct IRCUserJoinedChannelNotification: NotificationDescriptor {
    public init () {}

    public typealias Payload = IRCChannelEvent
    public let name = Notification.Name("IRCDidJoinChannel")
}

public struct IRCUserLeftChannelNotification: NotificationDescriptor {
    public init () {}

    public typealias Payload = IRCChannelEvent
    public let name = Notification.Name("IRCDidLeaveChannel")
}

public struct IRCChannelTopicChangeNotification: NotificationDescriptor {
    public init () {}

    public struct IRCChannelTopicChange {
        public let user: IRCUser?
        public let channel: IRCChannel
        public let contents: String
        public let raw: IRCMessage
    }

    public typealias Payload = IRCChannelTopicChange
    public let name = Notification.Name("IRCDidChangeChannelTopic")
}

public struct IRCChannelKickNotification: NotificationDescriptor {
    public init () {}

    public struct IRCChannelKick {
        public let sender: IRCSender
        public let channel: IRCChannel
        public let kickedUser: IRCUser
        public let message: String?
        public let raw: IRCMessage
    }

    public typealias Payload = IRCChannelKick
    public let name = Notification.Name("IRCDidKickFromChannel")
}

public struct IRCChannelInviteNotification: NotificationDescriptor {
    public init () {}

    public struct IRCChannelInvite {
        public let sender: IRCSender
        public let channel: IRCChannel
        public let invitedNick: String
        public let raw: IRCMessage
    }

    public typealias Payload = IRCChannelInvite
    public let name = Notification.Name("IRCDidInviteToChannel")
}





public struct IRCChannelModeChangeNotification: NotificationDescriptor {
    public init () {}

    public struct IRCChannelModeChange {
        public let user: IRCUser?
        public let channel: IRCChannel
        public let mode: IRCChannelMode
        public let state: FloatingPointSign
        public let raw: IRCMessage
    }

    public typealias Payload = IRCChannelModeChange
    public let name = Notification.Name("IRCDidChangeChannelMode")
}

public struct IRCChannelUserModeChangeNotification: NotificationDescriptor {
    public init () {}

    public struct IRCChannelUserModeChange {
        public let user: IRCUser?
        public let channel: IRCChannel
        public let mode: IRCChannelUserMode
        public let state: FloatingPointSign
        public let target: IRCUser
        public let raw: IRCMessage
    }

    public typealias Payload = IRCChannelUserModeChange
    public let name = Notification.Name("IRCDidChangeChannelUserMode")
}
