/*
 Copyright 2020 The Fuel Rats Mischief
 
 Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:
 
 1. Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.
 
 2. Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.
 
 3. Neither the name of the copyright holder nor the names of its contributors may be used to endorse or promote products derived from this software without specific prior written permission.
 
 THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

import Foundation

public struct IRCChannelEvent {
    public let user: IRCUser
    public let channel: IRCChannel
    public let message: String?
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
            
            let notification = IRCUserJoinedChannelNotification().encode(payload: IRCChannelEvent(
                user: user,
                channel: channel,
                message: nil,
                raw: message
            ))
            NotificationCenter.default.post(notification)
        } else {
            guard let channel = self.getChannel(named: message.parameters[0]) else {
                return
            }
            channel.set(member: user)
            
            let notification = IRCUserJoinedChannelNotification().encode(payload: IRCChannelEvent(
                user: user,
                channel: channel,
                message: nil,
                raw: message
            ))
            NotificationCenter.default.post(notification)
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
        
        let notification = IRCUserLeftChannelNotification().encode(payload: IRCChannelEvent(
            user: user,
            channel: channel,
            message: message.parameters[1],
            raw: message
        ))
        NotificationCenter.default.post(notification)
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
        
        let notification = IRCChannelKickNotification().encode(payload: IRCChannelKickNotification.IRCChannelKick(
            sender: sender,
            channel: channel,
            kickedUser: kickUser,
            message: message.parameters[2],
            raw: message
        ))
        NotificationCenter.default.post(notification)
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
        
        let notification = IRCChannelTopicChangeNotification().encode(payload: IRCChannelTopicChangeNotification.IRCChannelTopicChange(
            user: user,
            channel: channel,
            contents: message.parameters[1],
            raw: message
        ))
        NotificationCenter.default.post(notification)
    }
    
    func handleChannelModeChangeEvent (message: IRCMessage) {
        guard let channel = self.getChannel(named: message.parameters[0]) else {
            return
        }
        
        let modes = message.parameters[1]
        var modeArgs = message.parameters[2...]
        var revoking = false
        
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
                continue
            }
            
            if let channelMode = IRCChannelMode(rawValue: modeChar) {
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
                        break
                    
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
