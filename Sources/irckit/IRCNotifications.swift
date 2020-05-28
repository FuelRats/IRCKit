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

public struct IRCChannelEvent {
    public let user: IRCUser
    public let channel: IRCChannel
    public let message: String?
    public let raw: IRCMessage
}

public struct IRCUserAccountChangeNotification: NotificationDescriptor {
    public init () {}
    public struct IRCUserAccountChange {
        public let user: IRCUser
        public let oldValue: String?
    }
    
    public typealias Payload = IRCUserAccountChange
    public let name = Notification.Name("IRCUserAccountDidChange")
}

public struct IRCClientConnectionNotification: NotificationDescriptor {
    public init () {}
    public struct IRCConnectionChange {
        let client: IRCClient
    }
    
    public typealias Payload = IRCConnectionChange
    public let name = Notification.Name("IRCConnectionDidConnect")
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

public struct IRCChannelNoticeNotification: NotificationDescriptor {
    public init () {}
    public typealias Payload = IRCPrivateMessage
    public let name = Notification.Name("IRCChannelDidReceiveNotice")
}

public struct IRCChannelCTCPReplyNotification: NotificationDescriptor {
    public init () {}
    public typealias Payload = IRCPrivateMessage
    public let name = Notification.Name("IRCChannelDidReceiveCTCPReply")
}

public struct IRCPrivateNoticeNotification: NotificationDescriptor {
    public init () {}
    public typealias Payload = IRCPrivateMessage
    public let name = Notification.Name("IRCDidReceivePrivateNotice")
}

public struct IRCPrivateCTCPReplyNotification: NotificationDescriptor {
    public init () {}
    public typealias Payload = IRCPrivateMessage
    public let name = Notification.Name("IRCDidReceivePrivateCTCPReply")
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

public struct IRCUserQuitNotification: NotificationDescriptor {
    public init () {}

    public typealias Payload = IRCMessage
    public let name = Notification.Name("IRCDidQuitServer")
}

public struct IRCUserChangedNickNotification: NotificationDescriptor {
    public init () {}
    
    public struct IRCNickChange {
        public let message: IRCMessage
        public let newNick: String
    }

    public typealias Payload = IRCNickChange
    public let name = Notification.Name("IRCDidChangeNick")
}
