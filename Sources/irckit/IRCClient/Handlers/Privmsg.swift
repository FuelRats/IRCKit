/*
 Copyright 2020 The Fuel Rats Mischief
 
 Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:
 
 1. Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.
 
 2. Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.
 
 3. Neither the name of the copyright holder nor the names of its contributors may be used to endorse or promote products derived from this software without specific prior written permission.
 
 THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

import Foundation

public struct IRCPrivateMessage {
    public let client: IRCClient
    public let destination: IRCChannel
    public let user: IRCUser
    public let message: String
    public let raw: IRCMessage
    
    public func reply (message: String) {
        client.sendMessage(toChannel: destination, contents: message)
    }
    
    public func reply (list: [String], separator: String, heading: String = "") {
        let messages = list.reduce([String](), { (acc: [String], entry: String) -> [String] in
            var acc = acc
            var entry = entry
            
            if acc.last == nil {
                entry = heading + entry
            }
            
            if acc.last == nil || acc.last!.count + separator.count + list.count > 400 {
                acc.append(entry)
                return acc
            }
            
            acc[acc.count - 1] = acc[acc.count - 1] + separator + entry
            return acc
        })
        
        for message in messages {
            self.reply(message: message)
        }
    }
}


extension IRCClient {
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
                IRCChannelActionMessageNotification().encode(payload: IRCPrivateMessage(
                    client: self,
                    destination: channel,
                    user: user,
                    message: messageContents,
                    raw: message
                )).post()
            } else {
                IRCChannelCTCPRequestNotification().encode(payload: IRCPrivateMessage(
                    client: self,
                    destination: channel,
                    user: user,
                    message: messageContents,
                    raw: message
                )).post()
            }
        } else {
            user.lastMessage = messageContents
            IRCChannelMessageNotification().encode(payload: IRCPrivateMessage(
                client: self,
                destination: channel,
                user: user,
                message: messageContents,
                raw: message
            )).post()
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
                
                IRCPrivateActionMessageNotification().encode(payload: IRCPrivateMessage(
                    client: self,
                    destination: destination,
                    user: user,
                    message: messageContents,
                    raw: message
                )).post()
            } else {
                let user = IRCUser(fromPrivateMessage: message, onClient: self)
                let destination = IRCChannel(privateMessage: user, onClient: self)
                
                IRCPrivateCTCPRequestNotification().encode(payload: IRCPrivateMessage(
                    client: self,
                    destination: destination,
                    user: user,
                    message: messageContents,
                    raw: message
                )).post()
            }
        } else {
            let user = IRCUser(fromPrivateMessage: message, onClient: self)
            let destination = IRCChannel(privateMessage: user, onClient: self)
            
            IRCPrivateMessageNotification().encode(payload: IRCPrivateMessage(
                client: self,
                destination: destination,
                user: user,
                message: messageContents,
                raw: message
            )).post()
        }
    }
}

public struct IRCChannelMessageNotification: NotificationDescriptor {
    public init () {}
    public typealias Payload = IRCPrivateMessage
    public let name = Notification.Name("IRCChannelDidReceiveMessage")
}

public struct IRCChannelActionMessageNotification: NotificationDescriptor {
    public init () {}
    public typealias Payload = IRCPrivateMessage
    public let name = Notification.Name("IRCChannelDidReceiveActionMessage")
}

public struct IRCChannelCTCPRequestNotification: NotificationDescriptor {
    public init () {}
    public typealias Payload = IRCPrivateMessage
    public let name = Notification.Name("IRCChannelDidReceiveCTCPRequest")
}

public struct IRCPrivateMessageNotification: NotificationDescriptor {
    public init () {}
    public typealias Payload = IRCPrivateMessage
    public let name = Notification.Name("IRCDidReceivePrivateMessage")
}

public struct IRCPrivateActionMessageNotification: NotificationDescriptor {
    public init () {}
    public typealias Payload = IRCPrivateMessage
    public let name = Notification.Name("IRCDidReceivePrivateActionMessage")
}

public struct IRCPrivateCTCPRequestNotification: NotificationDescriptor {
    public init () {}
    public typealias Payload = IRCPrivateMessage
    public let name = Notification.Name("IRCDidReceivePrivateCTCPRequest")
}
