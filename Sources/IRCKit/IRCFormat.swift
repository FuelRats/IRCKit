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

public struct IRCFormat {
    public static func bold (_ string: String) -> String {
        return "\u{002}\(string)\u{002}"
    }
    
    public static func italic (_ string: String) -> String {
        return "\u{01D}\(string)\u{01D}"
    }
    
    public static func underline (_ string: String) -> String {
        return "\u{01F}\(string)\u{01F}"
    }
    
    public static func strikethrough (_ string: String) -> String {
        return "\u{01E}\(string)\u{01E}"
    }
    
    public static func monospace (_ string: String) -> String {
        return "\u{011}\(string)\u{011}"
    }
    
    public static func reverse (_ string: String) -> String {
        return "\u{016}\(string)\u{016}"
    }

    public static func color (_ color: IRCColor, background: IRCColor? = nil, _ string: String) -> String {
        if let background = background {
            return "\u{003}\(String(format: "%02d", color.rawValue)),\(String(format: "%02d", background.rawValue))\(string)\u{003}"
        }
        return "\u{003}\(String(format: "%02d", color.rawValue))\(string)\u{003}"
    }
}

public enum IRCColor: Int {
    case White
    case Black
    case Blue
    case Green
    case LightRed
    case Brown
    case Purple
    case Orange
    case Yellow
    case LightGreen
    case Cyan
    case LightCyan
    case LightBlue
    case Pink
    case Grey
    case LightGrey
}
