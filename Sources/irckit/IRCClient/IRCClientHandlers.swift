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
    func handleNameReply (message: IRCMessage) {
        guard message.parameters.count == 4 else {
            return
        }
        
        let channelName = message.parameters[2]
        let nameString = message.parameters[3]
        guard let channel = self.getChannel(named: channelName) else {
            return
        }
        
        let names = nameString.components(separatedBy: .whitespaces)
        for name in names {
            var name = name
            var userModes: [IRCChannelUserMode] = []
            while let symbol = name.first, let userMode = IRCChannelUserMode.from(symbol: symbol, onClient: self) {
                name.removeFirst()
                userModes.append(userMode)
            }
            
            guard let (nickname, username, hostmask) = IRCSender.hostmaskComponents(from: name) else {
                continue
            }
            
            let user = IRCUser(
                onClient: self,
                nickname: nickname,
                username: username,
                hostmask: hostmask,
                realName: nil,
                account: nil
            )
            
            channel.set(member: user)
        }
    }
    
    func handleExtendedWhoReply (message: IRCMessage) {
        let channelName = message.parameters[1]
        guard let channel = self.getChannel(named: channelName) else {
            return
        }
        
        let nickname = message.parameters[4]
        let account = message.parameters[5] == "0" ? nil : message.parameters[5]
        
        guard let user = channel.member(named: nickname) else {
            return
        }
        
        user.account = account
        channel.set(member: user)
    }
    
    func handleAuthenticationResponse (message: IRCMessage) {
        if message.parameters[0] == "+" {
            switch self.activeAuthenticationMechanism {
                case .external:
                    self.sendAuthenticate(message: "+")
                    break
                
                case .plainText:
                    guard let password = self.configuration.authenticationPassword else {
                        self.sendAuthenticate(message: "*")
                        return
                    }
                    
                    let username = configuration.authenticationUsername ?? configuration.username
                    
                    guard let encodedPassword = "\(username)\0\(username)\0\(password)".data(using: .utf8)?.base64EncodedString() else {
                        self.sendAuthenticate(message: "*")
                        return
                    }
                    
                    self.sendAuthenticate(message: encodedPassword)
                    break
                
                default:
                    self.sendAuthenticate(message: "*")
                    break
            }
        }
    }
    
    func handleAuthenticationCompleted (message: IRCMessage) {
        self.send(command: .CAP, parameters: ["END"])
    }
    
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
            
            if self.serverInfo.supportsExtendedWhoQuery {
                self.send(command: .WHO, parameters: [channel.name, "+%cnauhr"])
            }
            
            let notification = IRCUserJoinedChannelNotification().encode(payload: IRCUserJoinedChannelNotification.IRCUserJoin(
                user: user,
                channel: channel,
                message: message
            ))
            NotificationCenter.default.post(notification)
        } else {
            guard let channel = self.getChannel(named: message.parameters[0]) else {
                return
            }
            channel.set(member: user)
            
            let notification = IRCUserJoinedChannelNotification().encode(payload: IRCUserJoinedChannelNotification.IRCUserJoin(
                user: user,
                channel: channel,
                message: message
            ))
            NotificationCenter.default.post(notification)
        }
    }
    
    func handlePartChannelEvent (message: IRCMessage) {
        guard let sender = message.sender else {
            return
        }
        
        let channel = self.getChannel(named: message.parameters[0])
        channel?.remove(sender: sender)
        
        if sender.isCurrentUser(client: self) {
            self.removeChannel(named: message.parameters[0])
        }
    }
    
    func handleQuitServerEvent (message: IRCMessage) {
        guard let sender = message.sender else {
            return
        }
        
        for channel in self.channels {
            channel.remove(sender: sender)
        }
    }
    
    func handleNickChangeServerEvent (message: IRCMessage) {
        guard let sender = message.sender else {
            return
        }
        
        let newNick = message.parameters[0]
        
        for channel in self.channels {
            if let member = channel.member(fromSender: sender) {
                member.nickname = newNick
                channel.set(nickname: sender.nickname, member: member)
            }
        }
    }
    
    func handleAccountChangeServerEvent(message: IRCMessage) {
        guard let sender = message.sender else {
            return
        }
        
        for channel in self.channels {
            if let member = channel.member(fromSender: sender) {
                
                member.account = message.parameters[0] != "*" ? message.parameters[0] : nil
                channel.set(member: member)
            }
        }
        
    }
    
    func handlePrivmsgEvent (message: IRCMessage) {
        if message.sender?.nickname == self.currentNick {
            return
        }
        
        if let channel = self.getChannel(named: message.parameters[0]) {
            self.handleChannelPrivmsgEvent(message: message, channel: channel)
        } else {
            self.handleNonChannelPrivmsgEvent(message: message)
        }
        
    }
    
    func handleChannelPrivmsgEvent (message: IRCMessage, channel: IRCChannel) {
        guard let sender = message.sender, let user = channel.member(fromSender: sender) else {
            return
        }
        
        var messageContents = message.parameters[1]
        
        if message.isCTCPRequest {
            messageContents.remove(at: messageContents.startIndex)
            messageContents.remove(at: messageContents.index(messageContents.endIndex, offsetBy: -1))
            
            if message.isActionMessage {
                messageContents = String(messageContents.suffix(from: messageContents.index(messageContents.startIndex, offsetBy: 7)))
                let notification = IRCChannelActionMessageNotification().encode(payload: IRCPrivateMessage(
                    client: self,
                    destination: channel,
                    user: user,
                    message: messageContents
                ))
                NotificationCenter.default.post(notification)
            } else {
                let notification = IRCChannelCTCPRequestNotification().encode(payload: IRCPrivateMessage(
                    client: self,
                    destination: channel,
                    user: user,
                    message: messageContents
                ))
                NotificationCenter.default.post(notification)
            }
        } else {
            user.lastMessage = messageContents
            let notification = IRCChannelMessageNotification().encode(payload: IRCPrivateMessage(
                client: self,
                destination: channel,
                user: user,
                message: messageContents
            ))
            NotificationCenter.default.post(notification)
        }
    }
    
    func handleNonChannelPrivmsgEvent (message: IRCMessage) {
        guard message.sender != nil else {
            return
        }
        
        var messageContents = message.parameters[1]
        
        if message.isCTCPRequest {
            messageContents.remove(at: messageContents.startIndex)
            messageContents.remove(at: messageContents.index(messageContents.endIndex, offsetBy: -1))
            
            if message.isActionMessage {
                messageContents = String(messageContents.suffix(from: messageContents.index(messageContents.startIndex, offsetBy: 7)))
                let user = IRCUser(fromPrivateMessage: message, onClient: self)
                let destination = IRCChannel(privateMessage: user, onClient: self)
                
                let notification = IRCPrivateActionMessageNotification().encode(payload: IRCPrivateMessage(
                    client: self,
                    destination: destination,
                    user: user,
                    message: messageContents
                ))
                
                NotificationCenter.default.post(notification)
            } else {
                let user = IRCUser(fromPrivateMessage: message, onClient: self)
                let destination = IRCChannel(privateMessage: user, onClient: self)
                
                let notification = IRCPrivateCTCPRequestNotification().encode(payload: IRCPrivateMessage(
                    client: self,
                    destination: destination,
                    user: user,
                    message: messageContents
                ))
                NotificationCenter.default.post(notification)
            }
        } else {
            let user = IRCUser(fromPrivateMessage: message, onClient: self)
            let destination = IRCChannel(privateMessage: user, onClient: self)
            
            let notification = IRCPrivateMessageNotification().encode(payload: IRCPrivateMessage(
                client: self,
                destination: destination,
                user: user,
                message: messageContents
            ))
            NotificationCenter.default.post(notification)
        }
    }
}
