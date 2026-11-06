--[[
  TankSuite - texts (English / Francais)
  NOTE: the 1.12 client reads Lua files as Windows-1252, not UTF-8, so accents
  are written as decimal escapes (\195\169 = e acute, \195\137 = E acute, \195\160 = a grave,
  \195\168 = e grave, \195\170 = e circumflex, \195\180 = o circumflex, \195\185 = u grave,
  \195\167 = c cedilla, \195\162 = a circumflex, \195\128 = A grave).
  addons/tools/check_locale.py prints the decoded text to proof-read it.
]]

TankSuite = TankSuite or {}

TankSuite.strings = {

en = {
  welcome = "%s loaded - type |cff33a0f2/tks|r to open the menu.",
  nosuperwow = "SuperWoW not detected: nameplate features and spell-use announcements are disabled. Failed-taunt announcements still work.",
  status_ok = "SuperWoW detected - every feature is available.",
  status_nosw = "SuperWoW NOT detected. Nameplates and spell-use announcements need it (launch the game with the SuperWoW launcher). Failed-taunt announcements still work.",

  tab_general = "General", tab_announce = "Announcements", tab_maintank = "Main tank",
  tab_messages = "Messages", tab_plates = "Nameplates", tab_tanks = "Tanks", tab_about = "Help",

  sec_general = "General", sec_modules = "Modules", sec_status = "Status",
  sec_channels = "Where to announce", sec_fail = "Announce when a taunt FAILS",
  sec_used = "Announce when a taunt is USED", sec_cd = "Announce defensive cooldowns",
  sec_maintank = "Main tank mode", sec_salv = "Blessing of Salvation",
  sec_messages = "Message texts", sec_plates = "Nameplates", sec_colors = "Colours",
  sec_tanks = "Tank list", sec_about = "About TankSuite", sec_commands = "Commands",

  opt_language = "Language", opt_minimap = "Show the minimap button",
  opt_announcer = "Enable announcements", opt_plates = "Enable tank nameplates",
  opt_failchannel = "Failures go to", opt_infochannel = "Spell use goes to",
  opt_customchannel = "Custom channel name", opt_grouponly = "Only when in a group",
  opt_alertself = "Also show failures on my screen",
  opt_mt_enable = "Enable main tank mode", opt_mt_duration = "Duration (seconds)",
  opt_mt_dual = "Ignore white misses when dual wielding",
  opt_salv = "Remove Salvation automatically while tanking",
  opt_salv_notify = "Tell me when Salvation is removed",
  opt_colorbar = "Colour the health bar", opt_showtext = "Show who the mob attacks",
  opt_showicon = "Shield icon on tanks", opt_showonme = "Also write my own name",
  opt_combatonly = "Only mobs in combat", opt_pertank = "One colour per tank",
  opt_textpos = "Text position", opt_fontsize = "Text size",
  opt_autodetect = "Detect tanks automatically", opt_raidrole = "Use the raid Main Tank role",

  lang_auto = "Automatic", lang_en = "English", lang_fr = "Francais",
  pos_top = "Above the plate", pos_bottom = "Below the plate",

  ch_SAY = "Say", ch_YELL = "Yell", ch_PARTY = "Party", ch_RAID = "Raid",
  ch_RAID_WARNING = "Raid warning", ch_GROUP = "Raid or party", ch_GROUP_RW = "Raid warning or party",
  ch_CHANNEL = "Custom channel", ch_SELF = "Only in my chat window",

  spell_taunt = "Taunt", spell_growl = "Growl", spell_mocking = "Mocking Blow",
  spell_reckoning = "Hand of Reckoning", spell_earthshaker = "Earthshaker Slam",
  spell_shout = "Challenging Shout", spell_roar = "Challenging Roar",
  spell_shieldwall = "Shield Wall", spell_laststand = "Last Stand", spell_gem = "Lifegiving Gem",

  reason_resist = "RESISTED", reason_miss = "MISSED", reason_immune = "IMMUNE",
  reason_dodge = "DODGED", reason_parry = "PARRIED", reason_block = "BLOCKED",
  reason_evade = "EVADED", reason_reflect = "REFLECTED",
  melee = "Melee",
  mark_1 = "Star", mark_2 = "Circle", mark_3 = "Diamond", mark_4 = "Triangle",
  mark_5 = "Moon", mark_6 = "Square", mark_7 = "Cross", mark_8 = "Skull",

  msg_fail = ">>> {s} {r} on {m} {t} <<<",
  msg_used = ">>> {s} on {m} {t} <<<",
  msg_cd = ">>> {s} used <<<",
  msg_opening = ">>> TANK: {s} {r} on {t} - threat at risk! <<<",
  msg_label_fail = "A taunt failed",
  msg_label_used = "A taunt was used",
  msg_label_cd = "A defensive cooldown was used",
  msg_label_opening = "Main tank mode: miss / dodge / parry at the start of the fight",
  msg_hint = "Leave a box empty to get the default text back. Tokens: {s} spell, {r} reason (RESISTED...), {t} target name, {m} raid mark, {l} target level.",

  mt_desc = "For the tank who opens the pull. During the first seconds of the fight every miss, dodge or parry is announced, so the raid knows your threat is not there yet.",
  salv_desc = "A tank does not want Salvation (it lowers threat). Applies to Defensive Stance, Bear Form, Righteous Fury, and always in main tank mode.",

  col_me = "Mob attacks ME", col_tank = "Mob attacks a tank (default)", col_other = "Mob attacks someone else",
  col_none = "Mob has no target", col_pet = "Mob attacks a pet",
  prev_me = "on you", prev_tank = "on a tank", prev_other = "loose mob!", prev_none = "no target", prev_pet = "on a pet",

  tanks_desc = "Tanks get their own colour and a shield on the nameplates. They are detected automatically, or add them yourself.",
  th_name = "Name", th_source = "Source", th_color = "Colour",
  tanks_empty = "No tank yet. Target a player and click the button above.",
  tank_page = "Page %d / %d",
  src_manual = "Added by you", src_mt = "Raid Main Tank", src_auto = "Detected",

  btn_test = "Test announcements", btn_reset = "Reset everything", btn_reset_msgs = "Default texts",
  btn_reset_colors = "Default colours", btn_add_target = "Add my target", btn_add_name = "Add name",
  btn_keep = "Keep", btn_remove = "Remove", btn_prev = "Prev", btn_next = "Next", btn_clear = "Clear the list",

  tip_language = "Language of the menu and of the default announcement texts. Right-click goes backwards.",
  tip_announcer = "Master switch for every chat announcement.",
  tip_plates = "Master switch for the nameplate overlay.",
  tip_reset = "Shift-click to reset every setting and the tank list.",
  tip_failchannel = "Where failed taunts and (main tank mode) misses are announced.",
  tip_infochannel = "Where taunts used and cooldowns used are announced.",
  tip_customchannel = "Name of your own chat channel, used when 'Custom channel' is selected.",
  tip_grouponly = "Nothing is sent when you are alone.",
  tip_alertself = "Failures also flash in the red error text in the middle of your screen.",
  tip_mt = "Announces every miss, dodge and parry during the first seconds of the fight.",
  tip_mt_duration = "How long after combat starts the announcements last.",
  tip_mt_dual = "With two weapons you cannot tell which hand missed - stay quiet on white hits.",
  tip_colorbar = "Change the colour of the health bar (also on pfUI and ShaguPlates plates).",
  tip_showtext = "Write the name of the mob's target above the plate, in class colour. Turn it off to keep only the bar colour (and the shield on tanks).",
  tip_showonme = "Also write your own name when the mob is on you (the green bar already says it).",
  tip_combatonly = "Ignore mobs that are not in combat.",
  tip_pertank = "Each tank uses his own colour. Off: every tank uses the default tank colour.",
  tip_add_target = "Add the player you are targeting to the tank list.",
  tip_autodetect = "A group member who taunts, shapeshifts to Bear Form, uses Righteous Fury or Defensive Stance is treated as a tank.",
  tip_raidrole = "Players marked Main Tank in the raid frame are tanks.",

  tank_added = "%s added to the tank list.", tank_removed = "%s removed from the tank list.",
  tank_add_fail = "Target a friendly player first (or type /tks add Name).",
  tank_cleared = "Tank list cleared.", tank_none = "No tank in the list.",
  channel_missing = "Channel '%s' not found - join it first (/join %s).",
  salvation_removed = "Blessing of Salvation removed.",
  reset_hint = "Hold SHIFT while clicking to reset everything.", reset_done = "All settings were reset.",
  menu_error = "The menu could not be built (please report this message):",
  test_header = "Preview (nothing is sent). Failures -> %s, spell use -> %s:", test_mob = "Onyxia",

  mm_left = "Left click: open the menu", mm_right = "Right click: nameplates on / off", mm_drag = "Drag: move this button",

  about_text = "TankSuite for SuperWoW (Turtle WoW / 1.12).\n1) Announces failed taunts, taunts and cooldowns used, and misses at the start of a pull.\n2) Shows on every nameplate who the mob is attacking; tanks get their own colour and a shield.\n3) Everything is configurable here.",
  about_warn = "Turn off TankPlates / Tankalyze while TankSuite is on: they would announce and recolour twice. pfUI and ShaguPlates nameplates are supported; if pfUI's own threat colours are on too, TankSuite's colours are drawn on top.",

  help_title = "TankSuite commands:",
  help_menu = "/tks - open the menu", help_add = "/tks add [name] - add your target (or a name) as tank",
  help_remove = "/tks remove name - remove a tank", help_list = "/tks list - list the tanks",
  help_clear = "/tks clear - empty the tank list", help_test = "/tks test - preview the announcements",
  help_toggle = "/tks announce on|off, /tks plates on|off", help_lang = "/tks lang auto|en|fr",
},

fr = {
  welcome = "%s charg\195\169 - tapez |cff33a0f2/tks|r pour ouvrir le menu.",
  nosuperwow = "SuperWoW non d\195\169tect\195\169 : les nameplates et les annonces d'utilisation de sorts sont d\195\169sactiv\195\169s. Les annonces de taunts rat\195\169s fonctionnent quand m\195\170me.",
  status_ok = "SuperWoW d\195\169tect\195\169 - toutes les fonctions sont disponibles.",
  status_nosw = "SuperWoW NON d\195\169tect\195\169. Les nameplates et les annonces d'utilisation de sorts en ont besoin (lancez le jeu avec le launcher SuperWoW). Les annonces de taunts rat\195\169s fonctionnent quand m\195\170me.",

  tab_general = "G\195\169n\195\169ral", tab_announce = "Annonces", tab_maintank = "Main tank",
  tab_messages = "Messages", tab_plates = "Nameplates", tab_tanks = "Tanks", tab_about = "Aide",

  sec_general = "G\195\169n\195\169ral", sec_modules = "Modules", sec_status = "\195\137tat",
  sec_channels = "O\195\185 annoncer", sec_fail = "Annoncer quand un taunt \195\137CHOUE",
  sec_used = "Annoncer quand un taunt est UTILIS\195\137",
  sec_cd = "Annoncer les cooldowns d\195\169fensifs",
  sec_maintank = "Mode main tank", sec_salv = "B\195\169n\195\169diction de salut",
  sec_messages = "Textes des messages", sec_plates = "Nameplates", sec_colors = "Couleurs",
  sec_tanks = "Liste des tanks", sec_about = "\195\128 propos de TankSuite", sec_commands = "Commandes",

  opt_language = "Langue", opt_minimap = "Afficher le bouton de la minimap",
  opt_announcer = "Activer les annonces", opt_plates = "Activer les nameplates tank",
  opt_failchannel = "Les \195\169checs vont sur", opt_infochannel = "L'utilisation des sorts va sur",
  opt_customchannel = "Nom du canal perso", opt_grouponly = "Seulement en groupe",
  opt_alertself = "Afficher aussi les \195\169checs \195\160 l'\195\169cran",
  opt_mt_enable = "Activer le mode main tank", opt_mt_duration = "Dur\195\169e (secondes)",
  opt_mt_dual = "Ignorer les miss blancs \195\160 deux armes",
  opt_salv = "Retirer Salut automatiquement en tankant",
  opt_salv_notify = "Me pr\195\169venir quand Salut est retir\195\169",
  opt_colorbar = "Colorer la barre de vie", opt_showtext = "Afficher qui le mob attaque",
  opt_showicon = "Ic\195\180ne de bouclier sur les tanks", opt_showonme = "\195\137crire aussi mon propre nom",
  opt_combatonly = "Seulement les mobs en combat", opt_pertank = "Une couleur par tank",
  opt_textpos = "Position du texte", opt_fontsize = "Taille du texte",
  opt_autodetect = "D\195\169tecter les tanks automatiquement", opt_raidrole = "Utiliser le r\195\180le Main Tank du raid",

  lang_auto = "Automatique", lang_en = "English", lang_fr = "Fran\195\167ais",
  pos_top = "Au-dessus de la plaque", pos_bottom = "Sous la plaque",

  ch_SAY = "Dire", ch_YELL = "Crier", ch_PARTY = "Groupe", ch_RAID = "Raid",
  ch_RAID_WARNING = "Alerte raid", ch_GROUP = "Raid ou groupe", ch_GROUP_RW = "Alerte raid ou groupe",
  ch_CHANNEL = "Canal perso", ch_SELF = "Seulement dans mon chat",

  spell_taunt = "Provocation", spell_growl = "Grondement", spell_mocking = "Coup railleur",
  spell_reckoning = "Hand of Reckoning", spell_earthshaker = "Earthshaker Slam",
  spell_shout = "Cri de d\195\169fi", spell_roar = "Rugissement provocateur",
  spell_shieldwall = "Mur protecteur", spell_laststand = "Dernier rempart", spell_gem = "Gemme de vie",

  reason_resist = "R\195\137SIST\195\137", reason_miss = "RAT\195\137", reason_immune = "IMMUNIS\195\137",
  reason_dodge = "ESQUIV\195\137", reason_parry = "PAR\195\137", reason_block = "BLOQU\195\137",
  reason_evade = "\195\137VIT\195\137", reason_reflect = "RENVOY\195\137",
  melee = "M\195\170l\195\169e",
  mark_1 = "\195\137toile", mark_2 = "Cercle", mark_3 = "Losange", mark_4 = "Triangle",
  mark_5 = "Lune", mark_6 = "Carr\195\169", mark_7 = "Croix", mark_8 = "Cr\195\162ne",

  msg_fail = ">>> {s} {r} sur {m} {t} <<<",
  msg_used = ">>> {s} sur {m} {t} <<<",
  msg_cd = ">>> {s} utilis\195\169 <<<",
  msg_opening = ">>> TANK : {s} {r} sur {t} - aggro en danger ! <<<",
  msg_label_fail = "Un taunt a \195\169chou\195\169",
  msg_label_used = "Un taunt a \195\169t\195\169 utilis\195\169",
  msg_label_cd = "Un cooldown d\195\169fensif a \195\169t\195\169 utilis\195\169",
  msg_label_opening = "Mode main tank : miss / esquive / parade au d\195\169but du combat",
  msg_hint = "Laissez une case vide pour retrouver le texte par d\195\169faut. Variables : {s} sort, {r} raison (R\195\137SIST\195\137...), {t} nom de la cible, {m} marqueur de raid, {l} niveau de la cible.",

  mt_desc = "Pour le tank qui lance le pull. Pendant les premi\195\168res secondes du combat, chaque miss, esquive ou parade est annonc\195\169, pour que le raid sache que votre menace n'est pas encore l\195\160.",
  salv_desc = "Un tank ne veut pas de Salut (il r\195\169duit la menace). S'applique en Posture d\195\169fensive, Forme d'ours, Fureur vertueuse, et toujours en mode main tank.",

  col_me = "Le mob m'attaque MOI", col_tank = "Le mob attaque un tank (d\195\169faut)", col_other = "Le mob attaque quelqu'un d'autre",
  col_none = "Le mob n'a pas de cible", col_pet = "Le mob attaque un familier",
  prev_me = "sur vous", prev_tank = "sur un tank", prev_other = "mob libre !", prev_none = "sans cible", prev_pet = "sur un familier",

  tanks_desc = "Les tanks ont leur couleur et un bouclier sur les nameplates. Ils sont d\195\169tect\195\169s automatiquement, ou ajoutez-les vous-m\195\170me.",
  th_name = "Nom", th_source = "Source", th_color = "Couleur",
  tanks_empty = "Aucun tank pour l'instant. Ciblez un joueur et cliquez sur le bouton ci-dessus.",
  tank_page = "Page %d / %d",
  src_manual = "Ajout\195\169 par vous", src_mt = "Main Tank du raid", src_auto = "D\195\169tect\195\169",

  btn_test = "Tester les annonces", btn_reset = "Tout r\195\169initialiser", btn_reset_msgs = "Textes par d\195\169faut",
  btn_reset_colors = "Couleurs par d\195\169faut", btn_add_target = "Ajouter ma cible", btn_add_name = "Ajouter",
  btn_keep = "Garder", btn_remove = "Retirer", btn_prev = "Pr\195\169c.", btn_next = "Suiv.", btn_clear = "Vider la liste",

  tip_language = "Langue du menu et des textes d'annonce par d\195\169faut. Clic droit pour reculer.",
  tip_announcer = "Interrupteur g\195\169n\195\169ral de toutes les annonces dans le chat.",
  tip_plates = "Interrupteur g\195\169n\195\169ral de l'affichage sur les nameplates.",
  tip_reset = "Maj + clic pour tout r\195\169initialiser (r\195\169glages et liste des tanks).",
  tip_failchannel = "O\195\185 sont annonc\195\169s les taunts rat\195\169s et (mode main tank) les miss.",
  tip_infochannel = "O\195\185 sont annonc\195\169s les taunts et cooldowns utilis\195\169s.",
  tip_customchannel = "Nom de votre propre canal de discussion, utilis\195\169 si 'Canal perso' est choisi.",
  tip_grouponly = "Rien n'est envoy\195\169 quand vous \195\170tes seul.",
  tip_alertself = "Les \195\169checs s'affichent aussi en rouge au milieu de votre \195\169cran.",
  tip_mt = "Annonce chaque miss, esquive et parade pendant les premi\195\168res secondes du combat.",
  tip_mt_duration = "Combien de temps apr\195\168s le d\195\169but du combat les annonces durent.",
  tip_mt_dual = "\195\128 deux armes on ne sait pas quelle main a rat\195\169 - on reste silencieux sur les coups blancs.",
  tip_colorbar = "Change la couleur de la barre de vie (aussi sur les nameplates de pfUI et ShaguPlates).",
  tip_showtext = "\195\137crit le nom de la cible du mob au-dessus de la plaque, en couleur de classe. D\195\169sactivez pour ne garder que la couleur de barre (et le bouclier sur les tanks).",
  tip_showonme = "\195\137crit aussi votre nom quand le mob est sur vous (la barre verte le dit d\195\169j\195\160).",
  tip_combatonly = "Ignore les mobs qui ne sont pas en combat.",
  tip_pertank = "Chaque tank a sa couleur. D\195\169sactiv\195\169 : tous les tanks utilisent la couleur tank par d\195\169faut.",
  tip_add_target = "Ajoute le joueur que vous ciblez \195\160 la liste des tanks.",
  tip_autodetect = "Un membre du groupe qui taunt, passe en Forme d'ours, utilise Fureur vertueuse ou la Posture d\195\169fensive est consid\195\169r\195\169 comme un tank.",
  tip_raidrole = "Les joueurs marqu\195\169s Main Tank dans la fen\195\170tre de raid sont des tanks.",

  tank_added = "%s ajout\195\169 \195\160 la liste des tanks.", tank_removed = "%s retir\195\169 de la liste des tanks.",
  tank_add_fail = "Ciblez d'abord un joueur ami (ou tapez /tks add Nom).",
  tank_cleared = "Liste des tanks vid\195\169e.", tank_none = "Aucun tank dans la liste.",
  channel_missing = "Canal '%s' introuvable - rejoignez-le d'abord (/join %s).",
  salvation_removed = "B\195\169n\195\169diction de salut retir\195\169e.",
  reset_hint = "Maintenez MAJ en cliquant pour tout r\195\169initialiser.", reset_done = "Tous les r\195\169glages ont \195\169t\195\169 r\195\169initialis\195\169s.",
  menu_error = "Le menu n'a pas pu \195\170tre construit (merci de signaler ce message) :",
  test_header = "Aper\195\167u (rien n'est envoy\195\169). \195\137checs -> %s, sorts utilis\195\169s -> %s :", test_mob = "Onyxia",

  mm_left = "Clic gauche : ouvrir le menu", mm_right = "Clic droit : nameplates on / off", mm_drag = "Glisser : d\195\169placer ce bouton",

  about_text = "TankSuite pour SuperWoW (Turtle WoW / 1.12).\n1) Annonce les taunts rat\195\169s, les taunts et cooldowns utilis\195\169s, et les miss au d\195\169but d'un pull.\n2) Montre sur chaque nameplate qui le mob attaque ; les tanks ont leur couleur et un bouclier.\n3) Tout se r\195\168gle ici.",
  about_warn = "D\195\169sactivez TankPlates / Tankalyze quand TankSuite est actif : ils annonceraient et recoloreraient en double. Les nameplates de pfUI et ShaguPlates sont prises en charge ; si les couleurs de menace de pfUI sont aussi actives, celles de TankSuite passent par-dessus.",

  help_title = "Commandes TankSuite :",
  help_menu = "/tks - ouvrir le menu", help_add = "/tks add [nom] - ajouter votre cible (ou un nom) comme tank",
  help_remove = "/tks remove nom - retirer un tank", help_list = "/tks list - lister les tanks",
  help_clear = "/tks clear - vider la liste des tanks", help_test = "/tks test - aper\195\167u des annonces",
  help_toggle = "/tks announce on|off, /tks plates on|off", help_lang = "/tks lang auto|en|fr",
},

}
