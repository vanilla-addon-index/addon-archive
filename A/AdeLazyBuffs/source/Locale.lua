-- AdeLazyBuffs localization. English text is the key; Russian is looked up when the language is ru.
-- Written for the Lua 5.0 client: no '#', no '%', no select(), no string.match.

AdeLazyBuffs = {}
local A = AdeLazyBuffs
A.VERSION = "0.2.0"

function A.Print(msg)
  DEFAULT_CHAT_FRAME:AddMessage("|cff33ff99AdeLazyBuffs|r: " .. msg)
end

local RU = {
  ["Enable AdeLazyBuffs"] = "Включить AdeLazyBuffs",
  ["Cast on my input (out of combat, not in rested areas)"] = "Кастовать при моём действии (вне боя, не в зонах отдыха)",
  ["Show reminder window when a rebuff is due"] = "Показывать окно-напоминание, когда нужен ребафф",
  ["Lock reminder window"] = "Закрепить окно-напоминание",
  ["Show minimap button"] = "Показывать кнопку у миникарты",
  ["Reminder text size: %s"] = "Размер текста напоминания: %s",
  ["Background opacity: %s%%"] = "Непрозрачность фона: %s%%",
  ["Font: %s"] = "Шрифт: %s",
  ["Default font"] = "Стандартный",
  ["Trigger: %s"] = "Действие: %s",
  ["any button"] = "любая кнопка",
  ["mouse wheel"] = "колесо мыши",
  ["own key"] = "своя клавиша",
  ["Key: %s"] = "Клавиша: %s",
  ["Press a key..."] = "Нажмите клавишу...",
  ["Reminder window - drag to move"] = "Окно-напоминание - перетащите",
  ["Rebuff needed:"] = "Нужен ребафф:",
  ["gone"] = "нет",
  ["Click: settings. Drag: move the button."] = "Клик: настройки. Перетаскивание: сдвинуть кнопку.",
  ["Keep my Seal up (also in combat)"] = "Поддерживать печать (и в бою)",
  ["Single-target buffs: rebuff at %s sec left"] = "Одиночные баффы: обновлять при %s с",
  ["Group buffs: rebuff at %s sec left"] = "Групповые баффы: обновлять при %s с",
  ["Language: %s"] = "Язык: %s",
  ["Auto"] = "Авто",
  ["Seal: %s"] = "Печать: %s",
  ["none yet"] = "пока нет",
  ["Remembered targets"] = "Запомненные цели",
  ["Nothing remembered yet. Cast a buff once and it is learned."] = "Пока ничего нет. Один раз скастуйте бафф, и аддон запомнит.",
  ["Forget all"] = "Забыть все",
  ["Close"] = "Закрыть",
  ["Remembered: %s on %s"] = "Запомнено: %s на %s",
  ["Remembered seal: %s"] = "Запомнена печать: %s",
  ["Forgot %s"] = "Забыто: %s",
  ["Nobody called %s is remembered"] = "Цели с именем %s нет в памяти",
  ["Forgot everyone"] = "Все цели забыты",
  ["on"] = "вкл",
  ["off"] = "выкл",
  ["Enabled: %s, auto-cast: %s, seals: %s, timer: %s"] = "Включено: %s, авто-каст: %s, печати: %s, таймер: %s",
  ["Rebuff by timer (off: only when the buff is gone)"] = "Обновлять по таймеру (выкл: только если бафф пропал)",
  ["Commands: /alb (window), on, off, auto on|off, seal on|off, timer on|off, now, size <8-64>, list, why, debug on|off, forget <name>|all, lang auto|en|ru"] = "Команды: /alb (окно), on, off, auto on|off, seal on|off, timer on|off, now, size <8-64>, list, why, debug on|off, forget <имя>|all, lang auto|en|ru",
  ["This class has no buff list yet: AdeLazyBuffs stays idle."] = "Для этого класса пока нет списка баффов: AdeLazyBuffs бездействует.",
  ["Buff now"] = "Баффнуть сейчас",
  ["(Greater)"] = "(великое)",
  ["Nothing remembered."] = "Ничего не запомнено.",
  ["Error: %s"] = "Ошибка: %s",
}

-- db.lang: "en", "ru" or nil (auto: ruRU client = Russian)
function A.Lang()
  local l = AdeLazyBuffsDB and AdeLazyBuffsDB.lang
  if l == "en" or l == "ru" then return l end
  if GetLocale and GetLocale() == "ruRU" then return "ru" end
  return "en"
end

function A.T(s)
  if A.Lang() == "ru" then
    local r = RU[s]
    if r then return r end
  end
  return s
end

function A.TF(s, a, b, c, d)
  return string.format(A.T(s), a, b, c, d)
end

-- Static labels: SetT sets the text now and remembers the object; Relabel re-sets all of them.
A.labels = {}
function A.SetT(obj, key)
  obj:SetText(A.T(key))
  A.labels[obj] = key
end

function A.Relabel()
  local obj, key
  for obj, key in pairs(A.labels) do
    obj:SetText(A.T(key))
  end
  if A.RefreshWindow then A.RefreshWindow() end
end

BINDING_HEADER_ADELAZYBUFFS = "AdeLazyBuffs"
BINDING_NAME_ADELAZYBUFFS_NOW = A.T("Buff now")
