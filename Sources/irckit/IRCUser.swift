/*
 Copyright 2020 The Fuel Rats Mischief
 
 Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:
 
 1. Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.
 
 2. Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.
 
 3. Neither the name of the copyright holder nor the names of its contributors may be used to endorse or promote products derived from this software without specific prior written permission.
 
 THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

import Foundation

public class IRCUser {
    public let client: IRCClient
    public internal(set) var nickname: String
    public internal(set) var username: String
    public internal(set) var hostmask: String
    public internal(set) var realName: String?
    
    public var account: String? = nil {
        didSet {
            let notification = IRCUserAccountChangeNotification().encode(payload: IRCUserAccountChangeNotification.IRCUserAccountChange(user: self, oldValue: oldValue))
            NotificationCenter.default.post(notification)
        }
    }
    
    public var isAway = false
    public var isIRCOperator = false
    public var lastMessage: String?
    
    public var channelUserModes: [IRCChannelUserMode] = []
    
    init (onClient client: IRCClient, nickname: String, username: String, hostmask: String, realName: String?, account: String?) {
        self.client = client
        self.nickname = nickname
        self.username = username
        self.hostmask = hostmask
        self.realName = realName
        self.account = account
        self.isAway = false
        self.lastMessage = nil
    }
    
    init (fromPrivateMessage message: IRCMessage, onClient client: IRCClient) {
        self.client = client
        let sender = message.sender!
        
        self.nickname = sender.nickname
        self.username = sender.username!
        self.hostmask = sender.hostmask!
        self.realName = nil
        self.account = message.account
        self.isAway = false
        self.lastMessage = nil
    }
}

public enum IRCChannelUserMode: Character {
    case owner = "q"
    case admin = "a"
    case op = "o"
    case halfop = "h"
    case voice = "v"
    
    static func from (symbol: Character, onClient client: IRCClient) -> IRCChannelUserMode? {
        return client.serverInfo.prefixMapping.first(where: { $0.value == symbol })?.key
    }

    static func map (fromString prefixString: String) -> [IRCChannelUserMode: Character] {
        let prefixLettersStartIndex = prefixString.index(prefixString.firstIndex(of: "(")!, offsetBy: 1)
        let prefixLettersEndIndex = prefixString.firstIndex(of: ")")!
        let prefixSymbolsStartIndex = prefixString.index(prefixLettersEndIndex, offsetBy: 1)
        let prefixLetters = prefixString[prefixLettersStartIndex..<prefixLettersEndIndex]
        let prefixSymbols = prefixString.suffix(from: prefixSymbolsStartIndex)
        
        var prefixMap: [IRCChannelUserMode: Character] = [:]
        
        for (identifier,symbol) in zip(prefixLetters, prefixSymbols) {
            if let prefix = IRCChannelUserMode(rawValue: identifier) {
                prefixMap[prefix] = symbol
            }
        }
        
        return prefixMap
    }
}
