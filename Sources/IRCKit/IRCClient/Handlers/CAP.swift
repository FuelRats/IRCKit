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
    func handleIRCv3CapabilityReply(message: IRCMessage) {
        guard let capProtocolCommand = message.parameters[safe: 1] else {
            return
        }
        switch capProtocolCommand {
            case "LS":
                capNegotiation(message: message)
            case "ACK":
                capNegotiationComplete(message: message)
            case "NAK":
                capNegotiationFailed(message: message)
            case "NEW":
                capabilitiesAdded(message: message)
            case "DEL":
                capabilitiesRemoved(message: message)
            default:
                break
        }
    }

    func capNegotiation(message: IRCMessage) {
        // A `CAP LS 302` reply is split over multiple messages when the capability list
        // is too long for a single line. Continuation lines have the form
        // `CAP <client> LS * :<caps>` (a `*` in place of the trailing cap list); the
        // final line omits the `*`. Accumulate the tokens and only negotiate once the
        // complete list has arrived.
        let isMultilineContinuation = message.parameters.count > 3 && message.parameters[2] == "*"
        guard let capString = message.parameters[safe: isMultilineContinuation ? 3 : 2] else {
            return
        }

        if self.capabilityLSBuffer.isEmpty {
            self.capabilityLSBuffer = capString
        } else if capString.isEmpty == false {
            self.capabilityLSBuffer += " " + capString
        }

        if isMultilineContinuation {
            return
        }

        let fullCapString = self.capabilityLSBuffer
        self.capabilityLSBuffer = ""

        let caps = IRCv3CapabilityInfo.from(string: fullCapString)
        if let strictTransportInfo = caps.keyValuePairs(cap: .strictTransportSecurity) {
            if let port = Int.parse(strictTransportInfo["port"] ?? nil), port != self.configuration.serverPort {
                self.configuration.serverPort = port
                self.configuration.prefersInsecureConnection = false
                self.connection.disconnect()
                self.connection.connect()
            }
        }

        let supportedCapabilities = Array(caps.keys)
        self.serverInfo.supportedIRCv3Capabilities = supportedCapabilities
        self.requestIRCv3Capabilities(capabilities: supportedCapabilities)
    }

    func capNegotiationComplete(message: IRCMessage) {
        guard let capList = message.parameters[safe: 2] else {
            if self.capabilityNegotiationComplete == false {
                self.endCapabilityNegotiation()
            }
            return
        }

        let acceptedCapabilities = IRCv3Capability.list(fromString: capList)
        for capability in acceptedCapabilities where self.hasIRCv3Capability(capability) == false {
            self.serverInfo.enabledIRCv3Capabilities.append(capability)
        }

        // An ACK received after the initial handshake (e.g. in response to a CAP NEW) only updates
        // the enabled set; it must not restart SASL or re-send CAP END.
        guard self.capabilityNegotiationComplete == false else {
            return
        }

        let caps = IRCv3CapabilityInfo.from(string: capList)
        if let saslCap = caps[.sasl] as? [String] {
            let mechanisms = saslCap.compactMap({ (serverMechanism: String) -> SASLHandler.Type? in
                return IRCClient.supportedHandlers.first(where: { (clientHandler: SASLHandler.Type) -> Bool in
                    clientHandler.mechanism == serverMechanism
                })
            })
            self.serverInfo.supportedSASLMechanisms = mechanisms
        } else if self.hasIRCv3Capability(.sasl) {
            /* This server does not tell us what SASL mechanisms are supported,
             we will assume it supports PLAIN and EXTERNAL, and pray. */
            self.serverInfo.supportedSASLMechanisms = [PlainTextSASLHandler.self, ExternalSASLHandler.self]
        }

        if self.serverInfo.enabledIRCv3Capabilities.contains(.sasl) {
            if saslNegotiation() == true {
                return
            }
        }
        self.endCapabilityNegotiation()
    }

    func capNegotiationFailed(message: IRCMessage) {
        // A NAK after the handshake (a rejected CAP NEW request) requires no action.
        guard self.capabilityNegotiationComplete == false else {
            return
        }
        self.endCapabilityNegotiation()
    }

    /// Handles `CAP NEW` (cap-notify): records the newly-available capabilities and requests any the
    /// client understands and has not already enabled.
    func capabilitiesAdded(message: IRCMessage) {
        guard let capString = message.parameters[safe: 2] else {
            return
        }
        let caps = IRCv3CapabilityInfo.from(string: capString)
        for capability in caps.keys where self.serverInfo.supportedIRCv3Capabilities.contains(capability) == false {
            self.serverInfo.supportedIRCv3Capabilities.append(capability)
        }
        let capabilitiesToRequest = Array(caps.keys).filter({ self.hasIRCv3Capability($0) == false })
        self.requestIRCv3Capabilities(capabilities: capabilitiesToRequest)
    }

    /// Handles `CAP DEL` (cap-notify): the server has withdrawn the given capabilities.
    func capabilitiesRemoved(message: IRCMessage) {
        guard let capString = message.parameters[safe: 2] else {
            return
        }
        let removed = IRCv3Capability.list(fromString: capString)
        self.serverInfo.enabledIRCv3Capabilities.removeAll(where: { removed.contains($0) })
        self.serverInfo.supportedIRCv3Capabilities.removeAll(where: { removed.contains($0) })
    }

    func endCapabilityNegotiation() {
        self.capabilityNegotiationComplete = true
        self.send(command: .CAP, parameters: ["END"])
    }

    func hasIRCv3Capability(_ capability: IRCv3Capability) -> Bool {
        return self.serverInfo.enabledIRCv3Capabilities.contains(capability)
    }
}
