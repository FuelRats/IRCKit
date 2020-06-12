/*
 Copyright 2020 The Fuel Rats Mischief
 
 Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:
 
 1. Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.
 
 2. Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.
 
 3. Neither the name of the copyright holder nor the names of its contributors may be used to endorse or promote products derived from this software without specific prior written permission.
 
 THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

import Foundation

public enum IRCReply: String {
    case PING
    case ERROR
    case CAP
    case JOIN
    case NICK
    case AWAY
    case PART
    case QUIT
    case PRIVMSG
    case NOTICE
    case ACCOUNT
    case INVITE
    case KICK
    case MODE
    case TOPIC
    case AUTHENTICATE
    case SETNAME
    
    case RPL_WELCOME = "001"
    case RPL_YOURHOST = "002"
    case RPL_CREATED = "003"
    case RPL_MYINFO = "004"
    case RPL_ISUPPORT = "005"
    case RPL_MAP = "006"
    case RPL_MAPEND = "007"
    case RPL_BOUNCE = "010"
    case RPL_TRACELINK = "200"
    case RPL_TRACECONNECTING = "201"
    case RPL_TRACEHANDSHAKE = "202"
    case RPL_TRACEUNKNOWN = "203"
    case RPL_TRACEOPERATOR = "204"
    case RPL_TRACEUSER = "205"
    case RPL_TRACESERVER = "206"
    case RPL_TRACESERVICE = "207"
    case RPL_TRACENEWTYPE = "208"
    case RPL_TRACECLASS = "209"
    case RPL_TRACERECONNECT = "210"
    case RPL_STATSLINKINFO = "211"
    case RPL_STATSCOMMANDS = "212"
    case RPL_STATSCLINE = "213"
    case RPL_STATSOLDNLINE = "214"
    case RPL_STATSILINE = "215"
    case RPL_STATSKLINE = "216"
    case RPL_STATSQLINE = "217"
    case RPL_STATSYLINE = "218"
    case RPL_ENDOFSTATS = "219"
    case RPL_STATSBLINE = "220"
    case RPL_UMODEIS = "221"
    case RPL_MODLIST = "222"
    case RPL_STATSGLINE = "223"
    case RPL_STATSTLINE = "224"
    case RPL_STATSZLINE = "225"
    case RPL_STATSNLINE = "226"
    case RPL_STATSVLINE = "227"
    case RPL_SERVINCEINFO = "231"
    case RPL_ENDOFSERVICES = "232"
    case RPL_SERVICE = "233"
    case RPL_SERVLIST = "234"
    case RPL_SERVLISTEND = "235"
    case RPL_STATSCONN = "250"
    case RPL_LUSERCLIENT = "251"
    case RPL_LUSEROP = "252"
    case RPL_LUSERUNKNOWN = "253"
    case RPL_LUSERCHANNELS = "254"
    case RPL_LUSERNAME = "255"
    case RPL_LADMINME = "256"
    case RPL_LADMINLOC1 = "257"
    case RPL_LADMINLOC2 = "258"
    case RPL_ADMINEMAIL = "259"
    case RPL_TRACELOG = "261"
    case RPL_TRACEEND = "262"
    case RPL_TRYAGAIN = "263"
    case RPL_NONE = "300"
    case RPL_AWAY = "301"
    case RPL_USERHOST = "302"
    case RPL_ISON = "303"
    case RPL_TEXT = "304"
    case RPL_UNAWAY = "305"
    case RPL_NOAWAY = "306"
    case RPL_WHOISREGNICK = "307"
    case RPL_RULESTART = "308"
    case RPL_ENDOFRULES = "309"
    case RPL_WHOISHELPOP = "310"
    case RPL_WHOISUSER = "311"
    case RPL_WHOISSERVER = "312"
    case RPL_WHOISOPERATOR = "313"
    case RPL_WHOWASUSER = "314"
    case RPL_ENDOFWHO = "315"
    case RPL_WHOISCHANOP = "316"
    case RPL_WHOISIDLE = "317"
    case RPL_ENDOFWHOIS = "318"
    case RPL_WHOISCHANNELS = "319"
    case RPL_WHOISSPECIAL = "320"
    case RPL_LISTSTART = "321"
    case RPL_LIST = "322"
    case RPL_LISTEND = "323"
    case RPL_CHANNELMODEIS = "324"
    case RPL_UNIQUOPIS = "325"
    case RPL_NOCHANPASS = "326"
    case RPL_CHPASSUNKNOWN = "327"
    case RPL_CHANNEL_URL = "328"
    case RPL_CREATIONTIME = "329"
    case RPL_NOTOPIC = "331"
    case RPL_TOPIC = "332"
    case RPL_TOPICWHOTIME = "333"
    case RPL_LISTSYNTAX = "334"
    case RPL_WHOISBOT = "335"
    case RPL_BADCHANPASS = "339"
    case RPL_USERIP = "340"
    case RPL_INVITING = "341"
    case RPL_SUMMONING = "342"
    case RPL_INVITELIST = "346"
    case RPL_ENDOFINVITELIST = "347"
    case RPL_VERSION = "351"
    case RPL_WHORELY = "352"
    case RPL_NAMEREPLY = "353"
    case RPL_WHOSPCRPL = "354"
    case RPL_KILLDONE = "361"
    case RPL_CLOSING = "362"
    case RPL_CLOSENED = "363"
    case RPL_LINKS = "364"
    case RPL_ENDOFLINKS = "365"
    case RPL_ENDOFNAMES = "366"
    case RPL_BANLIST = "367"
    case RPL_ENDOFBNALIST = "368"
    case RPL_ENDOFWHOWAS = "369"
    case RPL_INFO = "371"
    case RPL_MOTD = "372"
    case RPL_INFOSTART = "373"
    case RPL_ENDOFINFO = "374"
    case RPL_MOTDSTART = "375"
    case RPL_ENDOFMOTD = "376"
    case RPL_WHOISHOST = "378"
    case RPL_WHOISMODES = "379"
    case RPL_YOUREOPER = "381"
    case RPL_REHASHING = "382"
    case RPL_YOURESERVICE = "383"
    case RPL_MYPORTIS = "384"
    case RPL_NOTOPERANYMORE = "385"
    case RPL_QLIST = "386"
    case RPL_ENDOFQLIST = "387"
    case RPL_ALIST = "388"
    case RPL_ENDOFALIST = "389"
    case RPL_TIME = "391"
    case ERR_NOSUCHSERVER = "402"
    
    case RPL_MONONLINE = "730"
    case RPL_MONOFFLINE = "731"
    case RPL_MONLIST = "732"
    case RPL_ENDOFMONLIST = "733"
    case ERR_MONLISTFULL = "734"
    
    case RPL_LOGGEDIN = "900"
    case RPL_LOGGEDOUT = "901"
    case ERR_NICKLOCKED = "902"
    case RPL_SASLSUCCESS = "903"
    case ERR_SASLFAIL = "904"
    case ERR_SASLTOOLONG = "905"
    case ERR_SASLABORTED = "906"
    case ERR_SASLALREADY = "907"
    case RPL_SASLMECHS = "908"
}
