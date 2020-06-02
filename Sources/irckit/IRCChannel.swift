/*
 Copyright 2020 The Fuel Rats Mischief
 
 Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:
 
 1. Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.
 
 2. Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.
 
 3. Neither the name of the copyright holder nor the names of its contributors may be used to endorse or promote products derived from this software without specific prior written permission.
 
 THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

import Foundation

public class IRCChannel {
    public struct Topic {
        public internal(set) var contents: String
        public internal(set) var author: String?
        public internal(set) var date: Date?
    }
    
    let client: IRCClient
    public let id: UUID
    public let name: String
    public internal(set) var channelModes: [IRCChannelMode: String?]
    public internal(set) var topic: Topic?
    public internal(set) var createdAt: Date?
    
    public internal(set) var members: [IRCUser]
    var isExpectingWhoUpdate: Bool = false
    public let isPrivateMessage: Bool
    
    init (channelName: String, onClient client: IRCClient, channelModes: [IRCChannelMode: String?] = [:], members: [IRCUser] = []) {
        self.id = UUID()
        self.name = channelName
        self.client = client
        self.channelModes = channelModes
        self.members = members
        self.isPrivateMessage = false
    }
    
    init (privateMessage sender: IRCUser, onClient client: IRCClient) {
        self.id = UUID()
        self.name = sender.nickname
        self.client = client
        self.channelModes = [:]
        self.members = [sender]
        self.isPrivateMessage = true
    }
    
    init (dummyName: String, onClient client: IRCClient, members: [IRCUser] = []) {
        self.id = UUID()
        self.name = dummyName
        self.client = client
        self.channelModes = [:]
        self.members = members
        self.isPrivateMessage = false
        self.topic = Topic(contents: "Test Topic", author: "John", date: Date())
    }
    
    public func send (message: String) {
        self.client.sendMessage(toChannel: self, contents: message)
    }
    
    func add (member: IRCUser) {
        self.members.append(member)
    }
    
    func set (nickname: String, member: IRCUser) {
        let existingMemberIndex = self.members.firstIndex(where: {
            $0.nickname == nickname
        })
        if let existingMemberIndex = existingMemberIndex {
            self.members[existingMemberIndex] = member
        } else {
            self.members.append(member)
        }
    }
    
    func set (member: IRCUser) {
        let existingMemberIndex = self.members.firstIndex(where: {
            $0.nickname == member.nickname
        })
        if let existingMemberIndex = existingMemberIndex {
            self.members[existingMemberIndex] = member
        } else {
            self.members.append(member)
        }
    }
    
    func remove (member: IRCUser) {
        self.members.removeAll(where: {
            member.nickname == $0.nickname
        })
    }
    
    func remove(named nickname: String) {
        self.members.removeAll(where: {
            $0.nickname == nickname
        })
    }
    
    func remove(sender: IRCSender) {
        self.remove(named: sender.nickname)
    }
    
    public func member (named nickname: String) -> IRCUser? {
        return members.first(where: {
            $0.nickname == nickname
        })
    }
    
    public func member(fromSender sender: IRCSender) -> IRCUser? {
        return members.first(where: {
            $0.nickname == sender.nickname
        })
    }
}
