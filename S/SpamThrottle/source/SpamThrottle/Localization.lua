-- English localization
-- English by Mopar

-- Localization Strings

SpamThrottleProp = {};
SpamThrottleProp.Version = GetAddOnMetadata("SpamThrottle", "Version");
SpamThrottleProp.Author = "Mopar";
SpamThrottleProp.AppName = "SpamThrottle";
SpamThrottleProp.Label = SpamThrottleProp.AppName .. " version " .. SpamThrottleProp.Version;
SpamThrottleProp.LongLabel = SpamThrottleProp.Label .. " by " .. SpamThrottleProp.Author;
SpamThrottleProp.CleanLabel = SpamThrottleProp.AppName .. " by " .. SpamThrottleProp.Author;
SpamThrottleProp.Description = "A spam-reducing addon to remove repeated and annoying chat messages";

SpamThrottleConfigMenuTitle = SpamThrottleProp.Label;
SpamThrottleGlobalOptions = "Global SpamThrottle Options";
SpamThrottleStatus = "SpamThrottle Status & Gapping";
SpamThrottleKeywords = "Filtering Keywords";
SpamThrottlePlayerbans = "Filtered Player Names (local bans)";
SpamThrottleGeneralMask = "<<<----[%a%d][%a%d][%a%d][%a%d][%a%d][%a%d][%a%d][%a%d][%a%d][%a%d][%a%d][%a%d]";

SpamThrottleChatMsg = {
	WelcomeMsg = SpamThrottleProp.CleanLabel .. " for reducing chat spam (Slash commands: /spamthrottle or /st)";
	ObjectLoadFail = "Error! Failed to load object:";
	ObjectSaveFail = "Error! Failed to save object:";
	LoadDefault = "Version update detected. Options have been reset to defaults.";
	LoadKeywordDefault = "Keyword filtering list has been reset to defaults.";
	LoadPlayerbanDefault = "Local player silencing list has been cleared.";
	EnterFilterKeyword = "Enter new filtering keyword:";
	EnterPlayername = "Enter player name:";
	BanAdded = "added to your local SpamThrottle ban list";
	BanRemoved = "removed from your local SpamThrottle ban list";
	Permanent = "unlimited time";
	Timeout = "timeout";
	WhisperBack = "Message delivery failure: Your whisper was blocked by an addon.";
}

SpamThrottleStatusMsg = {
	StatusText1 = "keywords in keyword filter list";
	StatusText2 = "player names in player filter list";
	StatusText4 = "player names in moderated ban list";
	StatusText5 = "unique received messages currently in database";
	StatusText6 = "messages filtered so far in this session";
	StatusText7 = "Whitelisted Channels:";
	StatusText8 = "1: ";
	StatusText9 = "2: ";
	StatusText10 = "3: ";
}

SpamThrottleConfigObjectText ={
	STActive = "Enable SpamThrottle Filtering";
	STDupFilter = "Remove duplicated messages until gap timeout";
	STColor = "Color messages rather than hiding";
	STFuzzy = "Fuzzy filter messages enabled";
	STGoldSeller = "Gold seller ad aggressive filtering enabled";
	STChinese = "Chinese character & QQ filtering enabled";
	STCtrlMsgs = "Control message block for chat channels";
	STYellMsgs = "Filtering of /y (yell) messages enabled";
	STSayMsgs = "Filtering of /s (say) messages enabled";
	STWispMsgs = "Filtering of /w (whisper) messages enabled";
	STWispBack = "Auto reply if filtered";
	STMultiWisp = "Filtering combined whispers from same player";
	STWispMsgsOFF = "Turn whispers completely off";
	STReverse = "Display ONLY keyword matches as a whitelist";
	STMinimapButton = "Display Minimap button";
	STGap = "Message Gapping (sec)";
	STBanPerm = "Permanent";
	STBanTimeout = "Ban Timeout (sec)";
}

SpamThrottleConfigObjectTooltip ={
	STActive = "Enable or disable all chat message filtering.";
	STDupFilter = "If checked, will filter duplicate messages, not allowing them to appear again until the number of seconds specified by Message Gapping has passed";
	STColor = "If checked, filtered messages are identified by coloring them rather than hiding. You see the messages but can visually skip over them more easily.";
	STFuzzy = "Enables fuzzy filtering which catches very similar repeated messages such as those sent by drunk characters.";
	STGoldSeller = "Enables aggressive gold advertising filtering to remove gold ad spam.";
	STChinese = "Filters messages containing Chinese, Korean or Japanese characters.";
	STCtrlMsgs = "Filters channel control messages to remove joined/left channel spam.";
	STYellMsgs = "Enables filtering of player messages yelled by nearby players";
	STSayMsgs = "Enables filtering of player messages said by nearby players.";
	STWispMsgs = "Enables filtering of player messages whispered to you directly.";
	STWispBack = "Automatically responds with a polite whisper back to the player telling them their message was blocked. Will not work if WIM present";
	STMultiWisp = "Enables filtering of multiple player messages combined, whispered to you by the same player within the last few seconds.";
	STWispMsgsOFF = "Turn whispers completely off by server command .wr at start";
	STReverse = "Reverses the sense of SpamThrottle filtering. Messages matching a keyword will be shown, all others will be blocked.";
	STMinimapButton = "Turn On or Off minimap button";
	STGap = "Sets the minimum required gap between repeated messages. If the gap time has not been reached for that player and message since the last one, it will be filtered.";
	STBanPerm = "If enabled, player bans stay in place until you remove them. Otherwise players will be removed automatically after the timeout expires for them.";
	STBanTimeout = "Players will automatically be removed from this list after this amount of time if permanent ban (above) is not set.";
}

