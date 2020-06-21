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

public struct IRCServerInfo {
    public internal(set) var serverName: String?
    public internal(set) var serverVersion: String?
    public internal(set) var networkName: String?

    public internal(set) var supportedUserModes: [IRCUserMode]?
    public internal(set) var supportedChannelModes: [IRCChannelMode]?
    public internal(set) var prefixMapping: [IRCChannelUserMode: Character] = [
        .owner: "~",
        .admin: "&",
        .operator: "@",
        .halfop: "%",
        .voice: "+"
    ]
    public internal(set) var caseMapping: String?
    public internal(set) var supportedChannelTypes: [IRCChannelType]?
    public internal(set) var supportedIRCv3Capabilities: [IRCv3Capability] = []
    public internal(set) var enabledIRCv3Capabilities: [IRCv3Capability] = []
    public internal(set) var supportedSASLMechanisms: [SASLHandler.Type] = []
    public internal(set) var supportsExtendedWhoQuery = false
    public internal(set) var supportsMonitor = false

    public internal(set) var maximumAwayMessageLength: Int?
    public internal(set) var maximumChannelNameLength: Int?
    public internal(set) var maximumQuitMessageLength: Int?
    public internal(set) var maximumKickMessageLength: Int?
    public internal(set) var maximumNicknameLength: Int?
    public internal(set) var maximumTopicLength: Int?
    public internal(set) var maximumRealNameLength: Int?
    public internal(set) var maximumMonitorTargets: Int?

    func supportsSASLMechanism (handler: SASLHandler.Type) -> Bool {
        return self.supportedSASLMechanisms.contains(where: { (supportedHandler: SASLHandler.Type) -> Bool in
            return supportedHandler == handler
        })
    }

    internal mutating func setServerInfo (parameters: [String]) {
        self.serverName = parameters[1]
        self.serverVersion = parameters[2]

        let userModeString = parameters[3]
        let channelModeString = parameters[4]
        self.supportedUserModes = IRCUserMode.modeList(fromString: userModeString)
        self.supportedChannelModes = IRCChannelMode.modeList(fromString: channelModeString)
    }

    internal mutating func setSupported (parameters: [String]) {
        var supportEntries = parameters
        supportEntries.removeFirst()
        supportEntries.removeLast()

        for (supportKey, supportValue) in supportEntries.keyValuePairs() {
            switch (supportKey, supportValue) {
                case let ("NETWORK", value):
                    self.networkName = value

                case let ("PREFIX", value):
                    if let prefixString = value {
                        self.prefixMapping = IRCChannelUserMode.map(fromString: prefixString)
                    }

                case ("WHOX", _):
                    self.supportsExtendedWhoQuery = true

                case let ("CASEMAPPING", value):
                    self.caseMapping = value

                case let ("AWAYLEN", value):
                    self.maximumAwayMessageLength = Int.parse(value)

                case let ("CHANNELLEN", value):
                    self.maximumChannelNameLength = Int.parse(value)

                case let ("QUITLEN", value):
                    self.maximumQuitMessageLength = Int.parse(value)

                case let ("KICKLEN", value):
                    self.maximumKickMessageLength = Int.parse(value)

                case let ("NICKLEN", value):
                    self.maximumNicknameLength = Int.parse(value)

                case let ("TOPICLEN", value):
                    self.maximumTopicLength = Int.parse(value)

                case let ("NAMELEN", value):
                    self.maximumRealNameLength = Int.parse(value)

                case let ("MONITOR", value):
                    self.supportsMonitor = true
                    self.maximumMonitorTargets = Int.parse(value)

                default:
                    break
            }
        }
    }
}

public enum IRCUserMode: Character {
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

    internal static func modeList (fromString userModeString: String) -> [IRCUserMode] {
        return Array(userModeString).compactMap({
            return IRCUserMode(rawValue: $0)
        })
    }
}

public enum IRCChannelMode: Character, Hashable {
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

    internal static func modeList (fromString channelModeString: String) -> [IRCChannelMode] {
        return Array(channelModeString).compactMap({
            return IRCChannelMode(rawValue: $0)
        })
    }

    internal static func modeMap (fromParams channelModes: [String]) -> [IRCChannelMode: String?] {
        var modeMap: [IRCChannelMode: String?] = [:]
        var modeArgs = channelModes
        let modes = modeArgs[0]
        modeArgs.removeFirst()

        for modeChar in Array(modes) {
            guard let mode = IRCChannelMode(rawValue: modeChar) else {
                continue
            }

            switch mode {
                case .floodProtection,
                     .playsChannelHistory,
                     .requiresPassword,
                     .limitUserCount:
                    modeMap[mode] = modeArgs.first
                    modeArgs.removeFirst()

                default:
                    modeMap[mode] = nil
            }
        }

        return modeMap
    }
}

typealias IRCv3CapabilityInfo = [IRCv3Capability: [String]?]

public enum IRCv3Capability: String {
    case extendedJoin = "extended-join"
    case hostnameChangeMessage = "chghost"
    case capaibilityChangeNotification = "cap-notify"
    case userhostInNames = "userhost-in-names"
    case multiplePrefixes = "multi-prefix"
    case awayNotification = "away-notify"
    case accountChangeNotification = "account-notify"
    case channelInviteNotification = "invite-notify"
    case sasl = "sasl"
    case messageTags = "message-tags"
    case accountTagInMessage = "account-tag"
    case serverSentTimestamps = "server-time"
    case messageConfirmation = "echo-message"
    case batchMessageProcessing = "batch"
    case labeledResponses = "labeled-response"
    case changeRealName = "setname"
    case strictTransportSecurity = "sts"

    internal static func list (fromString capString: String) -> [IRCv3Capability] {
        let capStrings = Array(capString.keyValuePairs(separatedBy: " ").keys)
        return capStrings.compactMap({ capItem in
            return IRCv3Capability(rawValue: capItem)
        })
    }
}

extension IRCv3CapabilityInfo {
    static func from (string: String) -> IRCv3CapabilityInfo {
        let availableCapabilities = string.keyValuePairs(separatedBy: " ")
        return availableCapabilities.reduce([:], { (acc: [IRCv3Capability: [String]?], kvPair: (String, String?)) ->
            [IRCv3Capability: [String]?] in

            var acc = acc
            let (key, val) = kvPair
            guard let capability = IRCv3Capability(rawValue: key) else {
                return acc
            }

            let values = val?.components(separatedBy: ",")
            acc[capability] = values

            return acc
        })
    }

    func keyValuePairs (cap: IRCv3Capability) -> [String: String?]? {
        guard let capInfo = self[cap] else {
            return nil
        }

        return capInfo?.keyValuePairs()
    }
}

public enum IRCChannelType {

}

enum IRCExtendedBanTypes {

}
