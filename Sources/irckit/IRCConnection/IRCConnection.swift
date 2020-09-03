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
import NIO
import NIOSSL
import NIOExtras

public class IRCConnection: ChannelInboundHandler {
    public typealias InboundIn = ByteBuffer
    public typealias OutboundOut = ByteBuffer
    private let group = MultiThreadedEventLoopGroup(numberOfThreads: 1)
    private var bootstrap: ClientBootstrap?
    private var channel: Channel?
    var floodTimer: RepeatedTask?
    var connectionTimer: Scheduled<()>?
    var pingTimer: RepeatedTask?
    var lastReceivedMessage: Date?
    var connectionAttempts: Int64 = 0
    var floodControlMessages = 0
    var sendQueue: [String] = []

    private let id: UUID
    private let configuration: IRCClientConfiguration
    weak var delegate: IRCConnectionDelegate?

    init? (configuration: IRCClientConfiguration) throws {
        self.id = UUID()
        self.configuration = configuration

        let verification = configuration.allowsServerSelfSignedCertificate ?
            CertificateVerification.none : CertificateVerification.fullVerification
        var certificateChain: [NIOSSLCertificateSource] = []
        var privateKeySource: NIOSSLPrivateKeySource?

        if
            let certPath = configuration.clientCertificatePath,
            let certs = try? NIOSSLCertificate.fromPEMFile(certPath),
            let privateKey = try? NIOSSLPrivateKey(file: certPath, format: .pem)
        {
            privateKeySource = .privateKey(privateKey)
            certificateChain.append(contentsOf: certs.map({
                .certificate($0)
            }))
        }

        let sslConfiguration = TLSConfiguration.forClient(
            cipherSuites: configuration.chiperSuite ?? TLSConfiguration.clientDefault.cipherSuites,
            minimumTLSVersion: .tlsv11,
            maximumTLSVersion: nil,
            certificateVerification: verification,
            trustRoots: .default,
            certificateChain: certificateChain,
            privateKey: privateKeySource
        )
        let sslContext = try NIOSSLContext(configuration: sslConfiguration)

        if let interval = self.configuration.floodControlDelayTimerInterval {
            self.floodTimer = group.next().scheduleRepeatedTask(
                initialDelay: .seconds(Int64(interval)),
                delay: .seconds(Int64(interval)), { _ in
                    self.floodControlMessages = 0

                    while
                        let message = self.sendQueue.first,
                        self.floodControlMessages < self.configuration.floodControlMaximumMessages ?? 5
                    {
                        self.sendDirectly(message: message)
                        self.sendQueue.removeFirst()
                    }
                }
            )
        }


        self.bootstrap = ClientBootstrap(group: group)
            .channelOption(ChannelOptions.socket(SocketOptionLevel(SOL_SOCKET), SO_REUSEADDR), value: 1)
            .channelInitializer({ channel in
                let sslHandler = try? NIOSSLClientHandler(
                    context: sslContext,
                    serverHostname: self.configuration.serverAddress
                )
                if let sslHandler = sslHandler, self.configuration.prefersInsecureConnection == false {
                    return channel.pipeline.addHandler(sslHandler).flatMap({
                        return channel.pipeline.addHandler(ByteToMessageHandler(LineBasedFrameDecoder())).flatMap({
                            channel.pipeline.addHandler(self)
                        })
                    })
                }

                return channel.pipeline.addHandler(ByteToMessageHandler(LineBasedFrameDecoder())).flatMap({
                    return channel.pipeline.addHandler(self)
                })
            })
    }

    public var connected: Bool {
        return self.channel?.isActive ?? false && self.channel?.isWritable ?? false
    }

    public func channelActive (context: ChannelHandlerContext) {
        self.connectionAttempts = 0

        self.pingTimer = group.next().scheduleRepeatedTask(initialDelay: .seconds(30), delay: .seconds(30), { _ in
            if self.lastReceivedMessage == nil || Date().timeIntervalSince(self.lastReceivedMessage!) > 120 {
                print("Connection timeout")
                self.disconnect()
            }
        })

        self.delegate?.didConnectToHost()

    }

    func connectionFailed () {
        guard self.configuration.autoReconnect == true else {
            return
        }

        let connectionTime: Int64 = 2 << self.connectionAttempts
        print("Attempting reconnect in \(connectionTime) seconds")
        self.connectionTimer = group.next().scheduleTask(in: .seconds(connectionTime), {
            self.connectionAttempts += 1
            self.connect()
        })
    }

    public func channelInactive(context: ChannelHandlerContext) {
        self.pingTimer?.cancel()
        self.connectionFailed()
    }

    public func channelRead (context: ChannelHandlerContext, data: NIOAny) {
        var buffer = unwrapInboundIn(data)
        let readableBytes = buffer.readableBytes

        guard let received = buffer.readString(length: readableBytes) else {
            return
        }

        lastReceivedMessage = Date()

        if received.starts(with: "PING ") {
            let pingResponse = String(received.suffix(from: received.index(received.startIndex, offsetBy: 5)))
            self.sendDirectly(message: "PONG \(pingResponse)")
            return
        }

        #if DEBUG
        print("< \(received)")
        #endif
        self.delegate?.didReceiveDataFromConnection(data: received)
    }

    public func errorCaught (context: ChannelHandlerContext, error: Error) {
        print("Connection closed due to an error")
        context.close(promise: nil)
    }

    func connect () {
        print("Connecting to \(self.configuration.serverAddress):\(self.configuration.serverPort)")
        self.bootstrap?.connect(
            host: self.configuration.serverAddress,
            port: self.configuration.serverPort
        ).whenComplete({ result in
            switch result {
                case .success(let channel):
                    self.channel = channel

                case .failure:
                    print("Failed to connect to server")
                    self.connectionFailed()
            }
        })
    }

    func disconnect () {
        _ = channel?.close(mode: .all)
    }

    private func sendDirectly (message: String) {
        if let channel = self.channel {
            let line = message + "\r\n"
            var buffer = channel.allocator.buffer(capacity: line.utf8.count)
            buffer.writeString(line)
            _ = channel.writeAndFlush(buffer)

            self.floodControlMessages += 1

            #if DEBUG
            print("> \(message)")
            #endif
        }
    }

    func send (message: String, bypassingQueue: Bool = false) {
        guard configuration.floodControlDelayTimerInterval != nil else {
            self.sendDirectly(message: message)
            return
        }
        if
            self.floodControlMessages < self.configuration.floodControlMaximumMessages ?? 5
                && self.sendQueue.count == 0
        {
            self.sendDirectly(message: message)
            return
        }
        self.sendQueue.append(message)
    }
}
