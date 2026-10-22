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
    func sendRegistration() {
        self.capabilityNegotiationComplete = false
        if let password = self.configuration.serverPassword {
            self.send(command: .PASS, parameters: [password])
        }
        self.send(command: .USER, parameters: [self.configuration.username, "0", "*", self.configuration.realName])
        self.sendNicknameChange(nickname: self.configuration.nickname)
        self.send(command: .CAP, parameters: ["LS", "302"])
        if self.monitor.count > 0 && self.serverInfo.supportsMonitor {
            self.sendMonitor(addTargets: self.monitor)
        }
    }

    public func sendJoin(channels: [String]) {
        var channels = channels
        while channels.count > 0 {
            let chunkSize = min(channels.count, 10)
            let joinChunk = Array(channels[0 ..< chunkSize])
            channels.removeFirst(chunkSize)
            self.send(command: .JOIN, parameters: joinChunk.joined(separator: ","))
        }
    }

    public func sendJoin(channelName: String) {
        self.send(command: .JOIN, parameters: [channelName])
    }

    public func sendNicknameChange(nickname: String) {
        self.send(command: .NICK, parameters: [nickname])
    }

    public func sendPart(channel: IRCChannel, message: String = "") {
        self.sendPart(channelName: channel.name)
    }

    public func sendPart(channelName: String, message: String = "") {
        self.send(command: .PART, parameters: [channelName, message])
    }

    public func sendQuit(message: String = "") {
        self.send(command: .QUIT, parameters: [message])
    }

    public func requestIRCv3Capabilities(capabilities: [IRCv3Capability]) {
        guard capabilities.count > 0 else {
            return
        }
        let capString = capabilities.map({
            $0.rawValue
        }).joined(separator: " ")

        self.send(command: .CAP, parameters: ["REQ", capString])
    }

    public func sendAuthenticate(message: String) {
        self.send(command: .AUTHENTICATE, parameters: [message])
    }

    public func sendMessage(toChannel channel: IRCChannel, contents: String, additionalTags: [String: String?] = [:]) {
        self.sendMessage(toTarget: channel.name, contents: contents, additionalTags: additionalTags)
    }

    public func sendMessage(toTarget target: String, contents: String, additionalTags: [String: String?] = [:]) {
        /*
         The IRC protocol has a maximum message length of 512 including source (nick!user@host), command and line break
         For this we are calculating the length of our source and adding 7 for PRIVMSG, 7 for spaces and characters
         in the command, and finally the length of the target (channel/pm user).

         Whilst the IRC protocol expects us to derive the length of our own source, this is sometimes impossible as
         following the RFC, the server never actually tells you your own hostname until you join a channel.
         Thanks Jarkko Oikarinen, very cool.

         In these circumstances we default to a sender length of 103, 30 for nickname, 10 for ident/username and
         63 for hostmask.
         */
        let senderLength = self.currentSender?.description.utf8.count ?? 103
        let maxMessageLength = 510 - (senderLength + 7 + 7 + target.utf8.count)

        for chunk in IRCClient.splitMessage(contents.withoutCTCPDelimiters(), maxBytes: maxMessageLength) {
            self.send(command: .PRIVMSG, parameters: [target, chunk], tags: additionalTags)
        }
    }

    /// The smallest per-line budget used when splitting, so a pathological sender or target length can never make
    /// the budget zero or negative.
    static let minimumSplitBytes = 32

    /**
     Splits a message into chunks of at most `maxBytes` UTF-8 bytes. Splits prefer the last whitespace before the
     limit, then the last whole grapheme cluster, then (for a single cluster larger than the limit, such as heavy
     combining marks) the last whole unicode scalar. Every chunk is non-empty, so splitting always terminates.
     */
    static func splitMessage(_ contents: String, maxBytes: Int) -> [String] {
        let maxBytes = max(maxBytes, IRCClient.minimumSplitBytes)
        var chunks: [String] = []
        var remaining = Substring(contents)

        while remaining.isEmpty == false {
            if remaining.utf8.count <= maxBytes {
                chunks.append(String(remaining))
                break
            }

            var limit = remaining.startIndex
            var byteCount = 0
            for index in remaining.indices {
                let characterBytes = remaining[index].utf8.count
                guard byteCount + characterBytes <= maxBytes else {
                    break
                }
                byteCount += characterBytes
                limit = remaining.index(after: index)
            }

            let splitIndex: String.Index
            if limit == remaining.startIndex {
                splitIndex = scalarSplitIndex(in: remaining, maxBytes: maxBytes)
            } else if
                let whitespace = remaining[remaining.startIndex..<limit].lastIndex(where: { $0.isWhitespace }),
                whitespace > remaining.startIndex {
                splitIndex = whitespace
            } else {
                splitIndex = limit
            }

            chunks.append(String(remaining[remaining.startIndex..<splitIndex]))
            remaining = remaining[splitIndex...].drop(while: { $0.isWhitespace })
        }
        return chunks
    }

    private static func scalarSplitIndex(in text: Substring, maxBytes: Int) -> String.Index {
        let scalars = text.unicodeScalars
        var index = scalars.startIndex
        var byteCount = 0
        while index < scalars.endIndex {
            let scalarBytes = String(scalars[index]).utf8.count
            guard byteCount + scalarBytes <= maxBytes else {
                break
            }
            byteCount += scalarBytes
            index = scalars.index(after: index)
        }
        return index > scalars.startIndex ? index : scalars.index(after: scalars.startIndex)
    }

    public func sendActionMessage(toChannel channel: IRCChannel, contents: String) {
        self.sendActionMessage(toChannelName: channel.name, contents: contents)
    }

    public func sendActionMessage(toChannelName channelName: String, contents: String) {
        self.send(command: .PRIVMSG, parameters: [channelName, "\u{001}ACTION \(contents.withoutCTCPDelimiters())\u{001}"])
    }

    public func sendCTCPRequest(toChannel channel: IRCChannel, contents: String) {
        self.send(command: .PRIVMSG, parameters: [channel.name, "\u{001}\(contents)\u{001}"])
    }

    public func sendNotice(toTarget target: String, contents: String) {
        self.send(command: .NOTICE, parameters: [target, contents.withoutCTCPDelimiters()])
    }

    public func sendMonitor(addTargets targets: Set<String>) {
        self.send(command: .MONITOR, parameters: "+", targets.joined(separator: ","))
    }

    public func sendMonitor(removeTargets targets: Set<String>) {
        self.send(command: .MONITOR, parameters: "-", targets.joined(separator: ","))
    }

   public func sendMonitorClear() {
        self.send(command: .MONITOR, parameters: "C")
    }

    public func sendMonitorListRequest() {
        self.send(command: .MONITOR, parameters: "L")
    }

    public func sendMonitorStatusRequest() {
        self.send(command: .MONITOR, parameters: "S")
    }
}
