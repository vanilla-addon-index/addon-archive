local addonName = ...
local LDB = LibStub("LibDataBroker-1.1")
local LDBIcon = LibStub("LibDBIcon-1.0")

Emoticons_Settings={
	["CHAT_MSG_OFFICER"]=true,		--1
	["CHAT_MSG_GUILD"]=true,		--2
	["CHAT_MSG_PARTY"]=true,		--3
	["CHAT_MSG_PARTY_LEADER"]=true,		--dont count, tie to 3
	["CHAT_MSG_PARTY_GUIDE"]=true,		--dont count, tie to 3
	["CHAT_MSG_RAID"]=true,			--4
	["CHAT_MSG_RAID_LEADER"]=true,		--dont count, tie to 4
	["CHAT_MSG_RAID_WARNING"]=true,		--dont count, tie to 4
	["CHAT_MSG_SAY"]=true,			--5
	["CHAT_MSG_YELL"]=true,			--6
	["CHAT_MSG_WHISPER"]=true,		--7
	["CHAT_MSG_WHISPER_INFORM"]=true,	--dont count, tie to 7
	["CHAT_MSG_CHANNEL"]=true,		--8
--	["CHAT_MSG_BN_WHISPER"]=true,	--9
--	["CHAT_MSG_BN_WHISPER_INFORM"]=true,--dont count, tie to 9
--	["CHAT_MSG_BN_CONVERSATION"]=true,--10
	["CHAT_MSG_BATTLEGROUND"]=true,--11
	["CHAT_MSG_BATTLEGROUND_LEADER"]=true,--dont count, tie to 11
	["MAIL"]=true,
	["TWITCHBUTTON"]=true,
	["sliderX"]=-35,
	["sliderY"]=0,
	["MinimapPos"] = 45,
	["MINIMAPBUTTON"] = true,
	["BUBBLEEMOTES"] = true,
	["AUTOCOMPLETE"] = true,
	["CLICKABLEEMOTES"] = true,
	["FAVEMOTES"] = {true,true,true,true,true,true,true,true,true,true,
	true,true,true,true,true,true,true,true,true,true,
	true,true,true,true,true,true,true,true,}

  };
  Emoticons_Eyecandy = false;
  local origsettings = {
	["CHAT_MSG_OFFICER"]=true,
	["CHAT_MSG_GUILD"]=true,
	["CHAT_MSG_PARTY"]=true,
	["CHAT_MSG_PARTY_LEADER"]=true,
	["CHAT_MSG_PARTY_GUIDE"]=true,
	["CHAT_MSG_RAID"]=true,
	["CHAT_MSG_RAID_LEADER"]=true,
	["CHAT_MSG_RAID_WARNING"]=true,
	["CHAT_MSG_SAY"]=true,
	["CHAT_MSG_YELL"]=true,
	["CHAT_MSG_WHISPER"]=true,
	["CHAT_MSG_WHISPER_INFORM"]=true,
--	["CHAT_MSG_BN_WHISPER"]=true,
--	["CHAT_MSG_BN_WHISPER_INFORM"]=true,
--	["CHAT_MSG_BN_CONVERSATION"]=true,
	["CHAT_MSG_CHANNEL"]=true,
	["CHAT_MSG_INSTANCE_CHAT"]=true,
	["MAIL"]=true,
	["TWITCHBUTTON"]=true,
	["sliderX"]=-35,
	["sliderY"]=0,
	["MinimapPos"] = 45,
	["MINIMAPBUTTON"] = true,
	["BUBBLEEMOTES"] = true,
	["AUTOCOMPLETE"] = true,
	["CLICKABLEEMOTES"] = true,
	["FAVEMOTES"] = {true,true,true,true,true,true,true,true,true,true,
	true,true,true,true,true,true,true,true,true,true,
	true,true,true,true,true,true,true,true,}
  };
  local dropdown_options={
	[1]=  {"Asmongold","asmon1","asmon2","asmon3","asmon4","asmonBoi","asmonC","asmonCD","asmonD","asmonDad","asmonDaze","asmonDegen","asmonE","asmonE1","asmonE2","asmonE3","asmonE4","asmonFiend","asmonG","asmonGASM","asmonGet","asmonHide","asmonL","asmonLFR","asmonLong1","asmonLong2","asmonLong3","asmonLong4","asmonLove","asmonM","asmonOcean","asmonOrc","asmonP","asmonPower","asmonPray","asmonPrime","asmonR","asmonREE","asmonSad","asmonStare","asmonTar","asmonTiger","asmonUH","asmonW","asmonWHAT","asmonWHATR","asmonWOW"},
	[2]=  {"Preachlfw","pgeBan","pgeBen","pgeBrian","pgeCheese","pgeChick","pgeClub","pgeCrisp","pgeDrama","pgeEdge","pgeEmma","pgeFish","pgeGhost","pgeHmm","pgeNem","pgeNoob","pgeOhno","pgeOhno2","pgePog","pgePug","pgeRay","pgeScience","pgeShame","pgeSherry"},
	[3]=  {"BTTV+FFZ","4Head","ANELE","AngelThump","BabyRage","BBona","BibleThump","BlessRNG","BloodTrail","bUrself","cmonBrother","cmonBrug","cmonBruh","ConcernDoge","ConcernFroge","D:","DansGame","DatSheffy","DD:","DogeWitIt","EleGiggle","eShrug","FacePalm","FailFish","FrankerZ","GabeN","gachiBASS","gachiGASM","gachiHYPER","GivePLZ","haHAA","HandsUp","HeyGuys","HotPokket","HYPERBRUG","HYPERLUL","HYPERTHONK","Jebaited","Kapp","Kappa","KappaPride","Keepo","KKomrade","Kreygasm","LUL","LULE","LULW","MegaLUL","MingLee","MingLUL","MrDestructoid","NickyQ","NotLike","NotLikeThis","o_O","OhMyDog","OpieOP","PagMan","PartyTime","pokiBASS","PotFriend","PowerUpL","PowerUpR","RCool","ResidentSleeper","RFrown","RGasp","RHeart","RMeh","RPatch","RSmile","RSmiling","RTired","RTongue","RWink","RWinkTongue","SeemsGood","smileC","smileW","SMOrc","Squid1","Squid2","Squid3","Squid4","SwiftRage","TakeNRG","Thonk","tooDank","TriHard","weSmart","WideHard","WinnerWinner","WTFF","Wut","WutFace","ZULOL","ZULUL"},
	[4]=  {"Custom","4Play","4WeirdBusiness",":alarm:",":alert:",":Aware:",":Awkward:",":Awoken:",":blinking:",":Cinema:",":Classic:",":Clueless:",":Concerned:",":cringe:",":doo:",":empty:",":ew:",":groove:",":hehe:",":hehesip:",":horror:",":jons:",":kissing:",":kms:",":mc:",":meow:",":misery:",":mo:",":noted:",":om:",":penguin:",":pls:",":queen:",":quest:",":sitch:",":soy:",":torment:",":waiting:",":WM:",":xdd:",":yo:","AbdulPls","AINTNOWAY","AlienPls","AMAZIN","ANEBruh","angrybear","arnoldHalt","AYAYA","bange","batBrah","BedgeMorgan","bidenBlast","bign","billyReady","bjornoVV","bjornoVVona","blobDance","BOGGED","bruggaroniNcheese","bufeY","businesscat","Catablepon","CatDance","catJAM","catKISS","CatMad","CatPop","channMies","channWeen","ChipiChipi","chompy","chupBro","chupDerp","chupHappy","ciaciuu","ciaciuWorried","Clap","Cluegi","cmon","confuseddoggo","cptfriHE","CUNGUS","deanWink","Del","Depresstiny","DestiSenpaii","DIESOFCRINGE","DisGonBGud","Disgustiny","DocArrive","DocLeave","docmeat","DogeKek","DONOTCUM","DonoWall","ednasly","Eggroll","endANELE","endBomb","endDawg","endFrench","endHarambe","endKyori","endNotLikeThis","endRP","endTrump","evilcat","fentL","FlipThis","FLOOSHED","flushdoggo","foxsus","freddyCREEP","freddyFINGER","freddyLUL","freddyW","FrogPog","fruitBug","GAMING","GasmChamp","GigaChad","GODSTINY","goinginsane","HappyMerchant","headBang","hehecat","HiveDiver","HmmStiny","HmmTodayIWill","HowSleeper","HUH","HUHH","HyperAngryMerchant","HyperMpreg","HYPERYOGGERS","ICANT","intjCaught","intjdreaming","intjGlad","intjIdk","intjMad","intjReallyMad","intjSad","intjSalute","intjShake","intjSmile","intjSus","intjWoa","intjXD1","intjXD2","jerryWhat","jewdai","jillzoMallet","jinL","Jons","Joy2","Kekflap","KEKok","KEKWait","KermitScream","KKonaS","Klappa","KomodoHype","Krug","LaurGasm","lebronJAM","LeoHug","LeRuse","LETHIMCOOK","LETSGOOO","lockOmegatayys","LockStone","Lole","LOLW","Maaaaan","marcithDerp","marcithMath","mastahFloor","megaflushed","MikeSmug","modCheck","MoneySniff","monkeyS","MooCowGold","MooCowW","moWait","MrStark","NeckBeard","NoAnime","NoBitches","NOBULLY","NoTears","OKKona","oldmorDim","OMEGAKEKMAN","OMEGALOL","omgBruh","OverRustle","PatrickMad","PatrickPray","pedro","peepoVW","PEPE","PogCena","PogT","poki1","poki2","pokiW","politeCatWTF","popCat","Popoga","PunkChamp","RAGEY","ratJAM","REE","ricardoFlick","RIPBOZO","sameEnergy","selyihHEY","SNIFFA","SpeedLaugh","StareBruh","Stonks","SuicideThinking","sunglassesflushed","SURPRISE","susfox","Sussy","SWEATSTINY","TeaTime","TheVoices","ThisIsFine","ThumbsUp","totekatze","TrollDespair","TrollLaugh","Tssk","VoHiYo","WeirdAYAYA","worryChocolate","worryCool","worryExcite","worryFat","worryHug","worryHugged","worryLove","worryPopcorn","worryStick","worryWave","WrathChest","yacubgasm","YEE","yeshoney","YodaSip","YOGGERS","YoshiBlush","YouTried","ZOINKS"},
	[5]=  {"Greekgodx","greekA","greekBrow","greekDiet","greekGirl","greekGordo","greekGweek","greekHard","greekHYPERP","greekJoy","greekKek","greekM","greekMlady","greekOi","greekP","greekPVC","greekSad","greekSheep","greekSleeper","greekSquad","greekT","greekThink","greekTilt","greekWC","greekWhy","greekWtf","greekYikes"},
	[6]=  {"nymn","nymn0","nymn1","nymn158","nymn2","nymn2x","nymn3","nymnA","nymnAww","nymnB","nymnBee","nymnBenis","nymnBiggus","nymnBridge","nymnC","nymnCaptain","nymnCC","nymnCD","nymnCozy","nymnCREB","nymnCringe","nymnCry","nymnDab","nymnDeer","nymnE","nymnElf","nymnEU","nymnEZ","nymnFEEDME","nymnFlag","nymnFlick","nymnFood","nymnG","nymnGasm","nymnGasp","nymnGnome","nymnGold","nymnGolden","nymnGun","nymnH","nymnHammer","nymnHmm","nymnHonk","nymnHydra","nymnJoy","nymnK","nymnKek","nymnKing","nymnKomrade","nymnL","nymnM","nymnNA","nymnNo","nymnNormie","nymnOkay","nymnP","nymnPains","nymnPog","nymnPuke","nymnR","nymnRaffle","nymnRupert","nymnS","nymnSad","nymnScuffed","nymnSleeper","nymnSmart","nymnSmol","nymnSmug","nymnSon","nymnSoy","nymnSpurdo","nymnStrong","nymnThink","nymnTransparent","nymnU","nymnV","nymnW","nymnWhy","nymnXD","nymnY","nymnZ"},
	[7]=  {"Drainerx","drxBrain","drxCozy","drxCri","drxCS","drxD","drxDict","drxED","drxED2","drxEyes","drxFE","drxFE1","drxFEED","drxGlad","drxGod","drxHappy","drxHey","drxKEK","drxLewd","drxLit","drxLUL","drxMad","drxmonkaEYES","drxPog","drxR","drxSad","drxSmart","drxSmile","drxSpace","drxSSJ","drxThink","drxW","drxWeird","drxWink"},
	[8]=  {"Emojis",":100:",":axe:",":b:",":bear:",":bell:",":blush:",":book:",":candle:",":checkmark:",":clock:",":coffee:",":cold_face:",":crab:",":crocodile:",":crown:",":cry:",":door:",":dragon:",":eggplant:",":eye:",":eyes:",":eyes_sus:",":f:",":face_with_raised_eyebrow:",":fire:",":flush:",":flushed:",":full_moon_with_face:",":gun:",":hand:",":handshake:",":heart:",":heart_eyes:",":hot_face:",":joy:",":kiss:",":lizard:",":mega:",":mouse_trap:",":muscle:",":nerd:",":ok_hand:",":onion:",":oof:",":peach:",":pig:",":pig_nose:",":point_left:",":point_right:",":poop:",":pray:",":question:",":rage:",":rolling_eyes:",":shrimp:",":skull:",":smiley:",":smiling_face_with_tear:",":smirk:",":smoking:",":snake:",":sob:",":sunglasses:",":sweat_drops:",":thinking:",":tiger:",":tired:",":tomato:",":tongue:",":triumph:",":turtle_cry:",":warning:",":wave:",":weary:",":wheelchair:",":wink:",":writing_hand:",":x:",":yum:",":zap:",":zipper_mouth:","eggplantW"},
	[9]=  {"Forsen","forsen1","forsen2","forsen3","forsen4","forsenAYAYA","forsenAYOYO","forsenBanned","forsenBee","forsenBlob","forsenBoys","forsenC","forsenCD","forsenChamp","forsenClown","forsenConnoisseur","forsenCool","forsenD","forsenDab","forsenDank","forsenDDK","forsenDED","forsenDespair","forsenDiglett","forsenE","forsenEcardo","forsenEmote","forsenEmote2","forsenFajita","forsenFeels","forsenFur","forsenG","forsenGa","forsenGASM","forsenGrill","forsenGun","forsenH","forsenHappy","forsenHead","forsenHobo","forsenHorsen","forsenIQ","forsenJoy","forsenK","forsenKek","forsenKnife","forsenKraken","forsenL","forsenLewd","forsenLicence","forsenLookingAtYou","forsenLooted","forsenLUL","forsenM","forsenMald","forsenMoney","forsenMonkey","forsenNam","forsenO","forsenODO","forsenOG","forsenOP","forsenP","forsenPepe","forsenPog","forsenPosture","forsenPosture1","forsenPosture2","forsenPuke","forsenPuke2","forsenPuke3","forsenPuke4","forsenPuke5","forsenR","forsenReally","forsenRedSonic","forsenRP","forsenS","forsenSambool","forsenScoots","forsenSheffy","forsenSith","forsenSkip","forsenSleeper","forsenSmile","forsenSS","forsenStein","forsenSwag","forsenT","forsenTILT","forsenTriggered","forsenW","forsenWC","forsenWeird","forsenWeird25","forsenWhat","forsenWhip","forsenWitch","forsenWTF","forsenWut","forsenX","forsenY","forsenYHD","PogChimp"},
	[10]=  {"AdmiralBahroo","rooAww","rooBlank","rooBless","rooBlind","rooBonk","rooBooli","rooBot","rooC","rooCarry","rooComfy","rooCookie","rooCop","rooCry","rooCult","rooD","rooDab","rooDerp","rooDevil","rooDisgust","rooDuck","rooEZ","rooGift","rooGun","rooHappy","rooLick","rooLick2","rooLove","rooMadSlam","rooMurica","rooNap","rooNom","rooPog","rooPs","rooRave","rooREE","rooScheme","rooScream","rooSellout","rooSleepy","rooSmush","rooThink","rooTHIVV","rooUwU","rooVV","rooW","rooWhine","rooWut"},
	[11]=  {"VR","02Dab","02Stare","02Yum",":HEH:","astrovrCry","astrovrHi","astrovrRee","CuteMelon","DrunkMelon","GaspMelon","HyperHappyMelon","HyperMelon","MelonGun","OwOMelon","radiantAYAYA","radiantBlush","radiantBomb","radiantBoop","radiantComfy","radiantCry","radiantCult","radiantCute","radiantEEEEE","radiantEvil","radiantGimme","radiantGun","radiantHmm","radiantISee","radiantJam","radiantKek","radiantLag","radiantLick","radiantLurk","radiantNom","radiantOmega","radiantOmegaOWO","radiantOwO","radiantPat","radiantPepega","radiantPog","radiantPout","radiantREE","radiantSalute","radiantScared","radiantShrug","radiantSip","radiantSmile","radiantSmug","radiantSnoze","radiantStare","radiantTOS","radiantWave","radiantWeird","RageMelon","ReeMelon","SadMelon","SweatMelon","tyrissBlush","tyrissBoop","tyrissComfy","tyrissDisappointed","tyrissGasp","tyrissGimme","tyrissGlare","tyrissHeadpat","tyrissHeart","tyrissHeartz","tyrissHi","tyrissHug","tyrissHyper","tyrissLul","tyrissLurk","tyrissPout","tyrissRee","tyrissRip","tyrissS","tyrissSad","tyrissSmug","tyrissSmugOwO","tyrissThink","tyrissVictory","ZevvyBlush"},
	[12]=  {"Pepe",":copium:",":done:",":drama:",":fml:",":fork:",":hmm:",":memes:",":need:",":shy:",":skip:",":think:",":whip:","Awakge","BadW","beanping","Bedge","Bedges","BedgeTogether","binocs","binocsSpin","BLUBBERS","Blushge","BOOBA","BOOFA","Boolin","Borpa","BorpaL","BorpaU","Catge","Chatting","Clownge","ClownHypers","COCKA","Copege","COPIUM","CringeW","CROGGERS","Cryge","CutePepe","DankHug","Deadge","DeadgeTogether","dejj","Despairge","DinkDonk","ehWTF","EVILSMILERS","EZ","FARTIUM","FatBod","FatDank","Fatge","FeelsAmazingMan","FeelsBetaMan","FeelsBlushMan","FeelsBoredMan","FeelsCoolMan","FeelsCopterMan","FeelsCringeMan","FeelsCryManW","FeelsCuteMan","FeelsDeadMan","FeelsDrunkMan","FeelsEvilMan","FeelsFatMan","FeelsGamerMan","FeelsGermanMan","FeelsGreekMan","FeelsIllidanMan","FeelsIncredibleMan","FeelsLateMan","FeelsLitMan","FeelsLoveManW","FeelsMyFingerMan","FeelsOakyMan","FeelsOldMan","FeelsPinkMan","FeelsQueueMan","FeelsRainSadge","FeelsRottenMan","FeelsSad","FeelsSorryMan","FeelsStrongMan","FeelsSuicideMan","FeelsTastyMan","FeelsTiredAF","FeelsWeakMan","FeelsWiredMan","fingi","FrogO","FUARK","FUTA","Gayge","GiggleHands","Gladge","gladgers","goodd","GoodW","HabibiPrayge","HACKERMANS","HappyJammies","Hmmge","Hmmmge","HYPEROMEGAPOGGERSCRAZY","HYPERS","imKEKWing","imOkayChamp","Jammies","JanCarlo","KEKGA","KEKWHands","KMS","LMAO","lookdown","lookup","lovehug","Lovge","LULERS","Madge","MadgeBackhand","MadgeClap","Madgee","MadgeNow","MadgeRightNow","majj","MALDD","maximumautism","meAutism","monakGun","monakHmm","monakMultiple","monakS","monakW","monkaCapture","monkaGasp","monkaGIGA","monkaHands","monkaInsane","monkaLaugh","monkaMEGA","monkaMultiple","monkaOh","monkaOMEGA","monkaPickle","monkaS","monkaShake","monkaShoot","monkaStab","monkaStare","monkaSteer","monkaSusp","monkaT","monkaThink","monkaTOS","monkaU","monkaVirus","monkaW","monkaWCB","monkaX","monkaYou","monkerS","NA","nanoMEGA","NeedCopium","Nerdge","noClown","NODDERS","NOOBA","NOP","NOPERS","Notsurege","Okayeg","Okayga","Okayge","OkaygeShrug","OkayLaugh","OkayW","oldpepe","OMEGAEZ","oniongang","PAUSERS","peep","PeepHand","peepo","peepo2","peepoAlliance","peepoBaba","peepoBlankey","peepoBritish","peepoBye","peepoCat","peepoChonk","peepoChop","peepoClap","peepoComfy","peepoDab","peepoEhm","peepoEvilSip","peepofeet","peepoFoil","peepoFR1","peepoFR2","peepoGhost","peepoGiggle","peepoGroovie","peepoHeart","peepoHehe","peepoHey","peepoHorse","peepoIsForMe","peepoJail","peepoJedi","peepoJorts","peepoJudge","peepoJuice","peepoLoser","peepoM","peepoMadder","peepoNotes","peepoPanda","peepoParty","peepoPlease","peepoPolice","peepoRiot","peepoSadLogize","peepoScam","peepoShake","peepoShy","peepoSimp","peepoSimping","peepoSith","peepoSleepo","peepoSmash","peepoSoup","peepoSPopcorn","peepoStonks","peepoStrong","peepoSure","peepoSweat","peepoTeeth","peepoTrash","peepoWhy","peepoWow","PepeAyy","PepeBald","PepeBlyat","PepeBruh","PepeCat","PepeCatGun","PepeCatHeart","PepeCoffee","PepeCoolStory","PepeCozy","PepeCry","PepeDisgust","PepeDribble","PepeFlushed","PepeFrench","PepeFU","PepeFuming","PepegaCredit","PepegaHammer","PepegaHands","PepeGang","PepegaSad","PepeHammer","PepeHands","PepeHard","PepeHeart","PepeHmm","PepeHug","PepeJAM","PepeKMS","PepeL","PepeLa","PepeLaffe","PepeLegs","PepeLoser","PepeM","PepeMods","PepeNOOO","PepeNotOK","PepeOK","PepeOuuuhh","PepePains","PepePants","PepePhone","PepePhoned","PepePlan","PepePls","PepePoint","PepePoo","PepePopcorn","PepePuke","PepePyroblast","PepeReach","PepeRun","PepeScoots","PepeScout","PepeSith","PepeSlice","PepeSmile","PepeSmug","PepeStepBro","PepeStressed","PepeThumbsUp","pepeW","PepeWizard","PepeWot","PepeXD","pepoEZ","pepoGun","PepoHide","pepoS","PepoScience","PepoThink","PepperHands","Plotge","pogg","PoggersHype","POGGIES","PogO2","POOGERS","ppEZ","ppFootbol","ppHop","Prayge","RandomPepe","Ratge","Readge","Riotge","SadBlanket","Sadga","Sadge","sadgers","SadHug","SadLove","SadPepe","SAJ","sajj","SALAMI","salutt","shadowChatting","shrujj","Smadge","SMILERS","Smoge","SMUGGERS","SmugPepe","soupchamp","Starege","Stronge","SucksMan","Susge","Suske","Thinkge","TiredW","tomatogang","TroggHYPERS","UHM","Voidge","Weirdga","Weirdge","WeirdJAM","WeirdU","WeirdW","WICKED","WickedDrip","WICKEDSTEER","widepeepoHappy","widepeepoLove","widepeepoPride","widepeepoSad","widepeepoWeird","WideSadge","widestpeepoHappy","widestpeepoSad","Wipege","WOAW","Wokege","Wokegesus","YEP","Yepge","YEPPERS","yikers"},
	[13]=  {"peepo","peepaKiss","peepoAP","peepoBeer","peepoBlanket","peepoBlush","peepoBored","peepoCool","peepoCringe","peepoCute","peepoExit","peepoEZ","peepoFA","peepoFat","peepoFH","peepoFight","peepoFriends","peepoGlad","peepoGun","peepoHands","peepoHide","peepoHit","peepoHmm","peepoHug","peepoHugged","peepoKEKW","peepoKiss","peepoKnight","peepoLip","peepoLove","peepoMaybe","peepoNo","peepoNolegs","peepoNOO","peepoOK","peepoPants","peepoPat","peepoPee","peepoPeek","peepoPlot","peepoPoint","peepoPoo","peepoPride","peepoRain","peepoReallyHappy","peepoS","peepoSad","peepoSalute","peepoSenor","peepoShrug","peepoSick","peepoSip","peepoSmile","peepoStudy","peepoSuspect","peepoSuspicious","peepoTalk","peepoTeddy","peepoThink","peepoTired","peepoUgh","peepoWave","peepoWoW","peepoWTF","peepoYes","pillowJammies"},
	[14]=  {"Suze4Mumes Life","ANELELUL","angery","beamB","beamBrah","beenocs","bricky","bubby","CaptainSuze","ClownBall","ClownPain","coffeeS","EZGiggle","FeelsCozyMan","FeelsDankMan","FeelsShadowMan","GAmer","JanCarlo2","miffs","mumes","PauseChamp","peep420","peepKing","peepoCheer","peepoChef","peepoChrist","peepoCozy","peepoCrown","peepoCry","peepoDK","peepoEZSip","peepoH","peepOK","peepoKing","peepoKnife","peepoKnifeNANI","peepoMad","peepoStab","peepoSuze","peepoWeirdCrown","PepeBed","PepeChill","PepeClown","PepeCool","PepeCop","PepeGiggle","PepeGod","PepeHacker","PepeKing","PepeKingLove","PepeRuski","PepeScience","PepeSmurf","PepeSoldier","PepeSpartan","PepeStudy","PepeSurgeon","PepeSuspect","PepeWave","PepeWheels","PogChampius","PogO","potter","SadHonk","SchubertSmile","spit1","spit2","suze4animals","suze4food","suze4know","suze4study","suzeOK","TheBoys","WeirdChampius"},
	[15]=  {"Ren Custom","0Head","1Head","2Head","3Head","3Lass","4HEader","4Mansion","4Shrug","4Weird","5Hard","5Head",":fluff2:",":fluff:","AMAZINGA","BaconEffect","BlackKnight","Boomer","BroKiss","cmoN","cmonEyes","CrazyChamp","DisappointChamp","DKKona","FLOPPERS","HYPERDANSGAMEW","KEKL","KEKSad","KEKW","KEKWeird","kkOna","KKonaW","LULChamp","LULWW","MaldChamp","MaN","NaM","noxSorry","OhISee","OkayChamp","OldChamp","PATHETIC","PikaWOW","pOg","Pogey","PogeyU","Poghurt","PogWarts","SadChamp","SillyChamp","StareChamp","TriEasy","TriGold","TriHardo","TriHardS","TriKool","TriPeek","VaN","WeirdBruh","WeirdChamp","WhiteKnight","WutChamp"},
	[16]=  {"Chromie","CavemanBob","CcKekThas","CcMile","Dedge","GusFring"},
	[17]=  {"HoMMedia","Anthoing","Anthoing1","BirdgeBath","Byege","CloakBan","DIDSOMEONESAYCOCK","heyge","homStuff","mantisD","sct"},
	[18]=  {"AnnieFuchsia","anniesAngry","anniesAw","anniesAYAYA","anniesBlind","anniesCHEER","anniesCheer","anniesCopium","anniesCozy","anniesCute","anniesDab","anniesDinkDonk","anniesFingi","anniesFull","anniesGasp","anniesGiggle","anniesHi5","anniesHmm","anniesHypers","anniesJAM","anniesKnight","anniesLUL","anniesMega","anniesNo","anniesNodders","anniesNoted","anniesPanic","anniesPet","anniesPls","anniesPog","anniesPoint","anniesPray","anniesPrime","anniesRave","anniesREE","anniesRiot","anniesRIP","anniesSad","anniesSHY","anniesSteer","anniesSwe","anniesThisIsFine","anniesToxic","anniesYikes","anniesZug"},
	[19]=  {"cdewx","dewRag"},
	[20]=  {"Pokelawl","poke1","poke2","poke3","poke4","pokeCOZY","pokeCRY","pokeEZ","pokeG","pokeHD","pokeHmm","pokeHungry","pokeL","pokeLAWL","pokeLurk","pokeM","pokeP","pokeRage","pokeSip","pokeSMOKE","pokeSUBS","pokeU","pokeWeird"},
	[21]=  {"loltyler1","tyler1B","tyler1B1","tyler1B2","tyler1BAD","tyler1E","tyler1H","tyler1H1","tyler1H2","tyler1H3","tyler1H4","tyler1Int","tyler1S","tyler1X"},
	[22]=  {"MOONMOON_OW","moon2A","moon2AY","moon2B","moon2BED","moon2BRAIN","moon2D","moon2E","moon2G","moon2PREGARIO","moon2PREGIGI","moon2SERF"},
	[23]=  {"GNeko","02Angery","02Cry","02Uwu","Keqing","starechamp"},
	[24]=  {"xQc","xqcPlot"},
	[25]=  {"OG_Feedback","GorillaPump"},
	[26]=  {"GuildEmotes","4Town","5Champ",":epic:",":epicW:",":gary:",":guna:",":italy:",":jaina:",":KEK:",":praise:",":squawk:",":stabby:",":twoofakind:","AngeryCry","Angy","BigNars","BinCat","Breadclown","CatChest","CatFat","checkdoggo","CloakofShadows","Coomer","deadgemines","DidntAsk","FatCat","FatDragon","Fradre","HmmChamp","HomieKiss","HomieL","HomieR","HYPEROMEGALUL","InspectorAngryWoof","InspectorAngryWoofM","KEKE","KEKLeo","KEKPog","KEKPoint","KEKWPog","Lyeasy","LyeCute","LyeREE","LyeShrug","LyEZ","noxWhat","OkayChomp","OMEGAKEKW","PantsGrab","Pausey","Pog","PogOff","Pogomega","PogOW","PogTasty","RowFish","RowSalt","SadCash","SadCatWave","SadOke","SmileHard","SmookSpook","SmookWink","sosig","sosigW","ThrallS","TriTasty","Wardøg","widepeepoPog","YAMERO","YUM","Zoomer"},
	[27]=  {"TwitchTV",":tf:","WutFaceW","YeahBoi"},
	[28]=  {"typeg","hyperjoy","laughhard","typegBASED","typegBricked","typegChill","typegKEKB","typegLoad","typegPaul","typegWeed","typegYIP"},
};

  function stripChars(str)
  local tableAccents = {}
    tableAccents["À"] = "A"
    tableAccents["Á"] = "A"
    tableAccents["Â"] = "A"
    tableAccents["Ã"] = "A"
    tableAccents["Ä"] = "A"
    tableAccents["Å"] = "A"
    tableAccents["Æ"] = "AE"
    tableAccents["Ç"] = "C"
    tableAccents["È"] = "E"
    tableAccents["É"] = "E"
    tableAccents["Ê"] = "E"
    tableAccents["Ë"] = "E"
    tableAccents["Ì"] = "I"
    tableAccents["Í"] = "I"
    tableAccents["Î"] = "I"
    tableAccents["Ï"] = "I"
    tableAccents["Ð"] = "D"
    tableAccents["Ñ"] = "N"
    tableAccents["Ò"] = "O"
    tableAccents["Ó"] = "O"
    tableAccents["Ô"] = "O"
    tableAccents["Õ"] = "O"
    tableAccents["Ö"] = "O"
    tableAccents["Ø"] = "O"
    tableAccents["Ù"] = "U"
    tableAccents["Ú"] = "U"
    tableAccents["Û"] = "U"
    tableAccents["Ü"] = "U"
    tableAccents["Ý"] = "Y"
    tableAccents["Þ"] = "P"
    tableAccents["ß"] = "s"
    tableAccents["à"] = "a"
    tableAccents["á"] = "a"
    tableAccents["â"] = "a"
    tableAccents["ã"] = "a"
    tableAccents["ä"] = "a"
    tableAccents["å"] = "a"
    tableAccents["æ"] = "ae"
    tableAccents["ç"] = "c"
    tableAccents["è"] = "e"
    tableAccents["é"] = "e"
    tableAccents["ê"] = "e"
    tableAccents["ë"] = "e"
    tableAccents["ì"] = "i"
    tableAccents["í"] = "i"
    tableAccents["î"] = "i"
    tableAccents["ï"] = "i"
    tableAccents["ð"] = "eth"
    tableAccents["ñ"] = "n"
    tableAccents["ò"] = "o"
    tableAccents["ó"] = "o"
    tableAccents["ô"] = "o"
    tableAccents["õ"] = "o"
    tableAccents["ö"] = "o"
    tableAccents["ø"] = "o"
    tableAccents["ù"] = "u"
    tableAccents["ú"] = "u"
    tableAccents["û"] = "u"
    tableAccents["ü"] = "u"
    tableAccents["ý"] = "y"
    tableAccents["þ"] = "p"
    tableAccents["ÿ"] = "y"
  local normalisedString = ''
  local normalisedString = str: gsub("[%z\1-\127\194-\244][\128-\191]*", tableAccents)
  return normalisedString
