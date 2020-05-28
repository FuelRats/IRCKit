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
                    message: messageContents,
                    raw: message
                ))
                NotificationCenter.default.post(notification)
            } else {
                let notification = IRCChannelCTCPRequestNotification().encode(payload: IRCPrivateMessage(
                    client: self,
                    destination: channel,
                    user: user,
                    message: messageContents,
                    raw: message
                ))
                NotificationCenter.default.post(notification)
            }
        } else {
            user.lastMessage = messageContents
            let notification = IRCChannelMessageNotification().encode(payload: IRCPrivateMessage(
                client: self,
                destination: channel,
                user: user,
                message: messageContents,
                raw: message
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
                    message: messageContents,
                    raw: message
                ))
                
                NotificationCenter.default.post(notification)
            } else {
                let user = IRCUser(fromPrivateMessage: message, onClient: self)
                let destination = IRCChannel(privateMessage: user, onClient: self)
                
                let notification = IRCPrivateCTCPRequestNotification().encode(payload: IRCPrivateMessage(
                    client: self,
                    destination: destination,
                    user: user,
                    message: messageContents,
                    raw: message
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
                message: messageContents,
                raw: message
            ))
            NotificationCenter.default.post(notification)
        }
    }
}
