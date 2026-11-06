# Caterer
 
This addon fully automates the trading of food and water.  
![caterer](https://user-images.githubusercontent.com/24303693/64069083-e8fc3600-cc4a-11e9-9161-78505bdd664d.jpg)

## Installation
1. Download Latest Version
* **[For WoW 1.12.1](https://gitlab.com/Artur91425/Caterer/-/archive/master/Caterer-master.zip)**
* [For WoW 1.13] **(COMING SOON)**
2. Unpack the Zip file
3. Rename the folder to "Caterer"
4. Copy "Caterer" into Wow-Directory\Interface\AddOns\
5. Restart WoW
___
**ATTENTION for users of version 1.12:**
if you used the addon before version 1.4, then there will be errors when launching the new version. To fix them you need to do one of the following:
* reset settings to default values from config frame
* enter the following commands in the chat: `/run CatererDB = nil`, `/run ReloadUI()`
* manually delete the configuration file into `Wow-Directory\WTF\Account\<ACCOUNT_NAME>\<SERVER_NAME>\<CHARACTER_NAME>\SavedVariables\Caterer.lua`

## Setting addon
First you need to configure the addon. This can be done very quickly.
1. Trade Filter  
Choose which players you want to trade with.  
![trade_filter](https://user-images.githubusercontent.com/24303693/64069121-f7971d00-cc4b-11e9-9e75-83a1ffd4d75e.jpg)  
2. Setting the number of items  
Set the amount of food and water for each class.  
![trade_filter_by_class](https://user-images.githubusercontent.com/24303693/64069116-db937b80-cc4b-11e9-9dca-5add4c3f37f6.jpg)

## Usage
All you have to do is prepare enough items. Unfortunately, automatic creation of items can not be implemented, so you have to do it manually.  
The addon will do the rest, and you can go for a coffee. Just make sure there is enough food and water for everyone. :)

### Standard trade
When a player starts trading with you, the addon will add a configured number of items depending on his class and will complete the trade automatically.

### Exception list
You can set the individual number of items for each player. To do this, just add the player to the list and specify the required number of items.  
![exception_list](https://user-images.githubusercontent.com/24303693/64069127-0aa9ed00-cc4c-11e9-8ded-2d93cd35f7dd.jpg)
 
When a player from the list starts trading with you, a specified number of items will be added. The numbers specified for the standard trade will be ignored.
 
### Whisper based request system (NOT AVAILABLE FOR VERSION 1.13!):
You can request a specific amount of water and food. To do this, wisper to the mage:
`#cat <amount of food> <amount of water>`  
Note:  
The `#cat` prefix is mandatory, so the addon can distinguish the request from an ordinary message. The amount of food is specified in the first parameter, the amount of water is specified in the second. **Both** parameters are required.
If you do not need an item, write zero in the corresponding parameter. Examples:  
* `#cat 20 0` - you will receive 20 pcs. of food.  
* `#cat 20 40` - you will receive 20 pcs. of food and 40 pcs. of water.
 
The amounts specified in a request supersede the amounts from the exception list and from the standard trade.
* * *
**P.S. My English is not very good, so I apologize for any mistakes. I will gladly accept any adjustments and corrections. :)**
