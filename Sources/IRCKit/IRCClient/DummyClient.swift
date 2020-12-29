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
    static var names: [IRCChannelUserMode?: [String]] {
        return [
            .owner: ["TheLegend27"],
            .admin: ["Donut[AFK]", "AzureDiamond"],
            .operator: ["Eurakarte", "BlackAdder", "t0rbad", "erno"],
            .halfop: ["Zybl0re", "nmp3bot", "HatfulOfHollow", "TheXPhial", "Guo_Si"],
            .voice: [
                "DeadMansHand", "PeteRepeat", "Judge-Mental", "Khassaki", "DragonflyBlade2", "anamexis", "xterm",
                "mage", "Kevyn", "JonJonB", "Rabidplaybunny87", "GarbageStan23"
            ],
            nil: ["death09", "ktp753", "JonTG", "Ben174", "ChrisLMB", "bloodninja", "T-Wolf", "RdAwG20", "Abstruse",
                  "jeebus", "NES", "Sonium", "Eticam"
            ]
        ]
    }

    public static var dummy: IRCClient {
        let clientConfiguration = IRCClientConfiguration(
            serverName: "Dummy Server",
            serverAddress: "127.0.0.1",
            nickname: "DummyUser",
            username: "dummy",
            realName: "Dummy User"
        )
        let client = IRCClient(configuration: clientConfiguration)
        let channelModes: [IRCChannelMode: String?] = [
            .noExternalMessages: nil,
            .topicChangeRestricted: nil,
            .registeredWithServices: nil
        ]

        var users: [IRCUser] = []
        for mode in names {
            users.append(contentsOf: mode.value.map({ (name: String) -> IRCUser in
                let user = IRCUser(
                    onClient: client,
                    nickname: name,
                    username: name.lowercased(),
                    hostmask: "\(name.lowercased()).example.com",
                    realName: name,
                    account: nil,
                    userModes: mode.key != nil ? [mode.key!] : []
                )
                user.isAway = Bool.random()
                return user
            }))
        }

        client.channels = [
            IRCChannel(
                channelName: "#test",
                onClient: client,
                channelModes: channelModes,
                members: users
            ),

            IRCChannel(
                channelName: "#help",
                onClient: client,
                channelModes: channelModes,
                members: users
            ),

            IRCChannel(
                channelName: "#random",
                onClient: client,
                channelModes: channelModes,
                members: users
            ),

            IRCChannel(
                channelName: "#general",
                onClient: client,
                channelModes: channelModes,
                members: users
            )
        ]
        return client
    }
}
