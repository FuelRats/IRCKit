/*
 Copyright 2020 The Fuel Rats Mischief
 
 Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:
 
 1. Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.
 
 2. Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.
 
 3. Neither the name of the copyright holder nor the names of its contributors may be used to endorse or promote products derived from this software without specific prior written permission.
 
 THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

import Foundation

extension IRCClient {
    func handleIRCv3CapabilityReply (message: IRCMessage) {
        let capProtocolCommand = message.parameters[1]
        switch capProtocolCommand {
            case "LS":
                capNegotiation(message: message)
                break
            
            case "ACK":
                capNegotiationComplete(message: message)
                break
            
            case "NAK":
                capNegotiationFailed(message: message)
                break
            
            default:
                break
        }
    }
    
    func capNegotiation (message: IRCMessage) {
        let caps = IRCv3Capability.map(fromString: message.parameters[2])
        let supportedCapabilities = Array(caps.keys)
        self.serverInfo.supportedIRCv3Capabilities = supportedCapabilities
        self.requestIRCv3Capabilities(capabilities: supportedCapabilities)
    }
    
    func capNegotiationComplete (message: IRCMessage) {
        let acceptedCapabilities = IRCv3Capability.list(fromString: message.parameters[2])
        self.serverInfo.enabledIRCv3Capabilities = acceptedCapabilities
        
        
        let caps = IRCv3Capability.map(fromString: message.parameters[2])
        if let saslCap = caps[.sasl] as? [String] {
            let mechanisms = saslCap.compactMap({
                SASLMechanism(rawValue: $0)
            })
            self.serverInfo.supportedSASLMechanisms = mechanisms
        } else if self.hasIRCv3Capability(.sasl) {
            // This server does not tell us what SASL mechanisms are supported, we will assume it supports PLAIN and EXTERNAL, and pray.
            self.serverInfo.supportedSASLMechanisms = [.plainText, .external]
        }
        
        if self.serverInfo.enabledIRCv3Capabilities.contains(.sasl) {
            if self.configuration.clientCertificatePath != nil && self.serverInfo.supportedSASLMechanisms.contains(.external) {
                self.initiateAuthentication(mechanism: .external)
                return
            } else if self.configuration.authenticationPassword != nil && self.serverInfo.supportedSASLMechanisms.contains(.plainText) {
                self.initiateAuthentication(mechanism: .plainText)
                return
            }
        }
        self.send(command: .CAP, parameters: ["END"])
    }
    
    func capNegotiationFailed (message: IRCMessage) {
        self.send(command: .CAP, parameters: ["END"])
    }
    
    func hasIRCv3Capability (_ capability: IRCv3Capability) -> Bool {
        return self.serverInfo.enabledIRCv3Capabilities.contains(capability)
    }
}
