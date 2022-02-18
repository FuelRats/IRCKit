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

public struct IRCMessage {
    public let client: IRCClient
    public let command: IRCReply
    public let messageTags: [String: String]
    public let parameters: [String]
    public let time: Date
    public let sender: IRCSender?

    public let messageId: String?
    public let label: String
    public let account: String?

    public var id: String {
        return label
    }

    init? (line: String, client: IRCClient) {
        self.client = client
        var params = line.components(separatedBy: .whitespaces)

        if let tagString = params.first, tagString.starts(with: "@") {
            self.messageTags = IRCMessage.parseMessageTags(tagsString: tagString, client: client)
            params.removeFirst()
        } else {
            self.messageTags = [:]
        }

        if let senderString = params.first, senderString.starts(with: ":") {
            self.sender = IRCSender(fromString: senderString)
            params.removeFirst()
        } else {
            self.sender = nil
        }

        guard let commandString = params.first, let command = IRCReply(rawValue: commandString) else {
            return nil
        }
        self.command = command
        params.removeFirst()

        var messageParameters: [String] = []
        while let param = params.first {
            if param.starts(with: ":") {
                var lastParam = params.joined(separator: " ")
                lastParam = String(lastParam.suffix(from: lastParam.index(lastParam.startIndex, offsetBy: 1)))
                messageParameters.append(lastParam)
                params.removeAll()
            } else {
                messageParameters.append(param)
                params.removeFirst()
            }
        }

        if let serverTime = messageTags["time"] {
            self.time = DateFormatter.iso8601Full.date(from: serverTime) ?? Date()
        } else {
            self.time = Date()
        }

        self.label = messageTags["label"] ?? UUID().uuidString
        self.messageId = messageTags["msgid"]
        self.account = messageTags["account"]

        self.parameters = messageParameters
    }

    public var isCTCPRequest: Bool {
        guard self.parameters.count > 1 else {
            return false
        }

        return self.command == .PRIVMSG && self.parameters[1].starts(with: "\u{001}")
            && self.parameters[1].hasSuffix("\u{001}")
    }

    public var isCTCPReply: Bool {
        guard self.parameters.count > 1 else {
            return false
        }

        return self.command == .NOTICE && self.parameters[1].starts(with: "\u{001}")
            && self.parameters[1].hasSuffix("\u{001}")
    }

    public var isActionMessage: Bool {
        guard self.isCTCPRequest == true else {
            return false
        }

        return self.parameters[1].uppercased().dropFirst().starts(with: "ACTION ")
    }

    static func parseMessageTags (tagsString: String, client: IRCClient) -> [String: String] {
        let tagsString = tagsString.suffix(from: tagsString.index(tagsString.startIndex, offsetBy: 1))
        return tagsString.split(separator: ";").reduce(into: [String: String](), { tags, tag in
            let tagComponents = tag.split(separator: "=")
            tags[String(tagComponents[0])] = tagComponents.count > 1 ? String(tagComponents[1]) : nil
        })
    }
}
