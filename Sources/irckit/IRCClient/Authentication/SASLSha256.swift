//
//  SASLSha256.swift
//  IRCKit
//
//  Created by Alex Sørlie Glomsaas on 2020-06-14.
//

import Foundation
import CryptoSwift

class Sha256SASLHandler: SASLHandler {
    static let mechanism = "SCRAM-SHA-256"
    var client: IRCClient
    var nonce: String?
    var serverSignature: Array<UInt8>?
    
    required init(client: IRCClient) {
        self.client = client
        client.send(command: .AUTHENTICATE, parameters: [Sha256SASLHandler.mechanism])
    }
    
    
    func handleResponse(message: IRCMessage) {
        if message.parameters[0] == "+" {
            self.sendAuthenticationChallenge()
        } else {
            parseSASLScramResponse(message: message)
        }
    }
    
    func sendAuthenticationChallenge () {
        let username = self.client.configuration.authenticationUsername ?? self.client.configuration.username
        let nonce = String.random(length: 32)
        self.nonce = nonce
        
        let challenge = "n,,n=\(username),r=\(nonce)"
        guard let encodedChallenge = challenge.data(using: .utf8)?.base64EncodedString() else {
            self.client.abortSaslAuthentication()
            return
        }
        
        self.client.sendAuthenticate(message: encodedChallenge)
    }
    
    func parseSASLScramResponse (message: IRCMessage) {
        guard
            let scramData = Data(base64Encoded: message.parameters[0]),
            let scramMessage = String(data: scramData, encoding: .utf8)
        else {
            return
        }
        
        let scramParams = scramMessage.keyValuePairs(separatedBy: ",")
        
        guard scramParams["e"] == nil else {
            self.client.abortSaslAuthentication()
            return
        }
        
        if let verification = scramParams["v"] as? String {
            scramSha256Verify(verification: verification)
            return
        }
        
        
        guard
            let nonce = scramParams["r"] as? String,
            let salt = scramParams["s"] as? String,
            let iterationCount = Int(scramParams["i"] as? String ?? "")
        else {
            return
        }
        
        scramSha256Authenticate(salt: salt, nonce: nonce, iterationCount: iterationCount, message: scramMessage)
    }
    
    /* Thank you to github.com/moortens for documenting how this works in their "yoil" IRC Library
     because the people who made the specification sure didn't bother to. */
    func scramSha256Authenticate (salt: String, nonce: String, iterationCount: Int, message: String) {
        guard
            let password = self.client.configuration.authenticationPassword,
            let saltedPassword = pbkdf2(password: password, salt: salt, iteration: iterationCount),
            let clientKey = try? HMAC(key: saltedPassword, variant: .sha256).authenticate(Array("Client Key".utf8)),
            let serverKey = try? HMAC(key: saltedPassword, variant: .sha256).authenticate(Array("Server Key".utf8)),
            let base64Message = message.data(using: .utf8)?.base64EncodedString()
        else {
            self.client.abortSaslAuthentication()
            return
        }
        
        let storedKey = Digest.sha256(clientKey)
        let username = self.client.configuration.authenticationUsername ?? self.client.configuration.username
        let authMessage = [
            "n": username,
            "r": nonce,
            base64Message: nil,
            "c": "biws"
        ].keyValueString(joinedBy: ",")
        
        guard
            let clientSignature = try? HMAC(key: storedKey, variant: .sha256).authenticate(Array(authMessage.utf8)),
            let serverSignature = try? HMAC(key: serverKey, variant: .sha256).authenticate(Array(authMessage.utf8)),
            let clientXor = clientKey.xor(with: clientSignature)
        else {
            self.client.abortSaslAuthentication()
            return
        }
        
        self.serverSignature = serverSignature
        
        let final = [
            "c": "biws",
            "r": nonce,
            "p": clientXor
        ].keyValueString(joinedBy: ",")
        
        guard let base64Final = final.data(using: .utf8)?.base64EncodedString() else {
            self.client.abortSaslAuthentication()
            return
        }
        
        self.client.sendAuthenticate(message: base64Final)
    }
    
    func scramSha256Verify (verification: String) {
        if verification.bytes == self.serverSignature {
            self.client.sendAuthenticate(message: "+")
        } else {
            self.client.abortSaslAuthentication()
        }
    }
}