end


local BuildOptionsTable, BuildFavOptionsTable  -- forward declarations; assigned below
local AceConfigDialog  -- set at ADDON_LOADED; used by the LDB menu and the navigate button

--Minimap Button
function Emoticons_OnEvent(self, event, ...)
    if (event == "ADDON_LOADED" and select(1, ...) == addonName) then
        if not LDBIcon then
            print("TwitchEmotes Error: LibDBIcon-1.0 not found!")
            return
        end
        
        for k, v in pairs(origsettings) do
            if k ~= "MinimapPos" and Emoticons_Settings[k] == nil then
                Emoticons_Settings[k] = v;
            end
        end

        -- Default any dropdown category with no saved favourite flag to on, so
        -- categories added after a save was first written (e.g. HoMMedia) still
        -- appear in the menu instead of silently defaulting off.
        for n = 1, #dropdown_options do
            if Emoticons_Settings["FAVEMOTES"][n] == nil then
                Emoticons_Settings["FAVEMOTES"][n] = true
            end
        end

        -- Create the LDB object first
        local TwitchEmotesLDB = LDB:NewDataObject("TwitchEmotesIcon", {
            type = "launcher", 
            icon = "Interface\\AddOns\\TwitchEmotes\\Emotes\\1337.tga",
            tooltip = "Twitch Emotes",
            OnClick = function(frame, button)
                if IsShiftKeyDown() then
                    TwitchStats_Toggle()
                elseif button == "LeftButton" then
                    ToggleDropDownMenu(1, nil, EmoticonChatFrameDropDown, frame, 0, 0)
                elseif button == "RightButton" then
                    AceConfigDialog:Open(addonName)
                end
            end,
            -- This LibDBIcon calls obj.OnEnter()/OnLeave() with no args (the
            -- button is only available via the global `this`), unlike OnClick
            -- which gets (this, mouseButton).
            OnEnter = function()
                GameTooltip:SetOwner(this, "ANCHOR_BOTTOMLEFT")
                GameTooltip:AddLine("Twitch Emotes")
                GameTooltip:AddLine("|cffeda55fClick:|r Show Emotes")
                GameTooltip:AddLine("|cffeda55fShift-Click:|r Emote Statistics")
                GameTooltip:AddLine("|cffeda55fRight-Click:|r Options")
                GameTooltip:Show()
            end,
            OnLeave = function()
                GameTooltip:Hide()
            end
        })
        Emoticons_Settings.hide = not Emoticons_Settings["MINIMAPBUTTON"]
        LDBIcon:Register("TwitchEmotesIcon", TwitchEmotesLDB, Emoticons_Settings)

        -- 1.12 has no Blizzard Interface Options panel (InterfaceOptionsFrame
        -- is a 3.0 addition), so options open as standalone AceConfigDialog
        -- windows instead of AddToBlizOptions categories. We register straight
        -- with AceConfigRegistry (what AceConfigDialog:Open reads from) rather
        -- than the AceConfig wrapper, whose Ace3v RegisterOptionsTable errors
        -- when called on the library itself and only adds slash-command support
        -- we don't use.
        local AceConfigRegistry = LibStub("AceConfigRegistry-3.0")
        AceConfigDialog = LibStub("AceConfigDialog-3.0")
        AceConfigRegistry:RegisterOptionsTable("TwitchEmotes", BuildOptionsTable())
        AceConfigRegistry:RegisterOptionsTable("TwitchEmotesFavs", BuildFavOptionsTable())
        AceConfigDialog:SetDefaultSize("TwitchEmotes", 600, 500)
        AceConfigDialog:SetDefaultSize("TwitchEmotesFavs", 400, 500)
    end
