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
    func handleNameReply(message: IRCMessage) {
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
            var userModes: Set<IRCChannelUserMode> = []
            while let symbol = name.first, let userMode = IRCChannelUserMode.from(symbol: symbol, onClient: self) {
                name.removeFirst()
                userModes.insert(userMode)
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
                account: nil,
                userModes: userModes
            )

            channel.set(member: user)
        }
    }

    // Standard WHO: <recipient> <channel> <username> <host> <server> <nick> <modes> <realname>
    // Extended WHO: <recipient> <channel> <username> <host> <server> <nick> <modes> <account> <realname>
    func handleWhoReply(message: IRCMessage) {
        guard message.parameters.count > 7 else {
            return
        }

        let channelName = message.parameters[1]
        guard let channel = self.getChannel(named: channelName) else {
            return
        }

        let nickname = message.parameters[5]

        guard let user = channel.member(named: nickname) else {
            return
        }

        user.username = message.parameters[2]
        user.hostmask = message.parameters[3]
        user.connectedServer = message.parameters[4]

        let modes = message.parameters[6]

        user.isAway = modes.contains("G")
        user.isIRCOperator = modes.contains("*") || modes.contains("!")
        user.isSecure = modes.contains("s")

        var realNameIndex = 7
        if message.parameters.count > 8 {
            let account = message.parameters[7] == "0" ? nil : message.parameters[7]
            user.account = account

            realNameIndex = 8
        }

        user.realName = message.parameters[realNameIndex]
        channel.set(member: user)
    }

    func handleTopicInformation(message: IRCMessage) {
        guard let channelName = message.parameters[safe: 1] else {
            return
        }
        guard let channel = self.getChannel(named: channelName) else {
            return
        }

        switch message.command {
            case .RPL_TOPIC:
                if let contents = message.parameters[safe: 2] {
                    channel.topic = IRCChannel.Topic(contents: contents, author: nil, date: nil)
                }

            case .RPL_TOPICWHOTIME:
                guard
                    let author = message.parameters[safe: 2],
                    let dateString = message.parameters[safe: 3],
                    let date = DateFormatter.iso8601Full.date(from: dateString)
                else {
                    return
                }

                channel.topic?.author = author
                channel.topic?.date = date

            case .RPL_NOTOPIC:
                channel.topic = nil

            default:
                break
        }
    }

    func handleChannelModeInformation(message: IRCMessage) {
        guard let channelName = message.parameters[safe: 1] else {
            return
        }
        guard let channel = self.getChannel(named: channelName) else {
            return
        }

        channel.channelModes = IRCChannelMode.modeMap(fromParams: Array(message.parameters[2...]))
    }

    func handleChannelCreatedInformation(message: IRCMessage) {
        guard let channelName = message.parameters[safe: 1] else {
            return
        }
        guard let channel = self.getChannel(named: channelName) else {
            return
        }

        guard
            let createdString = message.parameters[safe: 2],
            let date = DateFormatter.iso8601Full.date(from: createdString)
        else {
            return
        }

        channel.createdAt = date
    }
}
