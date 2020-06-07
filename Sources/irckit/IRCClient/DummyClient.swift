//
//  DummyClient.swift
//  IRCKit
//
//  Created by Alex Sørlie Glomsaas on 2020-06-03.
//

import Foundation

extension IRCClient {
    static var names: [IRCChannelUserMode?: [String]] {
        return [
            .owner: ["TheLegend27"],
            .admin: ["Donut[AFK]", "AzureDiamond"],
            .op: ["Eurakarte", "BlackAdder", "t0rbad", "erno"],
            .halfop: ["Zybl0re", "nmp3bot", "HatfulOfHollow", "TheXPhial", "Guo_Si"],
            .voice: ["DeadMansHand", "PeteRepeat", "Judge-Mental", "Khassaki", "DragonflyBlade2", "anamexis", "xterm", "mage", "Kevyn", "JonJonB", "Rabidplaybunny87", "GarbageStan23"],
            nil: ["death09", "ktp753", "JonTG", "Ben174", "ChrisLMB", "bloodninja", "T-Wolf", "RdAwG20", "Abstruse", "jeebus", "NES", "Sonium", "Eticam"]
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
            ),
        ]
        return client
    }
}
