//
//  SASLExternal.swift
//  IRCKit
//
//  Created by Alex Sørlie Glomsaas on 2020-06-14.
//

import Foundation

class ExternalSASLHandler: SASLHandler {
    static let mechanism = "EXTERNAL"
    var client: IRCClient
    
    required init(client: IRCClient) {
        self.client = client
        client.send(command: .AUTHENTICATE, parameters: [ExternalSASLHandler.mechanism])
    }
    
    
    func handleResponse(message: IRCMessage) {
        if message.parameters[0] == "+" {
            client.sendAuthenticate(message: "+")
        } else {
            client.abortSaslAuthentication()
        }
    }
}
