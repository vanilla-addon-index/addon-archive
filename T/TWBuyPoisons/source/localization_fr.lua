function BUYPOISONS_FR()

-- French translation by Sasmira ( Cosmos Team )
-- Updated : 13/04/2006


--Slash commands:
SLASH_BUYPOISONS1 = "/buypoisons";
SLASH_BUYPOISONS2 = "/bp";


BUYPOISONS_HELP_MESSAGE = {
"Utilisation de BUYPOISONS:",
"/bp ou /BUYPOISONS - Ouvre la fen\195\170tre de configuration.",
"/bp <command> ou /BUYPOISONS <command>",
"Commande:  (Please excuse English.)",
	"/bp wpX Y 	Buy Components for Y Level X Wound Poison",
	"/bp cpX Y 	Buy Components for Y Level X Crippling Poison",
	"/bp dpX Y 	Buy Components for Y Level X Deadly Poison",
	"/bp mpX Y 	Buy Components for Y Level X Mind-numbing Poison",
	"/bp ipX Y 	Buy Components for Y Level X Instant Poison",
	"/bp ap1 Y 	Buy Components for Y Agitating Poison",
	"/bp fp Y Buy Y Flash Powder",
	"e.g. '/bp wp3 10' will buy all components needed for 10 lots of level 3 Wound Poison.",
	"Warning: Using anything but multiples of 5 will not handle Vial Numbers properly",
	"as they can only be bought in multiples of 5 from stores.",
	"",
	"Automaticly Purchase Flashpowder every time you are at a vendor: ",
	"/bp rfp 0    -Turns off FlashPowder Auto Restock",
	"/bp rfp Y    -Turns on FlashPowder Auto Restock for Y FlashPowder"
};

BUYPOISONS_CLASS = "Voleur";

--UI labels and tooltips:
BUYPOISONS_UI_VERSION_LABEL = "Version "..BUYPOISONS_VERSION;
BUYPOISONS_BP_ENABLED_CHECKBT_LABEL = "BUYPOISONS Activ\195\169";
BUYPOISONS_BP_ENABLED_CHECKBT_TOOLTIP = "[ON/OFF] BUYPOISONS";


--Vendor Item Names

BUYPOISONS_COMPONENT_FLASH_POWDER ="Poudre \195\169clipsante";

BUYPOISONS_COMPONENT_DEATHWEED ="Herbe mortelle";
BUYPOISONS_COMPONENT_DUST_OF_DECAY ="Poudre de d\195\169labrement";
BUYPOISONS_COMPONENT_DUST_OF_DETERIORATION ="Poussi\195\168re de d\195\169t\195\169rioration";
BUYPOISONS_COMPONENT_ESSENCE_OF_AGONY ="Essence d\'agonie";
BUYPOISONS_COMPONENT_ESSENCE_OF_PAIN ="Essence de douleur";
BUYPOISONS_COMPONENT_LETHARGY_ROOT ="Poudre l\195\169thargique";
BUYPOISONS_COMPONENT_MAIDENS_ANGUISH ="Maiden's Anguish";

BUYPOISONS_VIAL_EMPTY ="Fiole vide";
BUYPOISONS_VIAL_CRYSTAL ="Fiole de cristal";
BUYPOISONS_VIAL_LEADED ="Fiole plomb\195\169e";

--Shortcut Key Commands


BUYPOISONS_SHORTKEY_CRYSTAL_VIAL ="crystalvial";
BUYPOISONS_SHORTKEY_DEATHWEED ="deathweed";
BUYPOISONS_SHORTKEY_DUST_OF_DECAY ="dustofdecay";
BUYPOISONS_SHORTKEY_DUST_OF_DETERIORATION ="dustofdeterioration";
BUYPOISONS_SHORTKEY_EMPTY_VIAL ="emptyvial";
BUYPOISONS_SHORTKEY_ESSENCE_OF_AGONY ="essenceofagony";
BUYPOISONS_SHORTKEY_ESSENCE_OF_PAIN ="essenceofpain";
BUYPOISONS_SHORTKEY_FLASH_POWDER ="flashpowder";
BUYPOISONS_SHORTKEY_LEADED_VIAL ="leadedvial";
BUYPOISONS_SHORTKEY_LETHARGY_ROOT ="lethargyroot";
BUYPOISONS_SHORTKEY_MAIDENS_ANGUISH ="maidensanguish";




