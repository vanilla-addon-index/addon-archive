# Archive Notice
I wrote this addon before realizing that [PizzaWorldBuffs](https://github.com/Pizzahawaiii/PizzaWorldBuffs.git) had this feature.  PWB has many other features including the "logout after getting the buff" one.  If you are on Turtle WoW, use that instead.  This addon will still work for Standard 1.12.1 servers.

https://github.com/Pizzahawaiii/PizzaWorldBuffs.git

note: PWB requires that you set the logout with each session and it does not work with the Zandalar buff.  If you need either of those features (always on logout or ZG buff) then this addon might be useful insteaed of or in addition to PWB.

# Overview
This addon will log out a character if they receive a "Fresh" Rallying Cry of the Dragonslayer or Spirit of Zandalar buff to assist in optimal AFK world buff acquisition uptime.

"Fresh" is defined as: You do not currently have a Rallying Cry of the Dragonslayer or Spirit of Zandalar and a new application of either of those buffs is applied to your character

# Options

```
/head logout - toggle logging out after receiving a fresh Dragonslayer of Zandalar buff
/head broadcast - toggle broadcasting or receiving broadcasted buff drop information
```

# Features
* Log Out - The primary function of the addon
* Broadcasting - The addon will currently broadcast to guildmates over the addon communication channel when a buff drops.  Guildmates with this addon should receive a notification in-chat to inform them (limited to 1 notification every 30 seconds).  TODO: If there is demand, to include server wide broadcasting.
