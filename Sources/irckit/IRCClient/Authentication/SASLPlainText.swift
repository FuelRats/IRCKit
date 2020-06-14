//
//  SASLPlainText.swift
//  IRCKit
//
//  Created by Alex Sørlie Glomsaas on 2020-06-14.
//

import Foundation


class PlainTextSASLHandler: SASLHandler {
    static let mechanism = "PLAIN"
    var client: IRCClient
    
    required init(client: IRCClient) {
        self.client = client
        client.send(command: .AUTHENTICATE, parameters: [PlainTextSASLHandler.mechanism])
    }
    
    
    func handleResponse(message: IRCMessage) {
        if message.parameters[0] == "+" {
            guard let password = client.configuration.authenticationPassword else {
                client.abortSaslAuthentication()
                return
            }
            
            let username = client.configuration.authenticationUsername ?? client.configuration.username
            
            guard let encodedPassword = "\(username)\0\(username)\0\(password)".data(using: .utf8)?.base64EncodedString() else {
                client.abortSaslAuthentication()
                return
            }
            
            client.sendAuthenticate(message: encodedPassword)
        } else {
            client.abortSaslAuthentication()
        }
    }
}
