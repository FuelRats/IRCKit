/*
 Copyright 2020 The Fuel Rats Mischief
 
 Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:
 
 1. Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.
 
 2. Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.
 
 3. Neither the name of the copyright holder nor the names of its contributors may be used to endorse or promote products derived from this software without specific prior written permission.
 
 THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

import Foundation
import CryptoSwift

public protocol SASLHandler {
    static var mechanism: String { get }
    
    init (client: IRCClient)
    
    func handleResponse (message: IRCMessage)
}

extension SASLHandler {
    static var supportedHandlers: [SASLHandler.Type] {
        return [PlainTextSASLHandler.self, ExternalSASLHandler.self, Sha256SASLHandler.self]
    }
}

extension IRCClient {
    func handleAuthenticationResponse (message: IRCMessage) {
        self.activeAuthenticationHandler?.handleResponse(message: message)
    }
    
    func abortSaslAuthentication () {
        self.sendAuthenticate(message: "*")
    }
    
    func handleAuthenticationCompleted (message: IRCMessage) {
        self.send(command: .CAP, parameters: ["END"])
    }
    
    func handleAccountChangeServerEvent(message: IRCMessage) {
        guard let sender = message.sender else {
            return
        }
        
        for channel in self.channels {
            if let member = channel.member(fromSender: sender) {
                
                member.account = message.parameters[0] != "*" ? message.parameters[0] : nil
                channel.set(member: member)
            }
        }
        
    }
}

func pbkdf2 (password: String, salt: String, iteration: Int) -> Array<UInt8>? {
    return try? PKCS5.PBKDF2(password: Array(password.utf8), salt: Array(salt.utf8), iterations: iteration, variant: .sha256).calculate()
}


public struct IRCUserAccountChangeNotification: NotificationDescriptor {
    public init () {}
    public struct IRCUserAccountChange: IRCNotification {
        public let id: String
        public let user: IRCUser
        public let oldValue: String?
    }
    
    public typealias Payload = IRCUserAccountChange
    public let name = Notification.Name("IRCUserAccountDidChange")
}
