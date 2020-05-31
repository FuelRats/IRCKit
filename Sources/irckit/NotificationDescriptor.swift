/*
 Copyright 2020 The Fuel Rats Mischief
 
 Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:
 
 1. Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.
 
 2. Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.
 
 3. Neither the name of the copyright holder nor the names of its contributors may be used to endorse or promote products derived from this software without specific prior written permission.
 
 THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

import Foundation

public protocol NotificationDescriptor {
    associatedtype Payload
    init ()
    var name: Notification.Name { get }
    func encode(payload: Payload) -> Notification
    func decode(_ note: Notification) -> Payload
}

extension Notification {
    func post () {
        DispatchQueue.main.async {
            NotificationCenter.default.post(self)
        }
    }
}

public extension NotificationDescriptor {
    var _modelKey: String {
        return "ModelKey"
    }
    
    func encode(payload: Payload) -> Notification {
        let info = [_modelKey: payload]
        let note = Notification(name: name, object: nil, userInfo: info)
        return note
    }
    
    func decode(_ note: Notification) -> Payload {
        let model = note.userInfo![_modelKey] as! Payload
        return model
    }
}

public final class NotificationToken {
    let token: NSObjectProtocol
    let center: NotificationCenter
    init(token: NSObjectProtocol, center: NotificationCenter) {
        self.token = token
        self.center = center
    }
    
    deinit {
        center.removeObserver(token)
    }
}

public extension NotificationCenter {
    func addObserver<A: NotificationDescriptor>(descriptor: A, queue: OperationQueue? = nil, using block: @escaping (A.Payload) -> ()) -> NotificationToken {
        let token = addObserver(forName: descriptor.name, object: nil, queue: queue, using: { note in
            block(descriptor.decode(note))
        })
        return NotificationToken(token: token, center: self)
    }
}
