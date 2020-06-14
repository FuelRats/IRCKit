/*
Copyright 2020 The Fuel Rats Mischief

Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:

1. Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.

2. Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.

3. Neither the name of the copyright holder nor the names of its contributors may be used to endorse or promote products derived from this software without specific prior written permission.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
*/

import Foundation

extension Array where Element == String {
    func keyValuePairs () -> [String: String?] {
        return self.reduce([:], { (acc: [String: String?], token: String) -> [String: String?] in
            var acc = acc
            let comps = token.components(separatedBy: "=")
            acc[comps[0]] = comps.count > 1 ? comps[1] : nil
            
            return acc
        })
    }
}

extension Dictionary where Key == String, Value == String {
    func keyValueString (joinedBy separator: String) -> String {
        return self.map({ (kv: (String, String)) -> String in
            let (key, value) = kv
            return "\(key)=\(value)"
        }).joined(separator: separator)
    }
}

extension Dictionary where Key == String, Value == String? {
    func keyValueString (joinedBy separator: String) -> String {
        return self.map({ (kv: (String, String?)) -> String in
            let (key, value) = kv
            return value != nil ? "\(key)=\(value!)" : key
        }).joined(separator: separator)
    }
}

extension Array where Element == UInt8 {
    func xor (with key: [UInt8]) -> String? {
        if self.isEmpty {
            return nil
        }
        
        var encrypted = [UInt8]()
        let length = key.count
        
        for t in self.enumerated() {
            encrypted.append(t.element ^ key[t.offset % length])
        }
        
        return encrypted.toBase64()
    }
}

extension String {
    func keyValuePairs (separatedBy separator: String) -> [String: String?] {
        let tokens = self.components(separatedBy: separator)
        
        return tokens.keyValuePairs()
    }
    
    static func random (length: Int = 20) -> String {
        let base = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
        var randomString: String = ""

        for _ in 0..<length {
            let randomValue = arc4random_uniform(UInt32(base.count))
            randomString += "\(base[base.index(base.startIndex, offsetBy: Int(randomValue))])"
        }
        return randomString
    }
    
}
