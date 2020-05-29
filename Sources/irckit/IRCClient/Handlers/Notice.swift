/*
 Copyright 2020 The Fuel Rats Mischief
 
 Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:
 
 1. Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.
 
 2. Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.
 
 3. Neither the name of the copyright holder nor the names of its contributors may be used to endorse or promote products derived from this software without specific prior written permission.
 
 THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

import Foundation

public struct IRCServerNotice {
    public let client: IRCClient
    public let destination: IRCChannel?
    public let sender: IRCSender
    public let message: String
    public let raw: IRCMessage
}

extension IRCClient {
    func handleNoticeEvent (message: IRCMessage) {
        if message.sender?.nickname == self.currentNick {
            return
        }
        
        if let channel = self.getChannel(named: message.parameters[0]) {
            self.handleChannelNoticeEvent(message: message, channel: channel)
        } else {
            self.handleNonChannelNoticeEvent(message: message)
        }
        
    }
    
    func handleChannelNoticeEvent (message: IRCMessage, channel: IRCChannel) {
        guard let sender = message.sender else {
            return
        }
        
        var messageContents = message.parameters[1]
        if sender.isServer {
            let notification = IRCChannelServerNoticeNotification().encode(payload: IRCServerNotice(
                client: message.client,
                destination: channel,
                sender: sender,
                message: messageContents,
                raw: message
            ))
            
            NotificationCenter.default.post(notification)
            return
        }
        
        guard let user = channel.member(fromSender: sender) else {
            return
        }
        
        if message.isCTCPReply {
            messageContents.remove(at: messageContents.startIndex)
            messageContents.remove(at: messageContents.index(messageContents.endIndex, offsetBy: -1))
            
            let notification = IRCChannelCTCPReplyNotification().encode(payload: IRCPrivateMessage(
                client: self,
                destination: channel,
                user: user,
                message: messageContents,
                raw: message
            ))
            NotificationCenter.default.post(notification)
        } else {
            user.lastMessage = messageContents
            let notification = IRCChannelNoticeNotification().encode(payload: IRCPrivateMessage(
                client: self,
                destination: channel,
                user: user,
                message: messageContents,
                raw: message
            ))
            NotificationCenter.default.post(notification)
        }
    }
    
    func handleNonChannelNoticeEvent (message: IRCMessage) {
        guard let sender = message.sender else {
            return
        }
        
        var messageContents = message.parameters[1]
        
        if sender.isServer {
            let notification = IRCPrivateServerNoticeNotification().encode(payload: IRCServerNotice(
                client: message.client,
                destination: nil,
                sender: sender,
                message: messageContents,
                raw: message
            ))
            
            NotificationCenter.default.post(notification)
            return
        }
        
        let user = IRCUser(fromPrivateMessage: message, onClient: self)
        let destination = IRCChannel(privateMessage: user, onClient: self)
        
        if message.isCTCPReply {
            messageContents.remove(at: messageContents.startIndex)
            messageContents.remove(at: messageContents.index(messageContents.endIndex, offsetBy: -1))
            
            let notification = IRCPrivateCTCPReplyNotification().encode(payload: IRCPrivateMessage(
                client: self,
                destination: destination,
                user: user,
                message: messageContents,
                raw: message
            ))
            NotificationCenter.default.post(notification)
        } else {
            let notification = IRCPrivateNoticeNotification().encode(payload: IRCPrivateMessage(
                client: self,
                destination: destination,
                user: user,
                message: messageContents,
                raw: message
            ))
            NotificationCenter.default.post(notification)
        }
    }
}

public struct IRCChannelNoticeNotification: NotificationDescriptor {
    public init () {}
    public typealias Payload = IRCPrivateMessage
    public let name = Notification.Name("IRCChannelDidReceiveNotice")
}

public struct IRCChannelServerNoticeNotification: NotificationDescriptor {
    public init () {}
    public typealias Payload = IRCServerNotice
    public let name = Notification.Name("IRCChannelDidReceiveServerNotice")
}

public struct IRCChannelCTCPReplyNotification: NotificationDescriptor {
    public init () {}
    public typealias Payload = IRCPrivateMessage
    public let name = Notification.Name("IRCChannelDidReceiveCTCPReply")
}

public struct IRCPrivateNoticeNotification: NotificationDescriptor {
    public init () {}
    public typealias Payload = IRCPrivateMessage
    public let name = Notification.Name("IRCDidReceivePrivateServerNotice")
}

public struct IRCPrivateServerNoticeNotification: NotificationDescriptor {
    public init () {}
    public typealias Payload = IRCServerNotice
    public let name = Notification.Name("IRCDidReceivePrivateNotice")
}

public struct IRCPrivateCTCPReplyNotification: NotificationDescriptor {
    public init () {}
    public typealias Payload = IRCPrivateMessage
    public let name = Notification.Name("IRCDidReceivePrivateCTCPReply")
}
