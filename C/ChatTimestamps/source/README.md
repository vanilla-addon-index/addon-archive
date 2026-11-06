# ChatTimestamps
Vanialla World of Warcraft Chat Addon created by Skizo in 2008

I just fixed the errors that occured when the addon is used with WoW Vanialla client 1.12 on private servers.

Here is the updated original description:

# Functions
This very tiny mod adds a customizable timestamp (defaulted to [HH:MM:SS] format) to every chat window there is.

Unlike some other addons for timestamps (just like Prat plugin for instance), this works perfectly with every Combat Log window aswell.

# Commands
* <code>/cts format &lt;timeformat&gt;</code> - sets timestamp format
* <code>/cts status</code> - displays settings

# Format Examples
Assuming time is 14:50:21
* <code>%H:%M:%S</code> - Prints out "14:50:21"
* <code>%I:%M:%S %p</code> - Prints out "02:50:21 pm"

More infos about time formats can be found at http://pubs.opengroup.org/onlinepubs/007908799/xsh/strftime.html

Two custom types have been added, #H and #I which replace %H and %I. Both of them are case sensitive and provide an easy way to have non padded hours (07 will become 7 and so on).

# Color Codes
You can use color codes too. The format is the following:

<code>|cAARRGGBB-text here-|r</code>
AA = Alpha, RR = Red GG = Green, BB = Blue

So, for example, if you want a standard 24h red timestamp, you would use |cFFFF0000[%H:%M:%s]|r as your format.
