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

extension IRCClient {
    func handleQuitServerEvent (message: IRCMessage) {
        guard let sender = message.sender else {
            return
        }

        for channel in self.channels {
            channel.remove(sender: sender)
        }

        IRCUserQuitNotification().encode(payload: message).post()
    }

    func handleNickChangeServerEvent (message: IRCMessage) {
        guard let sender = message.sender else {
            return
        }

        let newNick = message.parameters[0]

        for channel in self.channels {
            if let member = channel.member(fromSender: sender) {
                member.nickname = newNick
            }
        }

        IRCUserChangedNickNotification().encode(payload: IRCUserChangedNickNotification.IRCNickChange(
            id: message.id,
            raw: message,
            newNick: newNick
        )).post()
    }

    func handleAwayChangeEvent (message: IRCMessage) {
        guard let sender = message.sender else {
            return
        }

        let isAway = message.parameters.count > 0

        for channel in self.channels {
            if let member = channel.member(fromSender: sender) {
                member.isAway = isAway
            }
        }
    }

    func handleRealNameChange (message: IRCMessage) {
        guard let sender = message.sender else {
            return
        }

        let realName = message.parameters[0]

        for channel in self.channels {
            if let member = channel.member(fromSender: sender) {
                member.realName = realName
            }
        }
    }
}

public struct IRCUserQuitNotification: NotificationDescriptor {
    public init () {}

    public typealias Payload = IRCMessage
    public let name = Notification.Name("IRCDidQuitServer")
}

public struct IRCUserChangedNickNotification: NotificationDescriptor {
    public init () {}

    public struct IRCNickChange: IRCNotification {
        public let id: String
        public let raw: IRCMessage
        public let newNick: String
    }

    public typealias Payload = IRCNickChange
    public let name = Notification.Name("IRCDidChangeNick")
}