SpamThrottleGSC1 = { "%d%s+[Gg]", "%d+%D?%D?%D?%D?%D?[Gg]" };
SpamThrottleGSC2 = { "%$", "USD", "C[O@]M", "W@W", "G4", ">>", ">>>", "[gG][^%$]*%$", "%$[^gG]*[gG]", "[gG]%D?%D?%D?%D?%d+", "[lL][vV][lL]?%D?%D?%D?%D?%D?%d+" };
SpamThrottleGSO1 = { "ACCOUNT", "CHEAP", "LEGIT", "LEVELING", "LEVELLING", "LEVLING", "LEVILING", "LEVEL", "IEVEING","LVLING", "SAFE", "ITEM", "SERVICE", "NOST", "SELL", "POTION","POWER", "WOW",  };
SpamThrottleGSO2 = { "PRICE", "GOLD", "CURRENCY", "MONEY", "STARS", "SKYPE", "EPIC", "DOLLARS", "PROFESSIONAL", "RELIABLE", "PROMOTION", "DELIVER", "NAXX", "GAMES", "GREETINGS", "WEBSITE", "GOID", "CQM" , "MOK", "WEBMO", "MOGS", "NOST", "SAGEBLADE", "LFMDPSCOM","LFMBRDCOM"};
SpamThrottleGSUC5 = { "ITEM4" }
SpamThrottleSWLO = { "OKO", "GAMES", "NOST", "COM", "TANK", "WG" , "WMO", "K4WOW", }

