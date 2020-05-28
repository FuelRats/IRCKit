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
}
