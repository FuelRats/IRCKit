/*
 Copyright 2020 The Fuel Rats Mischief
 
 Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:
 
 1. Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.
 
 2. Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.
 
 3. Neither the name of the copyright holder nor the names of its contributors may be used to endorse or promote products derived from this software without specific prior written permission.
 
 THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

import Foundation

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
                self.send(command: .WHO, parameters: channel.name, "+%cnauhr")
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
}