end

local addonFrame = CreateFrame("Frame")
addonFrame:RegisterEvent("ADDON_LOADED")
addonFrame:SetScript("OnEvent", Emoticons_OnEvent)

  local ItemTextPageTextSetText = ItemTextPageText.SetText;
	function ItemTextPageText.SetText(self, msg, ...)
    if(Emoticons_Settings["MAIL"] and msg ~= nil) then
        msg = Emoticons_RunReplacement(msg);
    end
    ItemTextPageTextSetText(self, msg, ...);
end
  
  local OpenMailBodyTextSetText = OpenMailBodyText.SetText;
  function OpenMailBodyText.SetText(self,msg,...)
	if(Emoticons_Settings["MAIL"] and msg ~= nil) then
	  msg = Emoticons_RunReplacement(msg);
	end
	OpenMailBodyTextSetText(self,msg,...);
  end
  
  -- A DropDownList shows at most UIDROPDOWNMENU_MAXBUTTONS (40) rows, and menus
  -- go at most UIDROPDOWNMENU_MAXLEVELS (3) deep. One entry per pack:
  --   level 1 = pack -> level 2 = emote-range pages (only if >40) -> level 3 = emotes
  -- A pack with <=40 emotes skips the page level (level 2 lists its emotes).
  local function Emoticons_CatPages(v)
	return math.max(1, math.ceil((#v - 1) / UIDROPDOWNMENU_MAXBUTTONS));
  end

  local function Emoticons_AddEmotes(k, page, level)
	local v = dropdown_options[k];
	if (not v) then return end
	local first = (page - 1) * UIDROPDOWNMENU_MAXBUTTONS + 2;  -- [1] is the pack name
	local last = math.min(first + UIDROPDOWNMENU_MAXBUTTONS - 1, #v);
	for i = first, last do
	  local va = v[i];
	  local info = UIDropDownMenu_CreateInfo();
	  info.text = "|T"..defaultpack[va].."|t "..va;
	  info.value = va;
	  info.func = Emoticons_Dropdown_OnClick;
	  info.arg1 = va;
	  info.notCheckable = 1;
	  UIDropDownMenu_AddButton(info, level);
	end
  end

  function Emoticons_LoadChatFrameDropdown(level)
	level = level or UIDROPDOWNMENU_MENU_LEVEL or 1;
	if (level == 1) then
	  for k, v in ipairs(dropdown_options) do
		if (Emoticons_Settings["FAVEMOTES"][k]) then
		  local info = UIDropDownMenu_CreateInfo();
		  info.hasArrow = 1;
		  info.notCheckable = 1;
		  info.text = v[1];
		  info.value = { category = k };
		  UIDropDownMenu_AddButton(info, level);
		end
	  end
	else
	  local value = UIDROPDOWNMENU_MENU_VALUE;
	  if (type(value) ~= "table") then return end
	  local v = dropdown_options[value.category];
	  if (not v) then return end
	  if (value.page) then
		Emoticons_AddEmotes(value.category, value.page, level);       -- level 3: emotes of a page
	  elseif (Emoticons_CatPages(v) > 1) then
		local pages = Emoticons_CatPages(v);                          -- level 2: name-range pages
		for page = 1, pages do
		  local firstIdx = (page - 1) * UIDROPDOWNMENU_MAXBUTTONS + 2; -- [1] is the pack name
		  local lastIdx = math.min(page * UIDROPDOWNMENU_MAXBUTTONS + 1, #v);
		  local info = UIDropDownMenu_CreateInfo();
		  info.hasArrow = 1;
		  info.notCheckable = 1;
		  info.text = v[firstIdx].."-"..v[lastIdx];               -- e.g. "majj-peepofeet"
		  info.value = { category = value.category, page = page };
		  UIDropDownMenu_AddButton(info, level);
		end
	  else
		Emoticons_AddEmotes(value.category, 1, level);                -- level 2: emotes (single page)
	  end
	end
  end
  function Emoticons_Dropdown_OnClick(emote)
	if (ChatFrameEditBox:IsVisible()) then
	  ChatFrameEditBox:Insert(emote);
	end
  end
  function Emoticons_MailFrame_OnChar(self)
	local msg = self:GetText();
	if(Emoticons_Eyecandy and Emoticons_Settings["MAIL"] and string.sub(msg,1,1) ~= "/") then
	  self:SetText(Emoticons_RunReplacement(msg));
	end
  end
  
  local sm = SendMail;
  function SendMail(recipient,subject,msg,...)
	if(Emoticons_Eyecandy and Emoticons_Settings["MAIL"]) then
	  msg = Emoticons_Deformat(msg);
	end
	sm(recipient,subject,msg,...);
  end
  
  local scm = SendChatMessage;
  function SendChatMessage(msg,...)
	if(Emoticons_Eyecandy) then
	  msg = Emoticons_Deformat(msg);
	end
	scm(msg,...);
  end
  
  -- Overridden by TwitchEmotesStats.lua with a version that also counts
  -- emote usage. sender is the message author (arg2 of CHAT_MSG_* events).
  function Emoticons_FilterMessage(msg, sender)
	return Emoticons_RunReplacement(msg);
  end

  -- 1.12 has no ChatFrame_AddMessageEventFilter; hook ChatFrame_OnEvent and
  -- rewrite the message in the global arg1 before the original handler prints
  -- it. Gating on Emoticons_Settings[event] only passes for the CHAT_MSG_*
  -- keys, which are toggled live by Emoticons_SetType.
  local Emoticons_Orig_ChatFrame_OnEvent = ChatFrame_OnEvent;
  function ChatFrame_OnEvent(event)
	if (arg1 and Emoticons_Settings[event]) then
	  arg1 = Emoticons_FilterMessage(arg1, arg2);
	end
	Emoticons_Orig_ChatFrame_OnEvent(event);
  end
  
  function Emoticons_Deformat(msg)
	for k,v in pairs(emoticons) do
	  msg = string.gsub(msg, "|T"..defaultpack[k].."|t", v);
	end
	return msg;
  end
  
  function Emoticons_RunReplacement(msg)
	-- Turtle WoW wraps GM chat in a colour escape server-side (|c1049e6ff...|r,
	-- see tortoise-wow Chat.cpp BuildChatPacket). That glues the first/last words
	-- to |c<hex>/|r so they never tokenise as emotes. Peel a leading colour code
	-- and its trailing |r, replace the inner text, then re-wrap. Lossless for the
	-- ordinary "message is a single item link" case too.
	local prefix, suffix = "", "";
	local color = string.match(msg, "^(|c%x%x%x%x%x%x%x%x)");
	if(color) then
	  prefix = color;
	  msg = string.sub(msg, string.len(color) + 1);
	  if(string.sub(msg, -2) == "|r") then
		suffix = "|r";
		msg = string.sub(msg, 1, -3);
	  end
	end

	local outstr = "";
	local origlen = string.len(msg);
	local startpos = 1;
	local endpos;
  
	while(startpos <= origlen) do
	  endpos = origlen;
	  local pos = string.find(msg,"|H",startpos,true);
	  if(pos ~= nil) then
		endpos = pos;
	  end
	  outstr = outstr .. Emoticons_InsertEmoticons(string.sub(msg,startpos,endpos));
	  startpos = endpos + 1;
	  if(pos ~= nil) then
		endpos = string.find(msg,"|h",startpos,true);
		if(endpos == nil) then
		  endpos = origlen;
		end
		if(startpos < endpos) then
		  outstr = outstr .. string.sub(msg,startpos,endpos);
		  startpos = endpos + 1;
		end
	  end
	end

	return prefix .. outstr .. suffix;
  end
  
  function Emoticons_SetEyecandy(state)
	if(state) then
	  Emoticons_Eyecandy = true;
	  if(ChatFrameEditBox:IsVisible()) then
		ChatFrameEditBox:SetText(Emoticons_RunReplacement(ChatFrameEditBox:GetText()));
	  end
	else
	  Emoticons_Eyecandy = false;
	  if(ChatFrameEditBox:IsVisible()) then
		ChatFrameEditBox:SetText(Emoticons_Deformat(ChatFrameEditBox:GetText()));
	  end
	end
  end
  
  function Emoticons_SetMinimapButton(state)
    if state then state = true else state = false end 
    
    Emoticons_Settings["MINIMAPBUTTON"] = state; 

    if LDBIcon then 
        if state then
            LDBIcon:Show("TwitchEmotesIcon")
        else
            LDBIcon:Hide("TwitchEmotesIcon")
        end
    else
        print("TwitchEmotes Error: LibDBIcon not available when trying to set minimap button visibility.")
    end
end
  local EMOTE_DELIMITERS = "%s,'<>?-%.!"

  function Emoticons_InsertEmoticons(msg)
	local wrapPattern = "([" .. EMOTE_DELIMITERS .. "]+)"
	for word in string.gmatch(msg, "[^" .. EMOTE_DELIMITERS .. "]+") do
	  local emote = emoticons[word]
	  if (emote and defaultpack[emote]) then
		local tex = defaultpack[emote]
		local core
		if (Emoticons_Settings["CLICKABLEEMOTES"]) then
		  core = "|Htel:" .. word .. "|h|T" .. tex .. "|t|h"
		else
		  core = "|T" .. tex .. "|t"
		end
		msg = string.gsub(msg, wrapPattern .. word .. wrapPattern, "%1" .. core .. "%2", 1)
		msg = string.gsub(msg, wrapPattern .. word .. "$",         "%1" .. core,         1)
		msg = string.gsub(msg, "^" .. word .. wrapPattern,         core .. "%1",         1)
		msg = string.gsub(msg, "^" .. word .. "$",                 core)
		msg = string.gsub(msg, wrapPattern .. word .. "(%c)",      "%1" .. core .. "%2", 1)
		msg = string.gsub(msg, wrapPattern .. word .. wrapPattern, "%1" .. core .. "%2", 1)
	  end
	end
	return msg;
  end
  
  function Emoticons_SetType(chattype,state)
	if(state) then
	  state = true;
	else
	  state = false;
	end
	if(chattype == "CHAT_MSG_RAID") then
	  Emoticons_Settings["CHAT_MSG_RAID_LEADER"] = state;
	  Emoticons_Settings["CHAT_MSG_RAID_WARNING"] = state;
	end
	if(chattype == "CHAT_MSG_PARTY") then
	  Emoticons_Settings["CHAT_MSG_PARTY_LEADER"] = state;
	  Emoticons_Settings["CHAT_MSG_PARTY_GUIDE"] = state;
	end
	if(chattype == "CHAT_MSG_WHISPER") then
	  Emoticons_Settings["CHAT_MSG_WHISPER_INFORM"] = state;
	end
	if(chattype == "CHAT_MSG_BATTLEGROUND") then
	  Emoticons_Settings["CHAT_MSG_BATTLEGROUND_LEADER"] = state;
	end
	Emoticons_Settings[chattype] = state;
  end
local EmoticonChatFrameDropDown = CreateFrame("Frame", "EmoticonChatFrameDropDown", UIParent, "UIDropDownMenuTemplate")
UIDropDownMenu_Initialize(EmoticonChatFrameDropDown, Emoticons_LoadChatFrameDropdown, "MENU", 1)

-- ToggleDropDownMenu only tests whether a list runs off the bottom or the
-- right of the screen, flips its anchor once and never re-measures, so a list
-- flipped upwards overflows the top instead (a 40-row emote page opened from a
-- submenu halfway down the screen), and its off-screen-X test compares the
-- list's own coordinates against pixel widths, flipping submenus left even
-- when that pushes them past the left edge. Nudge our own lists back inside
-- the screen after it has positioned them; the emote pages are at most
-- 40 * UIDROPDOWNMENU_BUTTON_HEIGHT + borders tall, so they always fit.
local function Emoticons_ClampDropDownList(level)
  local list = _G["DropDownList"..level];
  if (not list or not list:IsShown()) then return end
  local scale = list:GetEffectiveScale();
  local uiScale = UIParent:GetEffectiveScale();
  local left, right = list:GetLeft(), list:GetRight();
  local bottom, top = list:GetBottom(), list:GetTop();
  if (not left or not bottom) then return end
  -- Everything below is in screen pixels, since the list carries a scale of
  -- its own (ToggleDropDownMenu sets it from the uiscale cvar).
  left, right, bottom, top = left * scale, right * scale, bottom * scale, top * scale;
  local screenWidth = GetScreenWidth() * uiScale;
  local screenHeight = GetScreenHeight() * uiScale;
  local dx, dy = 0, 0;
  if (right > screenWidth) then dx = screenWidth - right end
  if (left + dx < 0) then dx = -left end          -- a list wider than the screen keeps its left edge
  if (top > screenHeight) then dy = screenHeight - top end
  if (bottom + dy < 0) then dy = -bottom end
  if (dx == 0 and dy == 0) then return end
  -- UIParent's BOTTOMLEFT is screen pixel (0,0); SetPoint offsets are in the
  -- units of the frame being moved, so scale the corrected position back down.
  list:ClearAllPoints();
  list:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", (left + dx) / scale, (top + dy) / scale);
end

local Emoticons_Orig_ToggleDropDownMenu = ToggleDropDownMenu;
function ToggleDropDownMenu(level, value, dropDownFrame, anchorName, xOffset, yOffset)
  Emoticons_Orig_ToggleDropDownMenu(level, value, dropDownFrame, anchorName, xOffset, yOffset);
  -- Submenus are opened by the list buttons themselves with no dropDownFrame,
  -- so identify ours by the menu ToggleDropDownMenu just recorded as open.
  if (UIDROPDOWNMENU_OPEN_MENU == "EmoticonChatFrameDropDown") then
    Emoticons_ClampDropDownList(level or 1);
  end
end

do
    local pending, seen = {}, {}
    for _, group in ipairs(dropdown_options) do
        for i = 2, #group do 
            local tex = defaultpack[group[i]]
            if tex and not seen[tex] then
                seen[tex] = true
                pending[#pending + 1] = (string.gsub(tex, ":%d+:%d+$", ""))
            end
        end
    end

    local warmer = CreateFrame("Frame")
    local retained = {}
    local idx = 0
    warmer:SetScript("OnUpdate", function(self)
        if InCombatLockdown() then return end
        local budget = 15
        while budget > 0 and idx < #pending do
            idx = idx + 1
            local t = self:CreateTexture(nil, "BACKGROUND")
            t:SetTexture(pending[idx])
            t:Hide()
            retained[idx] = t
            budget = budget - 1
        end
        if idx >= #pending then
            self:SetScript("OnUpdate", nil)
        end
    end)
end

-- ── AceConfig options tables ──────────────────────────────────────────────────

BuildOptionsTable = function()
    local opts = {
        type = "group",
        name = "TwitchEmotes",
        args = {
            channelsHeader = { type = "header", name = "Chat Channels", order = 1 },
            say          = { type = "toggle", name = "Say",          order = 2,
                get = function() return Emoticons_Settings["CHAT_MSG_SAY"] end,
                set = function(_, v) Emoticons_SetType("CHAT_MSG_SAY", v) end },
            yell         = { type = "toggle", name = "Yell",         order = 3,
                get = function() return Emoticons_Settings["CHAT_MSG_YELL"] end,
                set = function(_, v) Emoticons_SetType("CHAT_MSG_YELL", v) end },
            guild        = { type = "toggle", name = "Guild",        order = 4,
                get = function() return Emoticons_Settings["CHAT_MSG_GUILD"] end,
                set = function(_, v) Emoticons_SetType("CHAT_MSG_GUILD", v) end },
            officer      = { type = "toggle", name = "Officer",      order = 5,
                get = function() return Emoticons_Settings["CHAT_MSG_OFFICER"] end,
                set = function(_, v) Emoticons_SetType("CHAT_MSG_OFFICER", v) end },
            whisper      = { type = "toggle", name = "Whisper",      order = 6,
                get = function() return Emoticons_Settings["CHAT_MSG_WHISPER"] end,
                set = function(_, v) Emoticons_SetType("CHAT_MSG_WHISPER", v) end },
            party        = { type = "toggle", name = "Party",        order = 7,
                get = function() return Emoticons_Settings["CHAT_MSG_PARTY"] end,
                set = function(_, v) Emoticons_SetType("CHAT_MSG_PARTY", v) end },
            raid         = { type = "toggle", name = "Raid",         order = 8,
                get = function() return Emoticons_Settings["CHAT_MSG_RAID"] end,
                set = function(_, v) Emoticons_SetType("CHAT_MSG_RAID", v) end },
            channel      = { type = "toggle", name = "Channel",      order = 9,
                get = function() return Emoticons_Settings["CHAT_MSG_CHANNEL"] end,
                set = function(_, v) Emoticons_SetType("CHAT_MSG_CHANNEL", v) end },
            battleground = { type = "toggle", name = "Battleground", order = 10,
                get = function() return Emoticons_Settings["CHAT_MSG_BATTLEGROUND"] end,
                set = function(_, v) Emoticons_SetType("CHAT_MSG_BATTLEGROUND", v) end },
            mail         = { type = "toggle", name = "Mail",         order = 11,
                get = function() return Emoticons_Settings["MAIL"] end,
                set = function(_, v) Emoticons_Settings["MAIL"] = v end },
            minimapHeader  = { type = "header", name = "Minimap", order = 20 },
            minimapButton  = { type = "toggle", name = "Show Minimap Button", order = 21,
                get = function() return Emoticons_Settings["MINIMAPBUTTON"] end,
                set = function(_, v) Emoticons_SetMinimapButton(v) end },
            bubblesHeader  = { type = "header", name = "Chat Bubbles", order = 25 },
            bubbleEmotes   = { type = "toggle", name = "Show emotes in chat bubbles", order = 26,
                get = function() return Emoticons_Settings["BUBBLEEMOTES"] end,
                set = function(_, v) Emoticons_Settings["BUBBLEEMOTES"] = v end },
            autocompleteHeader = { type = "header", name = "Autocomplete", order = 27 },
            autocomplete   = { type = "toggle", name = "Enable emote autocomplete", order = 28,
                get = function() return Emoticons_Settings["AUTOCOMPLETE"] end,
                set = function(_, v) Emoticons_Settings["AUTOCOMPLETE"] = v end },
            clickableHeader = { type = "header", name = "Clickable Emotes", order = 28.5 },
            clickableEmotes = { type = "toggle", name = "Clickable / hover emotes (show name on mouseover)", order = 28.6,
                get = function() return Emoticons_Settings["CLICKABLEEMOTES"] end,
                set = function(_, v) Emoticons_Settings["CLICKABLEEMOTES"] = v end },
            favHeader      = { type = "header", name = "Favourites", order = 29 },
            openFavs       = { type = "execute", name = "Open Favourite Groups", order = 30,
                func = function()
                    AceConfigDialog:Open("TwitchEmotesFavs")
                end },
        },
    }
    return opts
end

BuildFavOptionsTable = function()
    local opts = {
        type = "group",
        name = "Favourites",
        args = {
            enableAll = {
                type = "execute", name = "Enable All", order = 1,
                func = function()
                    for n = 1, #dropdown_options do
                        Emoticons_Settings["FAVEMOTES"][n] = true
                    end
                end,
            },
            disableAll = {
                type = "execute", name = "Disable All", order = 2,
                func = function()
                    for n = 1, #dropdown_options do
                        Emoticons_Settings["FAVEMOTES"][n] = false
                    end
                end,
            },
            spacer = { type = "header", name = "", order = 3 },
        },
    }
    for n, groupData in ipairs(dropdown_options) do
        opts.args["fav_" .. n] = {
            type = "toggle",
            name = groupData[1],
            order = 10 + n,
            get = function() return Emoticons_Settings["FAVEMOTES"][n] end,
            set = function(_, v) Emoticons_Settings["FAVEMOTES"][n] = v end,
        }
    end
    return opts
end

-- ── Chat Bubble Emoticon Processing ──────────────────────────────────────────

local EmoticonBubbles = {}

local function bubbleReplace(text)
    if not Emoticons_Settings["BUBBLEEMOTES"] then return text end
    local input = text .. " "
    local cur = input
    local prev
    repeat
        prev = cur
        cur = Emoticons_RunReplacement(cur)
    until cur == prev
    if cur ~= input then
        return cur
    end
    return text
end

-- The bubble text is drawn by one of two FontStrings we can't just overwrite:
--   * the engine's own (default UI) — SetText doesn't stick, the engine
--     re-asserts its text;
--   * pfUI's replacement (bubble.frame.text) when pfUI's bubbles module is on —
--     it shows the raw text in a pfUI-styled bubble and re-sets it on OnShow.
-- So we hide whichever one currently shows the text and draw our own
-- auto-sizing overlay (no width constraint, so wide emotes never clip) on top.
local function bubbleDisplayFS(bubble)
    if bubble.frame and bubble.frame.text then  -- pfUI's bubbles module owns it
        return bubble.frame.text
    end
    return bubble.tweEngineFS
end

local function applyBubbleEmotes(bubble)
    local fs = bubbleDisplayFS(bubble)
    local overlay = bubble.tweOverlay
    if not fs or not overlay then return end
    local raw = fs:GetText()
    if raw and raw ~= "" and Emoticons_Settings["BUBBLEEMOTES"] then
        local newText = bubbleReplace(raw)
        if newText ~= raw then
            local r, g, b, a = fs:GetTextColor()
            overlay:SetText(newText)
            overlay:SetTextColor(r, g, b, a)
            overlay:Show()
            fs:Hide()
            return
        end
    end
    -- no emotes (or feature off): show the source text, hide our overlay
    overlay:Hide()
    fs:Show()
end

-- ClassicAPI exposes the modern C_ChatBubbles.GetAllChatBubbles(); the spoken
-- text is a FontString region of each bubble. Each bubble is prepared once — we
-- find its display FontString, build a matching auto-sizing overlay on the same
-- parent (so scale matches pfUI's scaled child when present), and HookScript
-- OnShow so pooled bubbles re-sync when the engine (or pfUI) recycles them. The
-- scan is deferred (see the event handler) so pfUI's per-bubble setup already
-- ran and our OnShow hook lands after pfUI's.
function EmoticonBubbles:ScanBubbles()
    for _, bubble in ipairs(C_ChatBubbles.GetAllChatBubbles()) do
        if bubble.tweEngineFS == nil then
            bubble.tweEngineFS = false  -- mark inspected even if none found
            for j = 1, bubble:GetNumRegions() do
                local region = select(j, bubble:GetRegions())
                if region and region:GetObjectType() == "FontString" then
                    bubble.tweEngineFS = region
                    break
                end
            end
            if bubble.tweEngineFS then
                local fs = bubbleDisplayFS(bubble)
                local overlay = fs:GetParent():CreateFontString(nil, "OVERLAY")
                local font, size, flags = fs:GetFont()
                overlay:SetFont(font, size, flags)
                overlay:SetPoint("CENTER", fs, "CENTER", 0, 0)
                bubble.tweOverlay = overlay
                bubble:HookScript("OnShow", applyBubbleEmotes)
            end
        end
        if bubble.tweEngineFS then
            applyBubbleEmotes(bubble)
        end
    end
end

local bubbleFrame = CreateFrame("Frame")
bubbleFrame:RegisterEvent("CHAT_MSG_SAY")
bubbleFrame:RegisterEvent("CHAT_MSG_YELL")
bubbleFrame:RegisterEvent("CHAT_MSG_PARTY")
bubbleFrame:RegisterEvent("CHAT_MSG_PARTY_LEADER")
bubbleFrame:RegisterEvent("CHAT_MSG_MONSTER_SAY")
bubbleFrame:RegisterEvent("CHAT_MSG_MONSTER_YELL")
bubbleFrame:RegisterEvent("CHAT_MSG_MONSTER_PARTY")
bubbleFrame:SetScript("OnEvent", function()
    if Emoticons_Settings["BUBBLEEMOTES"] then
        -- Defer two frames: the bubble attaches one frame after the chat event,
        -- and pfUI's bubbles module (if active) sets up on that same next frame.
        -- Running a frame later lets us detect pfUI's managed FontString and land
        -- our OnShow hook after pfUI's SetScript, regardless of addon load order.
        RunNextFrame(function() RunNextFrame(function() EmoticonBubbles:ScanBubbles() end) end)
    end
end)

-- ── Clickable / hoverable emote hyperlinks ───────────────────────────────────
-- When CLICKABLEEMOTES is enabled, Emoticons_InsertEmoticons wraps each emote
-- texture in a |Htel:<name>|h ... |h hyperlink. These hooks show the emote name
-- on hover, insert the emote code into chat on shift-click (the CHATLINK
-- modifier, like item links), and harmlessly swallow a plain click (the link
-- type is not a real item/spell link, so the default handler must not resolve it).

-- Put the emote code into the chat edit box (opening it if needed).
local function Emoticons_InsertEmoteToChat(name)
    if ChatFrameEditBox:IsVisible() then
        ChatFrameEditBox:Insert(name)
    else
        ChatFrame_OpenChat(name)
    end
end

local Emoticons_orig_SetItemRef = SetItemRef
function SetItemRef(link, text, button, chatFrame)
    if link and link:sub(1, 4) == "tel:" then
        -- Always swallow tel: clicks so old links can't error, but only act on
        -- shift-click while the feature is enabled.
        if Emoticons_Settings["CLICKABLEEMOTES"] and IsShiftKeyDown() then
            Emoticons_InsertEmoteToChat(string.sub(link, 5))
        end
        return
    end
    return Emoticons_orig_SetItemRef(link, text, button, chatFrame)
end

local function Emoticons_OnHyperlinkEnter(self, link)
    if link and Emoticons_Settings["CLICKABLEEMOTES"] and link:sub(1, 4) == "tel:" then
        GameTooltip:SetOwner(self, "ANCHOR_CURSOR")
        GameTooltip:SetText(link:sub(5), 1, 0.82, 0)
        GameTooltip:Show()
    end
end

local function Emoticons_OnHyperlinkLeave(self, link)
    if link and link:sub(1, 4) == "tel:" then
        GameTooltip:Hide()
    end
end

local hyperlinkFrame = CreateFrame("Frame")
hyperlinkFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
hyperlinkFrame:SetScript("OnEvent", function(self)
    if self.hooked then return end
    self.hooked = true
    for i = 1, (NUM_CHAT_WINDOWS or 10) do
        local cf = _G["ChatFrame" .. i]
        if cf and cf.HookScript then
            -- pcall: if this client build doesn't expose these script handlers,
            -- degrade gracefully (clicks still swallowed, emotes still render).
            pcall(cf.HookScript, cf, "OnHyperlinkEnter", Emoticons_OnHyperlinkEnter)
            pcall(cf.HookScript, cf, "OnHyperlinkLeave", Emoticons_OnHyperlinkLeave)
        end
    end
end)