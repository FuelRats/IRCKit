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

extension Array where Element == String {
    func keyValuePairs() -> [String: String?] {
        return self.reduce([:], { (acc: [String: String?], token: String) -> [String: String?] in
            var acc = acc
            let comps = token.components(separatedBy: "=")
            acc[comps[0]] = comps[safe: 1]

            return acc
        })
    }
}

extension Array where Element == UInt8 {
    func xor(with key: [UInt8]) -> String? {
        if self.isEmpty {
            return nil
        }

        var encrypted = [UInt8]()
        let length = key.count

        for char in self.enumerated() {
            encrypted.append(char.element ^ key[char.offset % length])
        }

        return encrypted.toBase64()
    }
}

extension String {
    func keyValuePairs(separatedBy separator: String) -> [String: String?] {
        let tokens = self.components(separatedBy: separator)

        return tokens.keyValuePairs()
    }

    /// Removes the characters forbidden inside an IRC parameter (NUL, CR, LF) so caller-supplied
    /// text cannot terminate the line and inject additional commands. Filtering operates on unicode
    /// scalars because Swift treats a CR+LF pair as a single grapheme cluster.
    func ircParameterSanitized() -> String {
        return String(String.UnicodeScalarView(self.unicodeScalars.filter({
            $0 != "\0" && $0 != "\r" && $0 != "\n"
        })))
    }

    /// Folds a nickname or channel name to a canonical lowercase form for case-insensitive
    /// comparison, honouring the server's CASEMAPPING (RFC 2812 §2.2). `rfc1459` additionally treats
    /// `[]\~` as the uppercase forms of `{}|^`; `rfc1459-strict` does the same except for `~`;
    /// `ascii` folds only A–Z. Defaults to `rfc1459` when the server has not advertised a mapping.
    func ircCaseFolded(mapping: String?) -> String {
        let mapping = mapping?.lowercased() ?? "rfc1459"
        let foldsBrackets = mapping == "rfc1459" || mapping == "rfc1459-strict"
        let foldsTilde = mapping == "rfc1459"

        var folded = String.UnicodeScalarView()
        for scalar in self.unicodeScalars {
            switch scalar.value {
                case 0x41...0x5A:  // A–Z
                    folded.append(UnicodeScalar(scalar.value + 32) ?? scalar)
                case 0x5B where foldsBrackets:  // [
                    folded.append("{")
                case 0x5D where foldsBrackets:  // ]
                    folded.append("}")
                case 0x5C where foldsBrackets:  // \
                    folded.append("|")
                case 0x7E where foldsTilde:  // ~
                    folded.append("^")
                default:
                    folded.append(scalar)
            }
        }
        return String(folded)
    }

    static func random(length: Int = 20) -> String {
        let base = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
        var randomString: String = ""

        for _ in 0..<length {
            #if os(Linux)
            let randomValue = Int.random(in: 0..<length)
            #else
            let randomValue = Int.random(in: 0..<base.count)
            #endif
            randomString += "\(base[base.index(base.startIndex, offsetBy: randomValue)])"
        }
        return randomString
    }

    /// Escapes this string for use as an IRCv3 message-tag value, per the message-tags spec:
    /// `\` → `\\`, `;` → `\:`, space → `\s`, CR → `\r`, LF → `\n`.
    func ircTagValueEscaped() -> String {
        var escaped = ""
        escaped.reserveCapacity(self.count)
        for character in self {
            switch character {
                case "\\": escaped += "\\\\"
                case ";": escaped += "\\:"
                case " ": escaped += "\\s"
                case "\r": escaped += "\\r"
                case "\n": escaped += "\\n"
                default: escaped.append(character)
            }
        }
        return escaped
    }

    /// Reverses IRCv3 message-tag value escaping. Unrecognised escape sequences resolve to the
    /// escaped character itself, and a trailing lone backslash is dropped, both per the spec.
    func ircTagValueUnescaped() -> String {
        var unescaped = ""
        unescaped.reserveCapacity(self.count)
        var iterator = self.makeIterator()
        while let character = iterator.next() {
            guard character == "\\" else {
                unescaped.append(character)
                continue
            }
            guard let escaped = iterator.next() else {
                break
            }
            switch escaped {
                case ":": unescaped.append(";")
                case "s": unescaped.append(" ")
                case "\\": unescaped.append("\\")
                case "r": unescaped.append("\r")
                case "n": unescaped.append("\n")
                default: unescaped.append(escaped)
            }
        }
        return unescaped
    }

}
