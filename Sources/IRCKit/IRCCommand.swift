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

public enum IRCCommand: String {
    case PONG
    case PASS
    case USER
    case NICK
    case JOIN
    case QUIT
    case PART
    case CAP
    case AUTHENTICATE
    case PRIVMSG
    case NOTICE
    case ISON
    case INVITE
    case KICK
    case MODE
    case TOPIC
    case WHO
    case SETNAME
    case MONITOR
    case OPER
    case AWAY
    case CYCLE
    case CLOSE
    case DCCALLOW
    case DCCDENY
    case DIE
    case DNS
    case ELINE
    case GLOBOPS
    case HELP
    case INFO
    case IRCOPS
    case JUMPSERVER
    case KILL
    case KNOCK
    case LIST
    case MAP
    case MOTD
    case NAMES
    case OPERMOTD
    case REHASH
    case RESTART
    case SAJOIN
    case SAPART
    case SANICK
    case SAMODE
    case SETHOST
    case SETIDENT
    case SILENCE
    case SQUIT
    case STARTTLS
    case STAFF
    case STATS
    case TIME
    case SPAMFILTER
    case TEMPSHUN
    case UNDCCDENY
    case USERIP
    case VHOST
    case WALLOPS
    case WATCH
    case VERSION
    case WHOWAs
    case KLINE
    case GLINE
    case ZLINE
}