if GetLocale() == "ruRU" then
	-- Russian localization by Lichery
	
	SpamThrottleProp.Label = SpamThrottleProp.AppName .. " версия " .. SpamThrottleProp.Version;
	SpamThrottleProp.LongLabel = SpamThrottleProp.Label .. " от " .. SpamThrottleProp.Author;
	SpamThrottleProp.CleanLabel = SpamThrottleProp.AppName .. " от " .. SpamThrottleProp.Author;
	SpamThrottleProp.Description = "Снижающий спам аддон для удаления повторяющихся и раздражающих сообщений чата.";
	
	SpamThrottleConfigMenuTitle = SpamThrottleProp.Label;
	SpamThrottleGlobalOptions = "Настройки SpamThrottle";
	SpamThrottleStatus = "SpamThrottle Статус & Повтор";
	SpamThrottleKeywords = "Фильтрация ключевых слов";
	SpamThrottlePlayerbans = "Фильтрация имен игроков (местные запреты)";
	SpamThrottleGeneralMask = "<<<----[%a%d][%a%d][%a%d][%a%d][%a%d][%a%d][%a%d][%a%d][%a%d][%a%d][%a%d][%a%d]";
	
	SpamThrottleChatMsg = {
		WelcomeMsg = SpamThrottleProp.CleanLabel .. " для уменьшения спама чата (Команды: /spamthrottle или /st)";
		ObjectLoadFail = "Ошибка! Не удалось загрузить объект:";
		ObjectSaveFail = "Ошибка! Не удалось сохранить объект:";
		LoadDefault = "Обнаружено обновление версии. Настройки сброшены до значений по умолчанию.";
		LoadKeywordDefault = "Список фильтров ключевых слов сброшен до значений по умолчанию.";
		LoadPlayerbanDefault = "Местный список блокировки игроков был очищен.";
		EnterFilterKeyword = "Введите новое ключевое слово фильтрации:";
		EnterPlayername = "Введите имя игрока:";
		BanAdded = "добавлен в ваш местный список запрета спама SpamThrottle";
		BanRemoved = "удален из вашего местного списка запрета спама SpamThrottle";
		Permanent = "неограниченное время";
		Timeout = "перерыв";
		WhisperBack = "Ошибка доставки сообщений: ваш шепот был заблокирован аддоном.";
	}
	
	SpamThrottleStatusMsg = {
		StatusText1 = "ключевых слов в списке фильтрации слов";
		StatusText2 = "имен игроков в списке фильтрации игроков";
		StatusText4 = "имен игроков в списке модерируемых запретов";
		StatusText5 = "уникальных полученных сообщений в базе данных";
		StatusText6 = "отфильтрованных сообщений в этом сеансе";
		StatusText7 = "Каналы \"Белого\" списка:";
		StatusText8 = "1: ";
		StatusText9 = "2: ";
		StatusText10 = "3: ";
	}
	
	SpamThrottleConfigObjectText ={
		STActive = "Включить фильтрацию SpamThrottle";
		STDupFilter = "Удалять дублир. сообщения до истечения времени ожид.";
		STColor = "Окрашивать сообщения вместо скрытия";
		STFuzzy = "Нечеткая фильтрация";
		STGoldSeller = "Активная фильтрация рекламы продавцов золота включена";
		STChinese = "Китайские символы & QQ фильтрация включена";
		STCtrlMsgs = "Фильтрация контрольных сообщений для каналов чата";
		STYellMsgs = "Фильтрация /y (крикнуть) сообщений включена";
		STSayMsgs = "Фильтрация /s (сказать) сообщений включена";
		STWispMsgs = "Фильтрация /w (шепот) сообщений включена";
		STWispBack = "Автоматический ответ, если фильтруется";
		STMultiWisp = "Фильтрация комбинированного шепота одного и того же игрока"; --
		STWispMsgsOFF = "Выключить шепот полностью"; --
		STReverse = "Показывать ТОЛЬКО соответствия ключевых слов как\nв \"белом\" списке";
		STMinimapButton = "Отображать кнопку мини-карты";	--	
		STGap = "Повтор сообщений (секунды)";
		STBanPerm = "Постоянный";
		STBanTimeout = "Время запрета\n(секунды)";
	}
	
	SpamThrottleConfigObjectTooltip ={
		STActive = "Включение или отключение фильтрации всех сообщений чата.";
		STDupFilter = "Если флажок установлен, будет фильтровать повторяющиеся сообщения, не позволяя им появляться снова до тех пор, пока не пройдет число секунд, указанное в \"Повтор сообщений\".";
		STColor = "Если флажок установлен, отфильтрованные сообщения идентифицируются путем их окраски, а не скрытия. Вы видите сообщения, но можете визуально пропустить их более легко.";
		STFuzzy = "Включает нечеткую фильтрацию, которая захватывает очень похожие повторяющиеся сообщения, такие как отправленные пьяные символами.";
		STGoldSeller = "Включает агрессивную фильтрацию рекламы золота.";
		STChinese = "Фильтрует сообщения, содержащие иероглифы.";
		STCtrlMsgs = "Фильтрует сообщения каналов для удаления спама \"присоединяется к каналу\"/\"покидает канал\".";
		STYellMsgs = "Включает фильтрацию сообщений игроков, кричащих неподалеку.";
		STSayMsgs = "Включает фильтрацию сообщений игроков, говорящих  неподалеку.";
		STWispMsgs = "Включает фильтрацию сообщений игроков, шепчущих вам.";
		STWispBack = "Автоматически отвечает вежливым шепотом обратно игроку, сообщая им, что их сообщение заблокировано. Не будет работать, если присутствует WIM";
		STMultiWisp = "Включает фильтрацию нескольких объединенных сообщений, шепчущий вам один и тот же игрок в течение последних нескольких секунд."; --
		STWispMsgsOFF = "Полностью отключить шепот по команде сервера .wr при запуске"; --
		STReverse = "Изменяет смысл фильтрации SpamThrottle. Будут показаны сообщения, соответствующие ключевому слову, все остальные будут заблокированы.";
		STMinimapButton = "Кнопка включения или выключения мини-карты"; --
		STGap = "Устанавливает минимальный необходимый промежуток между повторяющимися сообщениями. Если для этого игрока с момента отправки последнего сообщения не было достигнуто установленное время, сообщение будет отфильтровано.";
		STBanPerm = "Если включено, запреты игроков остаются на месте, пока вы их не удалите. В противном случае игроки будут удалены автоматически после истечения времени ожидания для них.";
		STBanTimeout = "Игроки будут автоматически удаляться из списка через этот промежуток времени, если постоянный запрет (выше) не установлен.";
	}
	
	SpamThrottleGSC1 = { "%d%s+[Gg]", "%d+%D?%D?%D?%D?%D?[Gg]" };
	SpamThrottleGSC2 = { "%$", "USD", "C[O@]M", "W@W", "G4", ">>", ">>>", "[gG][^%$]*%$", "%$[^gG]*[gG]", "[gG]%D?%D?%D?%D?%d+", "[lL][vV][lL]?%D?%D?%D?%D?%D?%d+" };
	SpamThrottleGSO1 = { "ACCOUNT", "CHEAP", "LEGIT", "LEVELING", "LEVELLING", "LEVLING", "LEVILING", "LEVEL", "IEVEING","LVLING", "SAFE", "ITEM", "SERVICE", "NOST", "SELL", "POTION","POWER", "WOW",  };
	SpamThrottleGSO2 = { "PRICE", "GOLD", "CURRENCY", "MONEY", "STARS", "SKYPE", "EPIC", "DOLLARS", "PROFESSIONAL", "RELIABLE", "PROMOTION", "DELIVER", "NAXX", "GAMES", "GREETINGS", "WEBSITE", "GOID", "CQM" , "MOK", "WEBMO", "MOGS", "NOST", "SAGEBLADE", "LFMDPSCOM","LFMBRDCOM"};
	SpamThrottleGSUC5 = { "ITEM4" }
	SpamThrottleSWLO = { "OKO", "GAMES", "NOST", "COM", "TANK", "WG" , "WMO", "K4WOW", }	
end