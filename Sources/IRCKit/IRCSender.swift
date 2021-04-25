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

public struct IRCSender: CustomStringConvertible {
    public var nickname: String
    public var username: String?
    public var hostmask: String?
    public var address: String?
    public let isServer: Bool

    init? (fromString senderString: String) {
        // Remove :
        let senderString = String(senderString.suffix(from: senderString.index(senderString.startIndex, offsetBy: 1)))

        if senderString.contains("!") && senderString.contains("@") {
            guard let (nickname, username, hostname) = IRCSender.hostmaskComponents(from: senderString) else {
                return nil
            }
            self.nickname = nickname
            self.username = username
            self.hostmask = hostname
            self.address = nil
            self.isServer = false
        } else {
            self.nickname = senderString
            self.username = nil
            self.hostmask = nil
            self.address = senderString
            self.isServer = true
        }
    }


    public var description: String {
        if let username = username, let hostmask = hostmask {
            return "\(self.nickname)!\(username)@\(hostmask)"
        }
        return self.address ?? ""
    }

    public func isCurrentUser (client: IRCClient) -> Bool {
        return self.nickname == client.currentNick
    }

    static func hostmaskComponents (from senderString: String) -> (String, String, String)? {
        guard
            let nicknameDivIndex = senderString.firstIndex(of: "!"),
            let hostnameDivIndex = senderString.firstIndex(of: "@")
        else {
            return nil
        }

        let nickname = String(senderString.prefix(upTo: nicknameDivIndex))
        let username = String(senderString[senderString.index(nicknameDivIndex, offsetBy: 1)..<hostnameDivIndex])
        let hostname = String(senderString[senderString.index(hostnameDivIndex, offsetBy: 1)...])

        return (nickname, username, hostname)
    }
}
