# IRCKit
IRCKit is an asynchronous pure Swift modern IRC library using the Apple NIO event driven networking framework written to support the latest of IRCv3 features.

### Currently Supported:
* WHOX
* Capability Negotiation ([version 3.2](https://ircv3.net/specs/core/capability-negotiation))
* Real name and account on join ([extended-join](https://ircv3.net/specs/extensions/extended-join-3.1))
* Hostname change notifications ([chghost](https://ircv3.net/specs/extensions/chghost-3.2))
* Userhosts in /names ([userhost-in-names](https://ircv3.net/specs/extensions/userhost-in-names-3.2))
* Multiple user prefixes ([multi-prefix](https://ircv3.net/specs/extensions/multi-prefix-3.1))
* Account change updates ([account-notify](https://ircv3.net/specs/extensions/account-notify-3.1))
* [SASL 3.2](https://ircv3.net/specs/extensions/sasl-3.2) ([PLAIN](https://tools.ietf.org/search/rfc4616) and [EXTERNAL](https://tools.ietf.org/html/rfc4422#appendix-A))
* Message tags ([message-tags](https://ircv3.net/specs/extensions/message-tags))
* Account in message tags ([account-tag](https://ircv3.net/specs/extensions/account-tag-3.2))
* Server-sent timestamps ([server-time](https://ircv3.net/specs/extensions/server-time-3.2))
* Capability change notifications ([cap-notify](https://ircv3.net/specs/core/capability-negotiation#cap-notify))


### Partially Implemented:
* Labeled responses ([labeled-response](https://ircv3.net/specs/extensions/labeled-response))
* Unique message identifiers ([message-ids](https://ircv3.net/specs/extensions/message-ids))
* Message confirmations ([echo-message](https://ircv3.net/specs/extensions/echo-message-3.2))
   
   
###  To be implemented: 
* Away notifications ([away-notify](https://ircv3.net/specs/extensions/away-notify-3.1))
* Message batching ([batch](https://ircv3.net/specs/extensions/batch-3.2))
* Message replies ([client-tags/reply](https://ircv3.net/specs/client-tags/reply))
* Message reactions ([client-tags/react](https://ircv3.net/specs/client-tags/react))
* Typing notifications ([client-tags/typing](https://ircv3.net/specs/client-tags/typing))
* Invite notifications ([invite-notify](https://ircv3.net/specs/extensions/invite-notify-3.2))
* User monitoring ([monitor](https://ircv3.net/specs/core/monitor-3.2))
* SASL ([SCRAM-SHA-256](https://tools.ietf.org/html/rfc7677))
* Server Name Indication ([SNI](https://ircv3.net/specs/core/sni-3.3))
* Changing real name after connection ([setname](https://ircv3.net/specs/extensions/setname))
* Standardised notifications, warnings and errors ([standard-replies](https://ircv3.net/specs/extensions/standard-replies))
* Strict Transport Security ([STS](https://ircv3.net/specs/extensions/sts))
* ZNC Playback  module ([playback](https://wiki.znc.in/Playback))
* ZNC channel events buffer ([buffextras](https://wiki.znc.in/Buffextras))
