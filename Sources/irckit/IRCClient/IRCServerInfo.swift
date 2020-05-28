/*
 Copyright 2020 The Fuel Rats Mischief
 
 Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:
 
 1. Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.
 
 2. Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.
 
 3. Neither the name of the copyright holder nor the names of its contributors may be used to endorse or promote products derived from this software without specific prior written permission.
 
 THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

import Foundation

public struct IRCServerInfo {
    var serverName: String?
    var serverVersion: String?
    var networkName: String?
    
    var supportedUserModes: [IRCUserMode]?
    var supportedChannelModes: [IRCChannelMode]?
    var prefixMapping: [IRCChannelUserMode: Character] = [:]
    var caseMapping: String?
    var supportedChannelTypes: [IRCChannelType]?
    var supportedIRCv3Capabilities: [IRCv3Capability] = []
    var enabledIRCv3Capabilities: [IRCv3Capability] = []
    var supportedSASLMechanisms: [SASLMechanism] = []
    var supportsExtendedWhoQuery = false
    
    var maximumAwayMessageLength: Int?
    var maximumChannelNameLength: Int?
    var maximumQuitMessageLength: Int?
    var maximumKickMessageLength: Int?
    var maximumNicknameLength: Int?
    var maximumTopicLength: Int?
    
    mutating func setServerInfo (parameters: [String]) {
        self.serverName = parameters[1]
        self.serverVersion = parameters[2]
        
        let userModeString = parameters[3]
        let channelModeString = parameters[4]
        self.supportedUserModes = IRCUserMode.modeList(fromString: userModeString)
        self.supportedChannelModes = IRCChannelMode.modeList(fromString: channelModeString)
    }
    
    mutating func setSupported (parameters: [String]) {
        var supportEntries = parameters
        supportEntries.removeFirst()
        supportEntries.removeLast()
        
        for supportEntry in supportEntries {
            let supportComponents = supportEntry.components(separatedBy: "=")
            let supportKey = supportComponents[0]
            var supportValue: String? = nil
            if supportComponents.count > 1 {
                supportValue = supportComponents[1]
            }
            
            switch (supportKey, supportValue) {
                case let ("NETWORK", value) where value != nil:
                    self.networkName = value
                    break
                
                case let ("PREFIX", value) where value != nil:
                    if let prefixString = value {
                        self.prefixMapping = IRCChannelUserMode.map(fromString: prefixString)
                    }
                    break
                
                case ("WHOX", _):
                    self.supportsExtendedWhoQuery = true
                    break
                
                case let ("CASEMAPPING", value) where value != nil:
                    self.caseMapping = value
                    break
                
                case let ("AWAYLEN", value) where Int(value ?? "") != nil:
                    self.maximumAwayMessageLength = Int(value ?? "")
                    break
                
                case let ("CHANNELLEN", value) where Int(value ?? "") != nil:
                    self.maximumChannelNameLength = Int(value ?? "")
                    break
                
                case let ("QUITLEN", value) where Int(value ?? "") != nil:
                    self.maximumQuitMessageLength = Int(value ?? "")
                    break
                
                case let ("KICKLEN", value) where Int(value ?? "") != nil:
                    self.maximumKickMessageLength = Int(value ?? "")
                    break
                
                case let ("NICKLEN", value) where Int(value ?? "") != nil:
                    self.maximumNicknameLength = Int(value ?? "")
                    break
                
                case let ("TOPICLEN", value) where Int(value ?? "") != nil:
                    self.maximumTopicLength = Int(value ?? "")
                    break
                
                default:
                    break
            }
        }
    }
}

enum IRCUserMode: Character {
    case isBot = "B"
    case filterPrivateMessagesByPrefix = "d"
    case filterPrivateMessagesRegOnly = "R"
    case filterPrivateMessagesSSLOnly = "Z"
    case ignorePrivateMessages = "D"
    case censored = "G"
    case hideIRCOperatorStatus = "H"
    case hideOnlineTime = "I"
    case ircOperator = "o"
    case hideChannels = "p"
    case unkickable = "q"
    case registered = "r"
    case isServices = "S"
    case serverNotices = "s"
    case ignoreCTCP = "T"
    case hasVirtualHost = "t"
    case canSeeWALLOP = "w"
    case hasCloakedHostname = "x"
    case connectedViaSSL = "z"
    
    static func modeList (fromString userModeString: String) -> [IRCUserMode] {
        return Array(userModeString).compactMap({
            return IRCUserMode(rawValue: $0)
        })
    }
}

public enum IRCChannelMode: Character {
    case noColorAllowed = "c"
    case noCTCPAllowed = "C"
    case delayJoinUntilMessage = "D"
    case floodProtection = "f"
    case censored = "G"
    case playsChannelHistory = "H"
    case inviteOnly = "i"
    case requiresPassword = "k"
    case noKnockingAllowed = "K"
    case linkedChannel = "L"
    case limitUserCount = "l"
    case moderated = "m"
    case registeredOnlyMessage = "M"
    case noExternalMessages = "n"
    case IRCOperatorsOnly = "O"
    case permanent = "P"
    case privateChannel = "p"
    case noKickAllowed = "Q"
    case registeredOnlyAllowed = "R"
    case registeredWithServices = "r"
    case isSecret = "s"
    case stripColors = "S"
    case noNoticesAllowed = "T"
    case topicChangeRestricted = "t"
    case noInvitesAllowed = "V"
    case sslConnectionRequired = "z"
    case channelOnlyHasSecureMembers = "Z"
    
    static func modeList (fromString channelModeString: String) -> [IRCChannelMode] {
        return Array(channelModeString).compactMap({
            return IRCChannelMode(rawValue: $0)
        })
    }
}

public enum IRCv3Capability: String {
    case extendedJoin = "extended-join"
    case hostnameChangeMessage = "chghost"
    case capaibilityChangeNotification = "cap-notify"
    case userhostInNames = "userhost-in-names"
    case multiplePrefixes = "multi-prefix"
    case awayNotification = "away-notify"
    case accountChangeNotification = "account-notify"
    case sasl = "sasl"
    case messageTags = "message-tags"
    case accountTagInMessage = "account-tag"
    case serverSentTimestamps = "server-time"
    case messageConfirmation = "echo-message"
    case batchMessageProcessing = "batch"
    case labeledResponses = "labeled-response"
    
    static func list (fromString capString: String) -> [IRCv3Capability] {
        let availableCapabilities = capString.components(separatedBy: .whitespaces)
        return availableCapabilities.compactMap({
            capItemString in
            let capComponents = capItemString.components(separatedBy: "=")
            let capKey = capComponents[0]
            
            return IRCv3Capability(rawValue: capKey)
        })
    }
    
    static func map (fromString capString: String) -> [IRCv3Capability:[String]?] {
        let availableCapabilities = capString.components(separatedBy: .whitespaces)
        return availableCapabilities.reduce([:], { (acc: [IRCv3Capability: [String]?], capItemString: String) -> [IRCv3Capability: [String]?] in
            var acc = acc
            let capComponents = capItemString.components(separatedBy: "=")
            let capKey = capComponents[0]
            
            guard let capability = IRCv3Capability(rawValue: capKey) else {
                return acc
            }
            
            let values = capComponents.count > 1 ? capComponents[1].components(separatedBy: ",") : nil
            
            acc[capability] = values
            return acc
        })
    }
}

public enum SASLMechanism: String {
    case external = "EXTERNAL"
    case plainText = "PLAIN"
    case sha256 = "SCRAM-SHA-256"
}

enum IRCChannelType {
    
}

enum IRCExtendedBanTypes {
    
}
