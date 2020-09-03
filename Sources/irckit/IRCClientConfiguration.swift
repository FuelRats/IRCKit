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

public struct IRCClientConfiguration: Codable {
    public init (
        serverName: String,
        serverAddress: String,
        serverPort: Int = 6697,
        nickname: String,
        username: String,
        realName: String
    ) {
        self.serverName = serverName
        self.serverAddress = serverAddress
        self.serverPort = serverPort
        self.nickname = nickname
        self.username = username
        self.realName = realName
    }

    public var autoConnect = false
    public var autoReconnect = false

    public var serverAddress: String
    public var serverPort: Int = 6697
    public var serverPassword: String?
    public var serverName: String
    public var nickname: String
    public var username: String
    public var realName: String

    public var authenticationUsername: String?
    public var authenticationPassword: String?

    public var floodControlDelayTimerInterval: Int? = 3
    public var floodControlMaximumMessages: Int? = 5

    public var prefersInsecureConnection = false
    public var chiperSuite: String?
    public var clientCertificatePath: String?
    public var allowsServerSelfSignedCertificate = false

    public var channels: [String] = []
}
