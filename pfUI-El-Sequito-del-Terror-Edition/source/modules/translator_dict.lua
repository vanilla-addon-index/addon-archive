pfUI:RegisterModule("translator_dict", "vanilla", function ()
  -- ╔══════════════════════════════════════════════════════════════╗
  -- ║  LIBRERIA LEXICA OFFLINE v5.0.0 — COLOSSAL-TIER TRILINGUE    ║
  -- ║  Motor Hibrido Hash+Greedy | ES <-> ZH <-> EN              ║
  -- ║  5000+ entradas | 200 categorias | WoW Classic + Chat Real  ║
  -- ╚══════════════════════════════════════════════════════════════╝

  pfUI.translator_dicts = pfUI.translator_dicts or {}
  local DICT_PAIRS = { "es_en", "en_es", "zh_en", "en_zh", "zh_es", "es_zh" }
  for _, p in ipairs(DICT_PAIRS) do
    pfUI.translator_dicts[p .. "_words"]   = pfUI.translator_dicts[p .. "_words"] or {}
    pfUI.translator_dicts[p .. "_phrases"] = pfUI.translator_dicts[p .. "_phrases"] or {}
    pfUI.translator_dicts[p .. "_keys"]    = pfUI.translator_dicts[p .. "_keys"] or {}
  end

  local items = {
    {lang="es", text=""},
    {lang="en", text=""},
    {lang="zh", text=""}
  }

  -- Cuenta caracteres chinos (bytes UTF-8 de 3 bytes en rango 224-239)
  local function CountZhChars(s)
    if not s then return 0 end
    local n, i = 0, 1
    local len = strlen(s)
    while i <= len do
      local b = strbyte(s, i)
      if b and b >= 224 and b <= 239 then n = n + 1; i = i + 3
      elseif b and b >= 192 and b <= 223 then i = i + 2
      else i = i + 1 end
    end
    return n
  end

  local function add(es, en, zh)
    items[1].text = es
    items[2].text = en
    items[3].text = zh
    for i = 1, 3 do
      local item_i = items[i]
      local src_lang = item_i.lang
      local src_text = item_i.text
      if src_text and src_text ~= "" then
        if true then
          for j = 1, 3 do
            if i ~= j then
              local item_j = items[j]
              local dest_lang = item_j.lang
              local dest_text = item_j.text
              if dest_text and dest_text ~= "" then
                local isPhrase = strfind(src_text, " ") or strfind(dest_text, " ") or strlen(src_text) > 12 or src_lang == "zh"
                local prefix = src_lang .. "_" .. dest_lang
                local key = src_text
                if src_lang ~= "zh" then
                  key = string.lower(src_text)
                end
                if isPhrase then
                  if not pfUI.translator_dicts[prefix .. "_phrases"][key] then
                    pfUI.translator_dicts[prefix .. "_phrases"][key] = dest_text
                    table.insert(pfUI.translator_dicts[prefix .. "_keys"], key)
                  end
                else
                  pfUI.translator_dicts[prefix .. "_words"][key] = dest_text
                end
              end
            end
          end
        end
      end
    end
  end

  -- ╔══════════════════════════════════════════════╗
  -- ║  CAT 01: ABREVIATURAS DE CHAT Y SLANG        ║
  -- ╚══════════════════════════════════════════════╝
  add("afk",                                    "fuera del teclado",                  "暂离")
  add("brb",                                    "vuelvo enseguida",                   "马上回来")
  add("omw",                                    "en camino",                          "在路上了")
  add("lfg",                                    "busco grupo",                        "求组")
  add("lfm",                                    "busco mas",                          "招人")
  add("pst",                                    "susurro",                            "私聊")
  add("gg",                                     "buen juego",                         "打得好")
  add("gn",                                     "buenas noches",                      "晚安")
  add("gl",                                     "buena suerte",                       "祝你好运")
  add("hf",                                     "que se diviertan",                   "玩得开心")
  add("ty",                                     "gracias",                            "谢谢")
  add("yw",                                     "de nada",                            "不客气")
  add("nvm",                                    "no importa",                         "算了")
  add("idk",                                    "no se",                              "不知道")
  add("jk",                                     "es broma",                           "开玩笑")
  add("imo",                                    "en mi opinion",                      "个人觉得")
  add("imho",                                   "en mi humilde opinion",              "个人愚见")
  add("tbh",                                    "siendo honesto",                     "老实说")
  add("ngl",                                    "siendo real",                        "老实说")
  add("lmao",                                   "muerto de risa",                     "笑死我了")
  add("lol",                                    "jajaja",                             "哈哈哈")
  add("rofl",                                   "revolcandome de risa",               "笑趴了")
  add("smh",                                    "meneando cabeza",                    "摇头")
  add("gg ez",                                  "buen juego facil",                   "轻松拿下")
  add("rip",                                    "descanse en paz",                    "愿安息")
  add("dw",                                     "no te preocupes",                    "别担心")
  add("np",                                     "no hay problema",                    "没问题")
  add("wb",                                     "bienvenido de vuelta",               "欢迎回来")
  add("cya",                                    "nos vemos",                          "再见")
  add("gtg",                                    "tengo que irme",                     "得走了")
  add("bbl",                                    "vuelvo luego",                       "一会见")
  add("irl",                                    "en la vida real",                    "现实生活中")
  add("atm",                                    "en este momento",                    "目前")
  add("fyi",                                    "para tu informacion",                "顺便提一下")
  add("asap",                                   "lo antes posible",                   "尽快")
  add("ez",                                     "facil",                              "简单")
  add("nt",                                     "buen intento",                       "尽力了")
  add("wp",                                     "bien jugado",                        "打得好")
  add("glhf",                                   "buena suerte y que se diviertan",    "祝你好运，玩得开心")

  -- ╔══════════════════════════════════════════════╗
  -- ║  CAT 02: HSK & ESTRUCTURA DE CONVERSACION    ║
  -- ╚══════════════════════════════════════════════╝
  -- Pronombres y básicos
  add("yo",                                     "I",                                  "我")
  add("tú",                                     "you",                                "你")
  add("él",                                     "he",                                 "他")
  add("ella",                                   "she",                                "她")
  add("nosotros",                               "we",                                 "我们")
  add("ustedes",                                "you",                                "你们")
  add("ellos",                                  "they",                               "他们")
  add("mi",                                     "my",                                 "我的")
  add("tu",                                     "your",                               "你的")
  add("de",                                     "of",                                 "的")
  add("un",                                     "a",                                  "一个")
  add("este",                                   "this",                               "这个")
  add("ese",                                    "that",                               "那个")
  add("aquí",                                   "here",                               "这里")
  add("allí",                                   "there",                              "那里")
  add("quién",                                  "who",                                "谁")
  add("qué",                                    "what",                               "什么")
  add("dónde",                                  "where",                              "哪里")
  add("cuándo",                                 "when",                               "什么时候")
  add("cómo",                                   "how",                                "怎么")
  add("por qué",                                "why",                                "为什么")
  
  -- Verbos frecuentes
  add("tener",                                  "have",                               "有")
  add("no tener",                               "not have",                           "没有")
  add("hacer",                                  "do",                                 "做")
  add("ir",                                     "go",                                 "去")
  add("venir",                                  "come",                               "来")
  add("ver",                                    "see",                                "看")
  add("querer",                                 "want",                               "想")
  add("necesitar",                              "need",                               "要")
  add("poder",                                  "can",                                "能")
  add("saber",                                  "know",                               "知道")
  add("comprar",                                "buy",                                "买")
  add("vender",                                 "sell",                               "卖")
  add("matar",                                  "kill",                               "杀")
  add("jugar",                                  "play",                               "玩")
  add("comer",                                  "eat",                                "吃")
  add("beber",                                  "drink",                              "喝")
  add("esperar",                                "wait",                               "等")
  add("dar",                                    "give",                               "给")
  add("buscar",                                 "find",                               "找")

  -- Tiempo
  add("ahora",                                  "now",                                "现在")
  add("hoy",                                    "today",                              "今天")
  add("mañana",                                 "tomorrow",                           "明天")
  add("ayer",                                   "yesterday",                          "昨天")
  add("luego",                                  "later",                              "后来")
  add("tiempo",                                 "time",                               "时间")

  -- Adjetivos y Adverbios
  add("muy",                                    "very",                               "很")
  add("mucho",                                  "much",                               "多")
  add("poco",                                   "little",                             "少")
  add("bueno",                                  "good",                               "好")
  add("malo",                                   "bad",                                "坏")
  add("grande",                                 "big",                                "大")
  add("pequeño",                                "small",                              "小")
  add("rápido",                                 "fast",                               "快")
  add("lento",                                  "slow",                               "慢")
  add("difícil",                                "hard",                               "难")
  add("fácil",                                  "easy",                               "容易")
  add("caro",                                   "expensive",                          "贵")
  add("barato",                                 "cheap",                              "便宜")
  add("todo",                                   "all",                                "都")
  add("también",                                "also",                               "也")
  add("todavía",                                "still",                              "还")
  add("solo",                                   "only",                               "只")
  add("ya",                                     "already",                            "已经")

  -- Conectores y partículas
  add("y",                                      "and",                                "和")
  add("o",                                      "or",                                 "或")
  add("pero",                                   "but",                                "但是")
  add("porque",                                 "because",                            "因为")
  add("entonces",                               "then",                               "那么")
  add("con",                                    "with",                               "跟")
  add("en",                                     "at",                                 "在")

  -- Slang de Chat MMO Adicional (Incluyendo los detectados por usuario)
  add("por qué",                                "why",                                "为啥")
  add("cerrado",                                "closed",                             "关了")
  add("cerrar",                                 "close",                              "关闭")
  add("por lo tanto",                           "so",                                 "所以")
  add("extranjero",                             "foreigner",                          "老外")
  add("extranjero",                             "foreigner",                          "外国人")
  add("no usar",                                "no need",                            "不用")
  add("booster",                                "VPN",                                "加速器")
  add("normal",                                 "normal",                             "正常")
  add("soy",                                    "I am",                               "我是")
  add("págame 50",                              "v me 50",                            "V我50")
  add("obviamente",                             "obviously",                          "显然")
  add("se necesita",                            "needs",                              "需要")
  
  add("jefe",                                   "boss",                               "老一")
  add("oro",                                    "gold",                               "金")
  add("precio",                                 "price",                              "价")
  add("puntos",                                 "points",                             "点")
  add("nivel",                                  "level",                              "级")
  add("hermandad",                              "guild",                              "公会")
  add("equipo",                                 "gear",                               "装备")
  add("buscar",                                 "LF",                                 "求")
  add("misión",                                 "quest",                              "任务")
  add("terminado",                              "done",                               "完成")
  add("no",                                     "no",                                 "不")
  add("ok",                                     "ok",                                 "行")
  add("vamos",                                  "go",                                 "走")
  add("ayuda",                                  "help",                               "帮")
  add("gracias",                                "thanks",                             "多谢")

  -- ╔══════════════════════════════════════════════╗
  -- ║  CAT 02.5: VOCABULARIO HSK3/HSK4 Y MMO AVANZADO║
  -- ╚══════════════════════════════════════════════╝
  -- Frecuencias de tiempo y estado
  add("siempre",                                "always",                             "总是")
  add("nunca",                                  "never",                              "从不")
  add("a veces",                                "sometimes",                          "有时")
  add("antes",                                  "before",                             "以前")
  add("después",                                "after",                              "以后")
  add("pronto",                                 "soon",                               "马上")
  add("tarde",                                  "late",                               "晚")
  add("temprano",                               "early",                              "早")
  add("otra vez",                               "again",                              "再")
  add("justo ahora",                            "just now",                           "刚才")
  
  -- Conversación general
  add("hola",                                   "hello",                              "你好")
  add("adiós",                                  "bye",                                "再见")
  add("sí",                                     "yes",                                "对")
  add("no",                                     "not",                                "不是")
  add("claro",                                  "sure",                               "当然")
  add("por supuesto",                           "of course",                          "当然")
  add("tal vez",                                "maybe",                              "可能")
  add("problema",                               "problem",                            "问题")
  add("pregunta",                               "question",                           "问题")
  add("verdad",                                 "truth",                              "真的")
  add("falso",                                  "false",                              "假的")
  add("amigo",                                  "friend",                             "朋友")
  add("enemigo",                                "enemy",                              "敌人")
  add("gente",                                  "people",                             "人")
  add("mundo",                                  "world",                              "世界")
  add("juego",                                  "game",                               "游戏")
  add("nombre",                                 "name",                               "名字")
  
  -- Acciones y Verbos HSK3+
  add("entender",                               "understand",                         "明白")
  add("pensar",                                 "think",                              "觉得")
  add("creer",                                  "believe",                            "相信")
  add("sentir",                                 "feel",                               "感觉")
  add("hablar",                                 "speak",                              "说")
  add("escuchar",                               "listen",                             "听")
  add("escribir",                               "write",                              "写")
  add("leer",                                   "read",                               "读")
  add("empezar",                                "start",                              "开始")
  add("terminar",                               "finish",                             "结束")
  add("continuar",                              "continue",                           "继续")
  add("dejar",                                  "leave",                              "离开")
  add("volver",                                 "return",                             "回来")
  add("olvidar",                                "forget",                             "忘记")
  add("recordar",                               "remember",                           "记得")
  add("morir",                                  "die",                                "死")
  add("vivir",                                  "live",                               "活")
  add("ayudar",                                 "help",                               "帮忙")
  add("usar",                                   "use",                                "用")
  add("cambiar",                                "change",                             "换")
  add("enviar",                                 "send",                               "发")
  add("recibir",                                "receive",                            "收")
  add("perder",                                 "lose",                               "输")
  add("ganar",                                  "win",                                "赢")
  
  -- Adjetivos complejos
  add("importante",                             "important",                          "重要")
  add("diferente",                              "different",                          "不同")
  add("mismo",                                  "same",                               "一样")
  add("nuevo",                                  "new",                                "新")
  add("viejo",                                  "old",                                "老")
  add("feliz",                                  "happy",                              "快乐")
  add("triste",                                 "sad",                                "难过")
  add("fuerte",                                 "strong",                             "强")
  add("débil",                                  "weak",                               "弱")
  add("alto",                                   "high",                               "高")
  add("bajo",                                   "low",                                "低")
  add("seguro",                                 "safe",                               "安全")
  add("peligroso",                              "dangerous",                          "危险")
  
  -- Más vocabulario técnico MMO Vanilla
  add("servidor",                               "server",                             "服务器")
  add("cliente",                                "client",                             "客户端")
  add("lag",                                    "lag",                                "卡")
  add("desconexión",                            "dc",                                 "掉线")
  add("subasta",                                "ah",                                 "拍卖行")
  add("buzón",                                  "mail",                               "邮箱")
  add("banco",                                  "bank",                               "银行")
  add("bolsa",                                  "bag",                                "包")
  add("montura",                                "mount",                              "坐骑")
  add("experiencia",                            "exp",                                "经验")
  add("habilidad",                              "skill",                              "技能")
  add("talento",                                "talent",                             "天赋")
  add("profesión",                              "profession",                         "专业")
  add("daño",                                   "damage",                             "伤害")
  add("curación",                               "healing",                            "治疗量")
  add("agro",                                   "aggro",                              "仇恨")
  add("loot",                                   "loot",                               "战利品")
  add("dados",                                  "roll",                               "需求")
  add("pasar",                                  "pass",                               "贪婪")
  add("invocar",                                "summon",                             "拉")
  add("revivir",                                "res",                                "复活")
  add("comida",                                 "food",                               "吃喝")
  add("agua",                                   "water",                              "水")
  add("buf",                                    "buff",                               "BUFF")
  
  -- Palabras de cierre y estructura
  add("entendido",                              "roger",                              "收到")
  add("espera un momento",                      "wait a moment",                      "等一下")
  add("no importa",                             "nevermind",                          "没关系")
  add("sin problema",                           "no problem",                         "没事")
  add("qué pasa",                               "whats up",                           "怎么了")
  add("dónde estás",                            "where are you",                      "你在哪")
  add("ven aquí",                               "come here",                          "过来")
  add("vamos",                                  "lets go",                            "走吧")



  add("busco grupo",                            "lfg",                                "求组")
  add("buscando grupo",                         "lfg",                                "求组")
  add("busco mas gente",                        "lfm",                                "来人")
  add("busco un mas",                           "lfm",                                "来人")
  add("busco healer",                           "lf healer",                          "求组治疗")
  add("busco tanque",                           "lf tank",                            "求组坦克")
  add("busco dps",                              "lf dps",                             "求组输出")
  add("busco druida",                           "lf druid",                           "求组德鲁伊")
  add("busco sacerdote",                        "lf priest",                          "求组牧师")
  add("busco chamán",                           "lf shaman",                          "求组萨满")
  add("busco paladín",                          "lf paladin",                         "求组圣骑士")
  add("busco mago",                             "lf mage",                            "求组法师")
  add("busco brujo",                            "lf warlock",                         "求组术士")
  add("busco guerrero",                         "lf warrior",                         "求组战士")
  add("busco pícaro",                           "lf rogue",                           "求组盗贼")
  add("busco cazador",                          "lf hunter",                          "求组猎人")
  add("mandame susurro",                        "pst me",                             "私聊")
  add("dame susurro",                           "pst me",                             "私聊")
  add("susurrame",                              "pst me",                             "私聊")
  add("invitame",                               "inv me",                             "求邀请")
  add("invítame",                               "inv me",                             "求邀请")
  add("dame inv",                               "inv me",                             "求邀请")
  add("vuelvo enseguida",                       "brb",                                "马上回来")
  add("ya vengo",                               "brb",                                "马上回来")
  add("regresé",                                "back",                               "我回来了")
  add("estoy de vuelta",                        "back",                               "我回来了")
  add("fuera del teclado",                      "afk",                                "暂离")
  add("en camino",                              "omw",                                "在路上了")
  add("voy para allá",                          "omw",                                "在路上了")
  add("muchas gracias",                         "ty vm",                              "非常感谢")
  add("mil gracias",                            "tyvm",                               "万分感谢")
  add("de nada",                                "yw",                                 "不客气")
  add("no importa",                             "nvm",                                "算了")
  add("no te preocupes",                        "dw",                                 "别担心")
  add("lo siento",                              "sry",                                "抱歉")
  add("perdón",                                 "sry",                                "抱歉")
  add("perdon",                                 "sry",                                "抱歉")
  add("fallo mío",                              "my bad",                             "我的错")
  add("es mi culpa",                            "my bad",                             "我的错")
  add("lo siento es mi culpa",                  "my bad sry",                         "抱歉，我的错")
  add("buenas",                                 "hi",                                 "你好")
  add("hola a todos",                           "hi all",                             "大家好")
  add("nos vemos",                              "cya",                                "再见")
  add("buen juego",                             "gg",                                 "打得好")
  add("buenas noches",                          "gn",                                 "晚安")
  add("buena suerte",                           "gl",                                 "祝你好运")
  add("diviértanse",                            "hf",                                 "玩得开心")
  add("no lo se",                               "idk",                                "不知道")
  add("no lo sé",                               "idk",                                "不知道")
  add("no tengo idea",                          "idk",                                "不知道")
  add("es broma",                               "jk",                                 "开玩笑")
  add("es una broma",                           "just kidding",                       "开玩笑")
  add("por supuesto",                           "of course",                          "当然")
  add("claro que si",                           "sure",                               "好的")
  add("tal vez",                                "maybe",                              "也许")
  add("quizás",                                 "perhaps",                            "也许")
  add("quizas",                                 "perhaps",                            "也许")
  add("entiendo",                               "i see",                              "我懂了")
  add("me parece bien",                         "sounds good",                        "听起来不错")
  add("estoy de acuerdo",                       "i agree",                            "同意")
  add("de acuerdo",                             "agreed",                             "同意")
  add("ya sabes",                               "ya know",                            "你懂的")
  add("todo bien",                              "all good",                           "都好")
  add("esposo",                                 "hubby",                              "老公")
  add("marido",                                 "hubby",                              "老公")
  add("de vez en cuando",                       "from time to time",                  "偶尔")
  add("fue un placer",                          "it was a pleasure",                  "很荣幸")
  add("fue un placer jugar",                    "nice playing with you",              "合作愉快")
  add("mañana nos vemos",                       "see you tomorrow",                   "明天见")
  add("estoy cansado",                          "i am tired",                         "我累了")
  add("tengo que irme",                         "i have to go",                       "得走了")
  add("mi mama me llama",                       "mom calls me",                       "妈妈叫我")
  add("mi esposa me llama",                     "wife calls me",                      "老婆叫我")
  add("igualmente",                             "same to you",                        "你也一样")
  add("supongo que no",                         "i guess not",                        "我觉得不是")
  add("tengo lag",                              "i have lag",                         "我卡了")
  add("mi internet está mal",                   "my internet is bad",                 "我网络不行")
  add("esperen un momento",                     "wait a sec",                         "等一下")
  add("quién sabe",                             "who knows",                          "谁知道呢")
  add("alguien más",                            "anyone else",                        "还有人吗")

  -- ╔══════════════════════════════════════════════╗
  -- ║  CAT 02: MAZMORRAS — NAMES & ACRONYMS        ║
  -- ╚══════════════════════════════════════════════╝
  add("minas de la muerte",                     "deadmines",                          "死亡矿井")
  add("las minas",                              "deadmines",                          "死亡矿井")
  add("cavernas de los lamentos",               "wailing caverns",                    "哀嚎洞穴")
  add("cavernas de lamentos",                   "wailing caverns",                    "哀嚎洞穴")
  add("guarida de la losa negra",               "blackfathom deeps",                  "黑暗深渊")
  add("gnomeregan",                             "gnomeregan",                         "诺莫瑞根")
  add("guarida gnomeregan",                     "gnome",                              "诺莫瑞根")
  add("sima ígnea",                             "ragefire chasm",                     "怒焰裂谷")
  add("sima ignea",                             "rfc",                                "怒焰")
  add("sima ignea",                             "rfc",                                "怒焰裂谷")
  add("castillo colmillo oscuro",               "shadowfang keep",                    "影牙城堡")
  add("colmillo oscuro",                        "sfk",                                "影牙城堡")
  add("monasterio escarlata",                   "scarlet monastery",                  "血色修道院")
  add("biblioteca escarlata",                   "sm lib",                             "血色图书馆")
  add("armería escarlata",                      "sm arm",                             "血色军械库")
  add("catedral escarlata",                     "sm cath",                            "血色大教堂")
  add("cementerio escarlata",                   "sm gy",                              "血色墓地")
  add("profundidades de rocanegra",             "blackrock depths",                   "黑石深渊")
  add("brd",                                    "profundidades de rocanegra",         "黑石深渊")
  add("cumbre superior de rocanegra",           "upper blackrock spire",              "黑石塔上层")
  add("cumbre inferior de rocanegra",           "lower blackrock spire",              "黑石塔下层")
  add("ubrs",                                   "cumbre superior",                    "黑石塔上层")
  add("lbrs",                                   "cumbre inferior",                    "黑石塔下层")
  add("zul'farrak",                             "zul'farrak",                         "祖尔法拉克")
  add("maraudon",                               "maraudon",                           "玛拉顿")
  add("templo sumergido",                       "sunken temple",                      "沉没的神庙")
  add("masacre de diremaul norte",              "dire maul north",                    "厄运之槌北")
  add("masacre de diremaul este",               "dire maul east",                     "厄运之槌东")
  add("masacre de diremaul oeste",              "dire maul west",                     "厄运之槌西")
  add("diremaul",                               "dire maul",                          "厄运之槌")
  add("masacre norte",                          "dm north",                           "厄运之槌北")
  add("masacre este",                           "dm east",                            "厄运之槌东")
  add("masacre oeste",                          "dm west",                            "厄运之槌西")
  add("razas cenizas",                          "razorfen kraul",                     "剃刀沼泽")
  add("razorfen kraul",                         "razas cenizas",                      "剃刀沼泽")
  add("aguijón de razorfen",                    "razorfen downs",                     "剃刀高地")
  add("razorfen downs",                         "aguijon de razorfen",                "剃刀高地")
  add("uldaman",                                "uldaman",                            "奥达曼")
  add("zul'gurub",                              "zul'gurub",                          "祖尔格拉布")
  add("scholomance",                            "scholomance",                        "通灵学院")
  add("estratolme",                             "stratholme",                         "斯坦索姆")
  add("strat",                                  "estratolme",                         "斯坦索姆")
  add("scholo",                                 "scholomance",                        "通灵学院")
  add("estrato vivo",                           "strat live",                         "斯坦索姆前门")
  add("estrato muerto",                         "strat ud",                           "斯坦索姆后门")

  -- ╔══════════════════════════════════════════════╗
  -- ║  CAT 03: RAIDS — NAMES & ACRONYMS            ║
  -- ╚══════════════════════════════════════════════╝
  add("núcleo de magma",                        "molten core",                        "熔火之心")
  add("nucleo de magma",                        "molten core",                        "熔火之心")
  add("mc",                                     "molten core",                        "熔火之心")
  add("guarida alanegra",                       "blackwing lair",                     "黑翼之巢")
  add("bwl",                                    "blackwing lair",                     "黑翼之巢")
  add("guarida de onyxia",                      "onyxia's lair",                      "奥妮克希亚的巢穴")
  add("guarida de onixia",                      "onyxia's lair",                      "奥妮克希亚的巢穴")
  add("ony",                                    "onyxia",                             "奥妮克希亚")
  add("naxxramas",                              "naxxramas",                          "纳克萨玛斯")
  add("naxx",                                   "naxxramas",                          "纳克萨玛斯")
  add("ruinas de ahn'qiraj",                    "ruins of ahn'qiraj",                 "安其拉废墟")
  add("templo de ahn'qiraj",                    "temple of ahn'qiraj",                "安其拉神殿")
  add("aq20",                                   "aq 20",                              "安其拉废墟")
  add("aq40",                                   "aq 40",                              "安其拉神殿")
  add("zul'aman",                               "zul'aman",                           "祖阿曼")
  add("santuario esmeralda",                    "emerald sanctum",                    "翡翠圣殿")
  add("karazhan",                               "karazhan",                           "卡拉赞")
  add("karazhan inferior",                      "lower karazhan",                     "卡拉赞")
  add("kara",                                   "karazhan",                           "卡拉赞")
  add("cavernas del tiempo",                    "caverns of time",                    "时光之穴")
  add("pantano de las penas",                   "black morass",                       "悲伤沼泽")
  add("isla de lapidis",                        "lapidis isle",                       "拉皮迪斯岛")
  add("isla de gillijim",                       "gillijim's isle",                    "吉利吉姆岛")
  add("hiraeth",                                "hiraeth keep",                       "海勒斯堡")
  add("isla de tel'abim",                       "tel'abim isle",                      "泰拉比姆岛")

  -- ╔══════════════════════════════════════════════╗
  -- ║  CAT 04: JEFES VANILLA (Boss Names ES/EN)    ║
  -- ╚══════════════════════════════════════════════╝
  -- MC Bosses
  add("lucifron",                               "lucifron",                           "鲁西弗隆")
  add("magmadar",                               "magmadar",                           "玛格曼达")
  add("gehennas",                               "gehennas",                           "基赫纳斯")
  add("garr",                                   "garr",                               "加尔")
  add("baron geddon",                           "baron geddon",                       "迦顿男爵")
  add("geddon",                                 "geddon",                             "迦顿男爵")
  add("shazzrah",                               "shazzrah",                           "沙斯拉尔")
  add("sulfuron portador",                      "sulfuron harbinger",                 "萨尔弗隆先驱者")
  add("golemagg el incinerador",                "golemagg the incinerator",           "焚化者古雷曼格")
  add("golemagg",                               "golemagg",                           "焚化者古雷曼格")
  add("majordomo ejecutus",                     "majordomo executus",                 "管理者埃克索图斯")
  add("majordomo",                              "majordomo",                          "管理者埃克索图斯")
  add("ragnaros",                               "ragnaros",                           "拉格纳罗斯")
  add("el señor del fuego",                     "the firelord",                       "拉格纳罗斯")
  -- BWL Bosses
  add("razorgore el intacto",                   "razorgore the untamed",              "狂野的拉佐格尔")
  add("razorgore",                              "razorgore",                          "狂野的拉佐格尔")
  add("vaelastrasz el corrupto",                "vaelastrasz the corrupt",            "堕落的瓦拉斯塔兹")
  add("vael",                                   "vaelastrasz",                        "堕落的瓦拉斯塔兹")
  add("lashlayer braxiss",                      "broodlord lashlayer",                "勒什雷尔")
  add("broodlord",                              "broodlord",                          "勒什雷尔")
  add("firemaw",                                "firemaw",                            "费尔默")
  add("ebonroc",                                "ebonroc",                            "埃博诺克")
  add("flamegor",                               "flamegor",                           "弗莱格尔")
  add("chromaggus",                             "chromaggus",                         "克洛玛古斯")
  add("nefarian",                               "nefarian",                           "奈法利安")
  -- ZG Bosses
  add("venoxis el sacerdote serpiente",         "high priest venoxis",                "高阶祭司温诺希斯")
  add("venoxis",                                "venoxis",                            "高阶祭司温诺希斯")
  add("jeklik la sacerdotisa",                  "high priestess jeklik",              "高阶祭司耶克里克")
  add("jeklik",                                 "jeklik",                             "高阶祭司耶克里克")
  add("mar'li la sacerdotisa",                  "high priestess mar'li",              "高阶祭司玛尔里")
  add("marli",                                  "mar'li",                             "高阶祭司玛尔里")
  add("thekal el sacerdote",                    "high priest thekal",                 "高阶祭司塞卡尔")
  add("thekal",                                 "thekal",                             "高阶祭司塞卡尔")
  add("arlokk la sacerdotisa",                  "high priestess arlokk",              "高阶祭司阿罗克")
  add("arlokk",                                 "arlokk",                             "高阶祭司阿罗克")
  add("jindo el sacerdote oscuro",              "jin'do the hexxer",                  "妖术师金度")
  add("jindo",                                  "jin'do",                             "妖术师金度")
  add("hakkar el alma tortuosa",                "hakkar the soulflayer",              "哈卡")
  add("hakkar",                                 "hakkar",                             "哈卡")
  -- AQ40 Bosses
  add("el profeta skeram",                      "the prophet skeram",                 "预言者斯克拉姆")
  add("skeram",                                 "skeram",                             "预言者斯克拉姆")
  add("reyes bug",                              "the bug trio",                       "虫子三巨头")
  add("los tres reyes",                         "the twin emperors",                  "双子皇帝")
  add("vek'lor",                                "vek'lor",                            "维克洛尔")
  add("vek'nilash",                             "vek'nilash",                         "维克尼拉斯")
  add("emperadores gemelos",                    "twin emperors",                      "双子皇帝")
  add("c'thun",                                 "c'thun",                             "克苏恩")
  add("el ojo de c'thun",                       "the eye of c'thun",                  "克苏恩")
  -- Naxx Bosses
  add("anub'rekhan",                            "anub'rekhan",                        "阿努布雷坎")
  add("la gran viuda faerlina",                 "grand widow faerlina",               "黑女巫法琳娜")
  add("maexxna",                                "maexxna",                            "迈克斯纳")
  add("noth el empestador",                     "noth the plaguebringer",             "瘟疫使者诺斯")
  add("noth",                                   "noth",                               "瘟疫使者诺斯")
  add("heigan el impuro",                       "heigan the unclean",                 "脏鬼希根")
  add("heigan",                                 "heigan",                             "脏鬼希根")
  add("loatheb",                                "loatheb",                            "洛欧塞布")
  add("instructor razuvious",                   "instructor razuvious",               "教官拉苏维奥斯")
  add("gothik el segador",                      "gothik the harvester",               "收割者戈提克")
  add("gothik",                                 "gothik",                             "收割者戈提克")
  add("los cuatro jinetes",                     "the four horsemen",                  "天启四骑士")
  add("patchwerk",                              "patchwerk",                          "帕奇维克")
  add("grobbulus",                              "grobbulus",                          "格罗布鲁斯")
  add("gluth",                                  "gluth",                              "格鲁斯")
  add("thaddius",                               "thaddius",                           "塔迪乌斯")
  add("sapphiron",                              "sapphiron",                          "萨菲隆")
  add("kel'thuzad",                             "kel'thuzad",                         "克尔苏加德")
  add("kel thuzad",                             "kel'thuzad",                         "克尔苏加德")

  -- ╔══════════════════════════════════════════════╗
  -- ║  CAT 05: TÁCTICAS Y COMBATE                  ║
  -- ╚══════════════════════════════════════════════╝
  add("ataca mi objetivo",                      "attack my target",                   "攻击我的目标")
  add("enfoca mi objetivo",                     "focus my target",                    "打我的目标")
  add("ataquen mi target",                      "focus my target",                    "打我的目标")
  add("no ataquen",                             "don't attack",                       "停手")
  add("paren el daño",                          "stop dps",                           "停手")
  add("daño suave",                             "slow dps",                           "控制输出")
  add("máximo daño",                            "full dps",                           "全力输出")
  add("explosión de daño",                      "burn phase",                         "全力输出打爆发")
  add("fase de quema",                          "burn phase",                         "全力输出打爆发")
  add("esperen el pull",                        "wait for pull",                      "等拉怪")
  add("cuidado con el agro",                    "watch your aggro",                   "注意仇恨")
  add("tengo el agro",                          "i have aggro",                       "我OT了")
  add("perdí el agro",                          "lost aggro",                         "仇恨丢了")
  add("perdi el agro",                          "lost aggro",                         "仇恨丢了")
  add("el tanque murió",                        "tank is dead",                       "倒T了")
  add("necesito sanación",                      "need heals",                         "求奶")
  add("cura por favor",                         "heal plx",                           "求奶")
  add("dame buff",                              "buff me",                            "求buff")
  add("buffs por favor",                        "buffs plz",                          "求buff")
  add("buffeame",                               "buff me",                            "求buff")
  add("estamos listos",                         "we are ready",                       "准备好了")
  add("fuera del fuego",                        "out of the fire",                    "别踩火")
  add("sal del fuego",                          "get out of fire",                    "别踩火")
  add("sal del area",                           "get out of the aoe",                 "躲开AOE")
  add("no se muevan",                           "don't move",                         "别动")
  add("quédense quietos",                       "stand still",                        "别动")
  add("muévanse ahora",                         "move now",                           "快动")
  add("aléjense",                               "spread out",                         "分散站位")
  add("júntense",                               "stack up",                           "集合重合")
  add("agruparse",                              "group up",                           "集合重合")
  add("peguenle al boss",                       "nuke the boss",                      "全力RUSH BOSS")
  add("maten a los adds",                       "kill the adds",                      "清小怪")
  add("maten al add",                           "kill the add",                       "打小怪")
  add("limpien los adds",                       "clear the adds",                     "清小怪")
  add("control de masas",                       "crowd control",                      "控制怪")
  add("usa la oveja",                           "sheep it",                           "变羊")
  add("oveja al objetivo",                      "sheep the target",                   "变羊")
  add("poner oveja",                            "sheeping",                           "变羊")
  add("usa la trampa",                          "set the trap",                       "放陷阱")
  add("pon trampa de hielo",                    "place frost trap",                   "放冰冻陷阱")
  add("usa sap",                                "sap it",                             "闷棍")
  add("usa miedo",                              "fear it",                            "恐惧")
  add("usa shackle",                            "shackle it",                         "束缚亡灵")
  add("shackle al muerto",                      "shackle the undead",                 "束缚亡灵")
  add("hibernar a la bestia",                   "hibernate the beast",                "休眠")
  add("usa ciclón",                             "cyclone it",                         "吹风")
  add("usa seduce",                             "seduce it",                          "魅惑")
  add("usa banish",                             "banish it",                          "放逐")
  add("detrás del boss",                        "get behind the boss",                "找背攻击")
  add("posición detrás",                        "get behind",                         "找背攻击")
  add("línea de visión",                        "line of sight",                      "卡视角拉怪")
  add("fuera de los",                           "out of los",                         "卡视角")
  add("sin línea de visión",                    "no line of sight",                   "无视角")
  add("escóndanse",                             "take cover",                         "躲避")
  add("corran fuera",                           "run out",                            "跑出去")
  add("hacia atrás",                            "back off",                           "退后")
  add("retroceden",                             "fall back",                          "撤退")
  add("reinicien",                              "reset",                              "拉脱脱战")
  add("empezamos de nuevo",                     "reset and try again",                "拉脱脱战重开")
  add("wipe",                                   "nos morimos todos",                  "灭")
  add("hagan wipe",                             "wipe it",                            "灭")
  add("hacemos wipe",                           "let's wipe",                         "灭")
  add("primer intento",                         "first attempt",                      "第一次尝试")
  add("segundo intento",                        "second attempt",                     "第二次尝试")
  add("tercer intento",                         "third attempt",                      "第三次尝试")
  add("fase 1",                                 "phase 1",                            "第一阶段")
  add("fase 2",                                 "phase 2",                            "第二阶段")
  add("fase 3",                                 "phase 3",                            "第三阶段")
  add("fase 4",                                 "phase 4",                            "第四阶段")
  add("quédense ahí",                           "stay there",                         "待在那")
  add("vengan aquí",                            "come here",                          "过来")
  add("vénganse con el tanque",                 "come to the tank",                   "靠近坦克")
  add("síganme",                                "follow me",                          "跟我来")
  add("pareen",                                 "hold on",                            "稍等")
  add("esperen",                                "hold on",                            "稍等")
  add("aguanten",                               "hold your position",                 "坚守阵地")
  add("no entren todavía",                      "don't go in yet",                    "先别进去")
  add("lista de objetivos",                     "kill order",                         "击杀顺序")
  add("orden de muerte",                        "kill order",                         "击杀顺序")
  add("foco en el calavera",                    "focus skull",                        "打骷髅")
  add("maten la calavera",                      "kill skull",                         "击杀骷髅")
  add("foco en la equis",                       "focus cross",                        "打大叉")
  add("trampa a la luna",                       "trap moon",                          "冰月亮")
  add("oveja al cuadrado",                      "sheep square",                       "羊方块")
  add("sap al triángulo",                       "sap triangle",                       "闷三角")
  add("bandage",                                "venda",                              "绷带")
  add("venda",                                  "bandage",                            "绷带")
  add("curación de emergencia",                 "emergency heal",                     "紧急治疗")
  add("intervención de guerra",                 "intercept",                          "拦截")
  add("carga",                                  "charge",                             "冲锋")
  add("provocar",                               "taunt",                              "嘲讽")
  add("mockery",                                "taunt",                              "嘲讽")
  add("provokar",                               "taunt",                              "嘲讽")
  add("interrumpir",                            "interrupt",                          "打断")
  add("interrumpan el casteo",                  "interrupt the cast",                 "打断施法")
  add("silencio al healer",                     "silence the healer",                 "沉默治疗")
  add("nido de agro",                           "aggro dump",                         "消仇恨")
  add("resistió",                               "resisted",                           "抵抗")
  add("esquivó",                                "dodged",                             "躲闪")
  add("paró",                                   "parried",                            "招架")
  add("bloqueó",                                "blocked",                            "格挡")
  add("inmunidad",                              "immune",                             "免疫")
  add("aturdido",                               "stunned",                            "被晕")
  add("dormido",                                "sapped",                             "被闷")
  add("enraizado",                              "rooted",                             "被缠绕")
  add("congelado",                              "frozen",                             "被冰冻")
  add("encadenado",                             "shackled",                           "被束缚")
  add("desafiado",                              "taunted",                            "被嘲讽")
  add("maldecido",                              "cursed",                             "被诅咒")
  add("envenenado",                             "poisoned",                           "中毒")
  add("enfermedad",                             "disease",                            "疾病")
  add("maldición",                              "curse",                              "诅咒")
  add("disipar la maldición",                   "remove curse",                       "解除诅咒")
  add("quitar el veneno",                       "cure poison",                        "驱散毒素")
  add("quitar enfermedad",                      "cure disease",                       "驱散疾病")
  add("disipar",                                "dispel",                             "驱散")
  add("limpieza",                               "cleanse",                            "清洁")
  add("limpiarme",                              "cleanse me",                         "清洁我")
  add("decursar",                               "decurse",                            "解诅咒")
  add("corte de batalla",                       "battle cut",                         "战斗打断")

  -- ╔══════════════════════════════════════════════╗
  -- ║  CAT 06: MARCAS DE RAID                      ║
  -- ╚══════════════════════════════════════════════╝
  add("calavera",                               "skull",                              "骷髅")
  add("equis",                                  "cross",                              "大叉")
  add("círculo",                                "circle",                             "大饼")
  add("luna",                                   "moon",                               "月亮")
  add("triángulo",                              "triangle",                           "三角")
  add("diamante",                               "diamond",                            "菱形")
  add("cuadrado",                               "square",                             "方块")
  add("estrella",                               "star",                               "星星")
  add("pon marcas",                             "put markers",                        "标记")
  add("quita las marcas",                       "remove markers",                     "清除标记")
  add("marca en el objetivo",                   "mark the target",                    "标记目标")
  add("maten al marcado",                       "kill the marked",                    "击杀标记")
  add("foco en la marca",                       "focus the marker",                   "打标记")

  -- ╔══════════════════════════════════════════════╗
  -- ║  CAT 07: ECONOMÍA Y BOTÍN                    ║
  -- ╚══════════════════════════════════════════════╝
  add("vendo",                                  "wts",                                "出售")
  add("compro",                                 "wtb",                                "求购")
  add("cambio",                                 "wtt",                                "交换")
  add("wts",                                    "vendo",                              "出售")
  add("wtb",                                    "compro",                             "求购")
  add("wtt",                                    "cambio",                             "交换")
  add("se liga al equipar",                     "bind on equip",                      "装备后绑定")
  add("se liga al recoger",                     "bind on pickup",                     "拾取后绑定")
  add("boe",                                    "bind on equip",                      "装绑")
  add("bop",                                    "bind on pickup",                     "拾绑")
  add("puja mínima",                            "minimum bid",                        "最低出价")
  add("oferta inicial",                         "opening bid",                        "起拍价")
  add("alguien más",                            "anyone else",                        "还有人吗")
  add("a la una",                               "going once",                         "一次")
  add("a las dos",                              "going twice",                        "两次")
  add("vendido",                                "sold",                               "成交")
  add("todo looteado",                          "all looted",                         "全部拾取")
  add("reparto de oro",                         "gold payout",                        "分金")
  add("mi parte del gdkp",                      "my gdkp cut",                        "我的G分红")
  add("gdkp",                                   "gold dkp run",                       "金团")
  add("dkp",                                    "dragon kill points",                 "DKP")
  add("modo de saqueo",                         "loot mode",                          "分配模式")
  add("maestro despojador",                     "master looter",                      "队长分配")
  add("libre para todos",                       "free for all",                       "自由拾取")
  add("distribucion grupal",                    "group loot",                         "队伍分配")
  add("turno rotativo",                         "round robin",                        "轮流拾取")
  add("reserva suave",                          "soft reserve",                       "软保留")
  add("reserva dura",                           "hard reserve",                       "硬保留")
  add("rama principal",                         "main spec",                          "主天赋")
  add("rama secundaria",                        "off spec",                           "副天赋")
  add("ms os",                                  "main spec off spec",                 "主副天赋")
  add("solo ms",                                "main spec only",                     "仅限主天赋")
  add("tira dados",                             "roll for it",                        "R点")
  add("tira un dado",                           "roll",                               "R点")
  add("necesidad o codicia",                    "need or greed",                      "需求 o 贪婪")
  add("pasa el loot",                           "pass on loot",                       "放弃")
  add("desencantar",                            "disenchant",                         "分解")
  add("desencanta",                             "de it",                              "分解它")
  add("desen",                                  "de",                                 "分解")
  add("barato",                                 "cheap",                              "便宜")
  add("caro",                                   "expensive",                          "贵")
  add("precio de oferta",                       "buyout price",                       "一口价")
  add("precio de subasta",                      "auction price",                      "竞拍价")
  add("en subasta",                             "on ah",                              "在拍卖行")
  add("casa de subastas",                       "auction house",                      "拍卖行")
  add("subasta",                                "ah",                                 "拍卖行")
  add("buzón",                                  "mailbox",                            "邮箱")
  add("correo en el juego",                     "in-game mail",                       "游戏邮件")
  add("banco de hermandad",                     "guild bank",                         "公会银行")
  add("más barato que la subasta",              "cheaper than ah",                    "比拍卖行便宜")
  add("pagado",                                 "paid out",                           "已付")
  add("cobrado",                                "charged",                            "已收")
  add("gratis",                                 "free",                               "免费")
  add("sin cargo",                              "no charge",                          "免费")
  add("donacion",                               "donation",                           "捐赠")
  add("propina",                                "tip",                                "小费")
  add("propina incluida",                       "tip included",                       "含小费")
  add("acepto propinas",                        "tips accepted",                      "接受小费")

  -- ╔══════════════════════════════════════════════╗
  -- ║  CAT 08: CLASES (ES->EN)                     ║
  -- ╚══════════════════════════════════════════════╝
  add("guerrero",                               "warrior",                            "战士")
  add("paladín",                                "paladin",                            "圣骑士")
  add("paladin",                                "paladin",                            "圣骑士")
  add("cazador",                                "hunter",                             "猎人")
  add("pícaro",                                 "rogue",                              "盗贼")
  add("picaro",                                 "rogue",                              "盗贼")
  add("sacerdote",                              "priest",                             "牧师")
  add("chamán",                                 "shaman",                             "萨满")
  add("chaman",                                 "shaman",                             "萨满")
  add("mago",                                   "mage",                               "法师")
  add("brujo",                                  "warlock",                            "术士")
  add("druida",                                 "druid",                              "德鲁伊")
  add("warrior",                                "guerrero",                           "战士")
  add("paladin",                                "paladin",                            "圣骑士")
  add("hunter",                                 "cazador",                            "猎人")
  add("rogue",                                  "pícaro",                             "盗贼")
  add("priest",                                 "sacerdote",                          "牧师")
  add("shaman",                                 "chamán",                             "萨满")
  add("warlock",                                "brujo",                              "术士")
  add("druid",                                  "druida",                             "德鲁伊")

  -- Roles
  add("tanque",                                 "tank",                               "坦克")
  add("sanador",                                "healer",                             "治疗")
  add("curador",                                "healer",                             "治疗")
  add("dps",                                    "dps",                                "DPS")
  add("daño",                                   "damage",                             "伤害")

  -- Specs
  add("protección",                             "protection",                         "防护")
  add("proteccion",                             "protection",                         "防护")
  add("sagrado",                                "holy",                               "神圣")
  add("represalia",                             "retribution",                        "反击风暴")
  add("sombras",                                "shadow",                             "暗影")
  add("disciplina",                             "discipline",                         "戒律")
  add("restauración",                           "restoration",                        "恢复")
  add("restauracion",                           "restoration",                        "恢复")
  add("elemental",                              "elemental",                          "元素")
  add("mejora",                                 "enhancement",                        "提升")
  add("aflicción",                              "affliction",                         "痛苦")
  add("afliccion",                              "affliction",                         "痛苦")
  add("destrucción",                            "destruction",                        "毁灭")
  add("destruccion",                            "destruction",                        "毁灭")
  add("demonología",                            "demonology",                         "恶魔学识")
  add("demonologia",                            "demonology",                         "恶魔学识")
  add("escarcha",                               "frost",                              "冰霜")
  add("fuego",                                  "fire",                               "火焰")
  add("arcano",                                 "arcane",                             "奥术")
  add("equilibrio",                             "balance",                            "平衡")
  add("feral",                                  "feral",                              "野性")
  add("combate",                                "combat",                             "战斗")
  add("asesino",                                "assassination",                      "刺杀")
  add("puntería",                               "marksmanship",                       "射击")
  add("punteria",                               "marksmanship",                       "射击")
  add("bestias",                                "beast mastery",                      "野兽控制")
  add("supervivencia",                          "survival",                           "生存")
  add("armas",                                  "arms",                               "武器")
  add("furia guerrera",                         "fury",                               "狂怒")
  add("doble especialización",                  "dual spec",                          "双天赋")
  add("doble especializacion",                  "dual spec",                          "双天赋")
  add("doble spec",                             "dual spec",                          "双天赋")

  -- ╔══════════════════════════════════════════════╗
  -- ║  CAT 09: HABILIDADES — GUERRERO              ║
  -- ╚══════════════════════════════════════════════╝
  add("golpe heroico",                          "heroic strike",                      "英勇打击")
  add("espiral de tormenta",                    "whirlwind",                          "旋风斩")
  add("remolino",                               "whirlwind",                          "旋风斩")
  add("ejecutar",                               "execute",                            "斩杀")
  add("hendir armadura",                        "sunder armor",                       "破甲")
  add("grito de batalla",                       "battle shout",                       "破胆怒吼")
  add("muro de escudo",                         "shield wall",                        "盾墙")
  add("represalia de guerra",                   "retaliation",                        "反击风暴")
  add("último aliento",                         "last stand",                         "破釜沉舟")
  add("golpe mortal",                           "mortal strike",                      "致死打击")
  add("embestida",                              "charge",                             "冲锋")
  add("carga de berserker",                     "berserker charge",                   "拦截")
  add("interceptar",                            "intercept",                          "拦截")
  add("represalia",                             "retaliation",                        "反击风暴")
  add("golpe de escudo",                        "shield bash",                        "盾击")
  add("aplastar",                               "devastate",                          "毁灭打击")
  add("intimidar",                              "demoralizing shout",                 "挫志怒吼")
  add("grito aterrador",                        "intimidating shout",                 "破胆怒吼")
  add("grito de batalla",                       "battle shout",                       "破胆怒吼")

  -- ╔══════════════════════════════════════════════╗
  -- ║  CAT 10: HABILIDADES — PALADÍN               ║
  -- ╚══════════════════════════════════════════════╝
  add("destello de luz",                        "flash of light",                     "圣光闪现")
  add("luz sagrada",                            "holy light",                         "圣光术")
  add("sentencia",                              "judgement",                          "审判")
  add("escudo divino",                          "divine shield",                      "圣盾术")
  add("burbuja",                                "divine shield",                      "圣盾术")
  add("imposición de manos",                    "lay on hands",                       "圣疗术")
  add("sello de justicia",                      "seal of justice",                    "公正圣印")
  add("sello de sabiduría",                     "seal of wisdom",                     "智慧圣印")
  add("sello de la cruzada",                    "seal of the crusader",               "十字军圣印")
  add("sello de virtud",                        "seal of righteousness",              "正义圣印")
  add("sello de mando",                         "seal of command",                    "命令圣印")
  add("pureza divina",                          "divine favor",                       "神恩术")
  add("consagración",                           "consecration",                       "奉献")
  add("bendición de reyes",                     "blessing of kings",                  "王者祝福")
  add("bendición de sabiduría",                 "blessing of wisdom",                 "智慧祝福")
  add("bendición de poder",                     "blessing of might",                  "力量祝福")
  add("bendición de salvación",                 "blessing of salvation",              "拯救祝福")
  add("bendición de protección",                "blessing of protection",             "保护祝福")
  add("aura de devoción",                       "devotion aura",                      "虔诚光环")
  add("aura de retribución",                    "retribution aura",                   "惩罚光环")
  add("aura de concentración",                  "concentration aura",                 "专注光环")
  add("aura resistencia fuego",                 "fire resistance aura",               "抗火光环")
  add("purificar",                              "cleanse",                            "清洁术")
  add("ira sacrada",                            "holy wrath",                         "神圣愤怒")
  add("martillo del inquisidor",                "hammer of justice",                  "制裁之锤")
  add("escudo de cero",                         "hammer of wrath",                    "愤怒之锤")

  -- ╔══════════════════════════════════════════════╗
  -- ║  CAT 11: HABILIDADES — CAZADOR               ║
  -- ╚══════════════════════════════════════════════╝
  add("disparo de puntería",                    "aimed shot",                         "瞄准射击")
  add("multidisparo",                           "multi-shot",                         "多重射击")
  add("fingir muerte",                          "feign death",                        "假死")
  add("marca del cazador",                      "hunter's mark",                      "猎人印记")
  add("aspecto del halcón",                     "aspect of the hawk",                 "雄鹰守护")
  add("aspecto del mono",                       "aspect of the monkey",               "灵猴守护")
  add("aspecto de bestia salvaje",              "aspect of the wild",                 "野性守护")
  add("aspecto del chacal",                     "aspect of the cheetah",              "猎豹守护")
  add("trampa de fuego",                        "immolation trap",                    "献祭陷阱")
  add("trampa de hielo",                        "frost trap",                         "冰霜陷阱")
  add("trampa de serpiente",                    "snake trap",                         "毒蛇陷阱")
  add("trampa explosiva",                       "explosive trap",                     "爆炸陷阱")
  add("trampa de hielo glacial",                "freezing trap",                      "冰冻陷阱")
  add("disparo de serpiente",                   "serpent sting",                      "毒蛇钉刺")
  add("disparo de escorpión",                   "scorpid sting",                      "蝎毒钉刺")
  add("disparo de víbora",                      "viper sting",                        "蝮蛇钉刺")
  add("invocar mascota",                        "call pet",                           "召唤宠物")
  add("liberar mascota",                        "dismiss pet",                        "解散宠物")
  add("alimentar mascota",                      "feed pet",                           "喂养宠物")
  add("duelo de bestias",                       "beast within",                       "狂野怒火")
  add("ojos de bestia",                         "eyes of the beast",                  "野兽之眼")

  -- ╔══════════════════════════════════════════════╗
  -- ║  CAT 12: HABILIDADES — PÍCARO                ║
  -- ╚══════════════════════════════════════════════╝
  add("porrazo",                                "sap",                                "闷棍")
  add("golpe bajo",                             "cheap shot",                         "偷袭")
  add("golpe en los riñones",                   "kidney shot",                        "肾击")
  add("evasión",                                "evasion",                            "闪避")
  add("esfumarse",                              "vanish",                             "消失")
  add("ceguera",                                "blind",                              "致盲")
  add("veneno mortal",                          "deadly poison",                      "致命毒药")
  add("veneno instantáneo",                     "instant poison",                     "速效毒药")
  add("hemorragia",                             "hemorrhage",                         "出血")
  add("puñalada",                               "backstab",                           "背刺")
  add("golpe sinérgico",                        "sinister strike",                    "影袭")
  add("ruptura",                                "rupture",                            "割裂")
  add("rebanada y dados",                       "slice and dice",                     "切割")
  add("exposición de armadura",                 "expose armor",                       "破甲")
  add("abanico de cuchillos",                   "fan of knives",                      "刀扇")
  add("trampa de cuchillas",                    "blade flurry",                       "剑刃乱舞")
  add("danza de la muerte",                     "cold blood",                         "冷血")
  add("sigilo",                                 "stealth",                            "潜行")
  add("emboscada",                              "ambush",                             "伏击")
  add("mutilación",                             "mutilate",                           "毁伤")
  add("eviscerar",                              "eviscerate",                         "剔骨")

  -- ╔══════════════════════════════════════════════╗
  -- ║  CAT 13: HABILIDADES — SACERDOTE             ║
  -- ╚══════════════════════════════════════════════╝
  add("sanación superior",                      "greater heal",                       "强效治疗术")
  add("sanación relámpago",                     "flash heal",                         "快速治疗")
  add("escudo de poder",                        "power word: shield",                 "真言术：盾")
  add("burbuja del sacerdote",                  "power word: shield",                 "真言术：盾")
  add("infusión de poder",                      "power infusion",                     "能量灌注")
  add("palabra oscura muerte",                  "shadow word: death",                 "暗言术：灭")
  add("palabra oscura dolor",                   "shadow word: pain",                  "暗言术：痛")
  add("mente del vuelo",                        "mind flay",                          "精神鞭笞")
  add("mente en explosión",                     "mind blast",                         "心灵震爆")
  add("regeneración",                           "renew",                              "恢复")
  add("toque de curación",                      "heal",                               "治疗术")
  add("curación circular",                      "circle of healing",                  "治疗环")
  add("renacer del sacerdote",                  "divine spirit",                      "神圣之灵")
  add("oración de fortalecimiento",             "prayer of fortitude",                "坚韧祷言")
  add("oración de sombra",                      "prayer of shadow protection",        "暗影防护祷言")
  add("espíritu divino",                        "divine spirit",                      "神圣之灵")
  add("fortaleza de las sombras",               "vampiric embrace",                   "吸血鬼的拥抱")
  add("abrazo vampírico",                       "vampiric embrace",                   "吸血鬼的拥抱")
  add("toque vampírico",                        "vampiric touch",                     "吸血鬼之触")
  add("forma de sombra",                        "shadowform",                         "暗影形态")
  add("desvanecer",                             "fade",                               "渐隐术")
  add("ánimo mayor",                            "greater heal",                       "强效治疗术")
  add("dispersar",                              "dispel magic",                       "驱散魔法")
  add("limpieza masiva",                        "mass dispel",                        "群体驱散")
  add("compasión divina",                       "divine compassion",                  "神圣慈悲")

  -- ╔══════════════════════════════════════════════╗
  -- ║  CAT 14: HABILIDADES — MAGO                  ║
  -- ╚══════════════════════════════════════════════╝
  add("descarga de escarcha",                   "frostbolt",                          "寒冰箭")
  add("bola de fuego",                          "fireball",                           "火球术")
  add("bloque de hielo",                        "ice block",                          "寒冰屏障")
  add("polimorfia",                             "polymorph",                          "变形术")
  add("oveja",                                  "polymorph",                          "变形术")
  add("traslación",                             "blink",                              "闪现术")
  add("cono de frío",                           "cone of cold",                       "冰锥术")
  add("joya de escarcha",                       "frost nova",                         "冰霜新星")
  add("proyectil arcano",                       "arcane missiles",                    "奥术飞弹")
  add("explosión arcana",                       "arcane explosion",                   "奥术爆炸")
  add("contrahechizo",                          "counterspell",                       "法术反制")
  add("combustión",                             "combustion",                         "燃烧")
  add("presencia mental",                       "presence of mind",                   "气定神闲")
  add("ventisca",                               "blizzard",                           "暴风雪")
  add("tormenta de fuego",                      "flamestrike",                        "烈焰风暴")
  add("explosión de fuego",                     "fire blast",                         "火焰冲击")
  add("espejo de imágenes",                     "mirror image",                       "镜像")
  add("mesa de banquete",                       "conjure table",                      "拉桌子")
  add("conjurar agua",                          "conjure water",                      "造水术")
  add("conjurar comida",                        "conjure food",                       "造食术")
  add("portal a ventormenta",                   "portal: stormwind",                  "传送门：暴风城")
  add("portal a orgrimmar",                     "portal: orgrimmar",                  "传送门：奥格瑞玛")
  add("portal a ironforge",                     "portal: ironforge",                  "传送门：铁炉堡")
  add("portal a darnassus",                     "portal: darnassus",                  "传送门：达纳苏斯")
  add("portal a entrañas",                      "portal: undercity",                  "传送门：幽暗城")
  add("portal a thunder bluff",                 "portal: thunder bluff",              "传送门：雷霆崖")
  add("tele ventormenta",                       "teleport: stormwind",                "传送：暴风城")
  add("tele orgrimmar",                         "teleport: orgrimmar",                "传送：奥格瑞玛")
  add("romper nieve",                           "shatter",                            "碎冰")

  -- ╔══════════════════════════════════════════════╗
  -- ║  CAT 15: HABILIDADES — BRUJO                 ║
  -- ╚══════════════════════════════════════════════╝
  add("descarga de sombras",                    "shadow bolt",                        "暗影箭")
  add("corrupción",                             "corruption",                         "腐蚀术")
  add("maldición de agonía",                    "curse of agony",                     "痛苦诅咒")
  add("maldición de elementos",                 "curse of the elements",              "元素诅咒")
  add("maldición de debilidad",                 "curse of weakness",                  "虚弱诅咒")
  add("maldición de agotamiento",               "curse of exhaustion",                "疲劳诅咒")
  add("lluvia de fuego",                        "rain of fire",                       "火雨")
  add("tempestad infernal",                     "hellfire",                           "地狱烈焰")
  add("drenar vida",                            "drain life",                         "吸取生命")
  add("drenar alma",                            "drain soul",                         "吸取灵魂")
  add("drenar maná",                            "drain mana",                         "吸取法力")
  add("destierro",                              "banish",                             "放逐术")
  add("seducción",                              "seduction",                          "诱惑")
  add("atar demonio",                           "enslave demon",                      "奴役恶魔")
  add("sacrificio maléfico",                    "sacrifice",                          "牺牲")
  add("maldición de agotamiento",               "curse of exhaustion",                "疲劳诅咒")
  add("lengua de fuego",                        "conflagrate",                        "燃烧")
  add("tiro de fuego",                          "fire bolt",                          "火焰箭")
  add("creación ropas de tela",                 "create healthstone",                 "制造治疗石")
  add("piedra de salud",                        "healthstone",                        "治疗石")
  add("piedra de alma",                         "soulstone",                          "灵魂石")
  add("resurrección del brujo",                 "soulstone rez",                      "灵魂石复活")
  add("soulstone a mi",                         "soulstone me",                       "给我绑定灵魂石")
  add("ponme soulstone",                        "soulstone me",                       "给我绑定灵魂石")

  -- ╔══════════════════════════════════════════════╗
  -- ║  CAT 16: HABILIDADES — CHAMÁN                ║
  -- ╚══════════════════════════════════════════════╝
  add("descarga de relámpagos",                 "lightning bolt",                     "闪电箭")
  add("cadena de relámpagos",                   "chain lightning",                    "闪电链")
  add("ansia de sangre",                        "bloodlust",                          "嗜血")
  add("heroísmo",                               "heroism",                            "英雄")
  add("furia del viento",                       "windfury",                           "风怒")
  add("escudo del relámpago",                   "lightning shield",                   "闪电盾")
  add("escudo del agua",                        "water shield",                       "水之护盾")
  add("curación de cadena",                     "chain heal",                         "治疗链")
  add("marea de oleadas",                       "healing wave",                       "治疗波")
  add("oleada menor",                           "lesser healing wave",                "次级治疗波")
  add("golpe de tierra",                        "earth shock",                        "大地震击")
  add("golpe de escarcha",                      "frost shock",                        "冰霜震击")
  add("golpe de llama",                         "flame shock",                        "烈焰震击")
  add("ráfaga de viento",                       "wind shear",                         "风剪")
  add("tótem de terratemblor",                  "earthbind totem",                    "地缚图腾")
  add("tótem de llama chispa",                  "searing totem",                      "灼热图腾")
  add("tótem de magma",                         "magma totem",                        "熔岩图腾")
  add("tótem de curación",                      "healing stream totem",               "治疗之泉图腾")
  add("tótem de maná primavera",                "mana spring totem",                  "法力之泉图腾")
  add("tótem de gracia del aire",               "grace of air totem",                 "风之优雅图腾")
  add("tótem de fuerza de tierra",              "strength of earth totem",            "大地之力图腾")
  add("tótem de resistencia fuego",             "fire resistance totem",              "抗火图腾")
  add("tótem de resistencia naturaleza",        "nature resistance totem",            "抗自然图腾")
  add("tótem de sentido de la tierra",          "tremor totem",                       "战栗图腾")
  add("tótem de intuición",                     "stoneclaw totem",                    "石爪图腾")
  add("invocar tótem",                          "drop totem",                         "插图腾")
  add("revienta los totems",                    "kill the totems",                    "打图腾")

  -- ╔══════════════════════════════════════════════╗
  -- ║  CAT 17: HABILIDADES — DRUIDA                ║
  -- ╚══════════════════════════════════════════════╝
  add("toque de sanación",                      "healing touch",                      "治疗之触")
  add("estimular",                              "innervate",                          "激活")
  add("innervate",                              "estimular",                          "激活")
  add("renacer",                                "rebirth",                            "复生")
  add("resurrección de combate",                "battle rez",                         "战复")
  add("battle res",                             "resurrección de combate",            "战复")
  add("battle rez",                             "resurrección de combate",            "战复")
  add("rejuvenecimiento",                       "rejuvenation",                       "回春术")
  add("floración",                              "lifebloom",                          "生命绽放")
  add("alimentación regenerativa",              "regrowth",                           "愈合")
  add("forma de oso",                           "bear form",                          "熊形态")
  add("forma de viaje",                         "travel form",                        "旅行形态")
  add("forma de arbol",                         "tree form",                          "生命之树形态")
  add("forma acuática",                         "aquatic form",                       "水栖形态")
  add("forma de gato",                          "cat form",                           "猎豹形态")
  add("forma de vuelo",                         "flight form",                        "飞行形态")
  add("ciclón",                                 "cyclone",                            "旋风")
  add("enredar",                                "entangling roots",                   "纠缠根须")
  add("dormir a la bestia",                     "hibernate",                          "休眠")
  add("zarpa de la naturaleza",                 "nature's grasp",                     "自然之握")
  add("apuñalar",                               "ravage",                             "毁灭")
  add("desgarrar",                              "rip",                                "愿安息")
  add("golpe de raptor",                        "rake",                               "斜掠")
  add("maul",                                   "maul",                               "重击")
  add("rugido del oso",                         "demoralizing roar",                  "挫志咆哮")
  add("rugido de guerra",                       "war stomp",                          "战争践踏")
  add("luna estelar",                           "moonfire",                           "月火术")
  add("lluvia estelar",                         "starfall",                           "星辰坠落")
  add("ira de naturaleza",                      "wrath",                              "愤怒")
  add("tormenta solar",                         "solar beam",                         "日光术")

  -- ╔══════════════════════════════════════════════╗
  -- ║  CAT 18: ESTADÍSTICAS Y ATRIBUTOS           ║
  -- ╚══════════════════════════════════════════════╝
  add("fuerza",                                 "strength",                           "力量")
  add("str",                                    "strength",                           "力量")
  add("agilidad",                               "agility",                            "敏捷")
  add("agi",                                    "agility",                            "敏捷")
  add("intelecto",                              "intellect",                          "智力")
  add("int",                                    "intellect",                          "智力")
  add("espíritu",                               "spirit",                             "精神")
  add("spi",                                    "spirit",                             "精神")
  add("aguante",                                "stamina",                            "耐力")
  add("sta",                                    "stamina",                            "耐力")
  add("poder de ataque",                        "attack power",                       "攻击强度")
  add("poder con hechizos",                     "spell power",                        "法术强度")
  add("poder de hechizos",                      "spell power",                        "法术强度")
  add("daño con hechizos",                      "spell damage",                       "法术伤害")
  add("poder de curación",                      "healing power",                      "治疗效果")
  add("golpe crítico",                          "critical strike",                    "爆击")
  add("crítico",                                "crit",                               "爆击")
  add("probabilidad de golpe",                  "hit chance",                         "命中几率")
  add("rating de golpe",                        "hit rating",                         "命中等级")
  add("porcentaje de golpe",                    "hit percentage",                     "命中百分比")
  add("cap de hit",                             "hit cap",                            "命中上限")
  add("pericia",                                "expertise",                          "精准")
  add("cap de expertise",                       "expertise cap",                      "精准上限")
  add("esquivar",                               "dodge",                              "躲闪")
  add("parada",                                 "parry",                              "招架")
  add("bloqueo",                                "block",                              "格挡")
  add("defensa",                                "defense",                            "防御")
  add("defensa cap",                            "defense cap",                        "防御上限")
  add("armadura",                               "armor",                              "护甲")
  add("penetración arcana",                     "spell penetration",                  "法术穿透")
  add("velocidad de lanzamiento",               "casting speed",                      "施法速度")
  add("velocidad de ataque",                    "attack speed",                       "攻击速度")
  add("reducción de armadura",                  "armor penetration",                  "护甲穿透")
  add("arpen",                                  "armor penetration",                  "护甲穿透")
  add("resistencia al fuego",                   "fire resistance",                    "火焰抗性")
  add("resistencia a escarcha",                 "frost resistance",                   "冰霜抗性")
  add("resistencia a naturaleza",               "nature resistance",                  "自然抗性")
  add("resistencia arcana",                     "arcane resistance",                  "奥术抗性")
  add("resistencia a sombras",                  "shadow resistance",                  "暗影抗性")
  add("regeneración de vida",                   "health regeneration",                "生命恢复")
  add("regeneración de maná",                   "mana regeneration",                  "法力恢复")
  add("mp5",                                    "mana per 5 seconds",                 "每5秒恢复法力")
  add("maná por 5",                             "mana per 5 seconds",                 "每5秒恢复法力")
  add("haste",                                  "rapidez",                            "急速")
  add("rapidez",                                "haste",                              "急速")
  add("bonus de sanación",                      "healing bonus",                      "治疗加成")
  add("bonificación",                           "bonus",                              "加成")

  -- ╔══════════════════════════════════════════════╗
  -- ║  CAT 19: PROFESIONES                         ║
  -- ╚══════════════════════════════════════════════╝
  add("alquimia",                               "alchemy",                            "炼金术")
  add("herboristería",                          "herbalism",                          "采药")
  add("herboristeria",                          "herbalism",                          "采药")
  add("minería",                                "mining",                             "采矿")
  add("mineria",                                "mining",                             "采矿")
  add("herrería",                               "blacksmithing",                      "锻造")
  add("herreria",                               "blacksmithing",                      "锻造")
  add("ingeniería",                             "engineering",                        "工程学")
  add("ingenieria",                             "engineering",                        "工程学")
  add("encantamiento",                          "enchanting",                         "附魔")
  add("peletería",                              "leatherworking",                     "制皮")
  add("peleteria",                              "leatherworking",                     "制皮")
  add("sastrería",                              "tailoring",                          "裁缝")
  add("sastreria",                              "tailoring",                          "裁缝")
  add("cocina",                                 "cooking",                            "烹饪")
  add("pesca",                                  "fishing",                            "钓鱼")
  add("primeros auxilios",                      "first aid",                          "急救")
  add("recolección",                            "gathering",                          "采集")
  add("crafteo",                                "crafting",                           "制造")
  add("subir profesión",                        "level profession",                   "提升专业")
  add("maxear profesión",                       "max profession",                     "满级专业")
  add("maestro en",                             "master of",                          "大师")
  add("aprender receta",                        "learn recipe",                       "学习配方")
  add("receta de encantamiento",                "enchanting recipe",                  "附魔配方")
  add("receta de alquimia",                     "alchemy recipe",                     "炼金配方")
  add("patrón de sastrería",                    "tailoring pattern",                  "裁缝图样")
  add("diseño de herrería",                     "blacksmithing plans",                "锻造设计图")

  -- ╔══════════════════════════════════════════════╗
  -- ║  CAT 20: MATERIALES Y RECURSOS               ║
  -- ╚══════════════════════════════════════════════╝
  -- Telas
  add("paño de lino",                           "linen cloth",                        "亚麻布")
  add("paño de lana",                           "wool cloth",                         "毛料")
  add("paño de seda",                           "silk cloth",                         "丝绸")
  add("paño de tejido de magia",                "mageweave cloth",                    "魔纹布")
  add("paño rúnico",                            "runecloth",                          "符文布")
  add("tela de seda",                           "silk cloth",                         "丝绸")
  -- Minerales
  add("mineral de cobre",                       "copper ore",                         "铜矿")
  add("mineral de estaño",                      "tin ore",                            "锡矿")
  add("mineral de hierro",                      "iron ore",                           "铁矿")
  add("mineral de oro",                         "gold ore",                           "金矿")
  add("mineral de mitril",                      "mithril ore",                        "秘银矿")
  add("mineral de torio",                       "thorium ore",                        "瑟银矿")
  add("barra de cobre",                         "copper bar",                         "铜锭")
  add("barra de bronce",                        "bronze bar",                         "青铜锭")
  add("barra de hierro",                        "iron bar",                           "铁锭")
  add("barra de acero",                         "steel bar",                          "钢锭")
  add("barra de mitril",                        "mithril bar",                        "秘银锭")
  add("barra de torio",                         "thorium bar",                        "瑟银锭")
  add("barra de arcanita",                      "arcanite bar",                       "奥金锭")
  add("transmutación de arcanita",              "arcanite transmute",                 "转化奥金")
  -- Cueros
  add("cuero ligero",                           "light leather",                      "轻皮")
  add("cuero medio",                            "medium leather",                     "中皮")
  add("cuero pesado",                           "heavy leather",                      "重皮")
  add("cuero grueso",                           "thick leather",                      "厚皮")
  add("cuero basto",                            "rugged leather",                     "硬甲皮")
  add("cuero óseo",                             "heavy hide",                         "重型重皮")
  add("escamas de dragón",                      "dragonscales",                       "龙鳞")
  add("escamas de dragonkin",                   "dragonkin scales",                   "龙人鳞片")
  add("escamas negras de dragón",               "black dragonscales",                 "黑色龙鳞")
  add("cuero de cocodrilo",                     "thick crocodile skin",               "厚鳄鱼皮")
  -- Hierbas
  add("raíz de peacebloom",                     "peacebloom",                         "宁神花")
  add("silverleaf",                             "hoja de plata",                      "银叶草")
  add("earthroot",                              "raíz de tierra",                     "地根草")
  add("mageroyal",                              "real del mago",                      "魔皇草")
  add("briarthorn",                             "zarza",                              "石南草")
  add("bruiseweed",                             "hierba moreteada",                   "跌打草")
  add("wild steelbloom",                        "flor de acero salvaje",              "野钢花")
  add("gromsblood",                             "sangre de grom",                     "格罗姆之血")
  add("kingsbane",                              "veneno del rey",                     "皇血草")
  add("arthas lágrimas",                        "arthas' tears",                      "阿尔萨斯之泪")
  add("sungrass",                               "hierba solar",                       "太阳草")
  add("blindweed",                              "hierba ciega",                       "盲目草")
  add("plaguebloom",                            "flor de la plaga",                   "瘟疫花")
  add("mountain silversage",                    "salvia de plata de montaña",         "山鼠草")
  add("icecap",                                 "gorrocelo",                          "冰盖草")
  add("dreamfoil",                              "hoja de sueño",                      "梦叶草")
  add("flor de azafrán",                        "firebloom",                          "火焰花")
  add("flor del fuego",                         "firebloom",                          "火焰花")
  -- Gemas y Cristales
  add("cristal de nexo",                        "nexus crystal",                      "联结水晶")
  add("esencia astuta",                         "lesser eternal essence",             "次级永恒精华")
  add("esencia eterna menor",                   "lesser eternal essence",             "次级永恒精华")
  add("esencia eterna mayor",                   "greater eternal essence",            "强效永恒精华")
  add("astilla misteriosa menor",               "lesser mystic essence",              "次级神秘精华")
  add("polvo de oscuridad",                     "dream dust",                         "幻境尘")
  add("polvo de maravilla",                     "illusion dust",                      "幻影尘")
  add("esencia la ilusión",                     "illusion dust",                      "幻影尘")
  add("fragmento de alma",                      "soul shard",                         "灵魂碎片")
  add("fragmento de sombra",                    "shadow shard",                       "暗影碎片")
  -- Consumibles de combat
  add("pocion de vida",                         "healing potion",                     "治疗药水")
  add("pocion de mana",                         "mana potion",                        "法力药水")
  add("pocion de maná mayor",                   "major mana potion",                  "强效法力药水")
  add("pocion de vida mayor",                   "major healing potion",               "强效治疗药水")
  add("pocion de velocidad",                    "swiftness potion",                   "迅捷药水")
  add("pocion de escarcha",                     "frost protection potion",            "冰霜防护药水")
  add("pocion de fuego",                        "fire protection potion",             "火焰防护药水")
  add("pocion de naturaleza",                   "nature protection potion",           "自然防护药水")
  add("pocion de sombras",                      "shadow protection potion",           "暗影防护药水")
  add("pocion arcana",                          "arcane protection potion",           "奥术防护药水")
  add("elixir del gigante",                     "elixir of giants",                   "巨人药剂")
  add("elixir del mongoose",                    "elixir of the mongoose",             "猫鼬药剂")
  add("elixir de inteligencia",                 "elixir of greater intellect",        "强效智力药剂")
  add("elixir de la mangosta",                  "elixir of the mongoose",             "猫鼬药剂")
  add("elixir del sabio",                       "elixir of greater wisdom",           "强效智慧药剂")
  add("frasco de supremacía",                   "flask of supreme power",             "超级能量合剂")
  add("frasco del titán",                       "flask of the titans",                "泰坦合剂")
  add("frasco de destilación",                  "flask of distilled wisdom",          "精炼智慧合剂")
  add("frasco de resistencia",                  "flask of chromatic resistance",      "多彩抗性合剂")
  add("comida de buff",                         "buff food",                          "属性食物")
  add("comida con agilidad",                    "agility food",                       "敏捷食物")
  add("comida con fuerza",                      "strength food",                      "力量食物")
  add("comida con espíritu",                    "spirit food",                        "精神食物")
  add("gamba asada",                            "grilled squid",                      "烤鱿鱼")
  add("pescado asado",                          "baked bass",                         "烤大嘴鲈鱼")
  add("venda de tejido rúnico",                 "runecloth bandage",                  "符文布绷带")
  add("venda pesada de rúnico",                 "heavy runecloth bandage",            "厚符文布绷带")
  add("polvo de mana",                          "mana dust",                          "法力粉尘")
  add("tierra de sombra",                       "shadow dust",                        "暗影粉尘")

  -- ╔══════════════════════════════════════════════╗
  -- ║  CAT 21: PvP Y RANGOS MILITARES              ║
  -- ╚══════════════════════════════════════════════╝
  -- Alianza
  add("soldado raso",                           "private",                            "列兵")
  add("cabo",                                   "corporal",                           "下士")
  add("sargento alianza",                       "sergeant",                           "中士")
  add("sargento maestro",                       "master sergeant",                    "军士长")
  add("sargento mayor alianza",                 "sergeant major",                     "精锐军士长")
  add("caballero",                              "knight",                             "骑士")
  add("caballero teniente",                     "knight-lieutenant",                  "少尉")
  add("caballero capitán",                      "knight-captain",                     "大尉")
  add("caballero campeón",                      "knight-champion",                    "少校")
  add("teniente comandante",                    "lieutenant commander",               "中校")
  add("comandante",                             "commander",                          "司令")
  add("mariscal",                               "marshal",                            "元帅")
  add("mariscal de campo",                      "field marshal",                      "陆军元帅")
  add("gran mariscal",                          "grand marshal",                      "大元帅")
  -- Horda
  add("zalamero",                               "scout",                              "斥候")
  add("grunt",                                  "grunt",                              "步兵")
  add("guardia de piedra",                      "stone guard",                        "石卫士")
  add("guardia de sangre",                      "blood guard",                        "血卫士")
  add("legionario",                             "legionnaire",                        "军团士兵")
  add("centurión",                              "centurion",                          "百夫长")
  add("campeón horda",                          "champion",                           "勇士")
  add("teniente general",                       "lieutenant general",                 "将军")
  add("general horda",                          "general",                            "督军")
  add("señor de la guerra",                     "warlord",                            "督军")
  add("alto señor de la guerra",                "high warlord",                       "高阶督军")
  -- BGs
  add("garganta grito de guerra",               "warsong gulch",                      "战歌峡谷")
  add("cuenca de arathi",                       "arathi basin",                       "阿拉希盆地")
  add("valle de alterac",                       "alterac valley",                     "奥特兰克山谷")
  add("ojo de la tormenta",                     "eye of the storm",                   "风暴之眼")
  add("campo de batalla",                       "battleground",                       "战场")
  add("cola de campo de batalla",               "battleground queue",                 "战场排队")
  add("puntos de honor",                        "honor points",                       "荣誉点数")
  add("puntos de arena",                        "arena points",                       "竞技场点数")
  add("nuestra bandera",                        "our flag",                           "我们的旗帜")
  add("su bandera",                             "their flag",                         "他们的旗帜")
  add("capturar bandera",                       "cap flag",                           "开旗")
  add("la bandera fue tomada",                  "flag was taken",                     "旗帜被夺")
  add("bandera en suelo",                       "flag on ground",                     "旗帜落地")
  add("bandera devuelta",                       "flag returned",                      "旗帜归位")
  add("defender base",                          "defend base",                        "防守基地")
  add("capturar base",                          "cap base",                           "开旗")
  add("establos de arathi",                     "stables",                            "马厩")
  add("granja de arathi",                       "farm",                               "农场")
  add("mina de arathi",                         "goldmine",                           "金矿")
  add("aserradero de arathi",                   "lumber mill",                        "伐木场")
  add("herrería de arathi",                     "blacksmith",                         "铁匠铺")
  add("torres de alterac",                      "alterac towers",                     "奥特兰克哨塔")
  add("fuerte norteño",                         "stonehearth bunker",                 "石炉碉堡")
  add("fuerte sureño",                          "snowfall graveyard",                 "落雪墓地")
  add("fortaleza de drek",                      "drek's fortress",                    "霜狼要塞")
  add("fortaleza de van",                       "van's fortress",                     "雷矛要塞")

  -- ╔══════════════════════════════════════════════╗
  -- ║  CAT 22: GEOGRAFÍA AZEROTH                   ║
  -- ╚══════════════════════════════════════════════╝
  -- Ciudades Alianza
  add("ventormenta",                            "stormwind",                          "暴风城")
  add("entrada a ventormenta",                  "stormwind gate",                     "暴风城大门")
  add("ciudad de ventormenta",                  "stormwind city",                     "暴风城")
  add("magos de ventormenta",                   "stormwind mages",                    "暴风城法师")
  add("forjaz",                                 "ironforge",                          "铁炉堡")
  add("darnassus",                              "darnassus",                          "达纳苏斯")
  add("catedral de la luz",                     "cathedral of light",                 "光明大教堂")
  add("barrio de los magos",                    "mage quarter",                       "法师区")
  add("el enano borracho",                      "the drunken dwarf",                  "醉酒的矮人")
  -- Ciudades Horda
  add("orgrimmar",                              "orgrimmar",                          "奥格瑞玛")
  add("cima del trueno",                        "thunder bluff",                      "雷霆崖")
  add("entrañas",                               "undercity",                          "幽暗城")
  add("claro de la luna",                       "moonglade",                          "月光林地")
  -- Zonas
  add("bosque de elwynn",                       "elwynn forest",                      "艾尔文森林")
  add("páramos de poniente",                    "westfall",                           "西部荒野")
  add("montañas cresta roja",                   "redridge mountains",                 "赤脊山")
  add("bosque del ocaso",                       "duskwood",                           "暮色森林")
  add("bahía del botín",                        "booty bay",                          "藏宝海湾")
  add("trinquete",                              "ratchet",                            "棘齿城")
  add("ventana de cera",                        "wax window",                         "蜡质窗户")
  add("pantano de las penas",                   "swamp of sorrows",                   "悲伤沼泽")
  add("tierras de la peste este",               "eastern plaguelands",                "东瘟疫之地")
  add("tierras de la peste oeste",              "western plaguelands",                "西瘟疫之地")
  add("montañas del este",                      "eastern kingdoms",                   "东部王国")
  add("hinterlands",                            "the hinterlands",                    "辛特兰")
  add("tierras altas de arathi",                "arathi highlands",                   "阿拉希高地")
  add("badlands",                               "badlands",                           "荒芜之地")
  add("las tierras bajas",                      "the lowlands",                       "低地")
  add("valle de fresno",                        "ashenvale",                          "灰谷")
  add("tierras devastadas",                     "blasted lands",                      "诅咒之地")
  add("paso de la muerte",                      "deadwind pass",                      "逆风小径")
  add("feralas",                                "feralas",                            "菲拉斯")
  add("desolace",                               "desolace",                           "凄凉之地")
  add("tanaris",                                "tanaris",                            "塔纳利斯")
  add("silithus",                               "silithus",                           "希利苏斯")
  add("tierras de fuego",                       "firelands",                          "火焰之地")
  add("llanuras de cenizas",                    "ashenvale plains",                   "灰谷平原")
  add("cuna del invierno",                      "winterspring",                       "冬泉谷")
  add("un'goro",                                "un'goro crater",                     "安戈洛环形山")
  add("cazoleta de un'goro",                    "un'goro crater",                     "安戈洛环形山")
  add("cordillera de arathi",                   "arathi highlands",                   "阿拉希高地")
  add("zangarmarsh",                            "zangarmarsh",                        "赞加沼泽")
  add("hellfire peninsula",                     "peninsula del fuego infernal",       "地狱火半岛")

  -- Puntos de interés
  add("punto de vuelo",                         "flight point",                       "飞行点")
  add("maestra de vuelo",                       "flight master",                      "飞行管理员")
  add("vuelo al punto",                         "take the flight path",               "坐飞机")
  add("voy en vuelo",                           "taking the flight path",             "坐飞机中")
  add("piedra de hogar",                        "hearthstone",                        "炉石")
  add("grupo de misiones",                      "quest group",                        "任务队")
  add("buscando grupo",                         "lfg",                                "开组")
  add("grupo completo",                         "group full",                         "满")
  add("tienes hearthstone aquí",                "hearthstoned here?",                 "炉石在这吗?")
  add("ho en ventormenta",                      "hearthstone in sw",                  "炉石暴风城")
  add("ho en org",                              "hearthstone in org",                 "炉石奥格")
  add("punto de invocación",                    "summoning stone",                    "拉人石")
  add("cerca de la piedra",                     "near the stone",                     "在石头旁")

  -- ╔══════════════════════════════════════════════╗
  -- ║  CAT 23: TURTLE WOW CONTENIDO ESPECÍFICO     ║
  -- ╚══════════════════════════════════════════════╝
  add("carpa de descanso",                      "rest tent",                          "帐篷")
  add("tienda de campaña",                      "tent",                               "帐篷")
  add("carpas",                                 "tents",                              "帐篷")
  add("carpa",                                  "tent",                               "帐篷")
  add("hay carpas aquí",                        "any tents here?",                    "有帐篷吗?")
  add("bono de descanso",                       "rested xp bonus",                    "双倍经验奖励")
  add("xp de descanso",                         "rested xp",                          "双倍经验")
  add("estoy descansado",                       "i am rested",                        "我有双倍")
  add("hardcore",                               "hardcore",                           "硬核")
  add("modo hardcore",                          "hardcore mode",                      "硬核模式")
  add("desafío hardcore",                       "hardcore challenge",                 "硬核挑战")
  add("murió para siempre",                     "died permanently",                   "一命通关结束")
  add("perdió su personaje",                    "lost their character",               "失去了角色")
  add("f en el chat",                           "press f",                            "扣F")
  add("que descanse en paz",                    "rip",                                "愿安息")
  add("ánimo",                                  "cheer up",                           "振作起来")
  add("donado a turtle wow",                    "donated to turtle wow",              "赞助了乌龟服")
  add("donación al servidor",                   "server donation",                    "赞助服务器")
  add("servidor privado",                       "private server",                     "私服")
  add("turtle wow",                             "turtle wow",                         "乌龟服")
  add("tierras fantasmas",                      "ghostlands",                         "幽魂之地")
  add("sueño esmeralda",                        "emerald dream",                      "翡翠梦境")
  add("isla de tel'abim",                       "tel'abim isle",                      "泰拉比姆岛")
  add("telabim",                                "tel'abim",                           "泰拉比姆")
  add("hiraeth",                                "hiraeth",                            "海勒斯堡")
  add("lento y constante",                      "slow and steady",                    "慢而稳")
  add("vagabundo en turtle",                    "vagrant",                            "流浪者")
  add("sin usar posada",                        "no inns used",                       "禁用旅店")
  add("doble especializacion",                  "dual spec",                          "双天赋")
  add("doble spec",                             "dual spec",                          "双天赋")
  add("spec gratis",                            "free respec",                        "免费洗天赋")

  -- ╔══════════════════════════════════════════════╗
  -- ║  CAT 24: ADMINISTRACIÓN GUILD Y RAID         ║
  -- ╚══════════════════════════════════════════════╝
  add("hermandad",                              "guild",                              "公会")
  add("maestro de hermandad",                   "guild master",                       "会长")
  add("oficial de guild",                       "officer",                            "官员")
  add("recluta",                                "recruit",                            "招募")
  add("miembro de guild",                       "guild member",                       "公会成员")
  add("armonización",                           "attunement",                         "开门任务")
  add("attuned",                                "armonizado",                         "已做开门")
  add("armonizado",                             "attuned",                            "已做开门")
  add("no armonizado",                          "not attuned",                        "没做开门")
  add("tiene la armonización",                  "is attuned",                         "有资格")
  add("necesita armonización",                  "needs attunement",                   "需要开门")
  add("durabilidad",                            "durability",                         "耐久度")
  add("durabilidad baja",                       "low durability",                     "低耐久度")
  add("repara equipo",                          "repair your gear",                   "修理装备")
  add("reparar antes del pull",                 "repair before the pull",             "开怪前修理")
  add("reparador de combate",                   "field repair bot",                   "修理机器人")
  add("robot reparador",                        "field repair bot",                   "修理机器人")
  add("mazmorra",                               "dungeon",                            "地下城")
  add("mazmorras",                              "dungeons",                           "地下城")
  add("raid de 40 personas",                    "40 man raid",                        "40人团")
  add("raid de 20 personas",                    "20 man raid",                        "20人团")
  add("raid de 10 personas",                    "10 man raid",                        "10人团")
  add("listo para la raid",                     "raid ready",                         "团本准备就绪")
  add("raid programada",                        "scheduled raid",                     "活动计划")
  add("hora de raid",                           "raid time",                          "活动时间")
  add("inicio de raid",                         "raid start",                         "活动开始")
  add("hora central europea",                   "cet",                                "欧洲中部时间")
  add("hora del servidor",                      "server time",                        "服务器时间")
  add("composición de raid",                    "raid composition",                   "团队配置")
  add("composición de grupo",                   "group comp",                         "队伍配置")
  add("rostar",                                 "roster",                             "名单")
  add("lista de espera",                        "waitlist",                           "替补")
  add("en lista de espera",                     "on the waitlist",                    "在替补席")
  add("fuera del rostar",                       "not on the roster",                  "不在名单上")
  add("lista de asistencia",                    "attendance",                         "出勤")
  add("buena asistencia",                       "good attendance",                    "出勤良好")
  add("mala asistencia",                        "bad attendance",                     "出勤差")
  add("kickear del grupo",                      "kick from group",                    "踢出队伍")
  add("loot de consejo",                        "loot council",                       "分配委员会")
  add("officer loot",                           "officer loot",                       "官员分配")

  -- ╔══════════════════════════════════════════════╗
  -- ║  CAT 25: MANTENIMIENTO EN RAID Y PARTY       ║
  -- ╚══════════════════════════════════════════════╝
  add("necesito maná",                          "low on mana",                        "缺蓝")
  add("necesito mana",                          "low on mana",                        "缺蓝")
  add("bebiendo",                               "drinking",                           "喝水中")
  add("esperen maná",                           "waiting for mana",                   "等蓝")
  add("sin maná",                               "oom",                                "空蓝")
  add("estoy oom",                              "i am oom",                           "我空蓝了")
  add("curame",                                 "heal me",                            "加血")
  add("limpiame",                               "cleanse me",                         "驱散我")
  add("quítame el debuff",                      "dispel my debuff",                   "驱散我")
  add("ponme escudo",                           "shield me",                          "给个盾")
  add("invócame por favor",                     "summon me plz",                      "拉我一下")
  add("dame agua del mago",                     "give me mage water",                 "给点水")
  add("dame comida del mago",                   "give me mage food",                  "给点面包")
  add("usa la piedra de hogar",                 "hearthstone",                        "炉石")
  add("piedra de invocación lista",             "summoning stone is up",              "拉人石已就绪")
  add("están todos en la piedra",               "everyone at the stone",              "都来石头`这")
  add("necesito invocación",                    "i need a summon",                    "求拉")
  add("invócame a la mazmorra",                 "summon me to the dungeon",           "拉我进本")
  add("listo para el pull",                     "ready to pull",                      "准备开怪")
  add("empezamos cuando quieran",               "ready when you are",                 "随时可以")
  add("hacemos el pull en",                     "pulling in",                         "开怪倒计时")
  add("pullcando",                              "pulling",                            "开怪")
  add("preparados para el pull",                "ready for pull",                     "开怪准备")
  add("pull fallido",                           "bad pull",                           "开怪失误")
  add("se me fue el pull",                      "lost the pull",                      "没拉住")
  add("aggro al healer",                        "healer has aggro",                   "奶妈OT了")
  add("el healer está muriendo",                "healer is dying",                    "奶妈快死了")
  add("necesito rez",                           "need a rez",                         "求复活")
  add("néceito resurección",                    "need a resurrection",                "求复活")
  add("me puedes rezar",                        "can you rez me",                     "能拉我吗")
  add("dame rez",                               "rez me",                             "拉我")
  add("reu en la piedra",                       "regroup at stone",                   "石头处集合")
  add("vayan a reparar",                        "go repair",                          "去修理")
  add("queda poco tiempo",                      "running out of time",                "时间不够了")
  add("nos hemos quedado sin tiempo",           "out of time",                        "没时间了")
  add("empezamos otra vez",                     "starting again",                     "重新开始")
  add("siguiente pull",                         "next pull",                          "下一个")
  add("boss directo",                           "straight to the boss",               "直奔BOSS")

  -- ╔══════════════════════════════════════════════╗
  -- ║  CAT 26: SLOTS DE EQUIPO Y OBJETOS           ║
  -- ╚══════════════════════════════════════════════╝
  add("cabeza",                                 "head",                               "头部")
  add("cuello",                                 "neck",                               "颈部")
  add("espalda",                                "back",                               "背部")
  add("capa",                                   "cloak",                              "披风")
  add("pecho",                                  "chest",                              "胸部")
  add("muñecas",                                "wrists",                             "手腕")
  add("brazales",                               "bracers",                            "护腕")
  add("manos",                                  "hands",                              "手部")
  add("guantes",                                "gloves",                             "手套")
  add("cinturón",                               "belt",                               "腰带")
  add("piernas",                                "legs",                               "腿部")
  add("pantalones",                             "pants",                              "裤子")
  add("pies",                                   "feet",                               "脚部")
  add("botas",                                  "boots",                              "靴子")
  add("dedo",                                   "finger",                             "手指")
  add("anillo",                                 "ring",                               "戒指")
  add("amuleto",                                "trinket",                            "饰品")
  add("reliquia",                               "relic",                              "圣物")
  add("off-hand",                               "off hand weapon",                    "副手")
  add("mano secundaria",                        "off hand",                           "副手")
  add("arma principal",                         "main hand",                          "主手")
  add("arma a dos manos",                       "two-handed weapon",                  "双手武器")
  add("arco",                                   "bow",                                "弓")
  add("ballesta",                               "crossbow",                           "弩")
  add("vara",                                   "wand",                               "魔杖")
  add("espada",                                 "sword",                              "单手剑")
  add("hacha",                                  "axe",                                "单手斧")
  add("maza",                                   "mace",                               "单手锤")
  add("bastón de magia",                        "staff",                              "法杖")
  add("daga",                                   "dagger",                             "匕首")
  add("lanza",                                  "polearm",                            "长柄武器")
  add("fist weapon",                            "arma de puño",                       "拳套")
  add("arma de puño",                           "fist weapon",                        "拳套")
  add("escudo",                                 "shield",                             "盾牌")
  add("t1",                                     "tier 1",                             "T1")
  add("t2",                                     "tier 2",                             "T2")
  add("t3",                                     "tier 3",                             "T3")
  add("set de tier uno",                        "tier 1 set",                         "T1套装")
  add("set de tier dos",                        "tier 2 set",                         "T2套装")
  add("set de tier tres",                       "tier 3 set",                         "T3套装")
  add("pieza de set",                           "set piece",                          "套装部位")
  add("bono de set",                            "set bonus",                          "套装属性")
  add("objeto épico",                           "epic item",                          "史诗物品")
  add("objeto raro",                            "rare item",                          "精良物品")
  add("objeto poco común",                      "uncommon item",                      "优秀物品")
  add("objeto legendario",                      "legendary item",                     "传说物品")
  add("purple",                                 "épico",                              "史诗")
  add("naranja",                                "legendary",                          "传说")
  add("azul",                                   "rare",                               "精良")
  add("verde",                                  "uncommon",                           "优秀")
  add("gris",                                   "poor",                               "粗糙")
  add("blanco loot",                            "common loot",                        "普通掉落")
  add("pre-bis",                                "pre best in slot",                   "P5毕业前过渡")
  add("bis",                                    "best in slot",                       "毕业装备")
  add("mejor pieza posible",                    "best in slot",                       "毕业装备")
  add("mejora",                                 "upgrade",                            "提升")
  add("no es mejora para mí",                   "not an upgrade for me",              "对我没有提升")
  add("es mejora para mí",                      "it's an upgrade for me",             "对我是提升")

  -- ╔══════════════════════════════════════════════╗
  -- ║  CAT 27: MISIONES Y PROGRESIÓN               ║
  -- ╚══════════════════════════════════════════════╝
  add("misión",                                 "quest",                              "任务")
  add("misiones",                               "quests",                             "任务")
  add("registro de misiones",                   "quest log",                          "任务日志")
  add("completar misión",                       "complete quest",                     "完成任务")
  add("entregar misión",                        "turn in quest",                      "交任务")
  add("recompensa de misión",                   "quest reward",                       "任务奖励")
  add("misión de cadena",                       "chain quest",                        "系列任务")
  add("misión de raid",                         "raid quest",                         "团本任务")
  add("misión de élite",                        "elite quest",                        "精英任务")
  add("misión diaria",                          "daily quest",                        "日常任务")
  add("misión semanal",                         "weekly quest",                       "周常任务")
  add("reputación",                             "reputation",                         "声望")
  add("rep",                                    "reputation",                         "声望")
  add("neutral",                                "neutral",                            "中立")
  add("amistoso",                               "friendly",                           "友好")
  add("honorable",                              "honored",                            "尊敬")
  add("reverenciado",                           "revered",                            "敬重")
  add("exaltado",                               "exalted",                            "崇拜")
  add("odiado",                                 "hated",                              "仇恨")
  add("hostil",                                 "hostile",                            "敌对")
  add("grindear reputación",                    "grind reputation",                   "刷声望")
  add("grindear rep",                           "rep grind",                          "刷声望")
  add("experiencia",                            "experience",                         "经验")
  add("xp",                                     "experience",                         "经验")
  add("nivel",                                  "level",                              "等级")
  add("subir nivel",                            "level up",                           "升级")
  add("dinged",                                 "subí de nivel",                      "升级了")
  add("ding",                                   "subí de nivel",                      "升级了")
  add("bienvenido al nivel 60",                 "welcome to level 60",                "欢迎来到60级")
  add("llegar al máximo",                       "hit max level",                      "满级了")
  add("nivel máximo",                           "max level",                          "最高等级")
  add("al 60",                                  "at level 60",                        "在60级")
  add("montura",                                "mount",                              "坐骑")
  add("75 de montura",                          "60 percent mount",                   "小马")
  add("100 de montura",                         "100 percent mount",                  "大马")
  add("montura épica",                          "epic mount",                         "千金马")

  -- ╔══════════════════════════════════════════════╗
  -- ║  CAT 28: ETIQUETA SOCIAL Y CLIMA             ║
  -- ╚══════════════════════════════════════════════╝
  add("muchas gracias por el grupo",            "tyvm for the group",                 "谢谢队伍")
  add("buena suerte con los drops",             "gl with drops",                      "祝你好运")
  add("felicidades por el nivel",               "gz on the level",                    "恭喜升级")
  add("felicidades por el logro",               "gz on the achievement",              "恭喜成就")
  add("felicidades",                            "grats",                              "恭喜")
  add("que tengas un buen dia",                 "have a nice day",                    "祝你今天过得愉快")
  add("que pases una buena noche",              "have a good night",                  "祝你今晚过得愉快")
  add("que descanses",                          "get some rest",                      "多休息")
  add("cuídate",                                "take care",                          "保重")
  add("saludos",                                "greetings",                          "你好")
  add("saludos a todos",                        "greetings everyone",                 "大家好")
  add("nos vemos en el juego",                  "see you in game",                    "游戏中见")
  add("hasta pronto",                           "see you soon",                       "回头见")
  add("mañana jugamos",                         "let's play tomorrow",                "明天一起玩")
  add("fue divertido",                          "that was fun",                       "挺有趣的")
  add("mal día para jugar",                     "bad day to play",                    "今天不适合玩游戏")
  add("estoy tilteado",                         "i'm tilted",                         "我心态炸了")
  add("me toca descansar",                      "gotta take a break",                 "我得去休息了")
  add("gracias por la raid",                    "thanks for the raid",                "谢谢活动")
  add("buen pull",                              "nice pull",                          "拉得漂亮")
  add("buen intento",                           "good attempt",                       "尽力了")
  add("casi lo logramos",                       "so close",                           "太可惜了")
  add("la próxima vez",                         "next time",                          "下次一定")
  add("el destino nos tiene en mente",          "destiny has us in mind",             "缘分啊")

  -- ╔══════════════════════════════════════════════╗
  -- ║  CAT 29: EMOTES Y EXPRESIONES               ║
  -- ╚══════════════════════════════════════════════╝
  add("jajaja",                                 "lol",                                "哈哈哈")
  add("muerto de risa",                         "lmao",                               "笑死我了")
  add("que gracioso",                           "so funny",                           "太搞笑了")
  add("me haces reír",                          "you make me laugh",                  "你把我逗笑了")
  add("no puede ser",                           "no way",                             "不可能")
  add("impresionante",                          "impressive",                         "厉害")
  add("increíble",                              "incredible",                         "牛逼")
  add("brutal",                                 "sick",                               "牛逼")
  add("dios mío",                               "oh my god",                          "我的天啊")
  add("ay no",                                  "oh no",                              "噢不")
  add("qué lastima",                            "that's a shame",                     "太遗憾了")
  add("qué pena",                               "what a shame",                       "太遗憾了")
  add("buenísimo",                              "awesome",                            "太棒了")
  add("genial",                                 "great",                              "好极了")
  add("extraordinario",                         "extraordinary",                      "非凡的")
  add("clásico",                                "classic",                            "经典")
  add("qué momento",                            "what a moment",                      "太震撼了")
  add("eso duele",                              "that hurts",                         "好痛")
  add("nooo",                                   "noooo",                              "不啊")
  add("siii",                                   "yesss",                              "耶")
  add("eso estuvo bien",                        "that was nice",                      "干得漂亮")
  add("mal jugado",                             "bad play",                           "失误了")
  add("bien jugado",                            "well played",                        "打得好")
  add("nunca me canso de esto",                 "never get tired of this",            "永远玩不腻")
  add("primera vez",                            "first time",                         "第一次")
  add("nunca lo había visto",                   "never seen this before",             "见所未见")
  add("qué suerte",                             "so lucky",                           "运气太好了")
  add("qué mala suerte",                        "so unlucky",                         "运气太差了")
  add("drop increíble",                         "amazing drop",                       "大红手")
  add("no cayó nada",                           "nothing dropped",                    "黑手")
  add("maldito rng",                            "damn rng",                           "垃圾随机机制")
  add("el rng no me quiere",                    "rng hates me",                       "发牌员针对我")

  -- ╔══════════════════════════════════════════════╗
  -- ║  CAT 30: MECÁNICAS DE JUEGO Y UI             ║
  -- ╚══════════════════════════════════════════════╝
  add("addon",                                  "addon",                              "插件")
  add("interfaz de usuario",                    "user interface",                     "界面")
  add("lag",                                    "lag",                                "卡")
  add("latencia",                               "latency",                            "延迟")
  add("ping",                                   "ping",                               "网络延迟")
  add("desconectado",                           "disconnected",                       "掉线")
  add("dc",                                     "disconnected",                       "掉线")
  add("se desconectó",                          "got disconnected",                   "掉线了")
  add("crasheó el juego",                       "game crashed",                       "游戏闪退")
  add("bajo fps",                               "low fps",                            "掉帧")
  add("estoy congelado",                        "i'm frozen",                         "我画面冻结了")
  add("me lageo",                               "i'm lagging",                        "我卡了")
  add("bug del juego",                          "game bug",                           "游戏BUG")
  add("error del servidor",                     "server error",                       "服务器错误")
  add("caída del servidor",                     "server crash",                       "服务器宕机")
  add("mantenimiento del servidor",             "server maintenance",                 "服务器维护")
  add("reinicio del servidor",                  "server restart",                     "服务器重启")
  add("reportar un bug",                        "report a bug",                       "反馈BUG")
  add("barra de acción",                        "action bar",                         "动作条")
  add("barra de salud",                         "health bar",                         "生命条")
  add("barra de maná",                          "mana bar",                           "法力条")
  add("barra de energía",                       "energy bar",                         "能量条")
  add("barra de rabia",                         "rage bar",                           "怒气条")
  add("marcos de unidad",                       "unit frames",                        "头像框架")
  add("marco del jugador",                      "player frame",                       "玩家头像")
  add("marco del objetivo",                     "target frame",                       "目标头像")
  add("mapa del mundo",                         "world map",                          "世界地图")
  add("minimapa",                               "minimap",                            "小地图")
  add("hoja de personaje",                      "character sheet",                    "角色面板")
  add("árbol de talentos",                      "talent tree",                        "天赋树")
  add("talentos",                               "talents",                            "天赋")
  add("respeccear",                             "respec",                             "洗天赋")
  add("resetear talentos",                      "reset talents",                      "重置天赋")
  add("libro de hechizos",                      "spellbook",                          "技能书")
  add("habilidades",                            "abilities",                          "技能")
  add("bolsa",                                  "bag",                                "背包")
  add("mochila",                                "backpack",                           "双肩包")
  add("inventario lleno",                       "bags are full",                      "背包满了")
  add("bolsas llenas",                          "bags are full",                      "背包满了")
  add("necesito bolsas más grandes",            "need bigger bags",                   "需要大包")
  add("vendor",                                 "vendedor",                           "商人")
  add("vendedor",                               "vendor",                             "商人")
  add("comprar materiales",                     "buy mats",                           "买材料")
  add("vender basura",                          "sell junk",                          "卖垃圾")
  add("vender todo gris",                       "sell all grey",                      "一键卖灰")
  add("reparar equipo",                         "repair gear",                        "修装备")
  add("macros",                                 "macros",                             "宏")
  add("configuracion del juego",                "game settings",                      "设置")
  add("volumen de música",                      "music volume",                       "音乐音量")
  add("volumen de efectos",                     "sfx volume",                         "音效音量")
  add("captura de pantalla",                    "screenshot",                         "截图")
  add("sacar foto",                             "take screenshot",                    "截图")

  -- ╔══════════════════════════════════════════════╗
  -- ║  CAT 31: NÚMEROS Y CANTIDADES                ║
  -- ╚══════════════════════════════════════════════╝
  add("uno más",                                "1 more",                             "缺一")
  add("dos más",                                "2 more",                             "缺二")
  add("tres más",                               "3 more",                             "缺三")
  add("cuatro más",                             "4 more",                             "缺四")
  add("cinco más",                              "5 more",                             "缺五")
  add("primer intento",                         "first attempt",                      "第一次尝试")
  add("segundo intento",                        "second attempt",                     "第二次尝试")
  add("estamos en progresión",                  "we are progressing",                 "开荒中")
  add("primer kill",                            "first kill",                         "首杀")
  add("nuevo récord",                           "new record",                         "新纪录")
  add("record del servidor",                    "server record",                      "服务器纪录")
  add("record de guild",                        "guild record",                       "公会纪录")
  add("cien mil de oro",                        "100k gold",                          "十万金")
  add("mil de oro",                             "1k gold",                            "千金")
  add("cien de oro",                            "100 gold",                           "百金")
  add("cuánto oro",                             "how much gold",                      "多少金币")
  add("oro de la semana",                       "weekly gold",                        "周金")
  add("costos de reparación",                   "repair costs",                       "修理费")

  -- ╔════════════════════════════════════════════════════════════════╗
  -- ║  CAT 32: VOCABULARIO ESPECÍFICO CHINO (TRILINGÜE OMNI-TIER)    ║
  -- ╚════════════════════════════════════════════════════════════════╝
  add("afk",                                    "fuera del teclado",                  "离开")
  add("brb",                                    "vuelvo enseguida",                   "马上回来")
  add("omw",                                    "en camino",                          "在路上")
  add("lfg",                                    "busco grupo",                        "寻找队伍")
  add("lfm",                                    "busco mas",                          "寻找更多人")
  add("inv",                                    "invitame",                           "求组")
  add("tanque",                                 "tank",                               "坦克")
  add("sanador",                                "healer",                             "治疗")
  add("dps",                                    "dps",                                "输出")
  add("guerrero",                               "warrior",                            "战士")
  add("mago",                                   "mage",                               "法师")
  add("sacerdote",                              "priest",                             "牧师")
  add("pícaro",                                 "rogue",                              "盗贼")
  add("brujo",                                  "warlock",                            "术士")
  add("cazador",                                "hunter",                             "猎人")
  add("paladín",                                "paladin",                            "圣骑士")
  add("chamán",                                 "shaman",                             "萨满")
  add("druida",                                 "druid",                              "德鲁伊")
  add("minas de la muerte",                     "deadmines",                          "死亡矿井")
  add("cavernas de los lamentos",               "wailing caverns",                    "哀嚎洞穴")
  add("monasterio escarlata",                   "scarlet monastery",                  "血色修道院")
  add("profundidades de rocanegra",             "blackrock depths",                   "黑石深渊")
  add("brd",                                    "profundidades de rocanegra",         "黑石深渊")
  add("núcleo de magma",                        "molten core",                        "熔火之心")
  add("guarida alanegra",                       "blackwing lair",                     "黑翼之巢")
  add("guarida de onyxia",                      "onyxia's lair",                      "奥妮克希亚的巢穴")
  add("naxxramas",                              "naxxramas",                          "纳克萨玛斯")
  add("vendo",                                  "wts",                                "出售")
  add("compro",                                 "wtb",                                "求购")
  add("cambio",                                 "wtt",                                "交换")
  add("oro",                                    "gold",                               "金币")
  add("subasta",                                "ah",                                 "拍卖行")
  add("ventormenta",                            "stormwind",                          "暴风城")
  add("forjaz",                                 "ironforge",                          "铁炉堡")
  add("orgrimmar",                              "orgrimmar",                          "奥格瑞玛")
  add("cima del trueno",                        "thunder bluff",                      "雷霆崖")
  add("entrañas",                               "undercity",                          "幽暗城")
  add("darnassus",                              "darnassus",                          "达纳苏斯")
  add("ayuda",                                  "help",                               "救命")
  add("hola",                                   "hello",                              "你好")
  add("gracias",                                "thanks",                             "谢谢")
  add("de nada",                                "you are welcome",                    "不客气")
  add("es",                                     "is",                                 "是")
  add("sí",                                     "yes",                                "是的")
  add("sí",                                     "yes",                                "对")
  add("tanque",                                 "tank",                               "坦")
  add("sanador",                                "healer",                             "奶")
  add("lamentos",                               "wc",                                 "哀嚎")
  add("no",                                     "no",                                 "否")
  add("vamos",                                  "let's go",                           "出发")
  add("cuidado",                                "watch out",                          "小心")
  add("mana",                                   "mana",                               "没蓝")
  add("buff",                                   "buff",                               "加buff")
  add("res",                                    "resurrection",                       "复活")
  add("portal",                                 "portal",                             "开门")
  add("agua",                                   "water",                              "做水")
  add("comida",                                 "food",                               "面包")
  add("piedra de hogar",                        "hearthstone",                        "炉石")
  add("necesito",                               "need",                               "需要")
  add("vengan",                                 "come",                               "来")
  add("hacer mazmorra",                         "do dungeon",                         "打本")
  add("modo guerra",                            "war mode",                           "战争模式")
  add("guerra",                                 "war",                                "战争")
  add("tortuga",                                "turtle",                             "乌龟")
  add("ok",                                     "ok",                                 "好的")
  add("bastón",                                 "staff",                              "法杖")
  add("fusionar servidores",                    "merge servers",                      "合服")
  add("fusionar",                               "merge",                              "合并")
  add("servidor",                               "server",                             "服务器")
  add("servidor",                               "server",                             "服")
  add("servidor base",                          "base server",                        "基服")
  add("anuncio",                                "announcement",                       "公告")
  add("datos",                                  "data",                               "数据")
  add("recuperar",                              "restore",                            "恢复")
  add("fin de mes",                             "end of month",                       "月底")
  add("próximo mes",                            "next month",                         "下个月")
  add("mediados de mes",                        "mid-month",                          "中旬")
  add("cuándo",                                 "when",                               "什么时候")
  add("nuevo",                                  "new",                                "新开")
  add("mantenimiento",                          "maintenance",                        "维护")
  add("actualizar",                             "update",                             "更新")
  add("reinicio",                               "restart",                            "重启")
  add("cola",                                   "queue",                              "排队")
  add("lag",                                    "lag",                                "卡")
  add("desconexión",                            "disconnect",                         "掉线")

  -- ╔══════════════════════════════════════════════╗
  -- ║  [NUEVO] CAT 08b: Razas                      ║
  -- ╚══════════════════════════════════════════════╝
  add("humano",                                 "human",                              "人类")
  add("enano",                                  "dwarf",                              "矮人")
  add("gnomo",                                  "gnome",                              "侏儒")
  add("elfo de la noche",                       "night elf",                          "暗夜精灵")
  add("elfo",                                   "elf",                                "精灵")
  add("orco",                                   "orc",                                "兽人")
  add("no-muerto",                              "undead",                             "亡灵")
  add("no muerto",                              "undead",                             "亡灵")
  add("tauren",                                 "tauren",                             "牛头人")
  add("trol",                                   "troll",                              "巨魔")
  add("troll",                                  "troll",                              "巨魔")
  add("goblin",                                 "goblin",                             "地精")
  add("alto elfo",                              "high elf",                           "高等精灵")

  -- ╔══════════════════════════════════════════════╗
  -- ║  [NUEVO] CAT 33: Mascotas y Demonios         ║
  -- ╚══════════════════════════════════════════════╝
  add("diablillo",                              "imp",                                "小鬼")
  add("abisario",                               "voidwalker",                         "虚空行者")
  add("sucubo",                                 "succubus",                           "魅魔")
  add("súcubo",                                 "succubus",                           "魅魔")
  add("manáfago",                               "felhunter",                          "地狱犬")
  add("manafago",                               "felhunter",                          "地狱犬")
  add("guardia apocalíptico",                   "doomguard",                          "末日守卫")
  add("infernal",                               "infernal",                           "地狱火")
  add("mascota",                                "pet",                                "宠物")
  add("oso",                                    "bear",                               "熊")
  add("jabalí",                                 "boar",                               "野猪")
  add("jabali",                                 "boar",                               "野猪")
  add("gato",                                   "cat",                                "猫")
  add("lobo",                                   "wolf",                               "狼")

  -- ╔══════════════════════════════════════════════╗
  -- ║  [NUEVO] CAT 34: Facciones y Reputación      ║
  -- ╚══════════════════════════════════════════════╝
  add("alba argenta",                           "argent dawn",                        "银色黎明")
  add("cenarion",                               "cenarion circle",                    "塞纳里奥议会")
  add("círculo cenarion",                       "cenarion circle",                    "塞纳里奥议会")
  add("tribu zandalar",                         "zandalar tribe",                     "赞达拉部族")
  add("linaje de nozdormu",                     "brood of nozdormu",                  "诺兹多姆的子嗣")
  add("hermandad del torio",                    "thorium brotherhood",                "瑟银兄弟会")
  add("clarividentes",                          "timbermaw hold",                     "木喉要塞")
  add("fauces de madera",                       "timbermaw hold",                     "木喉要塞")
  add("reputación",                             "reputation",                         "声望")
  add("reputacion",                             "reputation",                         "声望")
  add("exaltado",                               "exalted",                            "崇拜")
  add("venerado",                               "revered",                            "崇敬")
  add("honorable",                              "honored",                            "尊敬")
  add("amistoso",                               "friendly",                           "友善")
  add("neutral",                                "neutral",                            "中立")

  -- ╔══════════════════════════════════════════════╗
  -- ║  [NUEVO] CAT 35: Encantamientos Comunes      ║
  -- ╚══════════════════════════════════════════════╝
  add("cruzado",                                "crusader",                           "十字军")
  add("arma ígnea",                             "fiery weapon",                       "烈焰")
  add("arma ignea",                             "fiery weapon",                       "烈焰")
  add("robo de vida",                           "lifestealing",                       "生命偷取")
  add("mangosta",                               "mongoose",                           "猫鼬")
  add("agilidad",                               "agility",                            "敏捷")
  add("fuerza",                                 "strength",                           "力量")
  add("intelecto",                              "intellect",                          "智力")
  add("espíritu",                               "spirit",                             "精神")
  add("espiritu",                               "spirit",                             "精神")
  add("aguante",                                "stamina",                            "耐力")
  add("poder de hechizos",                      "spell power",                        "法术能量")
  add("poder de sanación",                      "healing power",                      "治疗能量")

  -- ╔══════════════════════════════════════════════╗
  -- ║  [NUEVO] CAT 36: Comida de Buff              ║
  -- ╚══════════════════════════════════════════════╝
  add("delicia de pez descarriado",             "savory deviate delight",             "美味风蛇")
  add("sopa de aleta nocturna",                 "nightfin soup",                      "夜鳞鱼汤")
  add("calamar a la parrilla",                  "grilled squid",                      "烤鱿鱼")
  add("chuletón de lobo tierno",                "tender wolf steak",                  "嫩狼肉排")
  add("chuleton de lobo tierno",                "tender wolf steak",                  "嫩狼肉排")
  add("albóndigas del desierto ahumadas",       "smoked desert dumplings",            "沙漠肉丸子")
  add("albondigas del desierto ahumadas",       "smoked desert dumplings",            "沙漠肉丸子")
  add("té de cardo",                            "thistle tea",                        "菊花茶")
  add("te de cardo",                            "thistle tea",                        "菊花茶")
  add("pocion de sangre de mago",               "mageblood potion",                   "魔血药水")
  add("poción de sangre de mago",               "mageblood potion",                   "魔血药水")

  -- ╔══════════════════════════════════════════════╗
  -- ║  [NUEVO] CAT 37: Mazmorras Faltantes         ║
  -- ╚══════════════════════════════════════════════╝
  add("mazmorras de ventormenta",               "stockades",                          "监狱")
  add("stockades",                              "stockades",                          "监狱")
  add("templo sumergido",                       "sunken temple",                      "神庙")
  add("templo",                                 "sunken temple",                      "神庙")
  add("tributo",                                "dm tribute",                         "厄运贡品")
  add("scholo",                                 "scholomance",                        "通灵")
  add("estrat",                                 "stratholme",                         "斯坦索姆")

  -- ╔══════════════════════════════════════════════╗
  -- ║  [NUEVO] CAT 38: Habilidades de Clase Extra  ║
  -- ╚══════════════════════════════════════════════╝
  -- Warrior
  add("abrumar",                                "overpower",                          "压制")
  add("atrueno",                                "thunder clap",                       "雷霆一击")
  add("grito desmoralizador",                   "demoralizing shout",                 "挫志怒吼")
  add("desgarrar",                              "rend",                               "撕裂")
  add("rajar",                                  "cleave",                             "顺劈斩")
  add("embate",                                 "slam",                               "猛击")
  add("bloquear con escudo",                    "shield block",                       "盾牌格挡")
  add("desarmar",                               "disarm",                             "缴械")
  -- Rogue
  add("gubia",                                  "gouge",                              "凿击")
  add("esprintar",                              "sprint",                             "疾跑")
  add("patada",                                 "kick",                               "脚踢")
  add("estocada",                               "riposte",                            "还击")
  add("preparación",                            "preparation",                        "伺机待发")
  add("preparacion",                            "preparation",                        "伺机待发")
  add("aluvión de acero",                       "blade flurry",                       "剑刃乱舞")
  -- Shaman
  add("arma viento furioso",                    "windfury weapon",                    "风怒武器")
  add("arma muerdepiedras",                     "rockbiter weapon",                   "石化武器")
  add("purgar",                                 "purge",                              "净化术")
  add("vista lejana",                           "far sight",                          "视界术")
  add("regreso astral",                         "astral recall",                      "星界传送")
  -- Druid
  add("carga feral",                            "feral charge",                       "野性冲锋")
  add("azotar",                                 "bash",                               "猛击")
  add("abalanzarse",                            "pounce",                             "突袭")
  add("zarpa",                                  "claw",                               "爪击")
  add("triturar",                               "shred",                              "撕碎")
  add("marca de lo salvaje",                    "mark of the wild",                   "野性印记")
  add("espinas",                                "thorns",                             "荆棘术")
  add("suprimir veneno",                        "abolish poison",                     "驱毒术")
  -- Hunter
  add("matar",                                  "kill command",                       "杀戮命令")
  add("fuego rápido",                           "rapid fire",                         "急速射击")
  add("fuego rapido",                           "rapid fire",                         "急速射击")
  add("contraataque",                           "counterattack",                      "反击")
  add("disparo de dispersión",                  "scatter shot",                       "驱散射击")
  add("disparo de dispersion",                  "scatter shot",                       "驱散射击")
  add("presteza",                               "readiness",                          "准备就绪")
  add("salva",                                  "volley",                             "乱射")
  -- Paladin
  add("ahuyentar el mal",                       "turn evil",                          "超度邪恶")
  add("arrepentimiento",                        "repentance",                         "忏悔")
  add("sello de luz",                           "seal of light",                      "光明圣印")
  add("sello de sangre",                        "seal of blood",                      "鲜血圣印")
  add("escudo sagrado",                         "holy shield",                        "神圣之盾")
  add("exorcismo",                              "exorcism",                           "驱邪术")
  -- Priest
  add("fuego interno",                          "inner fire",                         "心灵之火")
  add("levitar",                                "levitate",                           "漂浮术")
  add("control mental",                         "mind control",                       "精神控制")
  add("retroalimentación",                      "feedback",                           "回馈")
  add("retroalimentacion",                      "feedback",                           "回馈")
  add("encadenar no-muerto",                    "shackle undead",                     "束缚亡灵")
  add("entereza",                               "fortitude",                          "坚韧")
  add("protección contra las sombras",          "shadow protection",                  "暗影防护")
  add("proteccion contra las sombras",          "shadow protection",                  "暗影防护")
  -- Mage
  add("agostar",                                "scorch",                             "灼烧")
  add("piroexplosión",                          "pyroblast",                          "炎爆术")
  add("piroexplosion",                          "pyroblast",                          "炎爆术")
  add("escudo de maná",                         "mana shield",                        "法力护盾")
  add("escudo de mana",                         "mana shield",                        "法力护盾")
  add("armadura de hielo",                      "ice armor",                          "冰甲术")
  add("armadura de escarcha",                   "frost armor",                        "霜甲术")
  add("amplificar magia",                       "amplify magic",                      "魔法增效")
  add("atenuar magia",                          "dampen magic",                       "魔法抑制")
  add("aliento de dragón",                      "dragon's breath",                    "龙息术")
  add("aliento de dragon",                      "dragon's breath",                    "龙息术")
  -- Warlock
  add("maestría de las sombras",                "shadow mastery",                     "暗影掌握")
  add("maestria de las sombras",                "shadow mastery",                     "暗影掌握")
  add("transfusión de vida",                    "life tap",                           "生命分流")
  add("transfusion de vida",                    "life tap",                           "生命分流")
  add("pacto oscuro",                           "dark pact",                          "黑暗契约")
  add("bloqueo de hechizo",                     "spell lock",                         "法术封锁")
  add("aullido de terror",                      "howl of terror",                     "恐惧嚎叫")

  -- ╔══════════════════════════════════════════════╗
  -- ║  [NUEVO] CAT 39: Saludos y Cortesía          ║
  -- ╚══════════════════════════════════════════════╝
  add("buenos días",                            "good morning",                       "早上好")
  add("buenos dias",                            "good morning",                       "早上好")
  add("buenas tardes",                          "good afternoon",                     "下午好")
  add("buenas noches",                          "good night",                         "晚上好")
  add("cómo estás",                             "how are you",                        "你好吗")
  add("como estas",                             "how are you",                        "你好吗")
  add("qué tal",                                "what's up",                          "怎么样")
  add("que tal",                                "what's up",                          "怎么样")
  add("muy bien",                               "very well",                          "很好")
  add("todo bien",                              "all good",                           "都挺好")
  add("gracias a ti",                           "thank you too",                      "也谢谢你")
  add("por favor",                              "please",                             "请")
  add("mucho gusto",                            "nice to meet you",                   "很高兴认识你")
  add("bienvenido",                             "welcome",                            "欢迎")
  add("bienvenidos",                            "welcome everyone",                   "欢迎大家")
  add("hasta luego",                            "see you later",                      "回头见")
  add("hasta pronto",                           "see you soon",                       "一会见")
  add("cuídate",                                "take care",                          "保重")
  add("cuidate",                                "take care",                          "保重")
  add("buen trabajo",                           "good job",                           "干得好")

  -- ╔══════════════════════════════════════════════╗
  -- ║  [NUEVO] CAT 40: Preguntas Diarias           ║
  -- ╚══════════════════════════════════════════════╝
  add("de dónde eres",                          "where are you from",                 "你来自哪里")
  add("de donde eres",                          "where are you from",                 "你来自哪里")
  add("hablas inglés",                          "do you speak english",               "你会说英语吗")
  add("hablas ingles",                          "do you speak english",               "你会说英语吗")
  add("hablas español",                         "do you speak spanish",               "你会说西班牙语吗")
  add("hablas espanol",                         "do you speak spanish",               "你会说西班牙语吗")
  add("qué significa eso",                      "what does that mean",                "那是什么意思")
  add("que significa eso",                      "what does that mean",                "那是什么意思")
  add("qué pasó",                               "what happened",                      "发生什么了")
  add("que paso",                               "what happened",                      "发生什么了")
  add("cuánto cuesta",                          "how much is it",                     "多少钱")
  add("cuanto cuesta",                          "how much is it",                     "多少钱")
  add("me ayudas",                              "can you help me",                    "能帮帮我吗")
  add("puedes ayudarme",                        "can you help me",                    "能帮帮我吗")
  add("a dónde vamos",                          "where are we going",                 "我们去哪")
  add("a donde vamos",                          "where are we going",                 "我们去哪")
  add("por qué",                                "why",                                "为什么")
  add("por que",                                "why",                                "为什么")
  add("cuándo",                                 "when",                               "什么时候")
  add("cuando",                                 "when",                               "什么时候")
  add("dónde estás",                            "where are you",                      "你在哪")
  add("donde estas",                            "where are you",                      "你在哪")
  add("quién es",                               "who is it",                          "是谁")
  add("quien es",                               "who is it",                          "是谁")
  add("qué haces",                              "what are you doing",                 "你在干嘛")
  add("que haces",                              "what are you doing",                 "你在干嘛")

  -- ╔══════════════════════════════════════════════╗
  -- ║  [NUEVO] CAT 41: Respuestas Básicas          ║
  -- ╚══════════════════════════════════════════════╝
  add("sí",                                     "yes",                                "是的")
  add("si",                                     "yes",                                "是的")
  add("no",                                     "no",                                 "不")
  add("tal vez",                                "maybe",                              "也许")
  add("puede ser",                              "perhaps",                            "可能")
  add("no sé",                                  "i don't know",                       "我不知道")
  add("no se",                                  "i don't know",                       "我不知道")
  add("por supuesto",                           "of course",                          "当然")
  add("claro",                                  "sure",                               "好的")
  add("imposible",                              "impossible",                         "不可能")
  add("tienes razón",                           "you are right",                      "你说得对")
  add("tienes razon",                           "you are right",                      "你说得对")
  add("estás equivocado",                       "you are wrong",                      "你错了")
  add("estas equivocado",                       "you are wrong",                      "你错了")
  add("ahora no",                               "not now",                            "现在不行")
  add("después",                                "later",                              "以后")
  add("despues",                                "later",                              "以后")
  add("no hay problema",                        "no problem",                         "没问题")
  add("listo",                                  "ready",                              "准备好了")

  -- ╔══════════════════════════════════════════════╗
  -- ║  [NUEVO] CAT 42: Estados y Emociones         ║
  -- ╚══════════════════════════════════════════════╝
  add("tengo hambre",                           "i'm hungry",                         "我饿了")
  add("voy a comer",                            "i'm going to eat",                   "我去吃饭了")
  add("estoy trabajando",                       "i'm working",                        "我在工作")
  add("estoy estudiando",                       "i'm studying",                       "我在学习")
  add("me voy a dormir",                        "i'm going to sleep",                 "我去睡觉了")
  add("tengo sueño",                            "i'm sleepy",                         "我困了")
  add("estoy aburrido",                         "i'm bored",                          "我很无聊")
  add("qué gracioso",                           "how funny",                          "真好笑")
  add("que gracioso",                           "how funny",                          "真好笑")
  add("estoy enojado",                          "i'm angry",                          "我很生气")
  add("estoy feliz",                            "i'm happy",                          "我很高兴")
  add("estoy triste",                           "i'm sad",                            "我很伤心")
  add("estoy cansado",                          "i'm tired",                          "我很累")
  add("estoy ocupado",                          "i'm busy",                           "我很忙")
  add("hermano",                                "brother",                            "兄弟")
  add("amigo",                                  "friend",                             "朋友")
  add("compañero",                              "mate",                               "伙伴")

  -- ╔══════════════════════════════════════════════╗
  -- ║  [NUEVO] CAT 43: Verbos Comunes Imperativos  ║
  -- ╚══════════════════════════════════════════════╝
  add("vengan",                                 "come",                               "来")
  add("ven",                                    "come",                               "来")
  add("ve",                                     "go",                                 "去")
  add("mira",                                   "look",                               "看")
  add("escucha",                                "listen",                             "听")
  add("compra",                                 "buy",                                "买")
  add("vende",                                  "sell",                               "卖")
  add("espera",                                 "wait",                               "等")
  add("ayuda",                                  "help",                               "帮")
  add("sigue",                                  "follow",                             "跟着")
  add("habla",                                  "speak",                              "说")
  add("ataca",                                  "attack",                             "攻击")
  add("corre",                                  "run",                                "跑")
  add("para",                                   "stop",                               "停")
  add("cura",                                   "heal",                               "治疗")
  add("retrocede",                              "fall back",                          "后退")
  add("avanza",                                 "move forward",                       "前进")
  add("reagrupar",                              "regroup",                            "重新集结")

  -- ╔══════════════════════════════════════════════╗
  -- ║  [NUEVO] CAT 44: Sustantivos / Adjetivos     ║
  -- ╚══════════════════════════════════════════════╝
  add("bueno",                                  "good",                               "好")
  add("malo",                                   "bad",                                "坏")
  add("grande",                                 "big",                                "大")
  add("pequeño",                                "small",                              "小")
  add("pequeno",                                "small",                              "小")
  add("rápido",                                 "fast",                               "快")
  add("rapido",                                 "fast",                               "快")
  add("lento",                                  "slow",                               "慢")
  add("fácil",                                  "easy",                               "简单")
  add("facil",                                  "easy",                               "简单")
  add("difícil",                                "hard",                               "难")
  add("dificil",                                "hard",                               "难")
  add("nuevo",                                  "new",                                "新")
  add("viejo",                                  "old",                                "旧")
  add("caro",                                   "expensive",                          "贵")
  add("barato",                                 "cheap",                              "便宜")
  add("dinero",                                 "money",                              "钱")
  add("oro",                                    "gold",                               "金币")
  add("grupo",                                  "group",                              "队伍")
  add("equipo",                                 "team",                               "团队")

  -- ╔══════════════════════════════════════════════╗
  -- ║  [NUEVO] CAT 45: Tiempo y Días               ║
  -- ╚══════════════════════════════════════════════╝
  add("hoy",                                    "today",                              "今天")
  add("mañana",                                 "tomorrow",                           "明天")
  add("manana",                                 "tomorrow",                           "明天")
  add("ayer",                                   "yesterday",                          "昨天")
  add("día",                                    "day",                                "天")
  add("dia",                                    "day",                                "天")
  add("noche",                                  "night",                              "晚上")
  add("hora",                                   "hour",                               "小时")
  add("minuto",                                 "minute",                             "分钟")
  add("segundo",                                "second",                             "秒")
  add("ahora",                                  "now",                                "现在")
  add("tarde",                                  "late",                               "晚")
  add("temprano",                               "early",                              "早")
  add("mucho",                                  "much",                               "多")
  add("poco",                                   "little",                             "少")
  add("demasiado",                              "too much",                           "太多")

  -- ╔══════════════════════════════════════════════╗
  -- ║  [NUEVO] CAT 46: Términos Especiales (Fotos) ║
  -- ╚══════════════════════════════════════════════╝
  add("hermandad",                              "guild",                              "工会")
  add("gremio",                                 "guild",                              "工会")
  add("campo de batalla",                       "battleground",                       "战场")
  add("servidor base",                          "base server",                        "基础服务器")
  add("nuevo servidor",                         "new server",                         "新服")
  add("discord",                                "discord",                            "YY")
  add("únete",                                  "join",                               "加入")
  add("unete",                                  "join",                               "加入")
  add("reclutamiento",                          "recruitment",                        "招募")
  add("vengan todos",                           "everyone come",                      "大家一起来")
  add("amigos nuevos y viejos",                 "new and old friends",                "新老朋友")
  add("todos son bienvenidos",                  "everyone is welcome",                "欢迎大家")

  -- ╔══════════════════════════════════════════════╗
  -- ║  [NUEVO] CAT 47: Pronombres y Conectores     ║
  -- ╚══════════════════════════════════════════════╝
  add("yo",                                     "i",                                  "我")
  add("tú",                                     "you",                                "你")
  add("tu",                                     "you",                                "你")
  add("él",                                     "he",                                 "他")
  add("el",                                     "he",                                 "他")
  add("ella",                                   "she",                                "她")
  add("nosotros",                               "we",                                 "我们")
  add("ellos",                                  "they",                               "他们")
  add("ellas",                                  "they",                               "她们")
  add("mi",                                     "my",                                 "我的")
  add("mío",                                    "mine",                               "我的")
  add("mio",                                    "mine",                               "我的")
  add("tuyo",                                   "yours",                              "你的")
  add("nuestro",                                "our",                                "我们的")
  add("su",                                     "his",                                "他的")
  add("sus",                                    "their",                              "他们的")
  add("quién",                                  "who",                                "谁")
  add("quien",                                  "who",                                "谁")
  add("qué",                                    "what",                               "什么")
  add("que",                                    "what",                               "什么")
  add("cómo",                                   "how",                                "怎么")
  add("como",                                   "how",                                "怎么")
  add("cuándo",                                 "when",                               "什么时候")
  add("cuando",                                 "when",                               "什么时候")
  add("dónde",                                  "where",                              "哪里")
  add("donde",                                  "where",                              "哪里")
  add("por qué",                                "why",                                "为什么")
  add("por que",                                "why",                                "为什么")
  add("cuál",                                   "which",                              "哪个")
  add("cual",                                   "which",                              "哪个")
  add("cuánto",                                 "how much",                           "多少")
  add("cuanto",                                 "how much",                           "多少")
  add("y",                                      "and",                                "和")
  add("o",                                      "or",                                 "或者")
  add("pero",                                   "but",                                "但是")
  add("porque",                                 "because",                            "因为")
  add("si",                                     "if",                                 "如果")
  add("con",                                    "with",                               "和")
  add("sin",                                    "without",                            "没有")
  add("para",                                   "for",                                "为了")
  add("de",                                     "from",                               "从")
  add("en",                                     "in",                                 "在")
  add("sobre",                                  "on",                                 "在上面")
  add("antes",                                  "before",                             "之前")
  add("después",                                "after",                              "之后")
  add("despues",                                "after",                              "之后")
  add("siempre",                                "always",                             "总是")
  add("nunca",                                  "never",                              "从不")
  add("también",                                "also",                               "也")
  add("tambien",                                "also",                               "也")
  add("tampoco",                                "neither",                            "也不")
  add("muy",                                    "very",                               "很")
  add("más",                                    "more",                               "更多")
  add("mas",                                    "more",                               "更多")
  add("menos",                                  "less",                               "更少")
  add("todo",                                   "all",                                "所有")
  add("nada",                                   "nothing",                            "什么也没有")
  add("algo",                                   "something",                          "某事")
  add("alguien",                                "someone",                            "某人")

  -- ╔══════════════════════════════════════════════╗
  -- ║  [NUEVO] CAT 48: Sustantivos de Vida Diaria  ║
  -- ╚══════════════════════════════════════════════╝
  add("familia",                                "family",                             "家人")
  add("trabajo",                                "work",                               "工作")
  add("escuela",                                "school",                             "学校")
  add("universidad",                            "university",                         "大学")
  add("casa",                                   "house",                              "房子")
  add("hogar",                                  "home",                               "家")
  add("país",                                   "country",                            "国家")
  add("pais",                                   "country",                            "国家")
  add("ciudad",                                 "city",                               "城市")
  add("música",                                 "music",                              "音乐")
  add("musica",                                 "music",                              "音乐")
  add("película",                               "movie",                              "电影")
  add("pelicula",                               "movie",                              "电影")
  add("internet",                               "internet",                           "网络")
  add("computadora",                            "computer",                           "电脑")
  add("pc",                                     "pc",                                 "电脑")
  add("celular",                                "phone",                              "手机")
  add("teléfono",                               "phone",                              "电话")
  add("comida",                                 "food",                               "食物")
  add("agua",                                   "water",                              "水")
  add("café",                                   "coffee",                             "咖啡")
  add("cafe",                                   "coffee",                             "咖啡")
  add("cerveza",                                "beer",                               "啤酒")
  add("esposa",                                 "wife",                               "妻子")
  add("esposo",                                 "husband",                            "丈夫")
  add("hijo",                                   "son",                                "儿子")
  add("hija",                                   "daughter",                           "女儿")
  add("hijos",                                  "children",                           "孩子们")
  add("padre",                                  "father",                             "父亲")
  add("madre",                                  "mother",                             "母亲")
  add("clima",                                  "weather",                            "天气")

  -- ╔══════════════════════════════════════════════╗
  -- ║  [NUEVO] CAT 49: Verbos Conversacionales     ║
  -- ╚══════════════════════════════════════════════╝
  add("querer",                                 "want",                               "想要")
  add("quiero",                                 "i want",                             "我想要")
  add("quieres",                                "you want",                           "你想要")
  add("necesitar",                              "need",                               "需要")
  add("necesito",                               "i need",                             "我需要")
  add("tener",                                  "have",                               "有")
  add("tengo",                                  "i have",                             "我有")
  add("tienes",                                 "you have",                           "你有")
  add("hacer",                                  "do",                                 "做")
  add("hago",                                   "i do",                               "我做")
  add("saber",                                  "know",                               "知道")
  add("sé",                                     "i know",                             "我知道")
  add("se",                                     "i know",                             "我知道")
  add("sabes",                                  "you know",                           "你知道")
  add("pensar",                                 "think",                              "想")
  add("pienso",                                 "i think",                            "我认为")
  add("decir",                                  "say",                                "说")
  add("digo",                                   "i say",                              "我说")
  add("hablar",                                 "speak",                              "说")
  add("hablo",                                  "i speak",                            "我说")
  add("entender",                               "understand",                         "懂")
  add("entiendo",                               "i understand",                       "我懂")
  add("comer",                                  "eat",                                "吃")
  add("beber",                                  "drink",                              "喝")
  add("dormir",                                 "sleep",                              "睡")
  add("trabajar",                               "work",                               "工作")
  add("estudiar",                               "study",                              "学习")
  add("vivir",                                  "live",                               "生活")
  add("gustar",                                 "like",                               "喜欢")
  add("me gusta",                               "i like",                             "我喜欢")
  add("amar",                                   "love",                               "爱")
  add("odiar",                                  "hate",                               "恨")
  add("ir",                                     "go",                                 "去")
  add("voy",                                    "i go",                               "我去")
  add("venir",                                  "come",                               "来")
  add("jugar",                                  "play",                               "玩")
  add("juego",                                  "i play",                             "我玩")
  add("poder",                                  "can",                                "能")
  add("puedo",                                  "i can",                              "我能")
  add("puedes",                                 "you can",                            "你能")

  -- ╔══════════════════════════════════════════════╗
  -- ║  [NUEVO] CAT 50: Frases Reales (Small Talk)  ║
  -- ╚══════════════════════════════════════════════╝
  add("cuántos años tienes",                    "how old are you",                    "你多大了")
  add("cuantos años tienes",                    "how old are you",                    "你多大了")
  add("en qué trabajas",                        "what do you do for work",            "你是做什么工作的")
  add("en que trabajas",                        "what do you do for work",            "你是做什么工作的")
  add("dónde vives",                            "where do you live",                  "你住在哪里")
  add("donde vives",                            "where do you live",                  "你住在哪里")
  add("tengo esposa",                           "i have a wife",                      "我有老婆")
  add("tengo esposo",                           "i have a husband",                   "我有老公")
  add("tengo novia",                            "i have a girlfriend",                "我有女朋友")
  add("tengo novio",                            "i have a boyfriend",                 "我有男朋友")
  add("tengo hijos",                            "i have children",                    "我有孩子")
  add("qué hora es en tu país",                 "what time is it in your country",    "你那里几点了")
  add("que hora es en tu pais",                 "what time is it in your country",    "你那里几点了")
  add("el clima está mal",                      "the weather is bad",                 "天气不好")
  add("el clima está bien",                     "the weather is good",                "天气不错")
  add("hace calor",                             "it's hot",                           "很热")
  add("hace frío",                              "it's cold",                          "很冷")
  add("hace frio",                              "it's cold",                          "很冷")
  add("está lloviendo",                         "it's raining",                       "下雨了")
  add("me parece genial",                       "sounds great",                       "听起来棒极了")
  add("no me importa",                          "i don't care",                       "我不在乎")
  add("eso es increíble",                       "that's incredible",                  "太不可思议了")
  add("eso es increible",                       "that's incredible",                  "太不可思议了")
  add("qué lástima",                            "what a pity",                        "真遗憾")
  add("que lastima",                            "what a pity",                        "真遗憾")
  add("no te entiendo",                         "i don't understand you",             "我不明白你的意思")
  add("habla más despacio",                     "speak slower",                       "请说慢点")
  add("habla mas despacio",                     "speak slower",                       "请说慢点")
  add("escríbelo por favor",                    "write it please",                    "请写下来")
  add("escribelo por favor",                    "write it please",                    "请写下来")
  add("estás loco",                             "you are crazy",                      "你疯了")
  add("estas loco",                             "you are crazy",                      "你疯了")

  -- ╔══════════════════════════════════════════════╗
  -- ║  [NUEVO] CAT 51: Números y Días              ║
  -- ╚══════════════════════════════════════════════╝
  add("lunes",                                  "monday",                             "星期一")
  add("martes",                                 "tuesday",                            "星期二")
  add("miércoles",                              "wednesday",                          "星期三")
  add("miercoles",                              "wednesday",                          "星期三")
  add("jueves",                                 "thursday",                           "星期四")
  add("viernes",                                "friday",                             "星期五")
  add("sábado",                                 "saturday",                           "星期六")
  add("sabado",                                 "saturday",                           "星期六")
  add("domingo",                                "sunday",                             "星期日")
  add("semana",                                 "week",                               "周")
  add("fin de semana",                          "weekend",                            "周末")
  add("mes",                                    "month",                              "月")
  add("año",                                    "year",                               "年")
  add("ano",                                    "year",                               "年")
  add("uno",                                    "one",                                "一")
  add("dos",                                    "two",                                "二")
  add("tres",                                   "three",                              "三")
  add("cuatro",                                 "four",                               "四")
  add("cinco",                                  "five",                               "五")
  add("seis",                                   "six",                                "六")
  add("siete",                                  "seven",                              "七")
  add("ocho",                                   "eight",                              "八")
  add("nueve",                                  "nine",                               "九")
  add("diez",                                   "ten",                                "十")
  add("cien",                                   "hundred",                            "百")
  add("mil",                                    "thousand",                           "千")

  -- ╔══════════════════════════════════════════════╗
  -- ║  [NUEVO] CAT 52: Profesiones y Comercio      ║
  -- ╚══════════════════════════════════════════════╝
  add("profesión",                              "profession",                         "专业")
  add("profesion",                              "profession",                         "专业")
  add("minería",                                "mining",                             "采矿")
  add("mineria",                                "mining",                             "采矿")
  add("herboristería",                          "herbalism",                          "草药学")
  add("herboristeria",                          "herbalism",                          "草药学")
  add("ingeniería",                             "engineering",                        "工程学")
  add("ingenieria",                             "engineering",                        "工程学")
  add("sastrería",                              "tailoring",                          "裁缝")
  add("sastreria",                              "tailoring",                          "裁缝")
  add("herrería",                               "blacksmithing",                      "锻造")
  add("herreria",                               "blacksmithing",                      "锻造")
  add("peletería",                              "leatherworking",                     "制皮")
  add("peleteria",                              "leatherworking",                     "制皮")
  add("alquimia",                               "alchemy",                            "炼金术")
  add("encantamiento",                          "enchanting",                         "附魔")
  add("pesca",                                  "fishing",                            "钓鱼")
  add("cocina",                                 "cooking",                            "烹饪")
  add("primeros auxilios",                      "first aid",                          "急救")
  add("cobre",                                  "copper",                             "铜")
  add("hierro",                                 "iron",                               "铁")
  add("mithril",                                "mithril",                            "秘银")
  add("torio",                                  "thorium",                            "瑟银")
  add("tela",                                   "cloth",                              "布")
  add("cuero",                                  "leather",                            "皮革")
  add("subasta",                                "auction",                            "拍卖")
  add("comerciar",                              "trade",                              "交易")
  add("crear",                                  "craft",                              "制造")
  add("recolectar",                             "gather",                             "采集")

  -- ╔══════════════════════════════════════════════╗
  -- ║  [NUEVO] CAT 53: Direcciones y Anatomía      ║
  -- ╚══════════════════════════════════════════════╝
  add("norte",                                  "north",                              "北")
  add("sur",                                    "south",                              "南")
  add("este",                                   "east",                               "东")
  add("oeste",                                  "west",                               "西")
  add("izquierda",                              "left",                               "左边")
  add("derecha",                                "right",                              "右边")
  add("arriba",                                 "up",                                 "上面")
  add("abajo",                                  "down",                               "下面")
  add("adelante",                               "forward",                            "前面")
  add("atrás",                                  "back",                               "后面")
  add("atras",                                  "back",                               "后面")
  add("cabeza",                                 "head",                               "头")
  add("mano",                                   "hand",                               "手")
  add("pie",                                    "foot",                               "脚")
  add("pierna",                                 "leg",                                "腿")
  add("brazo",                                  "arm",                                "手臂")
  add("espalda",                                "back",                               "背部")
  add("pecho",                                  "chest",                              "胸部")

  -- ╔══════════════════════════════════════════════╗
  -- ║  [NUEVO] CAT 54: Adverbios de Modo           ║
  -- ╚══════════════════════════════════════════════╝
  add("rápidamente",                            "quickly",                            "快点")
  add("rapidamente",                            "quickly",                            "快点")
  add("despacio",                               "slowly",                             "慢点")
  add("bien",                                   "well",                               "好")
  add("mal",                                    "badly",                              "坏")
  add("cuidadosamente",                         "carefully",                          "小心地")
  add("con cuidado",                            "be careful",                         "小心")
  add("silenciosamente",                        "silently",                           "安静地")
  add("fuerte",                                 "strong",                             "强")
  add("suave",                                  "soft",                               "软")
  add("juntos",                                 "together",                           "一起")
  add("solos",                                  "alone",                              "单独")

  -- ╔══════════════════════════════════════════════╗
  -- ║  [NUEVO] CAT 55: Emociones y Acciones        ║
  -- ╚══════════════════════════════════════════════╝
  add("bailar",                                 "dance",                              "跳舞")
  add("reír",                                   "laugh",                              "笑")
  add("reir",                                   "laugh",                              "笑")
  add("llorar",                                 "cry",                                "哭")
  add("sentarse",                               "sit",                                "坐下")
  add("montura",                                "mount",                              "坐骑")
  add("montar",                                 "mount up",                           "上马")
  add("desmontar",                              "dismount",                           "下马")
  add("bromear",                                "joke",                               "开玩笑")
  add("saludar",                                "wave",                               "挥手")
  add("aplaudir",                               "clap",                               "鼓掌")
  add("animar",                                 "cheer",                              "欢呼")

  -- ╔══════════════════════════════════════════════╗
  -- ║  [NUEVO] CAT 56: Tácticas de Combate Hardcore║
  -- ╚══════════════════════════════════════════════╝
  add("aggro",                                  "aggro",                              "仇恨")
  add("amenaza",                                "threat",                             "威胁")
  add("jalar",                                  "pull",                               "开怪")
  add("pululear",                               "pull",                               "开怪")
  add("oveja",                                  "sheep",                              "羊")
  add("miedo",                                  "fear",                               "恐惧")
  add("control de masas",                       "cc",                                 "控制")
  add("disipar",                                "dispel",                             "驱散")
  add("interrumpir",                            "interrupt",                          "打断")
  add("cortar",                                 "interrupt",                          "打断")
  add("tanque principal",                       "main tank",                          "主坦克")
  add("mt",                                     "main tank",                          "主坦克")
  add("tanque secundario",                      "off tank",                           "副坦克")
  add("ot",                                     "off tank",                           "副坦克")
  add("área de efecto",                         "aoe",                                "范围伤害")
  add("area",                                   "aoe",                                "范围伤害")
  add("enfocar",                                "focus",                              "集火")
  add("foco",                                   "focus",                              "集火")
  add("limpiar",                                "wipe",                               "灭团")
  add("revivir",                                "resurrect",                          "复活")
  add("res",                                    "res",                                "复活")

  -- ╔══════════════════════════════════════════════╗
  -- ║  [NUEVO] CAT 57: Colores y Descripciones     ║
  -- ╚══════════════════════════════════════════════╝
  add("rojo",                                  "red",                                "红")
  add("azul",                                  "blue",                               "蓝")
  add("verde",                                 "green",                              "绿")
  add("amarillo",                              "yellow",                             "黄")
  add("negro",                                 "black",                              "黑")
  add("blanco",                                "white",                              "白")
  add("morado",                                "purple",                             "紫")
  add("naranja",                               "orange",                             "橙")
  add("gris",                                  "grey",                               "灰")
  add("dorado",                                "golden",                             "金色")
  add("plateado",                              "silver",                             "银色")
  add("bonito",                                "beautiful",                          "美")
  add("hermoso",                               "beautiful",                          "漂亮")
  add("feo",                                   "ugly",                               "丑")
  add("alto",                                  "tall",                               "高")
  add("bajo",                                  "short",                              "矮")
  add("gordo",                                 "fat",                                "胖")
  add("flaco",                                 "thin",                               "瘦")
  add("fuerte",                                "strong",                             "强")
  add("débil",                                 "weak",                               "弱")
  add("debil",                                 "weak",                               "弱")

  -- ╔══════════════════════════════════════════════╗
  -- ║  [NUEVO] CAT 58: Familia Extendida           ║
  -- ╚══════════════════════════════════════════════╝
  add("hermana",                               "sister",                             "姐妹")
  add("hermano",                               "brother",                            "兄弟")
  add("abuelo",                                "grandfather",                        "爷爷")
  add("abuela",                                "grandmother",                        "奶奶")
  add("tío",                                   "uncle",                              "叔叔")
  add("tio",                                   "uncle",                              "叔叔")
  add("tía",                                   "aunt",                               "婘婘")
  add("tia",                                   "aunt",                               "婘婘")
  add("primo",                                 "cousin",                             "堰冀")
  add("prima",                                 "cousin",                             "表妹")
  add("novia",                                 "girlfriend",                         "女朋友")
  add("novio",                                 "boyfriend",                          "男朋友")
  add("bebé",                                  "baby",                               "宝宝")
  add("bebe",                                  "baby",                               "宝宝")
  add("niño",                                  "child",                              "小孩")
  add("nino",                                  "child",                              "小孩")
  add("adulto",                                "adult",                              "大人")
  add("viejo",                                 "old person",                         "老人")
  add("chico",                                 "guy",                                "小伙")
  add("chica",                                 "girl",                               "女生")

  -- ╔══════════════════════════════════════════════╗
  -- ║  [NUEVO] CAT 59: Internet y Gaming           ║
  -- ╚══════════════════════════════════════════════╝
  add("farm",                                  "farm",                               "刻怪")
  add("farmear",                               "farm",                               "刻怪")
  add("grind",                                 "grind",                              "刺级")
  add("grindar",                               "grind",                              "刺级")
  add("noob",                                  "noob",                               "菜鸟")
  add("pro",                                   "pro",                                "大神")
  add("hacker",                                "hacker",                             "外挂")
  add("campeón",                               "champion",                           "冠军")
  add("campeon",                               "champion",                           "冠军")
  add("perdedor",                              "loser",                              "输家")
  add("ganador",                               "winner",                             "赢家")
  add("ganar",                                 "win",                                "赢")
  add("perder",                                "lose",                               "输")
  add("empate",                                "tie",                                "平局")
  add("ranking",                               "ranking",                            "排行榜")
  add("guild bank",                            "guild bank",                         "工会银行")
  add("banco de hermandad",                    "guild bank",                         "工会银行")
  add("raid",                                  "raid",                               "团本")
  add("instancia",                             "instance",                           "副本")
  add("pvp",                                   "pvp",                                "PVP")
  add("pve",                                   "pve",                                "PVE")
  add("servidor",                              "server",                             "服务器")
  add("parche",                                "patch",                              "补丁")
  add("lag",                                   "lag",                                "延迟")
  add("ddos",                                  "ddos",                               "DDOS")
  add("stream",                                "stream",                             "直播")
  add("streamer",                              "streamer",                           "主播")

  -- ╔══════════════════════════════════════════════╗
  -- ║  [NUEVO] CAT 60: Viajes y Ubicaciones        ║
  -- ╚══════════════════════════════════════════════╝
  add("méxico",                                "mexico",                             "墨西哥")
  add("mexico",                                "mexico",                             "墨西哥")
  add("españa",                                "spain",                              "西班牙")
  add("espana",                                "spain",                              "西班牙")
  add("china",                                 "china",                              "中国")
  add("usa",                                   "usa",                                "美国")
  add("latinoamérica",                         "latin america",                      "拉丁美洲")
  add("latinoamerica",                         "latin america",                      "拉丁美洲")
  add("europa",                                "europe",                             "欧洲")
  add("asia",                                  "asia",                               "亚洲")
  add("aeropuerto",                            "airport",                            "机场")
  add("hotel",                                 "hotel",                              "酒店")
  add("restaurante",                           "restaurant",                         "餐厅")
  add("hospital",                              "hospital",                           "医院")
  add("banco",                                 "bank",                               "银行")
  add("tienda",                                "store",                              "商店")
  add("mercado",                               "market",                             "市场")
  add("calle",                                 "street",                             "街道")
  add("viaje",                                 "trip",                               "旅行")
  add("vacaciones",                            "vacation",                           "假期")

  -- ╔══════════════════════════════════════════════╗
  -- ║  [NUEVO] CAT 61: Expresiones Coloquiales     ║
  -- ╚══════════════════════════════════════════════╝
  add("qué onda",                              "what's up",                          "哎哟")
  add("que onda",                              "what's up",                          "哎哟")
  add("qué rollo",                             "what's going on",                    "怎了")
  add("que rollo",                             "what's going on",                    "怎了")
  add("chido",                                 "cool",                               "帅")
  add("chidazo",                               "awesome",                            "超帅")
  add("genial",                                "awesome",                            "太棒了")
  add("chevere",                               "cool",                               "奮了")
  add("chévere",                               "cool",                               "奮了")
  add("macanudo",                              "great",                              "天才")
  add("bacano",                                "cool",                               "帅")
  add("guay",                                  "cool",                               "帅")
  add("molón",                                 "cool",                               "帅")
  add("molon",                                 "cool",                               "帅")
  add("brutal",                                "brutal",                             "太厉害了")
  add("epicazo",                               "epic",                               "史诗级")
  add("fiesta",                                "party",                              "派对")
  add("farra",                                 "party",                              "派对")
  add("joda",                                  "party",                              "派对")
  add("pana",                                  "pal",                                "哥们")
  add("vale",                                  "ok",                                 "好的")
  add("dale",                                  "go ahead",                           "行啊")
  add("venga",                                 "come on",                            "加油")
  add("anda ya",                               "come on",                            "不可能吧")
  add("uy",                                    "oops",                               "哎哟")
  add("ay",                                    "ouch",                               "哎")
  add("vamos",                                 "let's go",                           "走吧")
  add("arriba",                                "let's go",                           "加油")
  add("buena",                                 "nice",                               "妈")
  add("bravo",                                 "bravo",                              "好样")
  add("eso es",                                "that's it",                          "就这样")
  add("qué va",                                "no way",                             "不可能")
  add("que va",                                "no way",                             "不可能")

  -- ╔══════════════════════════════════════════════╗
  -- ║  [NUEVO] CAT 62: Salud, Urgencias y Dinero   ║
  -- ╚══════════════════════════════════════════════╝
  add("me duele",                              "it hurts",                           "我痟")
  add("estoy enfermo",                         "i am sick",                          "我生病了")
  add("estoy mejor",                           "i am better",                        "我好多了")
  add("llama a un médico",                     "call a doctor",                      "叫师生")
  add("es una emergencia",                     "it's an emergency",                  "紧急情况")
  add("necesito ayuda",                        "i need help",                        "我需要帮助")
  add("cuánto cobras",                         "how much do you charge",             "你收多少")
  add("cuanto cobras",                         "how much do you charge",             "你收多少")
  add("no tengo dinero",                       "i have no money",                    "我没钱")
  add("es muy caro",                           "it's too expensive",                 "太贵了")
  add("me descuentas",                         "give me a discount",                 "打折吗")
  add("hay oferta",                            "is there a sale",                    "有打折吗")
  add("gratis",                                "free",                               "免费")
  add("pagar",                                 "pay",                                "付款")
  add("cobrar",                                "charge",                             "收费")
  add("prestar",                               "lend",                               "借")
  add("devolver",                              "return",                             "还")
  add("deuda",                                 "debt",                               "欠子")
  add("regalo",                                "gift",                               "礼物")

  -- ╔══════════════════════════════════════════════╗
  -- ║  [NUEVO] CAT 63: Ropa y Equipo Personal      ║
  -- ╚══════════════════════════════════════════════╝
  add("camisa",                                "shirt",                              "衬衫")
  add("pantalón",                              "pants",                              "裤子")
  add("pantalon",                              "pants",                              "裤子")
  add("zapatos",                               "shoes",                              "鞋子")
  add("botas",                                 "boots",                              "靴子")
  add("sombrero",                              "hat",                                "帽子")
  add("chaqueta",                              "jacket",                             "夹克")
  add("abrigo",                                "coat",                               "外套")
  add("mochila",                               "backpack",                           "背包")
  add("bolso",                                 "bag",                                "包")
  add("anillo",                                "ring",                               "戒指")
  add("collar",                                "necklace",                           "项链")
  add("reloj",                                 "watch",                              "手表")
  add("gafas",                                 "glasses",                            "眼镜")

  -- ╔══════════════════════════════════════════════╗
  -- ║  [NUEVO] CAT 64: Naturaleza y Entorno        ║
  -- ╚══════════════════════════════════════════════╝
  add("montaña",                               "mountain",                           "山")
  add("montana",                               "mountain",                           "山")
  add("bosque",                                "forest",                             "森林")
  add("mar",                                   "sea",                                "海")
  add("río",                                   "river",                              "河")
  add("rio",                                   "river",                              "河")
  add("lago",                                  "lake",                               "湖")
  add("desierto",                              "desert",                             "沙漠")
  add("isla",                                  "island",                             "岛")
  add("árbol",                                 "tree",                               "树")
  add("arbol",                                 "tree",                               "树")
  add("flor",                                  "flower",                             "花")
  add("piedra",                                "stone",                              "石头")
  add("fuego",                                 "fire",                               "火")
  add("hielo",                                 "ice",                                "冰")
  add("tierra",                                "earth",                              "土地")
  add("viento",                                "wind",                               "风")
  add("lluvia",                                "rain",                               "雨")
  add("nieve",                                 "snow",                               "雪")
  add("sol",                                   "sun",                                "太阳")
  add("luna",                                  "moon",                               "月亮")
  add("estrella",                              "star",                               "星星")

  -- ╔══════════════════════════════════════════════╗
  -- ║  [NUEVO] CAT 65: Tecnología Moderna          ║
  -- ╚══════════════════════════════════════════════╝
  add("teléfono inteligente",                  "smartphone",                         "智能手机")
  add("telefono inteligente",                  "smartphone",                         "智能手机")
  add("aplicación",                            "app",                                "应用")
  add("aplicacion",                            "app",                                "应用")
  add("red social",                            "social media",                       "社交媒体")
  add("redes sociales",                        "social media",                       "社交媒体")
  add("contraseña",                            "password",                           "密码")
  add("contrasena",                            "password",                           "密码")
  add("cuenta",                                "account",                            "账号")
  add("correo electrónico",                    "email",                              "电子邮件")
  add("correo electronico",                    "email",                              "电子邮件")
  add("video",                                 "video",                              "视频")
  add("foto",                                  "photo",                              "照片")
  add("pantalla",                              "screen",                             "屏幕")
  add("teclado",                               "keyboard",                           "键盘")
  add("ratón",                                 "mouse",                              "鼠标")
  add("raton",                                 "mouse",                              "鼠标")
  add("auriculares",                           "headphones",                         "耳机")
  add("micrófono",                             "microphone",                         "麦克风")
  add("microfono",                             "microphone",                         "麦克风")

  -- ╔══════════════════════════════════════════════╗
  -- ║  [NUEVO] CAT 66: Deportes y Actividad Física ║
  -- ╚══════════════════════════════════════════════╝
  add("fútbol",                                "soccer",                             "足球")
  add("futbol",                                "soccer",                             "足球")
  add("baloncesto",                            "basketball",                         "篮球")
  add("tenis",                                 "tennis",                             "网球")
  add("natación",                              "swimming",                           "游泳")
  add("natacion",                              "swimming",                           "游泳")
  add("correr",                                "running",                            "跑步")
  add("gimnasio",                              "gym",                                "健身房")
  add("ejercicio",                             "exercise",                           "运动")
  add("caminar",                               "walk",                               "走路")
  add("bicicleta",                             "bicycle",                            "自行车")
  add("entrenamiento",                         "training",                           "训练")
  add("campeón",                               "champion",                           "冠军")
  add("campeon",                               "champion",                           "冠军")
  add("partido",                               "match",                              "比赛")
  add("torneo",                                "tournament",                         "锦标赛")

  -- ╔══════════════════════════════════════════════╗
  -- ║  [NUEVO] CAT 67: Comida Real Específica      ║
  -- ╚══════════════════════════════════════════════╝
  add("arroz",                                 "rice",                               "米饭")
  add("pollo",                                 "chicken",                            "鸡肉")
  add("carne",                                 "meat",                               "肉")
  add("pescado",                               "fish",                               "鱼")
  add("pan",                                   "bread",                              "面包")
  add("leche",                                 "milk",                               "牛奶")
  add("huevo",                                 "egg",                                "鸡蛋")
  add("fruta",                                 "fruit",                              "水果")
  add("verdura",                               "vegetable",                          "蔬菜")
  add("sopa",                                  "soup",                               "汤")
  add("pizza",                                 "pizza",                              "披萨")
  add("tacos",                                 "tacos",                              "墨西哥卷")
  add("azúcar",                                "sugar",                              "糖")
  add("azucar",                                "sugar",                              "糖")
  add("sal",                                   "salt",                               "盐")
  add("aceite",                                "oil",                                "油")
  add("salsa",                                 "sauce",                              "酱汁")
  add("jugo",                                  "juice",                              "果汁")
  add("té",                                    "tea",                                "茶")
  add("te",                                    "tea",                                "茶")

  -- ╔══════════════════════════════════════════════╗
  -- ║  [NUEVO] CAT 68: Música y Arte               ║
  -- ╚══════════════════════════════════════════════╝
  add("canción",                               "song",                               "歌曲")
  add("cancion",                               "song",                               "歌曲")
  add("banda",                                 "band",                               "乐队")
  add("cantante",                              "singer",                             "歌手")
  add("guitarra",                              "guitar",                             "吉他")
  add("piano",                                 "piano",                              "钢琴")
  add("batería",                               "drums",                              "鼓")
  add("bateria",                               "drums",                              "鼓")
  add("arte",                                  "art",                                "艺术")
  add("pintura",                               "painting",                           "画")
  add("dibujo",                                "drawing",                            "素描")
  add("libro",                                 "book",                               "书")
  add("novela",                                "novel",                              "小说")
  add("serie",                                 "series",                             "剧集")
  add("anime",                                 "anime",                              "动漫")

  -- ╔══════════════════════════════════════════════╗
  -- ║  [NUEVO] CAT 69: Frases Idiomáticas          ║
  -- ╚══════════════════════════════════════════════╝
  add("más vale tarde que nunca",              "better late than never",             "亡羊补牢")
  add("no hay mal que por bien no venga",      "every cloud has a silver lining",    "塞翁失马")
  add("al mal tiempo buena cara",              "keep a positive attitude",           "苦中作乐")
  add("a otro perro con ese hueso",            "tell it to someone else",            "别骗我了")
  add("ojos que no ven corazón que no siente", "out of sight out of mind",           "眼不见心不烦")
  add("matar dos pájaros de un tiro",          "kill two birds with one stone",      "一石二鸟")
  add("matar dos pajaros de un tiro",          "kill two birds with one stone",      "一石二鸟")
  add("no todo lo que brilla es oro",          "all that glitters is not gold",      "金玉其外")
  add("a palabras necias oídos sordos",        "ignore foolish words",               "充耳不闻")
  add("camarón que se duerme se lo lleva",     "stay sharp or get left behind",      "不进则退")
  add("más sabe el diablo por viejo",          "experience beats everything",        "姜还是老的辣")

  -- ╔══════════════════════════════════════════════╗
  -- ║  [NUEVO] CAT 70: Confirmaciones Avanzadas    ║
  -- ╚══════════════════════════════════════════════╝
  add("con mucho gusto",                       "with pleasure",                      "很乐意")
  add("ningún problema",                       "no problem at all",                  "完全没问题")
  add("ningun problema",                       "no problem at all",                  "完全没问题")
  add("qué pena",                              "how embarrassing",                   "真尴尬")
  add("que pena",                              "how embarrassing",                   "真尴尬")
  add("te lo juro",                            "i swear",                            "我发誓")
  add("en serio",                              "seriously",                          "认真的")
  add("de verdad",                             "for real",                           "真的吗")
  add("me alegra",                             "i'm glad",                           "我很高兴")
  add("lo siento mucho",                       "i'm very sorry",                     "非常抱歉")
  add("qué bueno",                             "how great",                          "太好了")
  add("que bueno",                             "how great",                          "太好了")
  add("qué horrible",                          "how horrible",                       "太可怕了")
  add("que horrible",                          "how horrible",                       "太可怕了")
  add("qué aburrido",                          "how boring",                         "好无聊")
  add("que aburrido",                          "how boring",                         "好无聊")
  add("ya entendí",                            "i get it now",                       "我懂了")
  add("ya entendi",                            "i get it now",                       "我懂了")
  add("estamos de acuerdo",                    "we agree",                           "我们达成一致")
  add("lo que digas",                          "whatever you say",                   "随你")
  add("como quieras",                          "as you wish",                        "随你便")
  add("tú decides",                            "you decide",                         "你来决定")
  add("tu decides",                            "you decide",                         "你来决定")

  -- ╔══════════════════════════════════════════════╗
  -- ║  [NUEVO] CAT 71: Salud y Medicina            ║
  -- ╚══════════════════════════════════════════════╝
  add("médico",                                "doctor",                             "医生")
  add("medico",                                "doctor",                             "医生")
  add("enfermera",                             "nurse",                              "护士")
  add("medicina",                              "medicine",                           "药")
  add("pastilla",                              "pill",                               "药片")
  add("cirugía",                               "surgery",                            "手术")
  add("cirugia",                               "surgery",                            "手术")
  add("fiebre",                                "fever",                              "发烧")
  add("gripe",                                 "flu",                                "流感")
  add("resfriado",                             "cold",                               "感冒")
  add("dolor de cabeza",                       "headache",                           "头痛")
  add("dolor de estómago",                     "stomachache",                        "胃痛")
  add("dolor de estomago",                     "stomachache",                        "胃痛")
  add("presión arterial",                      "blood pressure",                     "血压")
  add("presion arterial",                      "blood pressure",                     "血压")
  add("alergia",                               "allergy",                            "过敏")
  add("vacuna",                                "vaccine",                            "疫苗")
  add("vitamina",                              "vitamin",                            "维生素")
  add("dieta",                                 "diet",                               "饮食")
  add("embarazada",                            "pregnant",                           "怀孕")
  add("receta médica",                         "prescription",                       "处方")
  add("ambulancia",                            "ambulance",                          "救护车")

  -- ╔══════════════════════════════════════════════╗
  -- ║  [NUEVO] CAT 72: Educación y Academia        ║
  -- ╚══════════════════════════════════════════════╝
  add("maestro",                               "teacher",                            "老师")
  add("profesor",                              "professor",                          "教授")
  add("alumno",                                "student",                            "学生")
  add("examen",                                "exam",                               "考试")
  add("tarea",                                 "homework",                           "作业")
  add("calificación",                          "grade",                              "成绩")
  add("calificacion",                          "grade",                              "成绩")
  add("clase",                                 "class",                              "课")
  add("materia",                               "subject",                            "科目")
  add("matemáticas",                           "mathematics",                        "数学")
  add("matematicas",                           "mathematics",                        "数学")
  add("historia",                              "history",                            "历史")
  add("ciencias",                              "science",                            "科学")
  add("idioma",                                "language",                           "语言")
  add("inglés",                                "english",                            "英语")
  add("ingles",                                "english",                            "英语")
  add("español",                               "spanish",                            "西班牙语")
  add("espanol",                               "spanish",                            "西班牙语")
  add("chino",                                 "chinese",                            "中文")
  add("diploma",                               "diploma",                            "文凭")
  add("beca",                                  "scholarship",                        "奖学金")

  -- ╔══════════════════════════════════════════════╗
  -- ║  [NUEVO] CAT 73: Trabajo y Profesiones       ║
  -- ╚══════════════════════════════════════════════╝
  add("jefe",                                  "boss",                               "老板")
  add("empleado",                              "employee",                           "员工")
  add("salario",                               "salary",                             "工资")
  add("sueldo",                                "wage",                               "薪水")
  add("oficina",                               "office",                             "办公室")
  add("reunión",                               "meeting",                            "会议")
  add("reunion",                               "meeting",                            "会议")
  add("proyecto",                              "project",                            "项目")
  add("empresa",                               "company",                            "公司")
  add("negocio",                               "business",                           "生意")
  add("contrato",                              "contract",                           "合同")
  add("renuncia",                              "resignation",                        "辞职")
  add("despido",                               "layoff",                             "裁员")
  add("entrevista",                            "interview",                          "面试")
  add("currículum",                            "resume",                             "简历")
  add("curriculum",                            "resume",                             "简历")
  add("ingeniero",                             "engineer",                           "工程师")
  add("abogado",                               "lawyer",                             "律师")
  add("contador",                              "accountant",                         "会计")
  add("arquitecto",                            "architect",                          "建筑师")
  add("programador",                           "programmer",                         "程序员")

  -- ╔══════════════════════════════════════════════╗
  -- ║  [NUEVO] CAT 74: Transporte y Viajes         ║
  -- ╚══════════════════════════════════════════════╝
  add("avión",                                 "airplane",                           "飞机")
  add("avion",                                 "airplane",                           "飞机")
  add("tren",                                  "train",                              "火车")
  add("autobús",                               "bus",                                "公交车")
  add("autobus",                               "bus",                                "公交车")
  add("metro",                                 "subway",                             "地铁")
  add("taxi",                                  "taxi",                               "出租车")
  add("barco",                                 "ship",                               "船")
  add("coche",                                 "car",                                "汽车")
  add("carro",                                 "car",                                "车")
  add("moto",                                  "motorcycle",                         "摩托车")
  add("gasolina",                              "gas",                                "汽油")
  add("carretera",                             "road",                               "公路")
  add("semáforo",                              "traffic light",                      "红绿灯")
  add("semaforo",                              "traffic light",                      "红绿灯")
  add("vuelo",                                 "flight",                             "航班")
  add("maleta",                                "suitcase",                           "行李箱")
  add("pasaporte",                             "passport",                           "护照")
  add("visa",                                  "visa",                               "签证")
  add("aduana",                                "customs",                            "海关")

  -- ╔══════════════════════════════════════════════╗
  -- ║  [NUEVO] CAT 75: Hogar y Muebles             ║
  -- ╚══════════════════════════════════════════════╝
  add("cama",                                  "bed",                                "床")
  add("sofá",                                  "sofa",                               "沙发")
  add("sofa",                                  "sofa",                               "沙发")
  add("mesa",                                  "table",                              "桌子")
  add("silla",                                 "chair",                              "椅子")
  add("cocina",                                "kitchen",                            "厨房")
  add("baño",                                  "bathroom",                           "浴室")
  add("bano",                                  "bathroom",                           "浴室")
  add("sala",                                  "living room",                        "客厅")
  add("habitación",                            "bedroom",                            "卧室")
  add("habitacion",                            "bedroom",                            "卧室")
  add("ventana",                               "window",                             "窗户")
  add("puerta",                                "door",                               "门")
  add("escalera",                              "stairs",                             "楼梯")
  add("jardín",                                "garden",                             "花园")
  add("jardin",                                "garden",                             "花园")
  add("garaje",                                "garage",                             "车库")
  add("llave",                                 "key",                                "钥匙")
  add("lámpara",                               "lamp",                               "灯")
  add("lampara",                               "lamp",                               "灯")
  add("refrigerador",                          "refrigerator",                       "冰箱")
  add("nevera",                                "fridge",                             "冰箱")
  add("lavadora",                              "washing machine",                    "洗衣机")

  -- ╔══════════════════════════════════════════════╗
  -- ║  [NUEVO] CAT 76: Animales                    ║
  -- ╚══════════════════════════════════════════════╝
  add("perro",                                 "dog",                                "狗")
  add("gato",                                  "cat",                                "猫")
  add("pájaro",                                "bird",                               "鸟")
  add("pajaro",                                "bird",                               "鸟")
  add("pez",                                   "fish",                               "鱼")
  add("caballo",                               "horse",                              "马")
  add("vaca",                                  "cow",                                "牛")
  add("cerdo",                                 "pig",                                "猪")
  add("pollo",                                 "chicken",                            "鸡")
  add("conejo",                                "rabbit",                             "兔子")
  add("ratón",                                 "mouse",                              "老鼠")
  add("serpiente",                             "snake",                              "蛇")
  add("araña",                                 "spider",                             "蜘蛛")
  add("arana",                                 "spider",                             "蜘蛛")
  add("dragón",                                "dragon",                             "龙")
  add("dragon",                                "dragon",                             "龙")
  add("lobo",                                  "wolf",                               "狼")
  add("oso",                                   "bear",                               "熊")
  add("tigre",                                 "tiger",                              "老虎")
  add("león",                                  "lion",                               "狮子")
  add("leon",                                  "lion",                               "狮子")

  -- ╔══════════════════════════════════════════════╗
  -- ║  [NUEVO] CAT 77: Cuerpo Humano Completo      ║
  -- ╚══════════════════════════════════════════════╝
  add("ojo",                                   "eye",                                "眼睛")
  add("ojos",                                  "eyes",                               "眼睛")
  add("nariz",                                 "nose",                               "鼻子")
  add("boca",                                  "mouth",                              "嘴")
  add("oreja",                                 "ear",                                "耳朵")
  add("diente",                                "tooth",                              "牙齿")
  add("pelo",                                  "hair",                               "头发")
  add("cuello",                                "neck",                               "脖子")
  add("hombro",                                "shoulder",                           "肩膀")
  add("codo",                                  "elbow",                              "肘")
  add("muñeca",                                "wrist",                              "手腕")
  add("muneca",                                "wrist",                              "手腕")
  add("dedo",                                  "finger",                             "手指")
  add("rodilla",                               "knee",                               "膝盖")
  add("tobillo",                               "ankle",                              "脚踝")
  add("estómago",                              "stomach",                            "胃")
  add("estomago",                              "stomach",                            "胃")
  add("corazón",                               "heart",                              "心脏")
  add("corazon",                               "heart",                              "心脏")
  add("pulmón",                                "lung",                               "肺")
  add("pulmon",                                "lung",                               "肺")
  add("sangre",                                "blood",                              "血")

  -- ╔══════════════════════════════════════════════╗
  -- ║  [NUEVO] CAT 78: Tiempo Atmosférico Avanzado ║
  -- ╚══════════════════════════════════════════════╝
  add("tormenta",                              "storm",                              "暴风雨")
  add("trueno",                                "thunder",                            "雷声")
  add("relámpago",                             "lightning",                          "闪电")
  add("relampago",                             "lightning",                          "闪电")
  add("granizo",                               "hail",                               "冰雹")
  add("niebla",                                "fog",                                "雾")
  add("nublado",                               "cloudy",                             "多云")
  add("despejado",                             "clear",                              "晴朗")
  add("húmedo",                                "humid",                              "潮湿")
  add("humedo",                                "humid",                              "潮湿")
  add("seco",                                  "dry",                                "干燥")
  add("temperatura",                           "temperature",                        "温度")
  add("grados",                                "degrees",                            "度")
  add("pronóstico",                            "forecast",                           "天气预报")
  add("pronostico",                            "forecast",                           "天气预报")

  -- ╔══════════════════════════════════════════════╗
  -- ║  [NUEVO] CAT 79: Sentimientos Avanzados      ║
  -- ╚══════════════════════════════════════════════╝
  add("emocionado",                            "excited",                            "兴奋")
  add("nervioso",                              "nervous",                            "紧张")
  add("asustado",                              "scared",                             "害怕")
  add("sorprendido",                           "surprised",                          "惊讶")
  add("avergonzado",                           "embarrassed",                        "尴尬")
  add("orgulloso",                             "proud",                              "自豪")
  add("celoso",                                "jealous",                            "嫉妒")
  add("confundido",                            "confused",                           "困惑")
  add("frustrado",                             "frustrated",                         "沮丧")
  add("relajado",                              "relaxed",                            "放松")
  add("estresado",                             "stressed",                           "压力大")
  add("agradecido",                            "grateful",                           "感激")
  add("aliviado",                              "relieved",                           "松了一口气")
  add("aburrido",                              "bored",                              "无聊")
  add("desesperado",                           "desperate",                          "绝望")

  -- ╔══════════════════════════════════════════════╗
  -- ║  [NUEVO] CAT 80: Chat y Reacciones Modernas  ║
  -- ╚══════════════════════════════════════════════╝
  add("wtf",                                   "what the heck",                      "什么鬼")
  add("omg",                                   "oh my god",                          "我的天")
  add("gg wp",                                 "good game well played",              "打得好，发挥不错")
  add("xd",                                    "lol",                                "哈哈")
  add("uwu",                                   "cute",                               "卖萌")
  add("bruh",                                  "seriously",                          "搞什么")
  add("based",                                 "respect",                            "有格调")
  add("cringe",                                "embarrassing",                       "尴尬")
  add("malding",                               "raging",                             "气得发狂")
  add("pog",                                   "amazing",                            "太帅了")
  add("poggers",                               "amazing",                            "太牛了")
  add("kappa",                                 "just kidding",                       "开玩笑")
  add("ez clap",                               "too easy",                           "轻松拿捏")
  add("git gud",                               "get better",                         "菜就多练")
  add("no cap",                                "for real",                           "没开玩笑")
  add("salty",                                 "bitter about losing",                "输了还酸")
  add("tilted",                                "mentally broken",                    "心态崩了")
  add("ratio",                                 "more dislikes than likes",           "被踩爆了")
  add("touch grass",                           "go outside",                         "出去晒太阳")
  add("irl",                                   "in real life",                       "现实中")

  -- ╔══════════════════════════════════════════════╗
  -- ║  [NUEVO] CAT 81: Política y Sociedad General ║
  -- ╚══════════════════════════════════════════════╝
  add("gobierno",                              "government",                         "政府")
  add("presidente",                            "president",                          "总统")
  add("ley",                                   "law",                                "法律")
  add("impuesto",                              "tax",                                "税")
  add("elección",                              "election",                           "选举")
  add("eleccion",                              "election",                           "选举")
  add("democracia",                            "democracy",                          "民主")
  add("libertad",                              "freedom",                            "自由")
  add("paz",                                   "peace",                              "和平")
  add("guerra",                                "war",                                "战争")
  add("economía",                              "economy",                            "经济")
  add("economia",                              "economy",                            "经济")
  add("inflación",                             "inflation",                          "通货膨胀")
  add("inflacion",                             "inflation",                          "通货膨胀")
  add("sociedad",                              "society",                            "社会")
  add("igualdad",                              "equality",                           "平等")
  add("justicia",                              "justice",                            "正义")
  add("derechos",                              "rights",                             "权利")
  add("corrupción",                            "corruption",                         "腐败")
  add("corrupcion",                            "corruption",                         "腐败")

  -- ╔══════════════════════════════════════════════╗
  -- ║  [NUEVO] CAT 82: Vida Nocturna y Social      ║
  -- ╚══════════════════════════════════════════════╝
  add("bar",                                   "bar",                                "酒吧")
  add("club",                                  "club",                               "夜店")
  add("fiesta",                                "party",                              "派对")
  add("karaoke",                               "karaoke",                            "卡拉OK")
  add("discoteca",                             "nightclub",                          "迪厅")
  add("cine",                                  "cinema",                             "电影院")
  add("teatro",                                "theater",                            "剧院")
  add("museo",                                 "museum",                             "博物馆")
  add("concierto",                             "concert",                            "演唱会")
  add("playa",                                 "beach",                              "海滩")
  add("piscina",                               "pool",                               "游泳池")
  add("parque",                                "park",                               "公园")
  add("plaza",                                 "plaza",                              "广场")
  add("salir",                                 "go out",                             "出去玩")
  add("voy a salir",                           "i'm going out",                      "我出去了")
  add("quedamos",                              "let's meet up",                      "我们见面吧")
  add("cita",                                  "date",                               "约会")
  add("enamorado",                             "in love",                            "恋爱中")
  add("soltero",                               "single",                             "单身")
  add("casado",                                "married",                            "已婚")

  -- ╔══════════════════════════════════════════════╗
  -- ║  [NUEVO] CAT 83: WoW Consumibles y Frascos   ║
  -- ╚══════════════════════════════════════════════╝
  add("poción de maná mayor",                  "major mana potion",                  "大强效法力药水")
  add("pocion de mana mayor",                  "major mana potion",                  "大强效法力药水")
  add("poción de salud mayor",                 "major healing potion",               "大强效治疗药水")
  add("pocion de salud mayor",                 "major healing potion",               "大强效治疗药水")
  add("elixir de poder de las sombras",        "elixir of shadow power",             "暗影之力药剂")
  add("elixir de poder de fuego",              "elixir of greater firepower",        "火力药剂")
  add("frasco de poder supremo",               "flask of supreme power",             "超能合剂")
  add("frasco de agua destilada",              "flask of distilled wisdom",          "精炼智慧合剂")
  add("poción de protección de fuego",         "greater fire protection potion",     "强效火焰防护药水")
  add("pocion de proteccion de fuego",         "greater fire protection potion",     "强效火焰防护药水")
  add("poción de protección de naturaleza",    "greater nature protection potion",   "强效自然防护药水")
  add("pocion de proteccion de naturaleza",    "greater nature protection potion",   "强效自然防护药水")
  add("poción de acción libre",                "free action potion",                 "自由行动药剂")
  add("pocion de accion libre",                "free action potion",                 "自由行动药剂")

  -- ╔══════════════════════════════════════════════╗
  -- ║  [NUEVO] CAT 84: Atributos de Combate        ║
  -- ╚══════════════════════════════════════════════╝
  add("probabilidad de golpe",                 "hit chance",                         "命中率")
  add("golpe crítico",                         "critical strike",                    "暴击")
  add("golpe critico",                         "critical strike",                    "暴击")
  add("celeridad",                             "haste",                              "急速")
  add("esquiva",                               "dodge",                              "躲闪")
  add("parada",                                "parry",                              "招架")
  add("bloqueo",                               "block",                              "格挡")
  add("penetración de armadura",               "armor penetration",                  "护甲穿透")
  add("penetracion de armadura",               "armor penetration",                  "护甲穿透")
  add("penetración de hechizos",               "spell penetration",                  "法术穿透")
  add("penetracion de hechizos",               "spell penetration",                  "法术穿透")
  add("poder de hechizo",                      "spell power",                        "法术能量")
  add("poder de curación",                     "healing power",                      "治疗能量")
  add("poder de curacion",                     "healing power",                      "治疗能量")

  -- ╔══════════════════════════════════════════════╗
  -- ║  [NUEVO] CAT 85: WoW Mecánicas Crowd Control ║
  -- ╚══════════════════════════════════════════════╝
  add("aturdir",                               "stun",                               "昏迷")
  add("aturdido",                              "stunned",                            "被昏迷")
  add("silenciar",                             "silence",                            "沉默")
  add("silenciado",                            "silenced",                           "被沉默")
  add("miedo",                                 "fear",                               "恐惧")
  add("temor",                                 "fear",                               "恐惧")
  add("polimorfia",                            "polymorph",                          "变形术")
  add("oveja",                                 "sheep",                              "变羊")
  add("desterrar",                             "banish",                             "放逐")
  add("desterrado",                            "banished",                           "被放逐")
  add("cegar",                                 "blind",                              "致盲")
  add("ralentizar",                            "slow",                               "减速")
  add("inmovilizar",                           "root",                               "定身")
  add("enraizar",                              "root",                               "定身")
  add("hipnotizar",                            "hypnotize",                          "催眠")
  add("embelesar",                             "charm",                              "魅惑")

  -- ╔══════════════════════════════════════════════╗
  -- ║  [NUEVO] CAT 86: WoW Jerga de Botín y DKP    ║
  -- ╚══════════════════════════════════════════════╝
  add("puja",                                  "bid",                                "出价")
  add("puja mínima",                           "min bid",                            "最低出价")
  add("puja minima",                           "min bid",                            "最低出价")
  add("tirar dados",                           "roll",                               "掷骰子")
  add("ligado al equipar",                     "boe",                                "装备后绑定")
  add("ligado al recoger",                     "bop",                                "拾取后绑定")
  add("reserva de botín",                      "loot reserve",                       "分配权保留")
  add("reserva de botin",                      "loot reserve",                       "分配权保留")
  add("maestro despojador",                    "master looter",                      "队长分配")
  add("botín del grupo",                       "group loot",                         "队伍分配")
  add("botin del grupo",                       "group loot",                         "队伍分配")
  add("necesidad antes que codicia",           "need before greed",                  "需求大于贪婪")

  -- ╔══════════════════════════════════════════════╗
  -- ║  [NUEVO] CAT 87: WoW Campos de Batalla       ║
  -- ╚══════════════════════════════════════════════╝
  add("garganta grito de guerra",              "wsg",                                "战歌峡谷")
  add("cuenca de arathi",                      "ab",                                 "阿拉希盆地")
  add("valle de alterac",                      "av",                                 "奥特兰克山谷")
  add("capturar bandera",                      "capture flag",                       "夺旗")
  add("asaltar base",                          "assault base",                       "开旗")
  add("defender base",                         "defend base",                        "守旗")
  add("cementerio",                            "graveyard",                          "墓地")
  add("mina de hierro",                        "iron mines",                         "铁矿洞")
  add("establo",                               "stables",                            "马厩")
  add("aserradero",                            "lumber mill",                        "伐木场")
  add("granja",                                "farm",                               "农场")
  add("herreria",                              "smithy",                             "铁匠铺")
  add("herrería",                              "smithy",                             "铁匠铺")

  -- ╔══════════════════════════════════════════════╗
  -- ║  [NUEVO] CAT 88: WoW Buffs del Mundo         ║
  -- ╚══════════════════════════════════════════════╝
  add("tributo de masacre",                    "dm tribute",                         "厄运贡品")
  add("cabeza de onyxia",                      "onyxia head",                        "奥妮克希亚的头颅")
  add("corazón de hakkar",                     "heart of hakkar",                    "哈卡的心脏")
  add("corazon de hakkar",                     "heart of hakkar",                    "哈卡的心脏")
  add("feria de la luna negra",                "dmf",                                "暗月马戏团")
  add("canción de flor de azote",              "songflower",                         "风歌夜霜")
  add("cancion de flor de azote",              "songflower",                         "风歌夜霜")
  add("grito de convocación",                  "rallying cry",                       "屠龙者的咆哮")
  add("grito de convocacion",                  "rallying cry",                       "屠龙者的咆哮")
  add("bendición de warchief",                 "warchief blessing",                  "大酋长的祝福")
  add("bendicion de warchief",                 "warchief blessing",                  "大酋长的祝福")

  -- ╔══════════════════════════════════════════════╗
  -- ║  [NUEVO] CAT 89: WoW Fórmulas y Transmutas   ║
  -- ╚══════════════════════════════════════════════╝
  add("transmutar arcanita",                   "transmute arcanite",                 "转化奥金")
  add("refinar sal profunda",                  "refine deeprock salt",               "筛盐")
  add("barra de arcanita",                     "arcanite bar",                       "奥金锭")
  add("paño de pirotejido",                    "flarecore cloth",                    "炽热之线")
  add("pano de pirotejido",                    "flarecore cloth",                    "炽热之线")
  add("aceite de maná menor",                  "minor mana oil",                     "次级法力油")
  add("aceite de mana menor",                  "minor mana oil",                     "次级法力油")
  add("aceite de mago menor",                  "minor wizard oil",                   "次级巫师油")
  add("cuero curado de pellejo de roca",       "cured rugged hide",                  "熟化毛皮")
  add("paño de runas",                         "runecloth",                          "符文布")
  add("pano de runas",                         "runecloth",                          "符文布")

  -- ╔══════════════════════════════════════════════╗
  -- ║  [NUEVO] CAT 90: WoW Hardcore y Seguridad    ║
  -- ╚══════════════════════════════════════════════╝
  add("agro invisible",                        "invisible aggro",                    "隐性仇恨")
  add("atraer con mascota",                    "pet pull",                           "宠物拉怪")
  add("zona segura",                           "safe spot",                          "安全点")
  add("pérdida de conexión",                   "disconnect",                         "掉线")
  add("perdida de conexion",                   "disconnect",                         "掉线")
  add("burbuja de piedra de hogar",            "bubble hearth",                      "无敌炉石")
  add("guardia de alma",                       "soulstone",                          "灵魂石")
  add("morir en hardcore",                     "hardcore death",                     "硬核死亡")
  add("evitar combate",                        "avoid combat",                       "脱战")
  add("limpiar agro",                          "clear threat",                       "清仇恨")

  -- ╔══════════════════════════════════════════════╗
  -- ║  [NUEVO] CAT 91: Turtle WoW Zonas Custom     ║
  -- ╚══════════════════════════════════════════════╝
  add("alah'thalas",                           "alah'thalas",                        "阿拉萨拉斯")
  add("tierras de la peste del sur",           "southern plaguelands",               "南瘟疫之地")
  add("isla de la disputa",                    "island of disputation",              "争议之岛")
  add("cavernas del tiempo custom",            "custom cot",                         "时光之穴")
  add("forjadores de hierro",                  "ironforge builders",                 "铁炉堡建造者")
  add("bahía del botín custom",                 "custom booty bay",                   "藏宝海湾")
  add("bahia del botin custom",                 "custom booty bay",                   "藏宝海湾")
  add("pueblo revantusk",                      "revantusk village",                  "恶齿村")
  add("bosque de elwynn custom",               "custom elwynn",                      "艾尔文森林")

  -- ╔══════════════════════════════════════════════╗
  -- ║  [NUEVO] CAT 92: Turtle WoW Supervivencia    ║
  -- ╚══════════════════════════════════════════════╝
  add("tienda de campaña",                     "tent",                               "帐篷")
  add("tienda de campana",                     "tent",                               "帐篷")
  add("fogata de supervivencia",               "survival campfire",                  "生存篝火")
  add("jardinería",                            "gardening",                          "园艺")
  add("jardineria",                            "gardening",                          "园艺")
  add("despellejar custom",                    "custom skinning",                    "剥皮")
  add("pesca de supervivencia",                "survival fishing",                   "生存钓鱼")
  add("hacha de supervivencia",                "survival axe",                       "生存手斧")
  add("bolsa de dormir",                       "sleeping bag",                       "睡袋")
  add("palo de fogata",                        "campfire wood",                      "篝火木柴")

  -- ╔══════════════════════════════════════════════╗
  -- ║  [NUEVO] CAT 93: Turtle WoW Modos de Juego   ║
  -- ╚══════════════════════════════════════════════╝
  add("vagabundo",                             "vagrant",                            "流浪者")
  add("lento y constante",                     "slow and steady",                    "龟速模式")
  add("modo desafío",                          "challenge mode",                     "挑战模式")
  add("modo desafio",                          "challenge mode",                     "挑战模式")
  add("modo pacifista",                        "pacifist mode",                      "和平主义")
  add("glifo del guerrero",                    "glyph of the warrior",               "战士雕文")
  add("glifo de experiencia",                  "glyph of experience",                "经验雕文")
  add("sin talentos",                          "no talents challenge",               "无天赋挑战")
  add("viaje de tortuga",                      "turtle journey",                     "乌龟之旅")

  -- ╔══════════════════════════════════════════════╗
  -- ║  [NUEVO] CAT 94: Slang y Modismos de España  ║
  -- ╚══════════════════════════════════════════════╝
  add("guay",                                  "cool",                               "酷")
  add("molar",                                 "to like / cool",                     "喜欢/很酷")
  add("tío",                                   "guy / dude",                         "哥们")
  add("tio",                                   "guy / dude",                         "哥们")
  add("chaval",                                "kid / boy",                          "小子")
  add("vale",                                  "ok",                                 "好的")
  add("currar",                                "to work",                            "工作")
  add("pasta",                                 "money",                              "钱")
  add("chungo",                                "bad / difficult",                    "糟糕/棘手")
  add("gilipollas",                            "asshole",                            "白痴")
  add("hostia",                                "wow / hit",                          "天哪")

  -- ╔══════════════════════════════════════════════╗
  -- ║  [NUEVO] CAT 95: Slang y Modismos de México  ║
  -- ╚══════════════════════════════════════════════╝
  add("chido",                                 "cool",                               "很棒")
  add("wey",                                   "dude",                               "兄弟")
  add("güey",                                  "dude",                               "兄弟")
  add("no manches",                            "no way",                             "不会吧")
  add("órale",                                 "come on / ok",                       "好啦/天哪")
  add("orale",                                 "come on / ok",                       "好啦/天哪")
  add("chavo",                                 "kid / boy",                          "小伙子")
  add("neta",                                  "truth / really",                     "真的吗")
  add("chamba",                                "work / job",                         "工作")
  add("compa",                                 "pal / friend",                       "朋友")
  add("fresa",                                 "snobby",                             "做作的")
  add("chafa",                                 "cheap / bad quality",                "山寨/劣质")

  -- ╔══════════════════════════════════════════════╗
  -- ║  [NUEVO] CAT 96: Slang y Modismos Argentina ║
  -- ╚══════════════════════════════════════════════╝
  add("che",                                   "hey",                                "嘿")
  add("boludo",                                "idiot / friend",                     "笨蛋/伙计")
  add("copado",                                "cool",                               "太棒了")
  add("mina",                                  "girl / woman",                       "女孩")
  add("pibe",                                  "boy / kid",                          "小子")
  add("bondi",                                 "bus",                                "公交车")
  add("laburar",                               "work",                               "工作")
  add("cheto",                                 "fancy / snobby",                     "装腔作势")
  add("quilombo",                              "mess / trouble",                     "混乱/大麻烦")
  add("guita",                                 "money",                              "钱")

  -- ╔══════════════════════════════════════════════╗
  -- ║  [NUEVO] CAT 97: Slang de Internet Chino     ║
  -- ╚══════════════════════════════════════════════╝
  add("yyds",                                  "greatest of all time",               "永远的神")
  add("run",                                   "run away",                           "润")
  add("tang ping",                             "lying flat",                         "躺平")
  add("niubi",                                 "awesome",                            "牛逼")
  add("diao",                                  "cool",                               "屌")
  add("666",                                   "smooth / awesome",                   "溜溜溜")
  add("2333",                                  "laughing out loud",                  "大笑")
  add("555",                                   "crying",                             "呜呜呜")
  add("886",                                   "bye bye",                            "拜拜啦")
  add("kawayi",                                "cute",                               "可爱")

  -- ╔══════════════════════════════════════════════╗
  -- ║  [NUEVO] CAT 98: Dinero y Finanzas Reales    ║
  -- ╚══════════════════════════════════════════════╝
  add("préstamo",                              "loan",                               "贷款")
  add("prestamo",                              "loan",                               "贷款")
  add("tasa de interés",                       "interest rate",                      "利率")
  add("tasa de interes",                       "interest rate",                      "利率")
  add("transferencia bancaria",                 "bank transfer",                      "银行转账")
  add("tarjeta de crédito",                    "credit card",                        "信用卡")
  add("tarjeta de credito",                    "credit card",                        "信用卡")
  add("cajero automático",                     "atm",                                "自动取款机")
  add("cajero automatico",                     "atm",                                "自动取款机")
  add("depósito",                              "deposit",                            "存款")
  add("deposito",                              "deposit",                            "存款")
  add("cuenta de ahorros",                     "savings account",                    "储蓄账户")

  -- ╔══════════════════════════════════════════════╗
  -- ║  [NUEVO] CAT 99: Salud y Emergencias Médicas ║
  -- ╚══════════════════════════════════════════════╝
  add("me siento mal",                         "i feel sick",                        "我感觉不舒服")
  add("necesito un médico",                    "i need a doctor",                    "我需要医生")
  add("necesito un medico",                    "i need a doctor",                    "我需要医生")
  add("ambulancia",                            "ambulance",                          "救护车")
  add("hospital",                              "hospital",                           "医院")
  add("dolor de cabeza",                       "headache",                           "头痛")
  add("farmacia",                              "pharmacy",                           "药房")
  add("receta médica",                         "medical prescription",               "医生处方")
  add("receta medica",                         "medical prescription",               "医生处方")
  add("fractura",                              "fracture",                           "骨折")
  add("fiebre",                                "fever",                              "发烧")

  -- ╔══════════════════════════════════════════════╗
  -- ║  [NUEVO] CAT 100: Redes y Streaming          ║
  -- ╚══════════════════════════════════════════════╝
  add("seguidores",                            "followers",                          "粉丝")
  add("transmisión en vivo",                   "livestream",                         "直播")
  add("transmision en vivo",                   "livestream",                         "直播")
  add("me gusta",                              "likes",                              "点赞")
  add("suscribirse",                           "subscribe",                          "订阅")
  add("compartir enlace",                      "share link",                         "分享链接")
  add("creador de contenido",                  "content creator",                    "内容创作者")
  add("canal de youtube",                      "youtube channel",                    "油管频道")
  add("video viral",                           "viral video",                        "热门视频")
  add("bloquear usuario",                      "block user",                         "拉黑")

  -- ╔══════════════════════════════════════════════╗
  -- ║  [NUEVO] CAT 101: Gastronomía Restaurante    ║
  -- ╚══════════════════════════════════════════════╝
  add("camarero",                              "waiter",                             "服务员")
  add("cuenta por favor",                      "bill please",                        "请结账")
  add("menú del día",                          "menu of the day",                    "今日菜单")
  add("menu del dia",                          "menu of the day",                    "今日菜单")
  add("propina",                               "tip",                                "小费")
  add("alergia alimentaria",                   "food allergy",                       "食物过敏")
  add("vegetariano",                           "vegetarian",                         "素食主义者")
  add("vegano",                                "vegan",                              "纯素食者")
  add("vaso de agua",                          "glass of water",                     "一杯水")
  add("carta de vinos",                        "wine list",                          "酒单")

  -- ╔══════════════════════════════════════════════╗
  -- ║  [NUEVO] CAT 102: Trabajo y Teletrabajo      ║
  -- ╚══════════════════════════════════════════════╝
  add("reunión virtual",                       "virtual meeting",                    "视频会议")
  add("reunion virtual",                       "virtual meeting",                    "视频会议")
  add("fecha límite",                          "deadline",                           "截止日期")
  add("fecha limite",                          "deadline",                           "截止日期")
  add("jefe de proyecto",                      "project manager",                    "项目经理")
  add("correo corporativo",                    "work email",                         "工作邮箱")
  add("horario de trabajo",                    "work hours",                         "工作时间")
  add("salario mensual",                       "monthly salary",                     "月薪")
  add("contrato laboral",                      "employment contract",                "劳动合同")
  add("videollamada",                          "video call",                         "视频通话")

  -- ╔══════════════════════════════════════════════╗
  -- ║  [NUEVO] CAT 103: Ciencia y Física Básica    ║
  -- ╚══════════════════════════════════════════════╝
  add("gravedad",                              "gravity",                            "重力")
  add("órbita planetaria",                     "planetary orbit",                    "行星轨道")
  add("orbita planetaria",                     "planetary orbit",                    "行星轨道")
  add("telescopio espacial",                   "space telescope",                    "空间望远镜")
  add("átomo",                                 "atom",                               "原子")
  add("atomo",                                 "atom",                               "原子")
  add("sistema solar",                         "solar system",                       "太阳系")
  add("agujero negro",                         "black hole",                         "黑洞")
  add("molécula",                              "molecule",                           "分子")
  add("molecula",                              "molecule",                           "分子")
  add("elemento químico",                      "chemical element",                   "化学元素")
  add("elemento quimico",                      "chemical element",                   "化学元素")

  -- ╔══════════════════════════════════════════════╗
  -- ║  [NUEVO] CAT 104: Fenómenos Extremos y Clima ║
  -- ╚══════════════════════════════════════════════╝
  add("terremoto",                             "earthquake",                         "地震")
  add("huracán",                               "hurricane",                          "飓风")
  add("huracan",                               "hurricane",                          "飓风")
  add("inundación repentina",                  "flash flood",                        "山洪暴发")
  add("inundacion repentina",                  "flash flood",                        "山洪暴发")
  add("sequía prolongada",                     "prolonged drought",                  "长期干旱")
  add("sequia prolongada",                     "prolonged drought",                  "长期干旱")
  add("tornado",                               "tornado",                            "龙卷风")
  add("tormenta de arena",                     "sandstorm",                          "沙尘暴")
  add("erupción volcánica",                    "volcanic eruption",                  "火山喷发")
  add("erupcion volcanica",                    "volcanic eruption",                  "火山喷发")

  -- ╔══════════════════════════════════════════════╗
  -- ║  [NUEVO] CAT 105: Cortesía y Expresiones     ║
  -- ╚══════════════════════════════════════════════╝
  add("disculpe las molestias",                "sorry for the inconvenience",        "抱歉给您带来不便")
  add("con su permiso",                        "with your permission",               "打扰一下")
  add("es usted muy amable",                   "you are very kind",                  "您太客气了")
  add("lo aprecio sinceramente",               "i sincerely appreciate it",          "由衷感谢")
  add("mucho gusto en conocerle",              "pleasure to meet you",               "很高兴认识您")
  add("le deseo lo mejor",                     "wish you the best",                  "祝您一切顺利")
  add("que tenga un buen día",                 "have a nice day",                    "祝你度过美好的一天")
  add("que tenga un buen dia",                 "have a nice day",                    "祝你度过美好的一天")

  -- ╔══════════════════════════════════════════════╗
  -- ║  [NUEVO] CAT 106: Ansiedad y Carga Emocional ║
  -- ╚══════════════════════════════════════════════╝
  add("estoy agobiado",                        "i am overwhelmed",                   "我快崩溃了")
  add("tengo dudas",                           "i have doubts",                      "我有疑虑")
  add("ataque de pánico",                      "panic attack",                       "恐慌发作")
  add("ataque de panico",                      "panic attack",                       "恐慌发作")
  add("ansiedad social",                       "social anxiety",                     "社交焦虑")
  add("estrés acumulado",                      "accumulated stress",                 "压力累积")
  add("estres acumulado",                      "accumulated stress",                 "压力累积")
  add("me siento bajo presión",                "i feel under pressure",              "我感到压力很大")
  add("me siento bajo presion",                "i feel under pressure",              "我感到压力很大")
  add("tensión mental",                        "mental tension",                     "精神紧张")
  add("tension mental",                        "mental tension",                     "精神紧张")

  -- ╔══════════════════════════════════════════════╗
  -- ║  [NUEVO] CAT 107: Compras y Regateo          ║
  -- ╚══════════════════════════════════════════════╝
  add("¿cuánto cuesta?",                       "how much does it cost?",             "这个多少钱？")
  add("¿cuanto cuesta?",                       "how much does it cost?",             "这个多少钱？")
  add("¿tiene descuento?",                     "is there a discount?",               "有折扣吗？")
  add("rebajas de temporada",                  "seasonal sales",                     "季节性打折")
  add("precio mínimo",                         "minimum price",                      "最低价")
  add("precio minimo",                         "minimum price",                      "最低价")
  add("muy costoso",                           "very expensive",                     "太贵了")
  add("esta barato",                           "it's cheap",                         "很便宜")
  add("está barato",                           "it's cheap",                         "很便宜")
  add("oferta especial",                       "special offer",                      "特价优惠")

  -- ╔══════════════════════════════════════════════╗
  -- ║  [NUEVO] CAT 108: Transporte Urbano          ║
  -- ╚══════════════════════════════════════════════╝
  add("boleto de metro",                       "subway ticket",                      "地铁票")
  add("estación de autobús",                   "bus station",                        "公交车站")
  add("estacion de autobus",                   "bus station",                        "公交车站")
  add("parada de taxis",                       "taxi stand",                         "出租车停靠点")
  add("hacer transbordo",                      "to transfer lines",                  "换乘")
  add("mapa de líneas",                        "transit map",                        "路线图")
  add("mapa de lineas",                        "transit map",                        "路线图")
  add("tarifa de viaje",                       "travel fare",                        "票价")
  add("viaje sencillo",                        "single trip",                        "单程票")

  -- ╔══════════════════════════════════════════════╗
  -- ║  [NUEVO] CAT 109: Vivienda y Alquileres      ║
  -- ╚══════════════════════════════════════════════╝
  add("apartamento amueblado",                 "furnished apartment",                "精装公寓")
  add("contrato de alquiler",                  "lease contract",                     "租赁合同")
  add("depósito de fianza",                    "security deposit",                   "押金")
  add("deposito de fianza",                    "security deposit",                   "押金")
  add("camión de mudanza",                     "moving truck",                       "搬家卡车")
  add("camion de mudanza",                     "moving truck",                       "搬家卡车")
  add("casero",                                "landlord",                           "房东")
  add("pago de renta",                         "rent payment",                       "房租")
  add("inquilino",                             "tenant",                             "租客")

  -- ╔══════════════════════════════════════════════╗
  -- ║  [NUEVO] CAT 110: Videojuegos e Hardware     ║
  -- ╚══════════════════════════════════════════════╝
  add("tarjeta gráfica",                       "graphics card",                      "显卡")
  add("tarjeta grafica",                       "graphics card",                      "显卡")
  add("latencia de red",                       "network latency",                    "网络延迟")
  add("fotogramas por segundo",                "frames per second",                  "帧率")
  add("resolución de pantalla",                "screen resolution",                  "屏幕分辨率")
  add("resolucion de pantalla",                "screen resolution",                  "屏幕分辨率")
  add("procesador central",                    "cpu",                                "处理器")
  add("memoria de video",                      "video ram",                          "显存")
  add("teclado mecánico",                      "mechanical keyboard",                "机械键盘")
  add("teclado mecanico",                      "mechanical keyboard",                "机械键盘")

  -- ╔══════════════════════════════════════════════╗
  -- ║  [NUEVO] CAT 111: Biología Marina y Océanos  ║
  -- ╚══════════════════════════════════════════════╝
  add("arrecife de coral",                     "coral reef",                         "珊瑚礁")
  add("delfín nariz de botella",               "bottlenose dolphin",                 "宽吻海豚")
  add("delfin nariz de botella",               "bottlenose dolphin",                 "宽吻海豚")
  add("tiburón blanco",                        "great white shark",                  "大白鲨")
  add("tiburon blanco",                        "great white shark",                  "大白鲨")
  add("marea alta",                            "high tide",                          "满潮")
  add("oleaje fuerte",                         "rough seas",                         "风浪")
  add("profundidades del mar",                 "deep sea",                           "深海")
  add("corriente marina",                      "ocean current",                      "洋流")

  -- ╔══════════════════════════════════════════════╗
  -- ║  [NUEVO] CAT 112: Servicios de Hotelería     ║
  -- ╚══════════════════════════════════════════════╝
  add("habitación doble",                      "double room",                        "双人间")
  add("habitacion doble",                      "double room",                        "双人间")
  add("registro de entrada",                   "check-in",                           "办理入住")
  add("registro de salida",                   "check-out",                          "办理退房")
  add("contraseña del wifi",                   "wifi password",                      "无线密码")
  add("contrasena del wifi",                   "wifi password",                      "无线密码")
  add("servicio de habitaciones",              "room service",                       "客房服务")
  add("recepción las veinticuatro horas",      "24-hour reception",                  "全天候前台")
  add("recepcion las veinticuatro horas",      "24-hour reception",                  "全天候前台")

  -- ╔══════════════════════════════════════════════╗
  -- ║  [NUEVO] CAT 113: Términos Legales           ║
  -- ╚══════════════════════════════════════════════╝
  add("abogado de oficio",                     "public defender",                    "公设辩护人")
  add("firmar contrato",                       "sign contract",                      "签署合同")
  add("demanda judicial",                      "lawsuit",                            "起诉")
  add("multa de tránsito",                     "traffic ticket",                     "交通罚单")
  add("multa de transito",                     "traffic ticket",                     "交通罚单")
  add("presentar denuncia",                    "file a complaint",                   "报案")
  add("juicio penal",                          "criminal trial",                     "刑事审判")
  add("tribunal de justicia",                  "court of law",                       "法庭")

  -- ╔══════════════════════════════════════════════╗
  -- ║  [NUEVO] CAT 114: Geografía Física           ║
  -- ╚══════════════════════════════════════════════╝
  add("cordillera montañosa",                  "mountain range",                     "山脉")
  add("cordillera montanosa",                  "mountain range",                     "山脉")
  add("desierto de arena",                     "sand desert",                        "沙质荒漠")
  add("selva tropical",                        "tropical rainforest",                "热带雨林")
  add("llanura verde",                         "green plain",                        "绿洲平原")
  add("cañón profundo",                        "deep canyon",                        "深峡谷")
  add("canon profundo",                        "deep canyon",                        "深峡谷")
  add("cascada de agua",                       "waterfall",                          "瀑布")
  add("lago de agua dulce",                    "freshwater lake",                    "淡水湖")

  -- ╔══════════════════════════════════════════════╗
  -- ║  [NUEVO] CAT 115: Familia Política           ║
  -- ╚══════════════════════════════════════════════╝
  add("mi prometido",                          "my fiancé",                          "我的未婚夫")
  add("mi prometida",                          "my fiancée",                         "我的未婚妻")
  add("mi suegro",                             "my father-in-law",                   "我的公公/岳父")
  add("mi cuñado",                             "my brother-in-law",                  "我的小叔子/大舅子")
  add("mi cunado",                             "my brother-in-law",                  "我的小叔子/大舅子")
  add("mi yerno",                              "my son-in-law",                      "我的女婿")
  add("mi nuera",                              "my daughter-in-law",                 "我的儿媳")
  add("noviazgo estable",                      "stable relationship",                "稳定的恋爱关系")
  add("suegra",                                "mother-in-law",                      "婆婆/岳母")

  -- ╔══════════════════════════════════════════════╗
  -- ║  [NUEVO] CAT 116: Inteligencia Artificial    ║
  -- ╚══════════════════════════════════════════════╝
  add("modelo de lenguaje",                    "language model",                     "语言模型")
  add("prompts de optimización",               "optimization prompts",               "优化提示词")
  add("prompts de optimizacion",               "optimization prompts",               "优化提示词")
  add("conjunto de datos",                     "dataset",                            "数据集")
  add("algoritmo predictivo",                  "predictive algorithm",               "预测算法")
  add("red neuronal",                          "neural network",                     "神经网络")
  add("aprendizaje automático",                "machine learning",                   "机器学习")
  add("aprendizaje automatico",                "machine learning",                   "机器学习")

  -- ╔══════════════════════════════════════════════╗
  -- ║  [NUEVO] CAT 117: Júbilo y Celebración       ║
  -- ╚══════════════════════════════════════════════╝
  add("enhorabuena",                           "congratulations",                    "祝贺")
  add("éxito rotundo",                         "resounding success",                 "巨大的成功")
  add("exito rotundo",                         "resounding success",                 "巨大的成功")
  add("celebración de victoria",               "victory celebration",                "胜利庆祝")
  add("celebracion de victoria",               "victory celebration",                "胜利庆祝")
  add("alegría inmensa",                       "immense joy",                        "极大的快乐")
  add("alegria inmensa",                       "immense joy",                        "极大的快乐")
  add("¡muchas felicidades!",                  "congratulations!",                   "衷心祝贺！")
  add("muchas felicidades",                    "congratulations",                    "衷心祝贺")

  -- ╔══════════════════════════════════════════════╗
  -- ║  [NUEVO] CAT 118: Vestimenta y Moda          ║
  -- ╚══════════════════════════════════════════════╝
  add("camisa de vestir",                      "dress shirt",                        "衬衫")
  add("pantalones cortos",                     "shorts",                             "短裤")
  add("zapatos de cuero",                      "leather shoes",                      "皮鞋")
  add("chaqueta de invierno",                  "winter jacket",                      "防寒夹克")
  add("lentes de sol",                         "sunglasses",                         "太阳镜")
  add("vestido elegante",                      "elegant dress",                      "礼服裙")
  add("sombrero de ala",                       "brimmed hat",                        "宽檐帽")
  add("bufanda de lana",                       "wool scarf",                         "羊毛围巾")

  -- ╔══════════════════════════════════════════════╗
  -- ║  [NUEVO] CAT 119: Hobbies y Manualidades     ║
  -- ╚══════════════════════════════════════════════╝
  add("tejer lana",                            "knit wool",                          "织毛衣")
  add("pintura al óleo",                       "oil painting",                       "油画")
  add("pintura al oleo",                       "oil painting",                       "油画")
  add("fotografía de naturaleza",               "nature photography",                 "自然摄影")
  add("fotografia de naturaleza",               "nature photography",                 "自然摄影")
  add("cocina gourmet",                        "gourmet cooking",                    "美食烹饪")
  add("lectura de novelas",                    "novel reading",                      "小说阅读")
  add("jardinería urbana",                     "urban gardening",                    "都市园艺")
  add("jardineria urbana",                     "urban gardening",                    "都市园艺")

  -- ╔══════════════════════════════════════════════╗
  -- ║  [NUEVO] CAT 120: Despedidas y Buenos Deseos ║
  -- ╚══════════════════════════════════════════════╝
  add("que te vaya excelente",                 "wish you all the best",              "祝你一切顺利")
  add("cuídate mucho",                         "take care a lot",                    "多加保重")
  add("cuidate mucho",                         "take care a lot",                    "多加保重")
  add("que tengas un feliz viaje",             "have a safe trip",                   "祝你旅途愉快")
  add("nos vemos pronto",                      "see you soon",                       "回头见")
  add("hasta la próxima",                      "until next time",                    "下次见")
  add("hasta la proxima",                      "until next time",                    "下次见")
  add("éxito en todo",                         "success in everything",              "事事顺心")
  add("exito en todo",                         "success in everything",              "事事顺心")

  -- ╔══════════════════════════════════════════════╗
  -- ║  [NUEVO] CAT 121: WoW Reclutamiento de Guild  ║
  -- ╚══════════════════════════════════════════════╝
  add("reclutando dps para raid",               "recruiting dps for raid",            "公会活动招输出")
  add("busco hermandad activa",                 "looking for active guild",           "求活跃公会")
  add("hacemos dkp",                            "we do dkp",                          "我们用dkp")
  add("loot por dados",                         "roll for loot",                      "roll点分装备")
  add("raid los fines de semana",               "weekend raid",                       "周末活动")
  add("busco dps para raid de hermandad",       "looking for guild raid dps",         "公会活动招输出")
  add("horario nocturno",                       "night schedule",                     "活动时间在晚上")
  add("discord obligatorio",                    "discord mandatory",                  "必须进语音")
  add("ambiente tranquilo",                     "chill environment",                  "氛围和谐")
  add("progreso de banda",                      "raid progress",                      "开荒进度")

  -- ╔══════════════════════════════════════════════╗
  -- ║  [NUEVO] CAT 122: WoW Jefes de Banda Núcleo    ║
  -- ╚══════════════════════════════════════════════╝
  add("núcleo de magma",                        "molten core",                        "熔火之心")
  add("nucleo de magma",                        "molten core",                        "熔火之心")
  add("guarida de onyxia",                      "onyxia's lair",                      "奥妮克希亚的巢穴")
  add("guarida de alanegra",                    "blackwing lair",                     "黑翼之巢")
  add("lucifron",                               "lucifron",                           "鲁西弗隆")
  add("magmadar",                               "magmadar",                           "玛格曼达")
  add("gehennas",                               "gehennas",                           "基根纳斯")
  add("garr",                                   "garr",                               "加尔")
  add("barón geddon",                           "baron geddon",                       "迦顿男爵")
  add("baron geddon",                           "baron geddon",                       "迦顿男爵")
  add("shazzrah",                               "shazzrah",                           "沙斯拉尔")
  add("sufuron",                                "sulfuron harbinger",                 "萨弗隆先驱者")
  add("golemagg",                               "golemagg the incinerator",           "焚化者古莱曼格")
  add("mayordomo executus",                     "majordomo executus",                 "管理者埃克索图斯")
  add("ragnaros",                               "ragnaros",                           "拉格纳罗斯")
  add("razorgore",                              "razorgore the untamed",              "狂野 de la 拉佐格尔")
  add("vaelastrasz",                            "vaelastrasz the red",                "红龙瓦拉斯塔兹")
  add("broodlord",                              "broodlord lashlayer",                "勒什雷尔")
  add("firemaw",                                "firemaw",                            "费尔默")
  add("ebonroc",                                "ebonroc",                            "埃博诺克")
  add("flamegor",                               "flamegor",                           "弗莱格尔")
  add("chromaggus",                             "chromaggus",                         "克洛玛古斯")
  add("nefarian",                               "nefarian",                           "奈法利安")

  -- ╔══════════════════════════════════════════════╗
  -- ║  [NUEVO] CAT 123: WoW Jefes de Banda ZG/AQ/NX ║
  -- ╚══════════════════════════════════════════════╝
  add("zul'gurub",                              "zul'gurub",                          "祖尔格拉布")
  add("ruinas de ahn'qiraj",                    "ruins of ahn'qiraj",                 "安其拉废墟")
  add("templo de ahn'qiraj",                    "templo de ahn'qiraj",                "安其拉神殿")
  add("naxxramas",                              "naxxramas",                          "纳克萨玛斯")
  add("hakkar el cazador de almas",             "hakkar the soulflayer",              "哈卡")
  add("ossirian el sin configurar",             "ossirian the unscarred",             "无孔不入的奥斯里安")
  add("sartura",                                "battleguard sartura",                "沙尔图拉")
  add("fankriss",                               "fankriss the unyielding",            "范克瑞斯")
  add("huhu",                                   "princess huhuran",                   "哈霍兰公主")
  add("emperadores gemelos",                    "twin emperors",                      "双子皇帝")
  add("c'thun",                                 "c'thun",                             "克苏恩")
  add("kel'thuzad",                             "kel'thuzad",                         "克尔苏加德")

  -- ╔══════════════════════════════════════════════╗
  -- ║  [NUEVO] CAT 124: WoW Consumibles de Alquimia║
  -- ╚══════════════════════════════════════════════╝
  add("frasco de poder supremo",                "flask of supreme power",             "至高能量合剂")
  add("frasco de titanes",                      "flask of the titans",                "泰坦合剂")
  add("elixir de mangosta",                     "elixir of the mongoose",             "猫鼬药剂")
  add("poción de maná excelente",               "major mana potion",                  "大蓝药水")
  add("pocion de mana excelente",               "major mana potion",                  "大蓝药水")
  add("poción de vida excelente",               "major healing potion",               "大红药水")
  add("pocion de vida excelente",               "major healing potion",               "大红药水")
  add("ron de ríonegro",                        "rumsey rum black label",             "朗姆酒")
  add("ron de rionegro",                        "rumsey rum black label",             "朗姆酒")
  add("té de cardo",                            "thistle tea",                        "菊花茶")
  add("te de cardo",                            "thistle tea",                        "菊花茶")

  -- ╔══════════════════════════════════════════════╗
  -- ║  [NUEVO] CAT 125: WoW Materiales de Crafteo  ║
  -- ╚══════════════════════════════════════════════╝
  add("paño de tejido de runas",                "runeweave cloth",                    "符文布")
  add("pano de tejido de runas",                "runeweave cloth",                    "符文布")
  add("barra de arcanita",                      "arcanite bar",                       "奥金锭")
  add("cuero de pellejo de sombra",             "shadowcat hide",                     "暗影猫皮")
  add("saronita",                               "saronite",                           "萨隆邪铁")
  add("barra de torio",                         "thorium bar",                        "瑟银锭")
  add("paño de linaje",                         "felcloth",                           "恶魔布")
  add("pano de linaje",                         "felcloth",                           "恶魔布")
  add("esencia de agua",                        "essence of water",                   "水之精华")
  add("esencia de fuego",                       "essence of fire",                    "火之精华")
  add("esencia de tierra",                      "essence of earth",                   "大地精华")
  add("esencia de aire",                        "essence of air",                     "空气精华")

  -- ╔══════════════════════════════════════════════╗
  -- ║  [NUEVO] CAT 126: Conversación Informal      ║
  -- ╚══════════════════════════════════════════════╝
  add("todo marcha bien",                       "everything is going fine",           "一切都进行得很好")
  add("tengo muchas ganas de jugar",            "i really want to play",              "我很想玩游戏")
  add("¿qué estás haciendo hoy?",               "what are you doing today?",          "你今天在干嘛？")
  add("que estas haciendo hoy",                 "what are you doing today?",          "你今天在干嘛？")
  add("no me siento bien hoy",                  "i don't feel well today",            "我今天感觉不太舒服")
  add("espero verte pronto",                    "hope to see you soon",               "希望很快见到你")
  add("gracias por la información",             "thanks for the info",                "谢谢你提供的信息")
  add("gracias por la informacion",             "thanks for the info",                "谢谢你提供的信息")
  add("eso tiene mucho sentido",                "that makes a lot of sense",          "这很有道理")
  add("estoy de acuerdo contigo",               "i agree with you",                   "我同意你的看法")

  -- ╔══════════════════════════════════════════════╗
  -- ║  [NUEVO] CAT 127: Expresiones de Comercio    ║
  -- ╚══════════════════════════════════════════════╝
  add("vendo por oro",                          "selling for gold",                   "金币出售")
  add("compro materiales",                      "buying mats",                        "收材料")
  add("hago descuento",                         "giving a discount",                  "打折优惠")
  add("no me queda oro",                        "no gold left",                       "没有金币了")
  add("precio negociable",                      "negotiable price",                   "价格可谈")
  add("precio fijo",                            "fixed price",                        "固定价格")
  add("¿haces rebaja?",                         "can you lower the price?",           "能便宜点吗？")
  add("haces rebaja",                           "can you lower the price?",           "能便宜点吗？")
  add("es demasiado caro",                      "it is too expensive",                "太贵了")
  add("es una ganga",                           "it's a bargain",                     "真划算")

  -- ╔══════════════════════════════════════════════╗
  -- ║  CAT 128: Turtle WoW Misiones y Economia     ║
  -- ╚══════════════════════════════════════════════╝
  add("misión personalizada",                   "custom quest",                       "自定义任务")
  add("mision personalizada",                   "custom quest",                       "自定义任务")
  add("tienda de donación",                     "donation shop",                      "商城")
  add("tienda de donacion",                     "donation shop",                      "商城")
  add("moneda de donación",                     "donation token",                     "商城币")
  add("moneda de donacion",                     "donation token",                     "商城币")
  add("isla de la disputa",                     "battleground island",                "战场岛")
  add("evento de hermandad",                    "guild event",                        "公会活动")
  add("recompensa de misión",                   "quest reward",                       "任务奖励")
  add("recompensa de mision",                   "quest reward",                       "任务奖励")
  add("reputación personalizada",               "custom reputation",                  "自定义声望")
  add("reputacion personalizada",               "custom reputation",                  "自定义声望")

  -- ╔══════════════════════════════════════════════╗
  -- ║  CAT 129: Slang de Gaming y Frustracion      ║
  -- ╚══════════════════════════════════════════════╝
  add("¡qué mala suerte!",                      "what bad luck!",                     "太倒霉了！")
  add("que mala suerte",                        "what bad luck!",                     "太倒霉了！")
  add("he muerto otra vez",                     "died again",                         "又死了")
  add("¿por qué siempre yo?",                   "why always me?",                     "为什么总是我？")
  add("por que siempre yo",                     "why always me?",                     "为什么总是我？")
  add("este grupo es terrible",                 "this group is terrible",             "这队伍太烂了")
  add("no saben jugar",                         "they don't know how to play",        "他们不会玩")
  add("¡qué asco!",                             "how disgusting!",                    "太恶心了！")
  add("que asco",                               "how disgusting!",                    "太恶心了！")
  add("estoy harto",                            "i am fed up",                        "我受够了")

  -- ╔══════════════════════════════════════════════╗
  -- ║  CAT 130: Felicitaciones, Ding y Logros      ║
  -- ╚══════════════════════════════════════════════╝
  add("¡felicidades por el nivel!",             "grats on level up!",                 "恭喜升级！")
  add("felicidades por el nivel",               "grats on level up!",                 "恭喜升级！")
  add("¡felicidades!",                          "congratulations!",                   "恭喜恭喜！")
  add("felicidades",                            "congratulations!",                   "恭喜恭喜！")
  add("¡bien hecho!",                           "well done!",                         "干得漂亮！")
  add("bien hecho",                             "well done!",                         "干得漂亮！")
  add("sigue así",                              "keep it up",                         "继续保持")
  add("sigue asi",                              "keep it up",                         "继续保持")
  add("¡buen trabajo!",                         "good job!",                          "做得好！")
  add("buen trabajo",                           "good job!",                          "做得好！")
  add("orgulloso de ti",                        "proud of you",                       "为你骄傲")

  -- ╔══════════════════════════════════════════════╗
  -- ║  CAT 131: Saludos y Despedidas Conversación  ║
  -- ╚══════════════════════════════════════════════╝
  add("hola amigo",                             "hello friend",                       "你好朋友")
  add("buenos días",                            "good morning",                       "早上好")
  add("buenos dias",                            "good morning",                       "早上好")
  add("buenas tardes",                          "good afternoon",                     "下午好")
  add("buenas noches",                          "good night",                         "晚安")
  add("hasta luego",                            "see you later",                      "回头见")
  add("nos vemos",                              "see you",                            "再见")
  add("cuídate",                                "take care",                          "保重")
  add("cuidate",                                "take care",                          "保重")
  add("bienvenido",                             "welcome",                            "欢迎")
  add("hola a todos",                           "hello everyone",                     "大家好")

  -- ╔══════════════════════════════════════════════╗
  -- ║  CAT 132: Expresiones de Cortesía Social     ║
  -- ╚══════════════════════════════════════════════╝
  add("por favor",                              "please",                             "请")
  add("muchas gracias",                         "thank you very much",                "非常感谢")
  add("de nada",                                "you are welcome",                    "不客气")
  add("disculpa",                               "excuse me",                          "打扰一下")
  add("perdón",                                 "sorry",                              "对不起")
  add("perdon",                                 "sorry",                              "对不起")
  add("no te preocupes",                        "don't worry",                        "别担心")
  add("está bien",                              "it's okay",                          "没关系")
  add("esta bien",                              "it's okay",                          "没关系")
  add("con gusto",                              "with pleasure",                      "乐意效劳")
  add("igualmente",                             "likewise",                           "你也一样")

  -- ╔══════════════════════════════════════════════╗
  -- ║  CAT 133: Acuerdo y Desacuerdo de Chat       ║
  -- ╚══════════════════════════════════════════════╝
  add("estoy de acuerdo",                       "i agree",                            "我同意")
  add("tienes razón",                           "you are right",                      "你说得对")
  add("tienes razon",                           "you are right",                      "你说得对")
  add("no estoy de acuerdo",                    "i disagree",                         "我不同意")
  add("claro que sí",                           "of course yes",                      "当然可以")
  add("claro que si",                           "of course yes",                      "当然可以")
  add("por supuesto",                           "of course",                          "当然")
  add("de ninguna manera",                      "no way",                             "绝对不行")
  add("tal vez",                                "maybe",                              "也许")
  add("quizás",                                 "perhaps",                            "可能")
  add("quizas",                                 "perhaps",                            "可能")
  add("creo que sí",                            "i think so",                         "我想是的")
  add("creo que si",                            "i think so",                         "我想是的")
  add("creo que no",                            "i don't think so",                   "我看不行")

  -- ╔══════════════════════════════════════════════╗
  -- ║  CAT 134: Preguntas Cotidianas de Conversación║
  -- ╚══════════════════════════════════════════════╝
  add("¿cómo estás?",                           "how are you?",                       "你好吗？")
  add("como estas",                             "how are you?",                       "你好吗？")
  add("¿qué tal?",                              "how's it going?",                    "怎么样？")
  add("que tal",                                "how's it going?",                    "怎么样？")
  add("¿de dónde eres?",                        "where are you from?",                "你来自哪里？")
  add("de donde eres",                          "where are you from?",                "你来自哪里？")
  add("¿qué haces?",                            "what are you doing?",                "你在干嘛？")
  add("que haces",                              "what are you doing?",                "你在干嘛？")
  add("¿puedes ayudarme?",                      "can you help me?",                   "你能帮我吗？")
  add("puedes ayudarme",                        "can you help me?",                   "你能帮我吗？")
  add("¿qué pasa?",                             "what's happening?",                  "怎么了？")
  add("que pasa",                               "what's happening?",                  "怎么了？")
  add("¿a qué hora?",                           "at what time?",                      "什么时候？")
  add("a que hora",                             "at what time?",                      "什么时候？")

  -- ╔══════════════════════════════════════════════╗
  -- ║  CAT 135: Expresiones de Tiempo e Intervalos ║
  -- ╚══════════════════════════════════════════════╝
  add("hoy",                                    "today",                              "今天")
  add("mañana",                                 "tomorrow",                           "明天")
  add("manana",                                 "tomorrow",                           "明天")
  add("ayer",                                   "yesterday",                          "昨天")
  add("ahora",                                  "now",                                "现在")
  add("después",                                "later",                              "稍后")
  add("despues",                                "later",                              "稍后")
  add("tarde",                                  "late",                               "迟到")
  add("temprano",                               "early",                              "早起")
  add("siempre",                                "always",                             "总是")
  add("nunca",                                  "never",                              "从不")
  add("a veces",                                "sometimes",                          "有时")
  add("un momento",                             "one moment",                         "稍等一下")

  -- ╔══════════════════════════════════════════════╗
  -- ║  CAT 136: Sentimientos, Estados y Opinión    ║
  -- ╚══════════════════════════════════════════════╝
  add("estoy cansado",                          "i am tired",                         "我很累")
  add("estoy feliz",                            "i am happy",                         "我很开心")
  add("tengo hambre",                           "i am hungry",                        "我饿了")
  add("tengo sueño",                            "i am sleepy",                        "我困了")
  add("tengo sueno",                            "i am sleepy",                        "我困了")
  add("estoy aburrido",                         "i am bored",                         "我很无聊")
  add("es difícil",                             "it is hard",                         "很难")
  add("es dificil",                             "it is hard",                         "很难")
  add("es fácil",                               "it is easy",                         "很简单")
  add("es facil",                               "it is easy",                         "很简单")
  add("me gusta",                               "i like it",                          "我喜欢")
  add("no me gusta",                            "i don't like it",                    "我不喜欢")
  add("es genial",                              "it is great",                        "太棒了")
  add("es increíble",                           "it is amazing",                      "太不可思议了")
  add("es increible",                           "it is amazing",                      "太不可思议了")

  -- ╔══════════════════════════════════════════════╗
  -- ║  CAT 137: Respuestas Cortas y Conectores     ║
  -- ╚══════════════════════════════════════════════╝
  add("entonces",                               "then",                               "然后")
  add("además",                                 "besides",                            "此外")
  add("ademas",                                 "besides",                            "此外")
  add("también",                                "also",                               "也")
  add("tambien",                                "also",                               "也")
  add("porque",                                 "because",                            "因为")
  add("pero",                                   "but",                                "但是")
  add("entendido",                              "understood",                         "明白了")
  add("correcto",                               "correct",                            "正确")
  add("perfecto",                               "perfect",                            "完美")
  add("listo",                                  "ready",                              "准备好了")
  add("vamos",                                  "let's go",                           "走吧")

  -- ╔══════════════════════════════════════════════╗
  -- ║  CAT 138: Localización e Indicadores         ║
  -- ╚══════════════════════════════════════════════╝
  add("aquí",                                   "here",                               "这里")
  add("aqui",                                   "here",                               "这里")
  add("allí",                                   "there",                              "那里")
  add("alli",                                   "there",                              "那里")
  add("cerca",                                  "near",                               "附近")
  add("lejos",                                  "far",                                "远")
  add("derecha",                                "right",                              "右边")
  add("izquierda",                              "left",                               "左边")
  add("recto",                                  "straight ahead",                     "直走")
  add("arriba",                                 "up",                                 "上面")
  add("abajo",                                  "down",                               "下面")
  add("dentro",                                 "inside",                             "里面")
  add("fuera",                                  "outside",                            "外面")

  -- ╔══════════════════════════════════════════════╗
  -- ║  CAT 139: Cantidades y Números Básicos       ║
  -- ╚══════════════════════════════════════════════╝
  add("uno",                                    "one",                                "一")
  add("dos",                                    "two",                                "二")
  add("tres",                                    "three",                              "三")
  add("mucho",                                  "a lot",                              "很多")
  add("poco",                                   "a little",                           "很少")
  add("todo",                                   "all",                                "全部")
  add("nada",                                   "nothing",                            "没有")
  add("algunos",                                "some",                               "一些")
  add("más",                                    "more",                               "更多")
  add("mas",                                    "more",                               "更多")
  add("menos",                                  "less",                               "更少")
  add("suficiente",                             "enough",                             "足够")

  -- ╔══════════════════════════════════════════════╗
  -- ║  CAT 140: Soporte, Red y Servidor General    ║
  -- ╚══════════════════════════════════════════════╝
  add("lag",                                    "latency",                            "延迟")
  add("ping alto",                              "high ping",                          "高延迟")
  add("caída de servidor",                      "server crash",                       "服务器崩溃")
  add("caida de servidor",                      "server crash",                       "服务器崩溃")
  add("reinicio",                               "restart",                            "重启")
  add("actualización",                          "update",                             "更新")
  add("actualizacion",                          "update",                             "更新")
  add("bugueado",                               "bugged",                             "卡bug")
  add("soporte técnico",                        "technical support",                  "技术支持")
  add("soporte tecnico",                        "technical support",                  "技术支持")
  add("foro",                                   "forum",                              "论坛")
  add("discord",                                "discord server",                     "DC群")
  add("parche",                                 "patch",                              "补丁")

  -- ╔══════════════════════════════════════════════╗
  -- ║  CAT 141: Interacción de la Comunidad        ║
  -- ╚══════════════════════════════════════════════╝
  add("buena vibra",                            "good vibes",                         "正能量")
  add("gente maja",                             "nice people",                        "友善的人")
  add("buena onda",                             "good vibes",                         "正能量")
  add("buen rollo",                             "good vibes",                         "和谐氛围")

  -- ╔══════════════════════════════════════════════╗
  -- ║  CAT 142: Tácticas de Combate Avanzadas      ║
  -- ╚══════════════════════════════════════════════╝
  add("hacer foco",                             "focus target",                       "集火目标")
  add("dispersarse",                            "spread out",                         "分散站位")
  add("interrumpir casteo",                     "interrupt cast",                     "打断施法")
  add("interrumpir el casteo",                  "interrupt the cast",                 "打断施法")

  -- ╔══════════════════════════════════════════════╗
  -- ║  CAT 143: Negociación en Subasta             ║
  -- ╚══════════════════════════════════════════════╝
  add("precio fijo",                            "fixed price",                        "一口价")
  add("precio negociable",                      "negotiable price",                   "价格可议")
  add("ultima oferta",                          "last offer",                         "最后出价")
  add("última oferta",                          "last offer",                         "最后出价")

  -- ╔══════════════════════════════════════════════╗
  -- ║  CAT 144: Exploración y Rutas                ║
  -- ╚══════════════════════════════════════════════╝
  add("camino seguro",                          "safe path",                          "安全路径")
  add("atajo",                                  "shortcut",                           "捷径")
  add("zona peligrosa",                         "dangerous zone",                     "危险区域")

  -- ╔══════════════════════════════════════════════╗
  -- ║  CAT 145: Alertas de Estado                  ║
  -- ╚══════════════════════════════════════════════╝
  add("tengo agro",                             "i have aggro",                       "我OT了")
  add("sin mana",                               "out of mana",                        "没蓝了")
  add("sin maná",                               "out of mana",                        "没蓝了")
  add("healer muerto",                          "healer is dead",                     "奶妈死了")

  -- ╔══════════════════════════════════════════════╗
  -- ║  CAT 146: Profesiones y Recolección          ║
  -- ╚══════════════════════════════════════════════╝
  add("mena de oro",                            "gold vein",                          "金矿")
  add("hierba rara",                            "rare herb",                          "稀有草药")
  add("crafteo gratis",                         "free crafting",                      "免费代工")

  -- ╔══════════════════════════════════════════════╗
  -- ║  CAT 147: Orientación y Brújula              ║
  -- ╚══════════════════════════════════════════════╝
  add("al norte",                               "to the north",                       "向北")
  add("al sur",                                 "to the south",                       "向南")
  add("al este",                                "to the east",                        "向东")
  add("al oeste",                               "to the west",                        "向西")

  -- ╔══════════════════════════════════════════════╗
  -- ║  CAT 148: Alertas de Emergencia              ║
  -- ╚══════════════════════════════════════════════╝
  add("corran por sus vidas",                   "run for your lives",                 "快逃命吧")
  add("cuidado atras",                          "watch out behind",                   "小心后面")
  add("cuidado atrás",                          "watch out behind",                   "小心后面")
  add("patrulla cerca",                         "patrol nearby",                      "巡逻怪靠近")

  -- ╔══════════════════════════════════════════════╗
  -- ║  CAT 149: Saludos Especiales de Rol          ║
  -- ╚══════════════════════════════════════════════╝
  add("que la luz te guie",                     "may the light guide you",            "愿圣光指引你")
  add("que la luz te guíe",                     "may the light guide you",            "愿圣光指引你")
  add("por la horda",                           "for the horde",                      "为了部落")
  add("por la alianza",                         "for the alliance",                   "为了联盟")

  -- ╔══════════════════════════════════════════════╗
  -- ║  CAT 150: Comentarios de Rendimiento         ║
  -- ╚══════════════════════════════════════════════╝
  add("buen dps",                               "good dps",                           "输出给力")
  add("curas excelentes",                       "excellent heals",                    "治疗给力")
  add("buen tanqueo",                           "good tanking",                       "拉得稳")

  -- ╔══════════════════════════════════════════════╗
  -- ║  CAT 151: Verbos de Movimiento               ║
  -- ╚══════════════════════════════════════════════╝
  add("correr",                                 "to run",                             "奔跑")
  add("corres",                                 "you run",                            "你跑")
  add("saltar",                                 "to jump",                            "跳跃")
  add("saltas",                                 "you jump",                           "你跳")
  add("volar",                                  "to fly",                             "飞行")

  -- ╔══════════════════════════════════════════════╗
  -- ║  CAT 152: Verbos de Percepción               ║
  -- ╚══════════════════════════════════════════════╝
  add("mirar",                                  "to look",                            "观看")
  add("miras",                                  "you look",                           "你看")
  add("ver",                                    "to see",                             "看见")
  add("ves",                                    "you see",                            "你看见")
  add("escuchar",                               "to listen",                          "聆听")

  -- ╔══════════════════════════════════════════════╗
  -- ║  CAT 153: Verbos de Transacción              ║
  -- ╚══════════════════════════════════════════════╝
  add("comprar",                                "to buy",                             "购买")
  add("compras",                                "you buy",                            "你买")
  add("vender",                                 "to sell",                            "出售")
  add("vendes",                                 "you sell",                           "你卖")
  add("pagar",                                  "to pay",                             "付款")

  -- ╔══════════════════════════════════════════════╗
  -- ║  CAT 154: Verbos de Acción Social            ║
  -- ╚══════════════════════════════════════════════╝
  add("jugar",                                  "to play",                            "玩耍")
  add("jugas",                                  "you play",                           "你玩")
  add("hablar",                                 "to speak",                           "说话")
  add("hablas",                                 "you speak",                          "你说话")
  add("cantar",                                 "to sing",                            "唱歌")

  -- ╔══════════════════════════════════════════════╗
  -- ║  CAT 155: Verbos de Intelecto                ║
  -- ╚══════════════════════════════════════════════╝
  add("entender",                               "to understand",                      "理解")
  add("entiendes",                              "you understand",                     "你理解")
  add("saber",                                  "to know",                            "知道")
  add("sabes",                                  "you know",                           "你知道")
  add("aprender",                               "to learn",                           "学习")

  -- ╔══════════════════════════════════════════════╗
  -- ║  CAT 156: Verbos de Ayuda y Soporte          ║
  -- ╚══════════════════════════════════════════════╝
  add("ayudar",                                 "to help",                            "帮助")
  add("ayudas",                                 "you help",                           "你帮助")
  add("proteger",                               "to protect",                         "保护")
  add("curar",                                  "to heal",                            "治疗")
  add("curas",                                  "you heal",                           "你治疗")

  -- ╔══════════════════════════════════════════════╗
  -- ║  CAT 157: Verbos de Combate General          ║
  -- ╚══════════════════════════════════════════════╝
  add("atacar",                                 "to attack",                          "攻击")
  add("atacas",                                 "you attack",                         "你攻击")
  add("defender",                               "to defend",                          "防守")
  add("luchar",                                 "to fight",                           "战斗")

  -- ╔══════════════════════════════════════════════╗
  -- ║  CAT 158: Verbos de Creación                 ║
  -- ╚══════════════════════════════════════════════╝
  add("crear",                                  "to create",                          "创造")
  add("creas",                                  "you create",                         "你创造")
  add("hacer",                                  "to do",                              "做")
  add("haces",                                  "you do",                             "你做")
  add("construir",                              "to build",                           "建造")

  -- ╔══════════════════════════════════════════════╗
  -- ║  CAT 159: Verbos de Necesidad                ║
  -- ╚══════════════════════════════════════════════╝
  add("necesitar",                              "to need",                            "需要")
  add("necesitas",                              "you need",                           "你需要")
  add("querer",                                 "to want",                            "想要")
  add("quieres",                                "you want",                           "你想要")
  add("buscar",                                 "to search",                          "寻找")

  -- ╔══════════════════════════════════════════════╗
  -- ║  CAT 160: Verbos de Comunicación             ║
  -- ╚══════════════════════════════════════════════╝
  add("decir",                                  "to say",                             "说")
  add("dices",                                  "you say",                            "你说")
  add("preguntar",                              "to ask",                             "询问")
  add("responder",                              "to answer",                          "回答")

  -- ╔══════════════════════════════════════════════╗
  -- ║  CAT 161: Relaciones y Personas              ║
  -- ╚══════════════════════════════════════════════╝
  add("amigo",                                  "friend",                             "朋友")
  add("companero",                              "companion",                          "伙伴")
  add("compañero",                              "companion",                          "伙伴")
  add("enemigo",                                "enemy",                              "敌人")
  add("lider",                                  "leader",                             "领袖")
  add("líder",                                  "leader",                             "领袖")

  -- ╔══════════════════════════════════════════════╗
  -- ║  CAT 162: Lugares y Vivienda                 ║
  -- ╚══════════════════════════════════════════════╝
  add("casa",                                   "house",                              "房子")
  add("ciudad",                                 "city",                               "城市")
  add("taberna",                                "tavern",                             "旅店")
  add("castillo",                               "castle",                             "城堡")

  -- ╔══════════════════════════════════════════════╗
  -- ║  CAT 163: Recursos y Riqueza                 ║
  -- ╚══════════════════════════════════════════════╝
  add("oro",                                    "gold",                               "金子")
  add("plata",                                  "silver",                             "银子")
  add("tesoro",                                 "treasure",                           "宝藏")
  add("dinero",                                 "money",                              "钱")

  -- ╔══════════════════════════════════════════════╗
  -- ║  CAT 164: Sustento y Consumibles             ║
  -- ╚══════════════════════════════════════════════╝
  add("comida",                                 "food",                               "食物")
  add("agua",                                   "water",                              "水")
  add("pan",                                    "bread",                              "面包")
  add("vino",                                   "wine",                               "红酒")

  -- ╔══════════════════════════════════════════════╗
  -- ║  CAT 165: Viaje y Orientación                ║
  -- ╚══════════════════════════════════════════════╝
  add("camino",                                 "path",                               "道路")
  add("mapa",                                   "map",                                "地图")
  add("sendero",                                "trail",                              "小径")
  add("puente",                                 "bridge",                             "桥梁")

  -- ╔══════════════════════════════════════════════╗
  -- ║  CAT 166: Tiempo y Ciclos                    ║
  -- ╚══════════════════════════════════════════════╝
  add("tiempo",                                 "time",                               "时间")
  add("hora",                                   "hour",                               "小时")
  add("dia",                                    "day",                                "白天")
  add("día",                                    "day",                                "白天")
  add("noche",                                  "night",                              "夜晚")

  -- ╔══════════════════════════════════════════════╗
  -- ║  CAT 167: Elementos Naturales                ║
  -- ╚══════════════════════════════════════════════╝
  add("fuego",                                  "fire",                               "火焰")
  add("tierra",                                 "earth",                              "大地")
  add("aire",                                   "air",                                "空气")

  -- ╔══════════════════════════════════════════════╗
  -- ║  CAT 168: Equipamiento y Armas               ║
  -- ╚══════════════════════════════════════════════╝
  add("espada",                                 "sword",                              "宝剑")
  add("escudo",                                 "shield",                             "盾牌")
  add("armadura",                               "armor",                              "护甲")
  add("arco",                                   "bow",                                "长弓")

  -- ╔══════════════════════════════════════════════╗
  -- ║  CAT 169: Flora y Fauna                      ║
  -- ╚══════════════════════════════════════════════╝
  add("animal",                                 "animal",                             "野兽")
  add("planta",                                 "plant",                              "植物")
  add("arbol",                                  "tree",                               "树木")
  add("árbol",                                  "tree",                               "树木")
  add("monstruo",                               "monster",                            "怪物")

  -- ╔══════════════════════════════════════════════╗
  -- ║  CAT 170: Objetos Cotidianos                 ║
  -- ╚══════════════════════════════════════════════╝
  add("bolsa",                                  "bag",                                "包包")
  add("cofre",                                  "chest",                              "宝箱")
  add("llave",                                  "key",                                "钥匙")
  add("libro",                                  "book",                               "书本")

  -- ╔══════════════════════════════════════════════╗
  -- ║  CAT 171: Adjetivos de Calidad               ║
  -- ╚══════════════════════════════════════════════╝
  add("bueno",                                  "good",                               "好的")
  add("malo",                                   "bad",                                "坏的")
  add("excelente",                              "excellent",                          "极好的")
  add("pesimo",                                 "terrible",                           "糟糕的")
  add("pésimo",                                 "terrible",                           "糟糕的")

  -- ╔══════════════════════════════════════════════╗
  -- ║  CAT 172: Adjetivos de Velocidad             ║
  -- ╚══════════════════════════════════════════════╝
  add("rapido",                                 "fast",                               "快速的")
  add("rápido",                                 "fast",                               "快速的")
  add("lento",                                  "slow",                               "慢速的")
  add("veloz",                                  "swift",                              "迅捷的")

  -- ╔══════════════════════════════════════════════╗
  -- ║  CAT 173: Adjetivos de Fuerza                ║
  -- ╚══════════════════════════════════════════════╝
  add("fuerte",                                 "strong",                             "强壮的")
  add("debil",                                  "weak",                               "虚弱的")
  add("débil",                                  "weak",                               "虚弱的")
  add("poderoso",                               "powerful",                           "强力的")
  add("fragil",                                 "fragile",                            "脆弱的")
  add("frágil",                                 "fragile",                            "脆弱的")

  -- ╔══════════════════════════════════════════════╗
  -- ║  CAT 174: Adjetivos de Edad                  ║
  -- ╚══════════════════════════════════════════════╝
  add("nuevo",                                  "new",                                "崭新的")
  add("viejo",                                  "old",                                "陈旧的")
  add("joven",                                  "young",                              "年轻的")
  add("antiguo",                                "ancient",                            "远古的")

  -- ╔══════════════════════════════════════════════╗
  -- ║  CAT 175: Adjetivos de Temperatura           ║
  -- ╚══════════════════════════════════════════════╝
  add("frio",                                   "cold",                               "寒冷的")
  add("frío",                                   "cold",                               "寒冷的")
  add("calor",                                  "hot",                                "炎热的")
  add("calido",                                 "warm",                               "温暖的")
  add("cálido",                                 "warm",                               "温暖的")
  add("helado",                                 "frozen",                             "冰冷的")

  -- ╔══════════════════════════════════════════════╗
  -- ║  CAT 176: Adjetivos de Tamaño                ║
  -- ╚══════════════════════════════════════════════╝
  add("grande",                                 "big",                                "巨大的")
  add("pequeno",                                "small",                              "娇小的")
  add("pequeño",                                "small",                              "娇小的")
  add("enorme",                                 "huge",                               "庞大的")

  -- ╔══════════════════════════════════════════════╗
  -- ║  CAT 177: Adjetivos de Dificultad            ║
  -- ╚══════════════════════════════════════════════╝
  add("facil",                                  "easy",                               "简单的")
  add("fácil",                                  "easy",                               "简单的")
  add("dificil",                                "difficult",                          "困难的")
  add("difícil",                                "difficult",                          "困难的")
  add("complejo",                               "complex",                            "复杂的")
  add("simple",                                 "simple",                             "简单的")

  -- ╔══════════════════════════════════════════════╗
  -- ║  CAT 178: Adjetivos de Estado Emocional      ║
  -- ╚══════════════════════════════════════════════╝
  add("feliz",                                  "happy",                              "开心的")
  add("triste",                                 "sad",                                "难过的")
  add("enojado",                                "angry",                              "愤怒的")
  add("cansado",                                "tired",                              "疲惫的")

  -- ╔══════════════════════════════════════════════╗
  -- ║  CAT 179: Adverbios de Tiempo                ║
  -- ╚══════════════════════════════════════════════╝
  add("ahora",                                  "now",                                "现在")
  add("luego",                                  "later",                              "稍后")
  add("antes",                                  "before",                             "之前")
  add("despues",                                "after",                              "之后")
  add("después",                                "after",                              "之后")

  -- ╔══════════════════════════════════════════════╗
  -- ║  CAT 180: Adverbios de Cantidad              ║
  -- ╚══════════════════════════════════════════════╝
  add("mucho",                                  "much",                               "很多")
  add("poco",                                   "little",                             "很少")
  add("bastante",                               "enough",                             "足够")
  add("demasiado",                              "too much",                           "太多")

  -- ╔══════════════════════════════════════════════╗
  -- ║  CAT 181: Nuevas Razas de Turtle WoW         ║
  -- ╚══════════════════════════════════════════════╝
  add("alto elfo",                              "high elf",                           "高等精灵")
  add("elfo noble",                             "noble elf",                          "高等精灵")
  add("goblin verde",                           "green goblin",                       "绿皮地精")

  -- ╔══════════════════════════════════════════════╗
  -- ║  CAT 182: Supervivencia y Campamentos        ║
  -- ╚══════════════════════════════════════════════╝
  add("tienda de campana",                      "survival tent",                      "野外帐篷")
  add("tienda de campaña",                      "survival tent",                      "野外帐篷")
  add("supervivencia",                          "survival skill",                     "生存技能")
  add("fogata",                                 "campfire",                           "营火")

  -- ╔══════════════════════════════════════════════╗
  -- ║  CAT 183: Modo Desafío Hardcore              ║
  -- ╚══════════════════════════════════════════════╝
  add("un solo intento",                        "one life only",                      "一命通关")
  add("modo hardcore",                          "hardcore mode",                      "硬核模式")
  add("inmortal",                               "immortal challenge",                 "不朽挑战")

  -- ╔══════════════════════════════════════════════╗
  -- ║  CAT 184: Modo de Guerra Warmode             ║
  -- ╚══════════════════════════════════════════════╝
  add("modo guerra",                            "war mode",                           "战争模式")
  add("pvp activo",                             "active pvp",                         "开启PVP")
  add("bonificacion de experiencia",            "xp bonus",                           "经验加成")
  add("bonificación de experiencia",            "xp bonus",                           "经验加成")

  -- ╔══════════════════════════════════════════════╗
  -- ║  CAT 185: Zonas Exclusivas de Turtle WoW     ║
  -- ╚══════════════════════════════════════════════╝
  add("alah'thalas",                            "alah'thalas",                        "亚拉萨拉斯")
  add("isla de gillijim",                       "gillijim's isle",                    "吉利吉姆岛")
  add("isla de lapidis",                        "lapidis isle",                       "拉皮迪斯岛")

  -- ╔══════════════════════════════════════════════╗
  -- ║  CAT 186: Mazmorras Custom                   ║
  -- ╚══════════════════════════════════════════════╝
  add("karazhan inferior",                      "lower karazhan",                     "卡拉赞下层")
  add("criptas de karazhan",                    "karazhan crypts",                    "卡拉赞地穴")

  -- ╔══════════════════════════════════════════════╗
  -- ║  CAT 187: Facciones Personalizadas           ║
  -- ╚══════════════════════════════════════════════╝
  add("gremio de artesanos",                    "craftsmen guild",                    "工匠协会")
  add("expedicion de la horda",                 "horde expedition",                   "部落远征军")
  add("expedición de la horda",                 "horde expedition",                   "部落远征军")

  -- ╔══════════════════════════════════════════════╗
  -- ║  CAT 188: Mecánicas de Rol                   ║
  -- ╚══════════════════════════════════════════════╝
  add("moneda de oro turtle",                   "turtle gold coin",                   "乌龟金币")
  add("fichas de rol",                          "roleplay tokens",                    "角色扮演代币")

  -- ╔══════════════════════════════════════════════╗
  -- ║  CAT 189: Cosméticos y Tienda Custom         ║
  -- ╚══════════════════════════════════════════════╝
  add("tienda turtle",                          "turtle shop",                        "乌龟商城")
  add("montura custom",                         "custom mount",                       "定制坐骑")
  add("mascota bonita",                         "cute pet",                           "可爱宠物")

  -- ╔══════════════════════════════════════════════╗
  -- ║  CAT 190: Eventos de Servidor                ║
  -- ╚══════════════════════════════════════════════╝
  add("evento festivo",                         "festive event",                      "节日活动")
  add("invasion de monstruos",                  "monster invasion",                   "怪物入侵")
  add("invasión de monstruos",                  "monster invasion",                   "怪物入侵")

  -- ╔══════════════════════════════════════════════╗
  -- ║  CAT 191: El Clima y Entorno                 ║
  -- ╚══════════════════════════════════════════════╝
  add("lluvia",                                 "rain",                               "下雨")
  add("sol",                                    "sun",                                "太阳")
  add("viento",                                 "wind",                               "大风")
  add("tormenta",                               "storm",                              "暴风雨")

  -- ╔══════════════════════════════════════════════╗
  -- ║  CAT 192: Hobbies y Pasatiempos              ║
  -- ╚══════════════════════════════════════════════╝
  add("musica",                                 "music",                              "音乐")
  add("música",                                 "music",                              "音乐")
  add("peliculas",                              "movies",                             "电影")
  add("películas",                              "movies",                             "电影")
  add("leer",                                   "reading",                            "阅读")
  add("viajar",                                 "traveling",                          "旅游")

  -- ╔══════════════════════════════════════════════╗
  -- ║  CAT 193: Estructura Familiar                ║
  -- ╚══════════════════════════════════════════════╝
  add("padre",                                  "father",                             "父亲")
  add("madre",                                  "mother",                             "母亲")
  add("hermano",                                "brother",                            "兄弟")
  add("hijo",                                   "son",                                "儿子")

  -- ╔══════════════════════════════════════════════╗
  -- ║  CAT 194: Entorno de Trabajo                 ║
  -- ╚══════════════════════════════════════════════╝
  add("trabajo",                                "work",                               "工作")
  add("oficina",                                "office",                             "办公室")
  add("reunion",                                "meeting",                            "会议")
  add("reunión",                                "meeting",                            "会议")
  add("jefe",                                   "boss",                               "老板")

  -- ╔══════════════════════════════════════════════╗
  -- ║  CAT 195: Computación y Hardware             ║
  -- ╚══════════════════════════════════════════════╝
  add("computadora",                            "computer",                           "电脑")
  add("teclado",                                "keyboard",                           "键盘")
  add("mouse",                                  "mouse",                              "鼠标")
  add("pantalla",                               "screen",                             "屏幕")

  -- ╔══════════════════════════════════════════════╗
  -- ║  CAT 196: Conectividad y Redes               ║
  -- ╚══════════════════════════════════════════════╝
  add("internet lento",                         "slow internet",                      "网速很慢")
  add("desconexion",                            "disconnection",                      "掉线")
  add("desconexión",                            "disconnection",                      "掉线")
  add("router",                                 "router",                             "路由器")

  -- ╔══════════════════════════════════════════════╗
  -- ║  CAT 197: Comidas y Bebidas cotidianas       ║
  -- ╚══════════════════════════════════════════════╝
  add("cafe",                                   "coffee",                             "咖啡")
  add("café",                                   "coffee",                             "咖啡")
  add("te",                                     "tea",                                "茶")
  add("té",                                     "tea",                                "茶")
  add("pizza",                                  "pizza",                              "披萨")
  add("cerveza",                                "beer",                               "啤酒")

  -- ╔══════════════════════════════════════════════╗
  -- ║  CAT 198: Salud y Bienestar                  ║
  -- ╚══════════════════════════════════════════════╝
  add("dolor de cabeza",                        "headache",                           "头疼")
  add("enfermo",                                "sick",                               "生病")
  add("sueno",                                  "sleepiness",                         "犯困")
  add("sueño",                                  "sleepiness",                         "犯困")
  add("descanso",                               "rest",                               "休息")

  -- ╔══════════════════════════════════════════════╗
  -- ║  CAT 199: Noticias y Actualidad              ║
  -- ╚══════════════════════════════════════════════╝
  add("noticias",                               "news",                               "新闻")
  add("mundo",                                  "world",                              "世界")
  add("leer el foro",                           "read the forum",                     "看论坛")
  add("enterado",                               "informed",                           "知晓了")

  -- ╔══════════════════════════════════════════════╗
  -- ║  CAT 200: Mensajes de Despedida Afectuosa    ║
  -- ╚══════════════════════════════════════════════╝
  add("cuidate mucho",                          "take good care of yourself",         "多保重")
  add("cuídate mucho",                          "take good care of yourself",         "多保重")
  add("buen viaje",                             "safe travels",                       "旅途愉快")
  add("hasta pronto",                           "see you soon",                       "后会有期")

  -- ╔══════════════════════════════════════════════╗
  -- ║  CAT 201: Mazmorras y Raids Abreviaciones      ║
  -- ╚══════════════════════════════════════════════╝
  add("rfc",                                    "ragefire chasm",                     "怒焰")
  add("wc",                                     "wailing caverns",                    "哀嚎")
  add("sfk",                                    "shadowfang keep",                    "影牙")
  add("bfd",                                    "blackfathom deeps",                  "黑暗深渊")
  add("gnomer",                                 "gnomeregan",                         "诺莫")
  add("rfk",                                    "razorfen kraul",                     "剃刀沼泽")
  add("rfd",                                    "razorfen downs",                     "剃刀高地")
  add("sm lib",                                 "scarlet monastery library",          "图书馆")
  add("sm arm",                                 "scarlet monastery armory",           "武器库")
  add("sm cath",                                "scarlet monastery cathedral",        "教堂")
  add("sm gy",                                  "scarlet monastery graveyard",        "墓地")
  add("zf",                                     "zul'farrak",                         "祖尔")
  add("mara",                                   "maraudon",                           "玛拉顿")
  add("st",                                     "sunken temple",                      "神庙")
  add("brd",                                    "blackrock depths",                   "深渊")
  add("lbrs",                                   "lower blackrock spire",              "黑下")
  add("ubrs",                                   "upper blackrock spire",              "黑上")
  add("mc",                                     "molten core",                        "MC")
  add("bwl",                                    "blackwing lair",                     "BWL")
  add("zg",                                     "zul'gurub",                          "ZG")
  add("aq20",                                   "ruins of ahn'qiraj",                 "废墟")
  add("aq40",                                   "temple of ahn'qiraj",                "神殿")
  add("naxx",                                   "naxxramas",                          "纳克萨玛斯")

  -- ╔══════════════════════════════════════════════╗
  -- ║  CAT 202: Jerga de Combate y Roles de Grupo    ║
  -- ╚══════════════════════════════════════════════╝
  add("t",                                      "tank",                               "坦/T")
  add("nai",                                    "healer",                             "奶妈/治疗")
  add("dd",                                     "dps",                                "输出/打手")
  add("main tank",                              "main tank",                          "主T")
  add("mt",                                     "main tank",                          "主T")
  add("off tank",                               "off tank",                           "副T")
  add("ot",                                     "off tank",                           "副T")
  add("oom",                                    "out of mana",                        "空蓝了")
  add("looteando",                              "looting",                            "摸尸体")
  add("ninja",                                  "ninja looter",                       "毛人/毛装备")

  -- ╔══════════════════════════════════════════════╗
  -- ║  CAT 203: Jerga Social MMO Trilingüe        ║
  -- ╚══════════════════════════════════════════════╝
  add("666",                                    "awesome",                            "溜溜溜")
  add("nb",                                     "pro",                                "牛逼")
  add("sb",                                     "idiot",                              "傻逼")
  add("1",                                      "invite me / ready",                  "111/组/好")
  add("123",                                    "click portal please",                "123点门")
  add("点门",                                   "click portal",                       "click portal")
  add("拉人",                                   "summon please",                      "summon me")

  -- ╔══════════════════════════════════════════════╗
  -- ║  CAT 204: Modismos Conversacionales Locales  ║
  -- ╚══════════════════════════════════════════════╝
  add("chale",                                  "that's bad",                         "惨了")
  add("wey",                                    "dude",                               "老兄")
  add("chingon",                                "cool",                               "给力")
  add("boludo",                                 "idiot",                              "笨蛋")
  add("weon",                                   "dude / idiot",                       "家伙")
  add("culiao",                                 "bastard",                            "混蛋")
  add("xd",                                     "laughing",                           "哈哈")
  add("cagaste",                                "you messed up",                      "你完蛋了")
  add("pinche",                                 "damn",                               "该死的")

  -- ╔══════════════════════════════════════════════╗
  -- ║  CAT 205: Instrucciones Rápidas de Mazmorra   ║
  -- ╚══════════════════════════════════════════════╝
  add("pull extra",                             "extra pull",                         "引到怪了")
  add("no combat",                              "no combat",                          "别打/脱战")
  add("run",                                    "run",                                "跑")
  add("dont attack",                            "dont attack",                        "别打")
  add("wait tank",                              "wait for tank",                      "等坦拉住")
  add("stop dps",                               "stop dps",                           "停手")

  -- ╔══════════════════════════════════════════════╗
  -- ║  CAT 206: Diálogos de Misiones Frecuentes    ║
  -- ╚══════════════════════════════════════════════╝
  add("donde entrego",                          "where do I hand in",                 "在哪里交任务")
  add("donde se entrega",                       "where to hand in",                   "哪里交")
  add("donde agarro",                           "where to take",                      "哪里接")
  add("donde se agarra",                        "where do I accept",                  "哪里接任务")
  add("mision compartida",                      "shared quest",                       "共享任务")
  add("comparte mision",                        "share quest please",                 "共享任务谢谢")
  add("no puedo entregar",                      "cannot hand in",                     "交不了任务")
  add("misión bugeada",                         "bugged quest",                       "任务卡住了/bug")
  add("mision bug",                             "bugged quest",                       "任务bug")

  -- ╔══════════════════════════════════════════════╗
  -- ║  CAT 207: Trade Channel y Negociación        ║
  -- ╚══════════════════════════════════════════════╝
  add("cuanto pides",                           "how much do you want",               "你要多少金")
  add("cuanto cuesta",                          "how much does it cost",              "多少钱")
  add("muy caro",                               "too expensive",                      "太贵了")
  add("puedes bajar",                           "can you lower",                      "便宜点行吗")
  add("precio fijo",                            "fixed price",                        "最低价")
  add("oferta",                                 "offer",                              "带价")
  add("ofrece",                                 "offer me",                           "带价私聊")
  add("cod por favor",                          "cod please",                         "邮寄谢谢/COD")
  add("mandame cod",                            "cod me please",                      "邮寄给我")
  add("envio cod",                              "send cod",                           "发邮寄")

  -- ╔══════════════════════════════════════════════╗
  -- ║  CAT 208: Guild Management y Convivencia     ║
  -- ╚══════════════════════════════════════════════╝
  add("hola guild",                             "hello guild",                        "公会好")
  add("hola g",                                 "hello guild",                        "公会好")
  add("buenas guild",                           "hello guild",                        "公会的大家好")
  add("buenas g",                               "hello guild",                        "公会的大家好")
  add("gracias g",                              "thanks guild",                       "谢公会")
  add("gracias guild",                          "thanks guild",                       "谢公会大家")
  add("alguien me ayuda",                       "anyone can help me",                 "有大佬帮我吗")
  add("alguien ayuda",                          "anyone helps",                       "有人帮一下吗")
  add("ayuda por favor",                        "help please",                        "请帮帮我")

  -- ╔══════════════════════════════════════════════╗
  -- ║  CAT 209: Hardcore Death y Reacciones        ║
  -- ╚══════════════════════════════════════════════╝
  add("f por el hermano",                       "f for the brother",                  "为兄弟点F")
  add("f hermano",                              "f brother",                          "兄弟走好")
  add("f en chat",                              "f in chat",                          "发F/点赞")
  add("lo siento mucho",                        "so sorry",                           "真遗憾")
  add("que lastima",                            "what a pity",                        "太可惜了")
  add("nivel alto",                             "high level",                         "高级号")
  add("murio a nivel",                          "died at level",                      "死在了几级")

  -- ╔══════════════════════════════════════════════╗
  -- ║  CAT 210: PvP y Battlegrounds                ║
  -- ╚══════════════════════════════════════════════╝
  add("defiendan base",                         "defend base",                        "守家/防守")
  add("ataquen base",                           "attack base",                        "攻打")
  add("defiendan lm",                           "defend lm",                          "守伐木")
  add("defiendan gy",                           "defend gy",                          "守墓地")
  add("vienen dos",                             "two coming",                         "来两个")
  add("vienen tres",                            "three coming",                       "来三个")
  add("vienen muchos",                          "many coming",                        "来一堆")
  add("ayuda aqui",                             "help here",                          "求支援")
  add("ayuda aca",                              "help here",                          "支援")

  -- ╔══════════════════════════════════════════════╗
  -- ║  CAT 211: Slang Avanzado en Chino (100% Gamer)║
  -- ╚══════════════════════════════════════════════╝
  add("woc",                                    "wtf",                                "卧槽")
  add("taola",                                  "boosted / carried",                  "躺好了")
  add("zhao ren",                               "lfm",                                "招人")
  add("qiu zu",                                 "lfg",                                "求组")

  -- ╔══════════════════════════════════════════════╗
  -- ║  CAT 212: Orientación y Rutas de Viaje       ║
  -- ╚══════════════════════════════════════════════╝
  add("como llego a",                           "how to get to",                      "怎么去")
  add("dónde queda",                            "where is",                           "在哪里")
  add("como voy a",                             "how to go to",                       "怎么到")
  add("vuelo a",                                "flight to",                          "飞往")
  add("ruta de vuelo",                          "flight path",                        "飞行点")
  add("toma el vuelo",                          "take flight",                        "坐飞机/坐飞兽")
  add("camina",                                 "walk",                               "走路")
  add("corre",                                  "run",                                "快跑")

  -- ╔══════════════════════════════════════════════╗
  -- ║  CAT 213: Emotes e Interacción Corta         ║
  -- ╚══════════════════════════════════════════════╝
  add("hola wey",                               "hi dude",                            "你好老兄")
  add("que onda",                               "what's up",                          "怎么了")
  add("todo bien",                              "all good",                           "一切顺利")
  add("de acuerdo",                             "agreed",                             "没问题")
  add("denada",                                 "welcome",                            "不客气")

  -- ╔══════════════════════════════════════════════╗
  -- ║  CAT 214: Comandos de Liderazgo en Mazmorra  ║
  -- ╚══════════════════════════════════════════════╝
  add("marca calavera",                         "mark skull",                         "打大饼/骷髅")
  add("foco calavera",                          "focus skull",                        "打骷髅")
  add("mata calavera",                          "kill skull",                         "击杀骷髅")
  add("focus x",                                "focus cross",                        "打十字/叉叉")
  add("cc estrella",                            "cc star",                            "控星星")
  add("oveja luna",                             "sheep moon",                         "羊月亮")
  add("duerme triangulo",                       "sleep triangle",                     "睡三角")

  -- ╔══════════════════════════════════════════════╗
  -- ║  CAT 215: Hardcore y Chat de Frustración     ║
  -- ╚══════════════════════════════════════════════╝
  add("morir",                                  "die",                                "死")
  add("morí",                                   "I died",                             "我死了")
  add("casi muero",                             "almost died",                        "差点死了")
  add("cuidado",                                "watch out",                          "小心")
  add("corran",                                 "run away",                           "快跑")
  add("no peleen",                              "dont fight",                         "别打")
  add("peligro",                                "danger",                             "危险")
  -- Injected from screenshot feedback
  add("el circo", "circus", "马戏团")
  add("villadorada", "goldshire", "闪金")
  add("villadorada", "goldshire", "闪金镇")
  add("apoyo", "agreed", "附议")
  add("invitame", "invite me", "组我")
  add("invitame", "invite me", "组我一个")
  add("listo", "done", "OK了")
  add("listo", "done", "ok了")
  add("mierda", "fuck", "靠")
  add("muerto por la horda", "killed by horde", "被BL杀了")
  add("la feria está cerrada hoy", "dmf is closed today", "今天马戏团休息")
  add("yo", "i", "我")
  add("soy", "am", "是")
  add("mago low", "low mage", "小法")
  add("busco", "lf", "来")
  add("o mas", "or higher", "以上的")
  add("dónde está", "where is", "在哪里")
  add("un", "one", "一个")
  add("un", "one", "一")
  -- Conversational and Particles (Injected V2)
  add("ping", "ping", "延时")
  -- Conversational and Particles (Injected V3)
  add("raza", "race", "种族")
  add("más", "more", "比较")
  add("debe", "must", "必须")
  add("guarda de miedo", "fear ward", "反恐")
  add("domar", "tame", "抓")
  add("atrapar", "catch", "抓")
  add("domado", "tamed", "抓到")
  add("disparar", "shoot", "射")
  add("mujer", "female", "女")
  add("hombre", "male", "男")
  add("transfiguración", "transmog", "幻化")
  add("usted", "you", "您")
  add("unirse al grupo", "join group", "进组")
  add("apariencia", "look", "造型")
  add("directamente", "directly", "直接")
  add("es", "is", "是")
  add("pequeño", "small", "小")
  add("grande", "big", "大")
  add("top", "top", "顶尖")
  add("progresión", "progression", "开荒")
  add("todos", "everyone", "各位")
  add("unirse", "join", "加盟")
  add("unirse a la guild", "join guild", "入会")
  add("unirse a la banda", "join raid", "参团")
  add("regalar", "gift", "送")
  add("mensualidad", "sub", "月卡")
  add("hay", "there is", "有")
  add("tiene", "has", "有")
  add("futuro", "future", "未来")
  add("humar", "humar", "修玛")
  add("comparado con", "compared to", "比")
  add("feliz", "happy", "开心嘛")
  add("un'goro", "un'goro", "环形")
  add("druida", "druid", "德")
  add("ayer", "yesterday", "昨")
  add("llegar a", "reach", "到")
  add("pregunto", "ask", "问下")
  add("preguntar", "ask", "问")
  add("básicamente", "basically", "根本")
  add("activar", "activate", "开")
  add("abrir", "open", "开")
  add("modo", "mode", "模式")
  add("mago low", "low mage", "小法")
  add("descendiente", "descendant", "后裔")
  add("tierra sagrada", "holy land", "圣地")

  add("odio", "hate", "讨厌")
  add("japón", "japan", "日本")
  add("taiwan", "taiwan", "台湾省")
  add("taiwan", "taiwan", "台湾")
  add("este", "this", "这")
  add("ese", "that", "那")
  add("qué", "what", "什么")
  add("ah", "ah", "啊")
  add("?", "?", "吗")
  add("?", "?", "么")
  add("?", "?", "呢")
  add("pues", "well", "吧")
  add("de", "of", "的")
  add("ya", "already", "了")
  add("solo", "just", "就")
  add("recién", "just now", "才")
  add("también", "also", "也")
  add("muy", "very", "非常")
  add("realmente", "really", "真正")
  add("error", "mistake", "错误")
  add("correcto", "correct", "没错")
  add("sin", "without", "没")
  add("equipo", "gear", "装备")
  add("equipo", "gear", "装")
  add("despojar", "loot", "拾取")
  add("monstruo", "mob", "怪")
  add("zona inicial", "starter zone", "新手村")
  add("pueblo", "village", "村")
  add("aunque", "although", "虽然")
  add("se puede", "can", "可以")
  add("correo", "mail", "邮件")
  add("tu mismo", "yourself", "自己")
  add("terminado", "finished", "打完")
  add("evento", "event", "活动")
  add("chillear", "chill", "摸鱼")
  add("chica taiwanesa", "taiwanese girl", "台妹")
  add("base", "base", "驻地")
  add("tierras de la peste del este", "epl", "东瘟疫")
  add("tierras de la peste del oeste", "wpl", "西瘟疫")
  add("prioridad", "prio", "优先")
  add("tela o malla", "cloth/mail", "布锁")
  add("farmear", "farm/run", "刷")
  add("terminología", "terminology", "术语")
  add("[WoWTranslate]", "[WoWTranslate]", "[由WoWTranslate翻译]")
  add("traductor en tiempo real", "real-time translator", "实时翻译")
  add("todo", "all", "全")
  add("nuevo", "new", "新")
  add("dar", "give", "给")
  add("hacer", "do", "做")
  add("jugar", "play", "玩")
  add("juego", "game", "游戏")
  add("gente", "people", "人")
  add("poder", "can", "能")
  add("ir", "go", "去")
  add("venir", "come", "来")
  add("curar", "heal", "奶")
  add("tanque", "tank", "防")
  add("dps", "dps", "输出")
  add("daño", "damage", "伤害")
  add("oro", "gold", "金")
  add("plata", "silver", "银")
  add("cobre", "copper", "铜")
  add("nivel", "level", "级")
  add("ayuda", "help", "帮")
  add("comprar", "buy", "买")
  add("vender", "sell", "卖")
  add("necesito", "need", "需")
  add("tener", "have", "有")
  add("buscar", "lf", "找")
  add("grupo", "group", "队")
  add("misión", "quest", "任务")
  add("mundo", "world", "世界")
  add("hola", "hello", "你好")
  add("adiós", "bye", "再见")
  add("gracias", "thanks", "谢谢")
  add("perdón", "sorry", "抱歉")
  add("mierda", "shit", "妈的")
  add("maldición", "damn", "擦")
  add("joder", "fuck", "草")
  add("hermandad", "guild", "公会")
  add("jugador", "player", "玩家")

  -- ╔══════════════════════════════════════════════╗
  -- ║  CAT 216: MACROS Y COMANDOS AVANZADOS        ║
  -- ╚══════════════════════════════════════════════╝
  add("lanzar", "cast", "施放")
  add("objetivo", "target", "目标")
  add("foco", "focus", "焦点")
  add("asistir", "assist", "协助")
  add("mascota", "pet", "宠物")
  add("cancelar aura", "cancelaura", "取消光环")
  add("usar", "use", "使用")
  add("equip", "equipar", "装备")
  add("desmontar", "dismount", "下马")
  add("ataque automatico", "startattack", "开始攻击")
  add("detener ataque", "stopattack", "停止攻击")
  add("macro de ráfaga", "burst macro", "爆发宏")
  add("macro de curación", "healing macro", "治疗宏")

  -- ╔══════════════════════════════════════════════╗
  -- ║  CAT 217: COMERCIO Y NEGOCIACIÓN AVANZADA    ║
  -- ╚══════════════════════════════════════════════╝
  add("pago contra reembolso", "cod", "货到付款")
  add("cuanto ofreces", "how much do you offer", "你出多少")
  add("cuál es tu oferta", "what is your offer", "你的报价是多少")
  add("no acepto menos de", "i won't accept less than", "最低价")
  add("precio fijo, no negociable", "firm price, no haggling", "一口价，不还价")
  add("descuento si compras por volumen", "discount for bulk", "量大从优")
  add("compro en cantidad", "buying in bulk", "大量收")
  add("busco encantador con mats", "lf enchanter with mats", "求附魔带材料")
  add("tengo mis propios mats", "have my own mats", "自带材料")
  add("te pongo propina", "will tip", "给小费")
  add("cuanto de propina", "how much tip", "要多少小费")

  -- ╔══════════════════════════════════════════════╗
  -- ║  CAT 218: TURTLE WOW & HARDCORE SLANG        ║
  -- ╚══════════════════════════════════════════════╝
  add("cantera de forja de odio", "hateforge quarry", "怨火采石场")
  add("arboleda de la media luna", "crescent grove", "新月林地")
  add("modo hardcore", "hardcore mode", "硬核模式")
  add("personaje hardcore", "hardcore character", "硬核角色")
  add("registro de muerte", "deathlog", "死亡日志")
  add("modo de guerra", "warmode", "战争模式")
  add("apelar muerte", "death appeal", "死亡申诉")
  add("banco de hermandad", "guild bank", "公会银行")
  add("mejor en ranura", "bis", "毕业装备")
  add("mejor antes de banda", "pre-raid bis", "团本前毕业")
  add("cola de entrada", "queue", "排队")
  add("tortugas", "turtles", "乌龟")
  add("moneda turtle", "turtle token", "乌龟币")
  add("servidor privado", "private server", "私服")
  add("transfiguración de armas", "weapon transmog", "武器幻化")
  add("tienda turtle", "turtle shop", "乌龟商城")
  add("tienda de donaciones", "donation shop", "赞助商城")

  -- ╔══════════════════════════════════════════════╗
  -- ║  CAT 219: MITIGACIÓN DE ESTILO TARZÁN EN CHAT║
  -- ╚══════════════════════════════════════════════╝
  add("alguien sabe si", "anyone knows if", "有人知道是否")
  add("¿alguien sabe?", "anyone knows", "有人知道吗")
  add("¿alguien sabe?", "anyone know", "有人知道")
  add("¿alguien me presta 3g?", "anyone lend me 3g?", "有人借我3金吗")
  add("¿alguien me presta", "anyone lend me", "有人能借我")
  add("busco prestado 3g", "lf borrow 3g", "求借3金")
  add("busco prestado", "lf borrow", "求借")
  add("necesito 3g para montar", "need 3g for riding", "需要3金学骑术")
  add("me falta 3g para montar", "short 3g for riding", "差3金学骑术")
  add("necesito oro para montar", "need gold for riding", "需要骑术金币")
  add("necesito para montar", "need for riding", "需要骑术")
  add("¿alguien sabe si", "anyone knows if", "有人知道是否")
  add("¿alguien sabe si", "anyone know if", "有人知道是否")

  -- ╔══════════════════════════════════════════════╗
  -- ║  LÓGICA DE ORDENAMIENTO (Greedy Matching)    ║
  -- ╚══════════════════════════════════════════════╝
  local p_keys = { "es_en", "en_es", "zh_en", "en_zh", "zh_es", "es_zh" }
  for _, p in ipairs(p_keys) do
    table.sort(pfUI.translator_dicts[p .. "_keys"], function(a, b) return strlen(a) > strlen(b) end)

    -- Inicializar Token-Bucket ( buckets de coincidencia rapida )
    pfUI.translator_dicts[p .. "_buckets"] = {}
    local buckets = pfUI.translator_dicts[p .. "_buckets"]
    local keys = pfUI.translator_dicts[p .. "_keys"]
    local src_lang = strsub(p, 1, 2)

    for _, key in ipairs(keys) do
      local first_key = nil
      if src_lang == "zh" then
        local b = string.byte(key, 1)
        local char_len = 1
        if b and b >= 224 and b <= 239 then char_len = 3
        elseif b and b >= 192 and b <= 223 then char_len = 2 end
        first_key = strsub(key, 1, char_len)
      else
        first_key = string.gsub(key, "^([%a%d\128-\255]+).*", "%1")
      end

      if first_key and first_key ~= "" then
        buckets[first_key] = buckets[first_key] or {}
        table.insert(buckets[first_key], key)
      end
    end
  end

  if pfUI_config.translator and pfUI_config.translator.debug_mode == "1" then
    DEFAULT_CHAT_FRAME:AddMessage("|cff33ffcc[TR]|r Lexico v7.3.0 Ultimate-Tier — 219 categorias y buckets de coincidencia inicializados.")
  end
end)