BuyPoisonsItemInfo[1]["name"] = "Poison mortel V";
BuyPoisonsItemInfo[2]["name"] = "Poison instantan\195\169 VI";
BuyPoisonsItemInfo[3]["name"] = "Poison douloureux IV";
BuyPoisonsItemInfo[4]["name"] = "Distraction mentale III";
BuyPoisonsItemInfo[5]["name"] = "Poison affaiblissant II";
BuyPoisonsItemInfo[6]["name"] = "Agitating Poison";
BuyPoisonsItemInfo[7]["name"] = "Poison mortel IV";
BuyPoisonsItemInfo[8]["name"] = "Poison instantan\195\169 V";
BuyPoisonsItemInfo[9]["name"] = "Poison douloureux III";
BuyPoisonsItemInfo[10]["name"] = "Poison mortel III";
BuyPoisonsItemInfo[11]["name"] = "Poison instantan\195\169 IV";
BuyPoisonsItemInfo[12]["name"] = "Poison douloureux II";
BuyPoisonsItemInfo[13]["name"] = "Poison mortel II";
BuyPoisonsItemInfo[14]["name"] = "Distraction mentale II";
BuyPoisonsItemInfo[15]["name"] = "Poison instantan\195\169 III";
BuyPoisonsItemInfo[16]["name"] = "Poison douloureux ";
BuyPoisonsItemInfo[17]["name"] = "Poison mortel ";
BuyPoisonsItemInfo[18]["name"] = "Poison instantan\195\169 II";
BuyPoisonsItemInfo[19]["name"] = "Distraction mentale ";
BuyPoisonsItemInfo[20]["name"] = "Poison affaiblissant ";
BuyPoisonsItemInfo[21]["name"] = "Poison instantan\195\169 ";
BuyPoisonsItemInfo[22]["name"] = "Poudre \195\169clipsante";


BuyPoisonsItemInfo[1]["shortkey"] = "dp5";
BuyPoisonsItemInfo[2]["shortkey"] = "ip6";
BuyPoisonsItemInfo[3]["shortkey"] = "wp4";
BuyPoisonsItemInfo[4]["shortkey"] = "mp3";
BuyPoisonsItemInfo[5]["shortkey"] = "cp2";
BuyPoisonsItemInfo[6]["shortkey"] = "ap1";
BuyPoisonsItemInfo[7]["shortkey"] = "dp4";
BuyPoisonsItemInfo[8]["shortkey"] = "ip5";
BuyPoisonsItemInfo[9]["shortkey"] = "wp3";
BuyPoisonsItemInfo[10]["shortkey"] = "dp3";
BuyPoisonsItemInfo[11]["shortkey"] = "ip4";
BuyPoisonsItemInfo[12]["shortkey"] = "wp2";
BuyPoisonsItemInfo[13]["shortkey"] = "dp2";
BuyPoisonsItemInfo[14]["shortkey"] = "mp2";
BuyPoisonsItemInfo[15]["shortkey"] = "ip3";
BuyPoisonsItemInfo[16]["shortkey"] = "wp1";
BuyPoisonsItemInfo[17]["shortkey"] = "dp1";
BuyPoisonsItemInfo[18]["shortkey"] = "ip2";
BuyPoisonsItemInfo[19]["shortkey"] = "mp1";
BuyPoisonsItemInfo[20]["shortkey"] = "cp1";
BuyPoisonsItemInfo[21]["shortkey"] = "ip1";
BuyPoisonsItemInfo[22]["shortkey"] = "fp1";


end