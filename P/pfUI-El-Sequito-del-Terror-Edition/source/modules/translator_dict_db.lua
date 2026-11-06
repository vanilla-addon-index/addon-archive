pfUI:RegisterModule("translator_dict_db", "vanilla", function ()
  -- ╔══════════════════════════════════════════════════════════════╗
  -- ║  BASE DE DATOS COLOSAL v6.0.0 — ULTIMATE-TIER SPELLS & QUESTS║
  -- ║  Inyector en Lote Comprimido de Alto Rendimiento             ║
  -- ╚══════════════════════════════════════════════════════════════╝

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
                -- FIX: NO aplicar strlower a texto chino — corrompe los bytes UTF-8
                local key = (src_lang == "zh") and src_text or strlower(src_text)
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


  local function load_batch(batch)
    for _, line in ipairs(batch) do
      local p1 = strfind(line, "|", 1, true)
      if p1 then
        local es = strsub(line, 1, p1 - 1)
        local rest = strsub(line, p1 + 1)
        local p2 = strfind(rest, "|", 1, true)
        if p2 then
          local en = strsub(rest, 1, p2 - 1)
          local zh = strsub(rest, p2 + 1)
          add(es, en, zh)
        end
      end
    end
  end

  local function load_batch_zh_en_es(batch)
    for _, line in ipairs(batch) do
      local p1 = strfind(line, "|", 1, true)
      if p1 then
        local zh = strsub(line, 1, p1 - 1)
        local rest = strsub(line, p1 + 1)
        local p2 = strfind(rest, "|", 1, true)
        if p2 then
          local en = strsub(rest, 1, p2 - 1)
          local es = strsub(rest, p2 + 1)
          add(es, en, zh)
        end
      end
    end
  end


  -- ============================================================
  -- LOTE A: FACULTADES Y HECHIZOS DE CLASE (CLASS SPELLS)
  -- ============================================================
  local spells_batch = {
    -- Guerrero (Warrior)
    "cargar|charge|冲锋",
    "mortal strike|mortal strike|致死打击",
    "golpe mortal|mortal strike|致死打击",
    "grito de batalla|battle shout|战斗怒吼",
    "executar|execute|斩杀",
    "ejecutar|execute|斩杀",
    "provocar|taunt|嘲讽",
    "actitud defensiva|defensive stance|防御姿态",
    "actitud de batalla|battle stance|战斗姿态",
    "actitud rabiosa|berserker stance|狂暴姿态",
    "grito desmoralizador|demoralizing shout|挫志怒吼",
    "abrumar|overpower|压制",
    "embate de escudo|shield slam|盾牌猛击",
    "desarmar|disarm|缴械",
    "temeridad|recklessness|鲁莽",
    "torbellino|whirlwind|旋风斩",
    "filotormenta|bladestorm|利刃风暴",
    "grito desafiante|challenging shout|挑战怒吼",
    "bloqueo con escudo|shield block|盾牌格挡",
    "pared de escudo|shield wall|盾墙",
    "embate|slam|猛击",
    "desgarrar|rend|撕裂",
    "golpe heroico|heroic strike|英勇打击",
    "rajar|cleave|顺劈斩",
    "ola de choque|shockwave|震荡波",
    -- Mago (Mage)
    "descarga de escarcha|frostbolt|寒冰箭",
    "descarga de frost|frostbolt|寒冰箭",
    "bola de fuego|fireball|火球术",
    "traslacion|blink|闪现",
    "traslación|blink|闪现",
    "intelecto arcano|arcane intellect|奥术智慧",
    "brillo arcano|arcane brilliance|奥术光辉",
    "polimorfia|polymorph|变形术",
    "oveja|sheep|变羊",
    "nova de escarcha|frost nova|冰霜新星",
    "deflagracion arcana|arcane explosion|奥术爆炸",
    "deflagración arcana|arcane explosion|奥术爆炸",
    "bloque de hielo|ice block|寒冰屏障",
    "barrera de hielo|ice barrier|寒冰护体",
    "poder arcano|arcane power|奥术强化",
    "defensa arcana|arcane power|奥术强化",
    "combustion|combustion|燃烧",
    "combustión|combustion|燃烧",
    "vena helada|icy veins|冰冷血脉",
    "venas heladas|icy veins|冰冷血脉",
    "evocacion|evocation|唤醒",
    "evocación|evocation|唤醒",
    "presencia de la mente|presence of mind|气定神闲",
    "presencia mental|presence of mind|气定神闲",
    "contrahechizo|counterspell|法术反制",
    "armadura de hielo|ice armor|冰霜护甲",
    "armadura de mago|mage armor|魔甲术",
    "armadura de arrabio|molten armor|熔岩护甲",
    "caida lenta|slow fall|缓落术",
    "caída lenta|slow fall|缓落术",
    "robar hechizo|spellsteal|法术吸取",
    "cono de frio|cone of cold|冰锥术",
    "cono de frío|cone of cold|冰锥术",
    "fogonazo|flamestrike|烈焰风暴",
    "crear agua|conjure water|造水术",
    "crear comida|conjure food|造食术",
    "portal orgrimmar|portal: orgrimmar|传送门：奥格瑞玛",
    "portal ventormenta|portal: stormwind|传送门：暴风城",
    -- Sacerdote (Priest)
    "palabra de poder escudo|power word: shield|真言术：盾",
    "palabra de poder: escudo|power word: shield|真言术：盾",
    "sanacion relampago|flash heal|快速治疗",
    "sanación relámpago|flash heal|快速治疗",
    "palabra de poder dolor|shadow word: pain|真言术：痛",
    "palabra de poder: dolor|shadow word: pain|真言术：痛",
    "sanacion superior|greater heal|强效治疗术",
    "sanación superior|greater heal|强效治疗术",
    "rezo de sanacion|prayer of healing|治疗祷言",
    "rezo de sanación|prayer of healing|治疗祷言",
    "renovar|renew|恢复",
    "desvanecerse|fade|渐隐术",
    "mind blast|mind blast|心灵震爆",
    "explosion mental|mind blast|心灵震爆",
    "explosión mental|mind blast|心灵震爆",
    "forma de las sombras|shadowform|暗影形态",
    "forma de sombra|shadowform|暗影形态",
    "infusion de poder|power infusion|能量灌注",
    "infusión de poder|power infusion|能量灌注",
    "espiritu divino|divine spirit|神圣之灵",
    "espíritu divino|divine spirit|神圣之灵",
    "rezo de espiritu|prayer of spirit|精神祷言",
    "rezo de espíritu|prayer of spirit|精神祷言",
    "tortura mental|mind flay|精神鞭笞",
    "peste devoradora|devouring plague|噬灵疫病",
    "silencio|silence|沉默",
    "disipar magia|dispel magic|驱散魔法",
    "disipar en masa|mass dispel|群体驱散",
    "curar enfermedad|cure disease|祛病术",
    "resurreccion|resurrection|复活术",
    "resurrección|resurrection|复活术",
    "abrazo vampirico|vampiric embrace|吸血鬼的拥抱",
    "abrazo vampírico|vampiric embrace|吸血鬼的拥抱",
    "fuego interno|inner fire|心灵之火",
    "encadenar no-muerto|shackle undead|束缚亡灵",
    -- Pícaro (Rogue)
    "golpe siniestro|sinister strike|邪恶攻击",
    "sigilo|stealth|潜行",
    "eviscerar|eviscerate|剔骨",
    "hacer picadillo|slice and dice|切割",
    "porrazo|sap|闷棍",
    "cegar|blind|致盲",
    "esfumarse|vanish|消失",
    "patada|kick|脚踢",
    "golpe bajo|cheap shot|偷袭",
    "garrote|garrote|绞喉",
    "emboscada|ambush|伏击",
    "puñalada|backstab|背刺",
    "punalada|backstab|背刺",
    "aluvion de acero|blade flurry|剑刃乱舞",
    "aluvión de acero|blade flurry|剑刃乱舞",
    "adrenalina|adrenaline rush|冲动",
    "subidon de adrenalina|adrenaline rush|冲动",
    "subidón de adrenalina|adrenaline rush|冲动",
    "sangre fria|cold blood|冷血",
    "sangre fría|cold blood|冷血",
    "preparacion|preparation|准备",
    "preparación|preparation|准备",
    "esprintar|sprint|疾跑",
    "forzar cerradura|pick lock|开锁",
    "robar|pickpocket|偷窃",
    "desarmar trampa|disarm trap|解除陷阱",
    "exponer armadura|expose armor|破甲",
    "golpe en los rinones|kidney shot|肾击",
    "golpe en los riñones|kidney shot|肾击",
    -- Brujo (Warlock)
    "descarga de las sombras|shadow bolt|暗影箭",
    "corrupcion|corruption|腐蚀术",
    "corrupción|corruption|腐蚀术",
    "transfusion de vida|life tap|生命分流",
    "transfusión de vida|life tap|生命分流",
    "miedo|fear|恐惧术",
    "inmolar|immolate|献祭",
    "succionar vida|siphon life|生命虹吸",
    "piedra de salud|healthstone|治疗石",
    "piedra de alma|soulstone|灵魂石",
    "invocar diablillo|summon imp|召唤小鬼",
    "invocar abisario|summon voidwalker|召唤虚空行者",
    "invocar súcubo|summon succubus|召唤魅魔",
    "invocar sucubo|summon succubus|召唤魅魔",
    "maldicion de agonia|curse of agony|痛苦诅咒",
    "maldición de agonía|curse of agony|痛苦诅咒",
    "maldicion de la agonia|curse of agony|痛苦诅咒",
    "maldición de la agonía|curse of agony|痛苦诅咒",
    "maldicion de las sombras|curse of shadow|暗影诅咒",
    "maldición de las sombras|curse of shadow|暗影诅咒",
    "maldicion de los elementos|curse of elements|元素诅咒",
    "maldición de los elementos|curse of elements|元素诅咒",
    "maldicion de debilidad|curse of weakness|虚弱诅咒",
    "maldición de debilidad|curse of weakness|虚弱诅咒",
    "maldicion de temeridad|curse of recklessness|鲁莽诅咒",
    "maldición de temeridad|curse of recklessness|鲁莽诅咒",
    "maldicion de lenguas|curse of tongues|语言诅咒",
    "maldición de lenguas|curse of tongues|语言诅咒",
    "drenar vida|drain life|吸取生命",
    "drenar mana|drain mana|吸取法力",
    "drenar maná|drain mana|吸取法力",
    "drenar alma|drain soul|吸取灵魂",
    "lluvia de fuego|rain of fire|火雨",
    "infierno|inferno|地狱火",
    "desterrar|banish|放逐术",
    "ritual de invocacion|ritual of summoning|召唤仪式",
    "ritual de invocación|ritual of summoning|召唤仪式",
    "ropero|closet|拉人门",
    "portal de invocacion|summoning portal|召唤传送门",
    "portal de invocación|summoning portal|召唤传送门",
    -- Druida (Druid)
    "rejuvenecimiento|rejuvenation|回春术",
    "recrecimiento|regrowth|愈合",
    "toque de sanacion|healing touch|治疗之触",
    "toque de sanación|healing touch|治疗之触",
    "fuego estelar|starfire|星火术",
    "colera|wrath|愤怒",
    "cólera|wrath|愤怒",
    "forma felina|cat form|猎豹形态",
    "forma de oso|bear form|熊形态",
    "forma de viaje|travel form|旅行形态",
    "estimulo|innervate|激活",
    "estímulo|innervate|激活",
    "marca de lo salvaje|mark of the wild|野性印记",
    "patita|motw|爪子",
    "enredar|entangling roots|纠缠根须",
    "raices enredaderas|entangling roots|纠缠根须",
    "raíces enredaderas|entangling roots|纠缠根须",
    "hibernar|hibernate|休眠",
    "forma de lechucho lunar|moonkin form|枭兽形态",
    "forma de lechúcho lunar|moonkin form|枭兽形态",
    "forma de arbol de vida|tree of life form|生命之树形态",
    "forma de árbol de vida|tree of life form|生命之树形态",
    "presura|dash|急奔",
    "azotar|bash|重击",
    "tranquilidad|tranquility|宁静",
    "limpiar veneno|cure poison|驱毒术",
    "eliminar maldicion|remove curse|解除诅咒",
    "eliminar maldición|remove curse|解除诅咒",
    -- Paladín (Paladin)
    "imposicion de manos|lay on hands|圣疗术",
    "imposición de manos|lay on hands|圣疗术",
    "bendicion de poder|blessing of might|力量祝福",
    "bendición de poder|blessing of might|力量祝福",
    "luz sagrada|holy light|圣光术",
    "destello de luz|flash of light|圣光闪现",
    "escudo divino|divine shield|圣盾术",
    "burbuja|bubble|无敌",
    "bendicion de reyes|blessing of kings|王者祝福",
    "bendición de reyes|blessing of kings|王者祝福",
    "sentencia|judgement|审判",
    "consagracion|consecration|奉献",
    "consagración|consecration|奉献",
    "aura de retribucion|retribution aura|惩罚光环",
    "aura de retribución|retribution aura|惩罚光环",
    "aura de devocion|devotion aura|虔诚光环",
    "aura de devoción|devotion aura|虔诚光环",
    "aura de concentracion|concentration aura|专注光环",
    "aura de concentración|concentration aura|专注光环",
    "bendicion de salvacion|blessing of salvation|拯救祝福",
    "bendición de salvación|blessing of salvation|拯救祝福",
    "bendicion de sabiduria|blessing of wisdom|智慧祝福",
    "bendición de sabiduría|blessing of wisdom|智慧祝福",
    "bendicion de libertad|blessing of freedom|自由祝福",
    "bendición de libertad|blessing of freedom|自由祝福",
    "bendicion de proteccion|blessing of protection|保护祝福",
    "bendición de protección|blessing of protection|保护祝福",
    "bendicion de sacrificio|blessing of sacrifice|牺牲祝福",
    "bendición de sacrificio|blessing of sacrifice|牺牲祝福",
    "colera vengativa|avenging wrath|复仇之怒",
    "cólera vengativa|avenging wrath|复仇之怒",
    "alas|wings|翅膀",
    "choque sagrado|holy shock|神圣震击",
    "martillo de justicia|hammer of justice|制裁之锤",
    "martillo de colera|hammer of wrath|愤怒之锤",
    "martillo de cólera|hammer of wrath|愤怒之锤",
    "exorcismo|exorcism|驱邪术",
    -- Chamán (Shaman)
    "descarga de relampagos|lightning bolt|闪电箭",
    "descarga de relámpagos|lightning bolt|闪电箭",
    "ola de sanacion|healing wave|治疗波",
    "ola de sanación|healing wave|治疗波",
    "choque de tierra|earth shock|地震术",
    "choque de llama|flame shock|烈焰震击",
    "choque de escarcha|frost shock|冰霜震击",
    "totem de nexo terrestre|earthbind totem|地缚图腾",
    "tótem de nexo terrestre|earthbind totem|地缚图腾",
    "totem de corriente de agua|healing stream totem|治疗之泉图腾",
    "tótem de corriente de agua|healing stream totem|治疗之泉图腾",
    "ansia de sangre|bloodlust|嗜血",
    "totem de fuerza de la tierra|strength of earth totem|大地之力图腾",
    "tótem de fuerza de la tierra|strength of earth totem|大地之力图腾",
    "totem viento furioso|windfury totem|风怒图腾",
    "tótem viento furioso|windfury totem|风怒图腾",
    "totem de viento furioso|windfury totem|风怒图腾",
    "tótem de viento furioso|windfury totem|风怒图腾",
    "wf|windfury|风怒",
    "arma viento furioso|windfury weapon|风怒武器",
    "escudo de relampagos|lightning shield|闪电盾",
    "escudo de relámpagos|lightning shield|闪电盾",
    "escudo de agua|water shield|水之护盾",
    "sanacion en cadena|chain heal|链状治疗",
    "sanación en cadena|chain heal|链状治疗",
    "relampago en cadena|chain lightning|闪电链",
    "relámpago en cadena|chain lightning|闪电链",
    "gracia de la naturaleza|nature's swiftness|自然迅捷",
    "rapidez de la naturaleza|nature's swiftness|自然迅捷",
    "reencarnacion|reincarnation|复生",
    "reencarnación|reincarnation|复生",
    "totem de temblor|tremor totem|战栗图腾",
    "tótem de temblor|tremor totem|战栗图腾",
    "totem de garra de piedra|stoneclaw totem|石爪图腾",
    "tótem de garra de piedra|stoneclaw totem|石爪图腾",
    -- Cazador (Hunter)
    "disparo arcano|arcane shot|奥术射击",
    "picadura de serpiente|serpent sting|毒蛇钉刺",
    "marca del cazador|hunter's mark|猎人印记",
    "disparo de punteria|aimed shot|瞄准射击",
    "disparo de puntería|aimed shot|瞄准射击",
    "fingir muerte|feign death|假死",
    "trampa congelante|freezing trap|冰冻陷阱",
    "aspecto de guepardo|aspect of the cheetah|猎豹守护",
    "aspecto de la manada|aspect of the pack|豹群守护",
    "disparo silenciador|silencing shot|沉默射击",
    "disparo de quimera|chimera shot|奇美拉射击",
    "disparo de dispersion|scatter shot|驱散射击",
    "disparo de dispersión|scatter shot|驱散射击",
    "disparo de distraccion|distracting shot|扰乱射击",
    "disparo de distracción|distracting shot|扰乱射击",
    "disparo mortal|kill shot|杀戮射击",
    "redireccion|redirection|误导",
    "redirección|redirection|误导",
    "retirada|disengage|逃脱",
    "asustar bestia|scare beast|恐吓野兽",
    "rastrear humanoides|track humanoids|寻找人型生物",
    "rastrear no-muertos|track undead|寻找亡灵",
    "aspecto de mono|aspect of the monkey|灵猴守护",
    "aspecto de halcon|aspect of the hawk|雄鹰守护",
    "aspecto de halcón|aspect of the hawk|雄鹰守护",
    "revivir mascota|revive pet|复活宠物",
    "curar mascota|mend pet|治疗宠物",
    "alimentar mascota|feed pet|喂养宠物",
    -- Buffs y utilidades de raid cruciales
    "resguardo contra el miedo|fear ward|防恐结界",
    "fear ward|fear ward|防恐",
    "defensa contra miedo|fear ward|防恐",
    "piedra de vida|healthstone|糖",
    "saludable|healthstone|糖",
    "mermelada|healthstone|糖",
    "piedra alma|soulstone|灵魂石",
    "ss|soulstone|灵魂石",
    "invocar void|summon voidwalker|召唤蓝胖",
    "invocar cazador|summon felhunter|召唤地狱犬",
    "felhunter|felhunter|狗/地狱犬",
    "desterrar|banish|放逐",
    "ritual de invocacion|ritual of summoning|拉人/召唤仪式",
    "fortaleza|power word: fortitude|耐力",
    "intelecto|arcane intellect|智力",
    "espiritu divino|divine spirit|精神",
    "marca de lo salvaje|mark of the wild|爪子",
    "motw|mark of the wild|爪子",
    "bendicion de reyes|blessing of kings|王者",
    "bendicion de poder|blessing of might|力量",
    "bendicion de sabiduria|blessing of wisdom|智慧",
    "bendicion de salvacion|blessing of salvation|拯救",
    "salvacion|salvation|拯救",
    "reyes|kings|王者",
    "sabiduria|wisdom|智慧",
    "viento furioso|windfury|风怒",
    -- Adiciones masivas de hechizos (Clásicos y Custom)
    "estimulo|innervate|激活",
    "palabra de poder escudo|power word: shield|真言术：盾",
    "pw shield|power word: shield|真言术：盾",
    "escudo de tierra|earth shield|大地盾",
    "fuego de alma|soul fire|灵魂之火",
    "descarga de las sombras|shadow bolt|暗影箭",
    "dolor de sombras|shadow pain|暗影痛苦",
    "palabra de las sombras: dolor|shadow word: pain|暗影字：痛",
    "palabra de sombras dolor|shadow word: pain|暗影痛",
    "sed de sangre|bloodthirst|嗜血",
    "imposicion de manos|lay on hands|圣疗术",
    "tormenta divina|divine storm|神圣风暴",
    "desarmar trampas|disarm trap|解除陷阱",
    "fuego de fenix|phoenix fire|凤凰之火",
    "teletransporte|teleport|传送",
    "portal de mago|mage portal|传送门",
    "crear portal|conjure portal|制造传送门",
    "piedra de alma ss|soulstone|灵魂石",
    "ss en tank|ss on tank|给坦绑灵魂石",
    "piedra de alma en tanque|ss on tank|灵魂石给坦",
    "piedra de salud hs|healthstone|健康糖",
    "estimulo al heal|innervate on healer|激活给奶妈",
    "estimulo a mi|innervate me|给我激活",
    "estimular al heal|innervate healer|给治疗激活",
    "tacho de luz|lightwell|光明之泉",
    "pozo de luz|lightwell|光明之泉",
    "bendi de salvacion|blessing of salvation|拯救祝福",
    "bendi de libertad|blessing of freedom|自由祝福",
    "bendi de reyes|blessing of kings|王者祝福",
    "bendi de sabiduria|blessing of wisdom|智慧祝福",
    "bendi de poder|blessing of might|力量祝福",
    "bendi de proteccion|blessing of protection|保护祝福",
    "bendi de sacrificio|blessing of sacrifice|牺牲祝福",
    "gracia de aire|grace of air|风之优雅",
    "totem gracia de aire|grace of air totem|风之优雅图腾",
    "tótem de fuerza|strength totem|力量图腾",
    "totem de fuerza|strength totem|力量图腾",
    "totem de resistencia|resistance totem|抗性图腾",
    "tótem de resistencia|resistance totem|抗性图腾",
    "rejuvenecimiento|rejuvenation|回春术",
    "fuego feerico|faerie fire|精灵之火",
    "fuego feérico|faerie fire|精灵之火",
    "estimular|innervate|激活",
    "forma de oso temible|dire bear form|巨熊形态",
    "forma acuatica|aquatic form|水栖形态",
    "forma acuática|aquatic form|水栖形态",
    "huracan|hurricane|飓风",
    "huracán|hurricane|飓风",
    "fuego lunar|moonfire|月火术",
    "raices enredadoras|entangling roots|缠绕根须",
    "raíces enredadoras|entangling roots|缠绕根须",
    "arañazo|rake|斜掠",
    "aranazo|rake|斜掠",
    "destripar|rip|割裂",
    "magullar|maul|槌击",
    "azotar|swipe|横扫",
    "limpiar|cleanse|清算",
    "sello de rectitud|seal of righteousness|正义圣印",
    "sello de orden|seal of command|命令圣印",
    "aura de reprension|retribution aura|惩罚光环",
    "aura de reprensión|retribution aura|惩罚光环",
    "succion de vida|siphon life|生命虹吸",
    "succión de vida|siphon life|生命虹吸",
    "fuego infernal|hellfire|地狱烈焰",
    "lluvia de fuego|rain of fire|火焰之雨",
    "invocar manafago|summon felhunter|召唤地狱猎犬",
    "invocar manáfago|summon felhunter|召唤地狱猎犬",
    "crear piedra de salud|create healthstone|制造治疗石",
    "crear piedra de alma|create soulstone|制造灵魂石",
    "quemadura de las sombras|shadowburn|暗影灼烧",
    "sanacion en cadena|chain heal|治疗链",
    "sanación en cadena|chain heal|治疗链",
    "cadena de relampagos|chain lightning|闪电链",
    "cadena de relámpagos|chain lightning|闪电链",
    "descarga de relampagos|lightning bolt|闪电箭",
    "choque de llamas|flame shock|烈焰震击",
    "totem derribador|grounding totem|根基图腾",
    "tótem derribador|grounding totem|根基图腾",
    "totem fuerza de la tierra|earthbind totem|地缚图腾",
    "tótem fuerza de la tierra|earthbind totem|地缚图腾",
    "totem corriente de sanacion|healing stream totem|治疗之泉图腾",
    "tótem corriente de sanación|healing stream totem|治疗之泉图腾",
    "totem fuente de mana|mana spring totem|法力之泉图腾",
    "tótem fuente de maná|mana spring totem|法力之泉图腾",
    "totem abrasador|searing totem|灼热图腾",
    "tótem abrasador|searing totem|灼热图腾",
    "totem nova de fuego|fire nova totem|火焰新星图腾",
    "tótem nova de fuego|fire nova totem|火焰新星图腾",
    "arma muerdepiedras|rockbiter weapon|石化武器",
    "arma estigma de escarcha|frostbrand weapon|冰霜武器",
    "arma lengua de fuego|flametongue weapon|火舌武器",
    "lobo fantasmal|ghost wolf|幽魂之狼",
    "disparo automatico|auto shot|自动射击",
    "disparo automático|auto shot|自动射击",
    "multidisparo|multi-shot|多重射击",
    "disparo de conmocion|concussive shot|震荡射击",
    "disparo de conmoción|concussive shot|震荡射击",
    "disparo arcano|arcane shot|奥术射击",
    "picadura de vibora|viper sting|蝰蛇钉刺",
    "picadura de víbora|viper sting|蝰蛇钉刺",
    "fijar objetivo|hunter's mark|猎人印记",
    "trampa de escarcha|frost trap|冰霜陷阱",
    "trampa inmolacion|immolation trap|献祭陷阱",
    "trampa inmolación|immolation trap|献祭陷阱",
    "trampa explosiva|explosive trap|爆炸陷阱",
    "llamar a mascota|call pet|召唤宠物",
    "aliviar mascota|mend pet|治疗宠物",
    "retirar mascota|dismiss pet|解散宠物",
    "ojo de la bestia|eyes of the beast|野兽之眼",
    "aspecto del mono|aspect of the monkey|灵猴守护",
    "aspecto del halcon|aspect of the hawk|雄鹰守护",
    "aspecto del halcón|aspect of the hawk|雄鹰守护",
    "aspecto del guepardo|aspect of the cheetah|猎豹守护"
  }

  -- ============================================================
  -- LOTE B: MISIONES DE ALTA FRECUENCIA (QUESTS)
  -- ============================================================
  local quests_batch = {
    "el diplomatico perdido|the missing diplomat|失踪的使节",
    "el diplomático perdido|the missing diplomat|失踪的使节",
    "las colinas de tuercespina|the green hills of stranglethorn|荆棘谷 de 青山",
    "la batalla de darrowshire|the battle for darrowshire|达隆郡 de 战斗",
    "en mis suenos|in dreams|在梦中",
    "en mis sueños|in dreams|在梦中",
    "la gran mascarada|the great masquerade|大化装舞会",
    "una reliquia del pasado|a relic of the past|过去的遗物",
    "mision de tienda de supervivencia|survival tent quest|生存帐篷任务",
    "misión de tienda de supervivencia|survival tent quest|生存帐篷任务",
    "la prueba de los elementos|the test of elements|元素的试炼",
    "el libro de ur|the book of ur|乌尔之书",
    "el regreso de helcular|helcular's revenge|赫尔库拉的复仇",
    "el fin de los hermitas|the hermit's end|隐士 de 终结",
    "la leyenda de stalvan|the legend of stalvan|斯塔文的传说",
    "mor'ladim|mor'ladim|摩拉迪姆",
    "la caida de rocanegra|the fall of blackrock|黑石山的沦陷",
    "la caída de rocanegra|the fall of blackrock|黑石山的沦陷",
    "el gran rescate|the great rescue|伟大的营救",
    "el ataque de la plaga|the plague attack|天灾军团的进攻",
    "la purificacion de darrowshire|the purification of darrowshire|净化达隆郡",
    "la purificación de darrowshire|the purification of darrowshire|净化达隆郡",
    "armas de espiritu|spirit weapons|精神武器",
    "armas de espíritu|spirit weapons|精神武器",
    "el collar de lady sylvanas|lady sylvanas' necklace|希尔瓦娜斯的项链",
    "el colgante de sylvanas|lady sylvanas' necklace|希尔瓦娜斯的项链",
    "las pruebas del chaman|the shaman trials|萨满的试炼",
    "las pruebas del chamán|the shaman trials|萨满的试炼",
    "el destino de alicia|alicia's destiny|爱丽丝的命运",
    "el destino de alicia|alicia's destiny|爱丽丝的命运",
    "el corazon de hakkar|the heart of hakkar|哈卡的心脏",
    "el corazón de hakkar|the heart of hakkar|哈卡的心脏",
    "la cabeza de onyxia|the head of onyxia|奥妮克希亚的头颅",
    "la cabeza de nefarían|the head of nefarian|奈法利安的头颅",
    "la cabeza de nefarian|the head of nefarian|奈法利安的头颅",
    "el rescate de reginald windsor|the rescue of reginald windsor|营救雷吉纳德·温德索尔",
    "el regreso del heroe|the return of the hero|英雄的归来",
    "el regreso del héroe|the return of the hero|英雄的归来",
    "el vástago de onyxia|the brood of onyxia|奥妮克希亚的子嗣",
    "el vastago de onyxia|the brood of onyxia|奥妮克希亚的子嗣",
    "mision custom|custom quest|自定义任务",
    "misión custom|custom quest|自定义任务",
    "el secreto de alah'thalas|the secret of alah'thalas|亚拉萨拉斯的秘密",

    -- Misiones personalizadas de Turtle WoW
    "tienda de campana de supervivencia|survival tent quest|生存帐篷任务",
    "mision de campamento|survival tent quest|帐篷任务",
    "amenaza en el bosque oscuro|threat in the darkwood|暮色森林的威胁",
    -- Adiciones extras
    "el despertar de la plaga|the plague awakening|天灾的觉醒",
    "el despertar de la sombra|the shadow awakening|阴影的觉醒",
    "mision de montura|mount quest|坐骑任务",
    "misión de montura|mount quest|坐骑任务",
    "mision de clase|class quest|职业任务",
    "misión de clase|class quest|职业任务",
    "mision de gremio|guild quest|公会任务",
    "misión de gremio|guild quest|公会任务"
  }

  -- ============================================================
  -- LOTE C: OBJETOS E ÍTEMS COMUNES Y EXCLUSIVOS (ITEMS)
  -- ============================================================
  local items_batch = {
    "trueno furioso|thunderfury|雷霆之怒",
    "trueno furioso espada bendecida del hijo del viento|thunderfury blessed blade of the windseeker|雷霆之怒，逐风者的祝福之剑",
    "espada bendecida del hijo del viento|thunderfury blessed blade|雷霆之怒祝福之剑",
    "mano de ragnaros|hand of ragnaros|炎魔拉格纳罗斯之手",
    "sulfuras mano de ragnaros|sulfuras hand of ragnaros|萨弗拉斯，炎魔拉格纳罗斯之手",
    "escama de tortuga|turtle scale|乌龟壳",
    "moneda turtle|turtle coin|乌龟币",
    "ficha de rol|roleplay token|角色扮演代币",
    "tienda de supervivencia|survival tent|生存帐篷",
    "tienda survival|survival tent|生存帐篷",
    "tabardo personalizado|custom tabard|定制战袍",
    "bolsa de 18 casillas|18 slot bag|18格包包",
    "bolsa de 20 casillas|20 slot bag|20格包包",
    "pocion de vida|health potion|生命药水",
    "poción de vida|health potion|生命药水",
    "pocion de mana|mana potion|法力药水",
    "poción de maná|mana potion|法力药水",
    "agua destilada|sweet nectar|甜花蜜",
    "pan de centeno|crusty rye bread|黑面包",
    "hoja de truenos|thunderfury|雷霆之怒",
    "gran baculo del guardian|atiesh greatstaff of the guardian|埃提耶什，守护者的传说之杖",
    "gran báculo del guardián|atiesh greatstaff of the guardian|埃提耶什，守护者的传说之杖",
    "atiesh gran baculo del guardian|atiesh greatstaff|埃提耶什",
    "atiesh|atiesh|埃提耶什",
    "crepusculo|twilight|暮光",
    "crepúsculo|twilight|暮光",
    "ashbringer corrupta|corrupted ashbringer|堕落的灰烬使者",
    "la ashbringer|ashbringer|灰烬使者",
    "cazador de hojas|leaf hunter|叶子弓",
    "arco de hoja de cazador|rhok'delar longbow of the ancient keepers|罗克迪拉，上古守护者的长弓",
    "rhok'delar|rhok'delar|罗克迪拉",
    "lok'delar|lok'delar|洛克迪拉",
    "bastón de la bendicion|benediction|祈福",
    "baston de la bendicion|benediction|祈福",
    "bastón de la bendición|benediction|祈福",
    "baston de la bendición|benediction|祈福",
    "la bendicion|benediction|祈福",
    "la bendición|benediction|祈福",
    "perdicion de los reyes|kingsfall|帝殒",
    "perdición de los reyes|kingsfall|帝殒",
    "kingsfall|kingsfall|帝殒",
    "el ojo de sulfuras|eye of sulfuras|萨弗拉斯之眼",
    "ojo de sulfuras|eye of sulfuras|萨弗拉斯之眼",
    "cristal de mana|mana crystal|法力水晶",
    "cristal de maná|mana crystal|法力水晶",
    "rubi de mana|mana ruby|法力红宝石",
    "rubí de maná|mana ruby|法力红宝石",
    "moneda de oro turtle|turtle gold coin|乌龟金币",
    "tabardo de gremio|guild tabard|公会战袍",
    "bolsa de viaje de 16 casillas|16 slot bag|16格包",
    "pocion de proteccion contra el fuego|fire protection potion|抗火药水",
    "poción de protección contra el fuego|fire protection potion|抗火药水",
    "pocion de proteccion contra la naturaleza|nature protection potion|自然防护药水",
    "poción de protección contra la naturaleza|nature protection potion|自然防护药水",
    "pocion de invisibilidad|invisibility potion|隐形药水",
    "poción de invisibilidad|invisibility potion|隐形药水",
    "elixir de elixir de gigante|elixir of giants|巨人药剂",
    "elixir de gigante|elixir of giants|巨人药剂",
    "elixir de fuerza de gigante|elixir of giants|巨人药剂",
    "frasco de poder supremo|flask of supreme power|超能合剂",
    "frasco de titan|flask of the titans|泰坦合剂",
    "frasco de titán|flask of the titans|泰坦合剂",
    "frasco de sabiduria destilada|flask of distilled wisdom|精炼智慧合剂",
    "frasco de sabiduría destilada|flask of distilled wisdom|精炼智慧合剂",
    -- Ítems Turtle WoW e ítems emblemáticos de raid
    "tienda de supervivencia|survival tent|生存帐篷",
    "tienda survival|survival tent|帐篷",
    "tabardo de gremio custom|custom guild tabard|定制公会战袍",
    "bolsa de 18 casillas|18 slot bag|18格包",
    "bolsa de 20 casillas|20 slot bag|20格包",
    "bolsa de 24 casillas|24 slot bag|24格包",
    "ficha de rol|roleplay token|角色扮演币",
    "donacion de tienda|shop donation|商城赞助",
    -- Adiciones extras
    "lagrima de neltharion|neltharion's tear|奈萨里奥之泪",
    "lágrima de neltharion|neltharion's tear|奈萨里奥之泪",
    "nelth tear|neltharion's tear|奈萨里奥之泪/泪",
    "talisman de poder efimero|talisman of ephemeral power|短暂能量护符",
    "talisman de poder efímero|talisman of ephemeral power|短暂能量护符",
    "set t1|t1 set|T1套",
    "set t2|t2 set|T2套",
    "set t3|t3 set|T3套",
    "tier 1|t1|T1",
    "tier 2|t2|T2",
    "tier 3|t3|T3",
    "montura epica|epic mount|千金马",
    "montura épica|epic mount|千金马",
    "montura rapida|fast mount|快马",
    "montura rápida|fast mount|快马",
    "piedra de hogar|hearthstone|炉石",
    "piedra hogar|hearthstone|炉石",
    "hearthstone|hearthstone|炉石",
    "dft|drake fang talisman|龙牙饰物",
    "talisman de colmillo de dragon|drake fang talisman|龙牙饰物",
    "talismán de colmillo de dragón|drake fang talisman|龙牙饰物",
    "zhm|zin'rokh destroyer of worlds|辛洛斯，诸界的毁灭者",
    "zinrokh|zin'rokh|辛洛斯",
    "zin'rokh|zin'rokh|辛洛斯",
    "crusader enchant|enchant weapon - crusader|附魔武器 - 十字军",
    "encantamiento de cruzado|enchant weapon - crusader|附魔武器 - 十字军",
    "encantamiento cruzado|enchant weapon - crusader|附魔武器 - 十字军",
    "spellpower enchant|enchant weapon - spellpower|附魔武器 - 法术能量",
    "encantamiento de poder de hechizo|enchant weapon - spellpower|附魔武器 - 法术能量",
    "encantamiento poder de hechizo|enchant weapon - spellpower|附魔武器 - 法术能量",
    "paño de tejido rúnico|runecloth|符文布",
    "pano de tejido runico|runecloth|符文布",
    "paño de seda|silk cloth|丝绸",
    "pano de seda|silk cloth|丝绸",
    "paño de tejido mágico|mageweave cloth|魔纹布",
    "pano de tejido magico|mageweave cloth|魔纹布",
    "paño de lino|linen cloth|亚麻布",
    "pano de lino|linen cloth|亚麻布",
    "paño de lana|wool cloth|毛料",
    "pano de lana|wool cloth|毛料",
    "paño vil|felcloth|恶魔布",
    "pano vil|felcloth|恶魔布",
    "loto negro|black lotus|黑莲花",
    "salvia plateada|mountain silversage|山鼠草",
    "capullo de loto|lotus bloom|莲花",
    "hierba cardenal|cardinal ruby|赤玉石",
    "flor de peste|plaguebloom|瘟疫花",
    "hojahielo|icecap|冰盖草",
    "sueñamaleza|dreamfoil|梦叶草",
    "suenamaleza|dreamfoil|梦叶草",
    "sangrerregia|kingsblood|皇血草",
    "raíz de tierra|earthroot|地根草",
    "raiz de tierra|earthroot|地根草",
    "musgo de tumba|grave moss|墓地苔",
    "acero vivo|living steel|活化钢",
    "barra de hierro|iron bar|铁锭",
    "barra de acero|steel bar|钢锭",
    "barra de mitril|mithril bar|秘银锭",
    "barra de torio|thorium bar|瑟银锭",
    "barra de arcanita|arcanite bar|奥金锭",
    "barra de veraplata|truesilver bar|真银锭",
    "barra de oro|gold bar|金锭",
    "barra de plata|silver bar|银锭",
    "barra de cobre|copper bar|铜锭",
    "barra de bronce|bronze bar|青铜锭",
    "barra de estaño|tin bar|锡锭",
    "barra de estano|tin bar|锡锭",
    "diamante de azeroth|azerothian diamond|艾泽拉斯钻石",
    "cristal arcano|arcane crystal|奥术水晶",
    "zafiro azul|blue sapphire|蓝宝石",
    "gran rubí|huge emerald|大块绿宝石",
    "gran rubi|huge emerald|大块绿宝石",
    "diamante estrella|star ruby|星木红宝石",
    "perla negra|black pearl|黑珍珠",
    "perla iridiscente|iridescent pearl|彩色珍珠",
    "perla dorada|golden pearl|金珍珠",
    "esencia de aire|essence of air|空气精华",
    "esencia de agua|essence of water|水之精华",
    "esencia de fuego|essence of fire|火焰精华",
    "esencia de tierra|essence of earth|大地精华",
    "esencia de no-muerto|essence of undeath|死灵精华",
    "gloria de los caídos|glory of the fallen|堕落者的荣耀",
    "lágrima de la diosa|tear of the goddess|女神之泪",
    "lagrima de la diosa|tear of the goddess|女神之泪",
    "gema del vacio|void gem|虚空宝石",
    "gema del vacío|void gem|虚空宝石",
    "crematoria|ashbringer|灰烬使者",
    "sulfuras|sulfuras|萨弗拉斯"
  }

  -- ============================================================
  -- LOTE D: JERGA AVANZADA DE INTERNET Y REAL LIFE EXTENDIDA
  -- ============================================================
  local slang_batch = {
    "no pasa nada|it's fine|没事",
    "esta bien|it's ok|没事",
    "está bien|it's ok|没事",
    "deja de llorar|stop crying|别哭了",
    "que pro|what a pro|太专业了",
    "eres el mejor|you are the best|你最棒了",
    "buen intento|nice try|尽力了",
    "no pasa nada buen intento|np nt|没事，尽力了",
    "tengo mucho lag|i have high lag|我好卡啊",
    "caida de internet|internet dropped|网络断了",
    "caída de internet|internet dropped|网络断了",
    "reiniciar pc|restart pc|重启电脑",
    "tengo sueno me voy a dormir|tired going to sleep|困了，去睡觉了",
    "tengo sueño me voy a dormir|tired going to sleep|困了，去睡觉了",
    "nos vemos manana|see you tomorrow|明天见",
    "nos vemos mañana|see you tomorrow|明天见",
    "hola a todos|hi everyone|大家好",
    "como estan|hi all how are you|大家好，你们好吗",
    "cómo están|hi all how are you|大家好，你们好吗",
    "mucho exito|good luck|祝成功",
    "mucho éxito|good luck|祝成功",
    "tengo que ir al bano|need to go to restroom|去个洗手间",
    "tengo que ir al baño|need to go to restroom|去个洗手间",
    "afk bano|afk bio|洗手间暂离",
    "afk baño|afk bio|洗手间暂离",
    "bio break|bio break|方便一下",
    "regreso en 5 minutos|back in 5 minutes|5分钟后回来",
    "regreso en 5 min|back in 5 min|5分钟回来",
    "dame lider|give me lead|给我队长",
    "dame líder|give me lead|给我队长",
    "pasa el lider|pass lead|传火/给队长",
    "pasa el líder|pass lead|传火/给队长",
    "hazme lider|make me lead|升我队长",
    "hazme líder|make me lead|升我队长",
    "necesitamos mas dps|need more dps|需要更多DPS",
    "necesitamos más dps|need more dps|需要更多DPS",
    "necesitamos healer|need healer|缺治疗",
    "necesitamos tanque|need tank|缺坦克",
    "el tanque se murio|tank died|坦倒了",
    "el tanque se murió|tank died|坦倒了",
    "cuidado con el pull|careful with pull|小心拉怪",
    "cuidado pull|care with pull|小心怪",
    "vamos a limpiar|let's clear|清小怪",
    "wipear|wipe|灭地",
    "es un wipe|it's a wipe|灭了",
    "revivan por favor|please resurrect|请复活我",
    "revivan pls|res pls|求复活",
    "dame resurreccion|res me pls|复活我",
    "dame resurrección|res me pls|复活我",
    "dame piedra de alma|soulstone me|给我绑灵魂石",
    "tira piedra de alma|ss me pls|绑灵魂石",
    "invoca por favor|summon please|求拉/召唤",
    "dame portal|portal please|求开门",
    "mago haz comida|mage conjure food|法师面包",
    "mago agua por favor|mage water please|法师给点水",
    "mago agua pls|mage water pls|法师水",
    "bufos por favor|buffs please|求buff",
    "dame bufos|buff me pls|给点buff",
    "marca de lo salvaje pls|motw pls|求爪子",
    "intelecto pls|intellect pls|求智力",
    "fortaleza pls|fortitude pls|求耐力",
    "espiritu pls|spirit pls|求精神",
    "espíritu pls|spirit pls|求精神",
    "reyes pls|kings pls|求王者",
    "poder de batalla pls|might pls|求力量祝福",
    "el healer no tiene mana|healer oom|治疗没蓝了",
    "el healer no tiene maná|healer oom|治疗没蓝了",
    "oom|out of mana|没蓝了",
    "estoy sin mana|out of mana|我没蓝了",
    "estoy sin maná|out of mana|我没蓝了",
    "beber agua|drinking water|回蓝中",
    "esperen|wait|等等",
    "esperen un momento|wait a moment|等一下",
    "listo|ready|准备好了",
    "listos|ready|好了吗",
    "check de listos|ready check|就位确认",
    "rc|ready check|就位确认",
    "pullear|pulling|拉怪了",
    "ya voy|i am coming|来了",
    "buena batalla|good fight|好样的",
    "buen intento|nice try|虽败犹荣",
    "felicidades|congrats|恭喜",
    "felicidades por el nivel|grats on level|恭喜升级",
    "felicidades por el drop|grats on drop|恭喜拿装备",
    "grats|congrats|恭喜",
    "gz|congrats|恭喜",
    "gracias a todos|thanks all|谢谢大家",
    "gracias por el grupo|thanks for group|谢谢组队",
    "buen grupo|good group|优秀的队伍",
    -- Abreviaturas de chat y reclutamientos avanzados (LFG/LFM)
    "necesito summon|need summon|求拉",
    "necesito invocacion|need summon|求拉",
    "need summon|need summon|求拉",
    "click portal|click portal|点门",
    "123 en el portal|click portal 123|点门123",
    "123 port|click portal 123|123点门",
    "por favor invoca|summon pls|拉人谢谢",
    "inv pls|invite please|求组",
    "invitame por favor|invite please|组我谢谢",
    "lf1m tank|need 1 tank|缺1坦",
    "lf2m dps|need 2 dps|缺2输出",
    "lf1m healer|need 1 healer|缺1奶",
    "manco|noob|菜鸟",
    "carreado|boosted|被带的",
    "carrear|boost|带刷",
    "noob|noob|新手/菜鸟",
    "wipe total|wipe|灭地",
    "666|awesome|666/牛逼",
    "niu bi|pro|牛逼",
    "sb|idiot|傻逼",
    "my bad|my bad|我的错",
    "wd|my bad|我的/抱歉",
    -- Adiciones extras
    "ayudame por favor|help me please|求帮/帮我",
    "ayudame pls|help pls|求帮",
    "ayuda en mision|quest help|任务求助",
    "mision de grupo|group quest|精英任务",
    "grupo por favor|group please|求组/组队",
    "invitame pls|invite pls|求拉/求组",
    "estoy listo|i am ready|我准备好了",
    "estamos listos|we are ready|我们好了",
    "espera un segundo|wait a sec|等一下",
    "ya voy de camino|on my way|我在路上了",
    "ya vuelvo|back soon|马上回来",
    "buen intento a todos|nice try all|尽力了大家",
    "gracias por el carry|thanks for carry|谢谢大佬带",
    "gracias carry|thanks carry|谢谢带我",
    "carry de mazmorra|dungeon carry|副本带刷",
    "carry de oro|gold carry|金币带刷",
    "busco comprador|selling run|金团招买家",
    "busco tank|looking for tank|求组坦克",
    "busco heal|looking for heal|求组治疗",
    "dps extra|extra dps|多余的DPS",
    "mas dps|more dps|更多输出",
    "no ninja loot|no ninja|不要毛装备",
    "loot libre|free loot|自由拾取",
    "loot de grupo|group loot|队伍分配",
    "botin libre|free loot|自由分配",
    "maestro despojador|master loot|分配者/主分配",
    "ml|master looter|队长分配",
    "gdkp|gdkp|金团/G团",
    "dkp|dkp|DKP团",
    "roll de dados|roll dice|掷骰子",
    "tirar dados|roll dice|掷骰子",
    "dame dados|roll me|掷骰子",
    "saque 100|rolled 100|roll了100",
    "saque 1|rolled 1|roll了1",
    "mala suerte|bad luck|运气差",
    "buena suerte con el loot|good luck loot|祝好运掉落",
    "felicidades amigo|grats buddy|恭喜兄弟",
    "gracias amigo|thanks mate|多谢兄弟",
    "juego aburrido|boring game|无聊的游戏",
    "no seas toxico|don't be toxic|别这么暴躁",
    "no seas tóxico|don't be toxic|别这么暴躁",
    "estoy comiendo|i'm eating|吃饭去",
    "voy al bano|brb bathroom|去洗手间",
    "voy al baño|brb bathroom|去洗手间",
    "juego con lag|i'm lagging|卡死了",
    "me da tirones|stuttering|掉帧",
    "cuantos ms tienes|what's your ping|你多少延迟",
    "cuántos ms tienes|what's your ping|你多少延迟",
    "cuanto ping|how much ping|延迟多高",
    "cuánto ping|how much ping|延迟多高",
    "tengo ping alto|high ping|延迟太高了",
    "me desconecte|disconnected|掉线了",
    "me desconecté|disconnected|掉线了",
    "esperando a un amigo|waiting for a friend|等朋友",
    "viene mi amigo|friend is coming|朋友马上来",
    "solo hablamos espanol|we only speak spanish|我们只说西班牙语",
    "solo hablamos español|we only speak spanish|我们只说西班牙语",
    "no hablo ingles|i don't speak english|不会说英语",
    "no hablo inglés|i don't speak english|不会说英语",
    "no hablo chino|i don't speak chinese|不会说中文",
    "puedes usar traductor|can you use translator|能用翻译器吗",
    "usa pfui translator|use pfui translator|用pfUI翻译器吧",
    "alguien habla espanol|anyone speaks spanish|有人说西班牙语吗",
    "alguien habla español|anyone speaks spanish|有人说西班牙语吗",
    "hermandad latina|latin guild|拉美公会",
    "hermandad hispana|spanish guild|西班牙语公会",
    "reclutando latinos|recruiting latins|招募拉美玩家",
    "hola a todos|hi everyone|大家好",
    "gracias por el grupo|thanks for the group|谢谢组队",
    "buen grupo|good group|好队伍",
    "buena party|good party|好队伍",
    "GGwp|good game well played|打得好",
    "ggs|good games|打得好",
    "lol|laugh out loud|哈哈",
    "lmao|laugh my ass off|笑死了",
    "rofl|rolling on floor laughing|笑死我了",
    "wtf|what the fuck|什么鬼",
    "omg|oh my god|我的天",
    "noob|noob|菜鸟",
    "manco|noob|手残/菜鸟",
    "pro|pro|大神",
    "maestro|master|师傅",
    "jefe|boss|老板",
    "tkm|love you|爱你",
    "te quiero|i love you|我爱你",
    "besos|kisses|亲亲",
    "abrazos|hugs|抱抱",
    "saludos|regards|问候"
  }

  -- ============================================================
  -- LOTE E: ZONAS Y CAPITALES (ZONES)
  -- ============================================================
  local zones_batch = {
    "páramos de poniente|westfall|西部荒野",
    "paramos de poniente|westfall|西部荒野",
    "bosque de elwynn|elwynn forest|艾尔文森林",
    "bosque del ocaso|duskwood|暮色森林",
    "crestagrana|redridge|赤脊山",
    "montañas de crestagrana|redridge mountains|赤脊山",
    "vallesangre|stranglethorn vale|荆棘谷",
    "tuercespina|stranglethorn vale|荆棘谷",
    "valle de tuercespina|stranglethorn vale|荆棘谷",
    "arathi|arathi|阿拉希高地",
    "tierras altas de arathi|arathi highlands|阿拉希高地",
    "los páramos|the barrens|贫瘠之地",
    "los paramos|the barrens|贫瘠之地",
    "páramos|barrens|贫瘠之地",
    "paramos|barrens|贫瘠之地",
    "marjal revolcafango|dustwallow marsh|尘泥沼泽",
    "mil agujas|thousand needles|千针石林",
    "tanaris|tanaris|塔纳利斯",
    "cráter de un'goro|un'goro crater|安戈洛环形山",
    "crater de un'goro|un'goro crater|安戈洛环形山",
    "silithus|silithus|希利苏斯",
    "cuna de invierno|winterspring|冬泉谷",
    "tierras de la peste del este|eastern plaguelands|东瘟疫之地",
    "tierras de la peste del oeste|western plaguelands|西瘟疫之地",
    "estepas ardientes|burning steppes|燃烧平原",
    "garganta de fuego|searing gorge|灼热峡谷",
    "el paso de la muerte|deadwind pass|逆风小径",
    "valle de fresno|ashenvale|灰谷",
    "ashenvale|ashenvale|灰谷",
    "desolace|desolace|凄凉之地",
    "claros de tirisfal|tirisfal glades|提瑞斯法林地",
    "bosque de argénteos|silverpine forest|银松森林",
    "bosque de argenteos|silverpine forest|银松森林",
    "laderas de trabalomas|hillsbrad foothills|希尔斯布莱德丘陵",
    "trabalomas|hillsbrad|希尔斯布莱德",
    "tierras del interior|the hinterlands|辛特兰",
    "ventormenta|stormwind|暴风城",
    "forjaz|ironforge|铁炉堡",
    "darnassus|darnassus|达纳苏斯",
    "orgrimmar|orgrimmar|奥格瑞玛",
    "cima del trueno|thunder bluff|雷霆崖",
    "entrañas|undercity|幽暗城",
    "entranas|undercity|幽暗城",
    "bahía del botín|booty bay|藏宝海湾",
    "bahia del botin|booty bay|藏宝海湾",
    "booty bay|booty bay|藏宝海湾",
    -- Adiciones extras de zonas y subzonas
    "isla de lapidis|lapidis isle|拉皮迪斯岛",
    "isla lapidis|lapidis isle|拉皮迪斯岛",
    "isla de gillijim|gillijim's isle|吉利吉姆岛",
    "isla gillijim|gillijim's isle|吉利吉姆岛",
    "alah'thalas|alah'thalas|亚拉萨拉斯",
    "tierras altas de thalassian|thalassian highlands|萨拉斯高地",
    "mirza's oasis|mirza's oasis|米尔扎绿洲",
    "oasis de mirza|mirza's oasis|米尔扎绿洲",
    "oasis mirza|mirza's oasis|米尔扎绿洲",
    "valle de alanah|alanah valley|阿兰纳谷",
    "alanah valley|alanah valley|阿兰纳谷",
    "islas de bruma|misty islands|迷雾群岛",
    "islas misty|misty islands|迷雾群岛",
    "cumbres de tormenta|alterac mountains|奥特兰克山脉",
    "montañas de alterac|alterac mountains|奥特兰克山脉",
    "valle de las pruebas|valley of trials|试炼谷",
    "valle de pruebas|valley of trials|试炼谷",
    "cerrotajo|razor hill|剃刀岭",
    "aldea sen'jin|sen'jin village|森金村",
    "aldea senjin|sen'jin village|森金村",
    "islas del eco|echo isles|回音群岛",
    "islas eco|echo isles|回音群岛",
    "cresta del trueno|thunder ridge|雷霆山",
    "barranco seco|drygulch ravine|枯谷",
    "fuerte tiragarde|tiragarde keep|提拉加德城堡",
    "terrenos erizados|razormane grounds|剃刀野猪营地",
    "roca del craneo|skull rock|骷髅石",
    "roca del cráneo|skull rock|骷髅石",
    "mesa de nube roja|redcloud mesa|红云台地",
    "nube roja|redcloud mesa|红云台地",
    "aldea pezuna de sangre|bloodhoof village|血蹄村",
    "aldea pezuña de sangre|bloodhoof village|血蹄村",
    "caravana saqueada|ravaged caravan|被毁的商队",
    "rocas rojas|red rocks|红石谷",
    "mina de ventura y cia|the venture co. mine|风险投资公司矿井",
    "mina de ventura y cía|the venture co. mine|风险投资公司矿井",
    "excavacion de bael'dun|bael'dun digsite|巴尔丹挖掘场",
    "excavación de bael'dun|bael'dun digsite|巴尔丹挖掘场",
    "campamento taurajo|camp taurajo|陶拉祖营地",
    "el cruce|the crossroads|十字路口",
    "el lodazal de lodo|the sludge fen|淤泥沼泽",
    "cumbre niebla de pavor|dreadmist peak|畏雾山峰",
    "fuerte de la guardia del norte|northwatch hold|北方城堡",
    "fuerte guardia del norte|northwatch hold|北方城堡",
    "pozas olvidadas|the forgotten pools|被遗忘的池塘",
    "oasis de agua frondosa|lushwater oasis|甜水绿洲",
    "oasis estancado|the stagnant oasis|死水绿洲",
    "trinquete|ratchet|棘齿城",
    "dalaran|dalaran|达拉然",
    "strahnbrad|strahnbrad|斯坦恩布莱德",
    "ruinas de alterac|ruins of alterac|奥特兰克废墟",
    "solar de northfold|northfold manor|诺斯弗德农场",
    "granja go'shek|goshek farm|高雪克农场",
    "granja goshek|goshek farm|高雪克农场",
    "sentinela de refugio|refuge point|避难谷地",
    "sentinela de martillo|hammerfall|落锤镇",
    "castillo de stromgarde|stromgarde keep|激流堡",
    "castillo stromgarde|stromgarde keep|激流堡",
    "cueva de faldir|faldir's cove|法尔迪平湾",
    "viaducto de thandol|thandol span|萨多尔大桥",
    "kargath|kargath|卡加斯",
    "portal oscuro|dark portal|黑暗之门",
    "castillo de nethergarde|nethergarde keep|守望堡",
    "castillo nethergarde|nethergarde keep|守望堡",
    "la muralla|the bulwark|堡垒",
    "campo santo|deathknell|丧钟镇",
    "granja solliden|solliden farmstead|索利丹农场",
    "molinos de agamand|agamand mills|阿加曼德磨坊",
    "rémol|brill|布瑞尔",
    "remol|brill|布瑞尔",
    "isla de fenris|fenris isle|芬里斯岛",
    "isla fenris|fenris isle|芬里斯岛",
    "aldea piroleña|pyrewood village|焚木村",
    "aldea pirolena|pyrewood village|焚木村",
    "castillo de colmillo oscuro|shadowfang keep|影牙城堡",
    "castillo colmillo oscuro|shadowfang keep|影牙城堡",
    "sfk|shadowfang keep|影牙城堡",
    "vega del amparo|hearthglen|壁炉谷",
    "ruinas de andorhal|ruins of andorhal|安多哈尔废墟",
    "colina del pesar|sorrow hill|悔恨丘陵",
    "lago darrowmere|darromere lake|达隆米尔湖",
    "caer darrow|caerdarrow|凯尔达隆",
    "villa de darrow|darrowshire|达隆郡",
    "mano de tyr|tyr's hand|提尔之手",
    "capilla de la esperanza de la luz|light's hope chapel|圣光之愿礼拜堂",
    "capilla esperanza de la luz|light's hope chapel|圣光之愿礼拜堂",
    "costasur|southshore|南海镇",
    "molino de tarren|tarren mill|塔伦米尔",
    "castillo de durnholde|durnholde keep|敦霍尔德城堡",
    "castillo durnholde|durnholde keep|敦霍尔德城堡",
    "isla de la purgación|purgation isle|净化之岛",
    "isla de la purgacion|purgation isle|净化之岛",
    "pico nido de águilas|aerie peak|鹰巢山",
    "pico nido de aguilas|aerie peak|鹰巢山",
    "jintha'alor|jintha'alor|辛萨罗",
    "altar de zul|the altar of zul|祖尔祭坛",
    "kharanos|kharanos|卡加斯 / 卡拉诺斯",
    "anvilmar|anvilmar|安威玛尔",
    "cantera de gol'bolar|gol'bolar quarry|戈尔波拉采石场",
    "valle de villanorte|northshire valley|北郡山谷",
    "lago de cristal|crystal lake|水晶湖",
    "mina del abismo de far|fargodeep mine|法戈第矿洞",
    "villadorada|goldshire|闪金镇",
    "campamento leñador de la vega del este|eastvale logging camp|东谷伐木场",
    "campamento lenador de la vega del este|eastvale logging camp|东谷伐木场",
    "torre de azora|tower of azora|阿佐拉之塔",
    "karazhan|karazhan|卡拉赞",
    "cruce del hombre muerto|deadman's crossing|死人路口",
    "villa oscura|duskwood / darkshire|夜色镇",
    "colina del cuervo|ravenhill|乌鸦岭",
    "arboleda del crepúsculo|twilight grove|暮色森林",
    "arboleda del crepusculo|twilight grove|暮色森林",
    "thelsamar|thelsamar|塞尔萨玛",
    "presa de la cantera|stonewrought dam|巨石水坝",
    "villa del lago|lakeshire|湖畔镇",
    "castillo de stonewatch|stonewatch|石堡",
    "expedición de nesingwary|nesingwary expedition|纳辛贝里远征队",
    "expedicion de nesingwary|nesingwary expedition|纳辛贝里远征队",
    "campamento base de grom'gol|grom'gol base camp|格罗姆高营地",
    "campamento base de gromgol|grom'gol base camp|格罗姆高营地",
    "rocard|stonard|斯通纳德",
    "estanque de las lágrimas|pool of tears|泪水之池",
    "estanque de las lagrimas|pool of tears|泪水之池",
    "arroyo de la luna|moonbrook|月溪镇",
    "colina del centinela|sentinel hill|哨兵岭",
    "faro de poniente|westfall lighthouse|西部荒野灯塔",
    "pistas de centelleo|the shimmering flats|闪光平原",
    "puerto de bonvapor|steamwheedle port|热砂港",
    "gadgetzan|gadgetzan|加基森",
    "valle de los vigilantes|valley of the watchers|观察者谷",
    "fuerte cenarion|cenarion hold|塞纳里奥要塞",
    "valle de las lanzas|valley of the spears|巨齿谷",
    "aldea de viento del sur|southwind village|南风村",
    "vista eterna|everlook|永望镇",
    "bastión de los fauces de madera|timbermaw hold|木喉要塞",
    "bastion de los fauces de madera|timbermaw hold|木喉要塞",
    "bastión de plumaluna|feathermoon stronghold|羽月要塞",
    "bastion de plumaluna|feathermoon stronghold|羽月要塞",
    "claro de la branda del halcón|talonbranch glade|爪枝林",
    "claro de la branda del halcon|talonbranch glade|爪枝林",
    "aldea brisa de plata|silverbreeze village|银风村",
    "aldea brisa de estrellas|starbreeze village|星风村",
    "nordanaar|nordanaar|诺丹纳",
    "arboleda creciente|crescent grove|新月林地",
    "tumba de los siete|tomb of the seven|七贤之墓",
    "tumba de los 7|tomb of the seven|七贤之墓",
    "campamento rebelde|rebel camp|反抗军营地",
    "campamento base de thalassian|thalassian base camp|萨拉斯大本营",
    "valle de la luna este|eastmoon ruins|东月废墟",
    "valle de la luna sur|southmoon ruins|南月废墟",
    "tierras secas|the dry hills|干旱丘陵",
    "isla del terror|isle of dread|恐惧之岛",
    "isla de otoño eterno|isle of eternal autumn|永秋岛",
    "puesto maulogg|maulogg post|毛洛格哨站",
    "refugio maulogg|maulogg refuge|毛洛格避难所",
    "cima terror|dreadmist peak|畏雾山峰",
    "valle devastado|feralscar vale|野性伤痕山谷",
    "paso de los riscos|cliff pass|悬崖小径",
    "colina de brujas|witch hill|女巫岭",
    "valle del rocío|dew valley|露水谷",
    "tumba de ironbeard|ironbeard's tomb|铁须之墓",
    "fortaleza gnarlpine|gnarlpine hold|瘤木要塞",
    "puesto forestal de hacha de trueno|thunderaxe fortress|雷斧堡垒",
    "muro de thoradin|thoradin's wall|索拉丁之墙",
    "arroyo del terror|terror run|恐惧小径",
    "tumba de uter|uther's tomb|乌瑟尔之墓",
    "el remolino|the maelstrom|大漩涡",
    "santuario esmeralda|emerald sanctuary|翡翠圣地",
    "campamento de kargath|kargath expedition|卡加斯远征军",
    "isla purificación|purgation isle|净化之岛",
    "isla jaguero|jaguero isle|哈圭罗岛",
    "campamento grom'gol|grom'gol base camp|格罗姆高营地",
    "asentamiento nethander|nethander stead|尼桑德农场",
    "el marjal resbaladizo|the slithering scar|泥泞低地",
    "minas de la muerte|deadmines|死亡矿井",
    "puesto libre de viento|freewind post|乱风岗",
    "puesto del hacha|axepost|战斧哨站",
    "cañón del eco|echo canyon|回音峡谷",
    "el bosque oscuro|darkwoods|黑暗森林",
    "las ruinas de andorhal|the ruins of andorhal|安多哈尔废墟",
    "campamento nesingwary|nesingwary's expedition|奈辛瓦里远征队",
    "arena de gurubashi|gurubashi arena|古拉巴什竞技场",
    "zulfarrak|zul'farrak|祖尔法拉克",
    "cueva de los lamentos|wailing caverns|哀嚎洞穴",
    "sima ígnea|ragefire chasm|怒焰裂谷",
    "sima ignea|ragefire chasm|怒焰裂谷",
    "kraul escaldarrajes|razorfen kraul|剃刀沼泽",
    "zahúrda rojiza|razorfen downs|剃刀高地",
    "cavernas de brazanegra|blackfathom deeps|黑暗深渊",
    "gnomeregan|gnomeregan|诺莫瑞根",
    "monasterio escarlata|scarlet monastery|血色修道院",
    "urldaman|uldamen|奥达曼",
    "profundidades de roca negra|blackrock depths|黑石深渊",
    "cumbre de roca negra|blackrock spire|黑石塔",
    "nucleo de magma|molten core|熔火之心",
    "núcleo de magma|molten core|熔火之心",
    "guarida de alanegra|blackwing lair|黑翼之巢",
    "naxxramas|naxxramas|纳克萨玛斯"
  }

  -- ============================================================
  -- LOTE F: MECÁNICAS DE COMBATE Y TERMINOLOGÍA PVE/PVP (MECHANICS)
  -- ============================================================
  local mechanics_batch = {
    "control de masas|crowd control|控怪/羊/恐惧",
    "cc|crowd control|控制/控怪",
    "linea de vision|line of sight|卡视角",
    "línea de visión|line of sight|卡视角",
    "los|line of sight|卡视角",
    "daño en el tiempo|damage over time|持续伤害",
    "dano en el tiempo|damage over time|持续伤害",
    "dot|damage over time|持续伤害/DOT",
    "sanacion en el tiempo|healing over time|持续治疗",
    "sanación en el tiempo|healing over time|持续治疗",
    "hot|healing over time|持续治疗/HOT",
    "daño por segundo|damage per second|伤害输出/DPS",
    "dano por segundo|damage per second|伤害输出/DPS",
    "dps|damage per second|输出/伤害",
    "tanque|tank|坦克/防战/熊T",
    "healer|healer|治疗/奶妈",
    "curador|healer|治疗/奶妈",
    "esbirro|add|小怪",
    "esbirros|adds|小怪",
    "bicho|mob|小怪",
    "bichos|mobs|怪",
    "jefe|boss|首领/BOSS",
    "limpiar|clear|清怪",
    "pull|pull|拉怪",
    "atraer|pull|拉怪",
    "foco|focus|集火/单点",
    "disipar|dispel|驱散",
    "cortar hechizo|interrupt|打断施法",
    "cortar cast|interrupt|打断",
    "amenaza|threat|仇恨",
    "aggro|aggro|仇恨/怪打我",
    "robar agro|draw aggro|OT/抢仇恨",
    "robar aggro|draw aggro|OT/抢仇恨",
    "ot|overthreat|OT/仇恨失控",
    "kitear|kiting|风筝",
    "hacer cometa|kiting|拉风筝",
    "combatir|combat|战斗",
    "en combate|in combat|战斗中",
    "fuera de combate|out of combat|脱战/战斗外",
    "resucitar|resurrect|复活",
    "revivir|revive|复活",
    "buff|buff|增益/Buff",
    "debuff|debuff|减益/Debuff",
    "veneno|poison|毒",
    "maldicion|curse|诅咒",
    "maldición|curse|诅咒",
    "enfermedad|disease|疾病",
    "magia|magic|魔法",
    "resistencia|resistance|抗性",
    "armadura|armor|护甲"
  }

  -- ============================================================
  -- LOTE G: PROFESIONES, MATERIALES Y COMERCIO (PROFESSIONS & TRADE)
  -- ============================================================
  local professions_batch = {
    -- Profesiones Primarias
    "alquimia|alchemy|炼金术",
    "herboristería|herbalism|草药学",
    "herboristeria|herbalism|草药学",
    "minería|mining|采矿",
    "mineria|mining|采矿",
    "herrería|blacksmithing|锻造",
    "herreria|blacksmithing|锻造",
    "ingeniería|engineering|工程学",
    "ingenieria|engineering|工程学",
    "peletería|leatherworking|制皮",
    "peleteria|leatherworking|制皮",
    "desollar|skinning|剥皮",
    "sastrería|tailoring|裁缝",
    "sastreria|tailoring|裁缝",
    "encantamiento|enchanting|附魔",
    "encantamiento|enchanting|附魔",

    -- Profesiones Secundarias y Custom
    "supervivencia|survival|生存",
    "cocina|cooking|烹饪",
    "pesca|fishing|钓鱼",
    "primeros auxilios|first aid|急救",

    -- Especializaciones e interacciones
    "ingenieria gnomica|gnomish engineering|侏儒工程学",
    "ingeniería gnómica|gnomish engineering|侏儒工程学",
    "ingenieria goblin|goblin engineering|地精工程学",
    "ingeniería goblin|goblin engineering|地精工程学",
    "alquimia de transmutacion|transmutation alchemy|转化大师",
    "alquimia de transmutación|transmutation alchemy|转化大师",
    "elixires|elixirs|药剂",
    "pociones|potions|药水",

    -- Comercio y Economía
    "craftear|craft|制作",
    "crafteo|craft|制作",
    "materiales|mats|材料",
    "receta|recipe|配方",
    "patrón|pattern|图纸",
    "patron|pattern|图纸",
    "comerciar|trade|交易",
    "ligado al equipar|bind on equip|装备后绑定",
    "ligado al recoger|bind on pickup|拾取后绑定",
    "boe|bind on equip|装绑",
    "bop|bind on pickup|拾绑",
    "banco de gremio|guild bank|公会仓库",
    "subasta|auction house|拍卖行",
    "ah|auction house|拍卖行",
    "compro|buying|收购",
    "vendo|selling|出售",
    "cambio|trading|交换",
    "gremio|guild|公会",
    "hermandad|guild|公会",
    "invitar al gremio|guild invite|公会邀请",
    "inv al gremio|guild invite|公会邀请"
  }

  -- ============================================================
  -- LOTE H: CONTENIDO, ZONAS, MAZMORRAS Y MODOS CUSTOM DE TURTLE WOW
  -- ============================================================
  local turtle_custom_batch = {
    -- Mazmorras y Raids Custom
    "arboleda creciente|crescent grove|新月林地",
    "arboleda|crescent grove|新月林地",
    "tumba de los siete|tomb of the seven|七贤之墓",
    "tumba de los 7|tomb of the seven|七贤之墓",
    "laboratorio de alah'thalas|alah'thalas laboratory|亚拉萨拉斯实验室",
    "alah'thalas|alah'thalas|亚拉萨拉斯",
    -- Geografía y Zonas Custom
    "isla de gillijim|gillijim's isle|吉利吉姆岛",
    "isla gillijim|gillijim's isle|吉利吉姆岛",
    "isla de lapidis|lapidis isle|拉皮迪斯岛",
    "isla lapidis|lapidis isle|拉皮迪斯岛",
    "tierras altas destrozadas|shattered highlands|破碎高地",
    "monte hyjal|mount hyjal|海加尔山",
    "valle bosquenegro|blackwood glen|黑木谷",
    "bosquenegro|blackwood glen|黑木谷",
    -- Modos de Juego y Desafíos
    "hardcore|hardcore|硬核/一命",
    "hc|hardcore|硬核",
    "modo hardcore|hardcore mode|一命模式/硬核模式",
    "vagabundo|vagrant|流浪者",
    "modo vagabundo|vagrant mode|流浪者模式",
    "lento y constante|slow and steady|慢而稳",
    "slow y steady|slow and steady|慢而稳",
    "autodidacta|self-crafted|自制装备/孤狼",
    "modo autodidacta|self-crafted mode|自制模式",
    "glifo de la tortuga|glyph of the turtle|乌龟雕文",
    "glifo de tortuga|glyph of the turtle|乌龟雕文",
    "modo exhausto|exhausted mode|精疲力竭模式",
    -- Modos y desafios sociales de Turtle WoW
    "un solo intento|one life|一命",
    "modo un solo intento|hardcore mode|一命模式",
    "f en el chat|f in chat|发F/点赞",
    "rip bozo|rip bozo|好死",
    "we go agane|we go again|再来一次",
    "self crafted|self crafted|自制装备",
    "vagrant|vagrant|流浪者",
    -- Adiciones extras de contenido custom
    "glifo de fatiga|glyph of fatigue|疲劳雕文",
    "glifo de superacion|glyph of progression|进度雕文",
    "glifo de superación|glyph of progression|进度雕文",
    "carpa de supervivencia|survival tent|生存帐篷",
    "tienda para descansar|resting tent|双倍经验帐篷",
    "tienda de descanso|resting tent|休息帐篷",
    "campamento de descanso|resting camp|休息营地",
    "campamento de superviviente|survivor camp|生存者营地",
    "piedra de ilusion|illusion stone|幻化石",
    "piedra de ilusión|illusion stone|幻化石",
    "ilusion|illusion|幻化",
    "ilusión|illusion|幻化",
    "glifo custom|custom glyph|自定义雕文",
    "tienda xp|xp tent|经验帐篷",
    "xp tent|xp tent|帐篷",
    "tent xp|xp tent|帐篷",
    "moneda de plata turtle|turtle silver coin|乌龟银币",
    "gilneas|gilneas city|吉尔尼斯城",
    "ciudad de gilneas|gilneas city|吉尔尼斯城",
    "criptas de karazhan|karazhan crypts|卡拉赞地下墓穴",
    "criptas karazhan|karazhan crypts|卡拉赞地下墓穴",
    "bóveda de ventormenta|stormwind vault|暴风城地牢",
    "boveda de ventormenta|stormwind vault|暴风城地牢",
    "cantera de hateforge|hateforge quarry|仇恨熔炉采石场",
    "cantera hateforge|hateforge quarry|仇恨熔炉采石场",
    "cavernas del tiempo|caverns of time|时光之穴",
    "isla de los diseñadores|designer island|设计师之岛",
    "isla de los disenadores|designer island|设计师之岛",
    "tierras altas de tirisfal|tirisfal uplands|提瑞斯法高地",
    "isla de gillijim|gillijim's isle|吉利吉姆岛",
    "carpa de la luna de sangre|bloodmoon tent|血月帐篷",
    "tienda de supervivencia|survival tent|生存帐篷",
    "modo hardcore|hardcore mode|硬核模式",
    "modo tortuga|turtle mode|乌龟模式",
    "modo guerra|warmode|战争模式",
    "modo de guerra|warmode|战争模式",
    "supervivencia|survival|生存",
    "carpinteria|woodworking|木工",
    "carpintería|woodworking|木工",
    "moneda donador|donation coin|捐赠币",
    "tienda de turtle|turtle shop|乌龟商店",
    "transmog|transmogrification|幻化",
    "transfiguración|transmogrification|幻化",
    "transfiguracion|transmogrification|幻化",
    "apariencia|appearance|外观",
    "montura tortuga|turtle mount|乌龟坐骑",
    "caballero de la muerte|death knight|死亡骑士",
    "elfo alto|high elf|高等精灵",
    "goblin|goblin|地精",
    "campamento goblin|goblin camp|地精营地",
    "tienda goblin|goblin shop|地精商店",
    "mercader de monturas|mount vendor|坐骑商人",
    "banco portátil|portable bank|便携银行",
    "banco portatil|portable bank|便携银行"
  }

  -- ============================================================
  -- LOTE I: ESTADÍSTICAS, ATRIBUTOS, RESISTENCIAS Y TALENTOS (STATS & SPECS)
  -- ============================================================
  local stats_talents_batch = {
    -- Atributos Principales
    "fuerza|strength|力量",
    "agilidad|agility|敏捷",
    "aguante|stamina|耐力",
    "intelecto|intellect|智力",
    "espíritu|spirit|精神",
    "espiritu|spirit|精神",

    -- Estadísticas Secundarias de Combate
    "índice de golpe|hit rating|命中等级",
    "indice de golpe|hit rating|命中等级",
    "golpe crítico|crit rating|爆击等级",
    "golpe critico|crit rating|爆击等级",
    "crítico|crit|爆击",
    "critico|crit|爆击",
    "esquivar|dodge|躲闪",
    "parada|parry|招架",
    "bloqueo|block|格挡",
    "poder de ataque|attack power|攻击强度",
    "ap|attack power|攻强",
    "poder con hechizos|spell power|法术强度",
    "sp|spell power|法强",
    "sanación|healing power|治疗效果",
    "sanacion|healing power|治疗效果",
    "penetración de armadura|armor penetration|护甲穿透",
    "penetracion de armadura|armor penetration|护甲穿透",
    "defensa|defense|防御",

    -- Tipos de Daño y Resistencias
    "daño físico|physical damage|物理伤害",
    "daño fisico|physical damage|物理伤害",
    "fuego|fire|火焰",
    "escarcha|frost|冰霜",
    "naturaleza|nature|自然",
    "sombras|shadow|暗影",
    "arcano|arcane|奥术",
    "sagrado|holy|神圣",
    "resistencia al fuego|fire resistance|火焰抗性",
    "resistencia a la escarcha|frost resistance|冰霜抗性",
    "resistencia a la naturaleza|nature resistance|自然抗性",
    "resistencia a las sombras|shadow resistance|暗影抗性",
    "resistencia a lo arcano|arcane resistance|奥术抗性",

    -- Clases y Especializaciones de Talentos
    "guerrero|warrior|战士",
    "paladín|paladin|圣骑士",
    "paladin|paladin|圣骑士",
    "cazador|hunter|猎人",
    "pícaro|rogue|潜行者/盗贼",
    "picaro|rogue|潜行者/盗贼",
    "sacerdote|priest|牧师",
    "chamán|shaman|萨满",
    "chaman|shaman|萨满",
    "mago|mage|法师",
    "brujo|warlock|术士",
    "druida|druid|德鲁伊",
    "armas|arms|武器",
    "furia|fury|狂暴",
    "protección|protection|防护",
    "proteccion|protection|防护",
    "retribución|retribution|惩戒",
    "retribucion|retribution|惩戒",
    "bestias|beast mastery|野兽控制",
    "puntería|marksmanship|射击",
    "punteria|marksmanship|射击",
    "sutileza|subtlety|敏锐",
    "asesinato|assassination|刺杀",
    "disciplina|discipline|戒律",
    "elemental|elemental|元素",
    "mejora|enhancement|增强",
    "restauración|restoration|恢复",
    "restauracion|restoration|恢复",
    "aflicción|affliction|痛苦",
    "afliccion|affliction|痛苦",
    "demonología|demonology|恶魔学识",
    "demonologia|demonology|恶魔学识",
    "destrucción|destruction|毁灭",
    "destruccion|destruction|毁灭",
    "equilibrio|balance|平衡",
    "combate feral|feral combat|野性战斗"
  }

  -- ============================================================
  -- LOTE J: PVP, CAMPOS DE BATALLA Y CONSUMIBLES DE RAID (PVP & CONSUMABLES)
  -- ============================================================
  local pvp_consumables_batch = {
    -- Campos de Batalla (BGs)
    "garganta grito de guerra|warsong gulch|战歌峡谷",
    "garganta de grito de guerra|warsong gulch|战歌峡谷",
    "wsg|warsong gulch|战歌",
    "valle de alterac|alterac valley|奥特兰克山谷",
    "av|alterac valley|奥山",
    "cuenca de arathi|arathi basin|阿拉希盆地",
    "ab|arathi basin|阿拉希",

    -- Objetivos PvP y Estructuras
    "cementerio|graveyard|墓地",
    "gy|graveyard|墓地",
    "bandera|flag|旗帜",
    "mina|mine|矿洞",
    "aserradero|lumber mill|伐木场",
    "lm|lumber mill|伐木场",
    "establo|stables|马厩",
    "establos|stables|马厩",
    "herrería|blacksmith|铁匠铺",
    "herreria|blacksmith|铁匠铺",
    "bs|blacksmith|铁匠铺",
    "granja|farm|农场",

    -- Rangos y Mecánicas PvP
    "rango pvp|pvp rank|PVP军衔",
    "muertes con honor|honorable kills|荣誉击杀",
    "hk|honorable kills|击杀",
    "puntos de honor|honor points|荣誉点",
    "marcas de warsong|warsong marks|战歌牌子",
    "marcas de arathi|arathi marks|阿拉希牌子",
    "marcas de alterac|alterac marks|奥山牌子",

    -- Consumibles de Raid y Soporte
    "agua de maná|mana water|法力水",
    "agua de mana|mana water|法力水",
    "pan|bread|面包",
    "comida|food|食物",
    "bebida|drink|饮料",
    "té de cardo|thistle tea|菊花茶",
    "te de cardo|thistle tea|菊花茶",
    "pocion de mana mayor|major mana potion|大蓝",
    "poción de maná mayor|major mana potion|大蓝",
    "pocion de vida mayor|major healing potion|大红",
    "poción de vida mayor|major healing potion|大红",
    "runa demoníaca|demonic rune|恶魔符文",
    "runa demoniaca|demonic rune|恶魔符文",
    "runa oscura|dark rune|黑暗符文",
    "venda de tejido de runas gruesa|heavy runecloth bandage|厚符文布绷带",
    "venda de tejido de runas|runecloth bandage|符文布绷带",
    "busco calabozo|looking for dungeon|求组副本",
    "busco mazmorra|looking for dungeon|求组副本",
    "hacer misiones|do quests|做任务",
    "subir nivel|leveling|升级",
    "levear|leveling|升级",
    "boostear|boosting|带刷",

    -- Consumibles y pvp adicionales
    "pocion de accion libre|free action potion|自由行动药水",
    "pocion de accion viva|living action potion|活性行动药水",
    "fap|free action potion|自由行动药水",
    "aceite de mago brillante|brilliant wizard oil|卓越巫师之油",
    "aceite de mana brillante|brilliant mana oil|卓越法力之油",
    "aceite de mago|wizard oil|巫师之油",
    "aceite de mana|mana oil|法力之油"
  }

  local v10_turtle_legendary_es_en_zh = {
    -- Contenido Custom y Zonas de Turtle WoW
    "sagrario esmeralda|emerald sanctum|翡翠圣地",
    "santuario esmeralda|emerald sanctum|翡翠圣地",
    "karazhan inferior|lower karazhan|卡拉赞下层",
    "ruinas de bosquenegro|blackwood ruins|黑木废墟",
    "claro del sol|sunnyglade|阳光林地",
    "isla de lapidis|lapidis isle|拉皮迪斯岛",
    "isla lapidis|lapidis isle|拉皮迪斯岛",
    "isla de gillijim|gillijim's isle|吉利吉姆岛",
    "isla gillijim|gillijim isle|吉利吉姆岛",
    "islas de bruma|misty islands|迷雾群岛",
    "valle de alanah|alanah valley|阿兰纳谷",
    "tierras altas de thalassian|thalassian highlands|萨拉斯高地",

    -- Retos y Modos Custom de Turtle WoW
    "modo un solo intento|hardcore mode|硬核模式",
    "modo hardcore|hardcore mode|硬核模式",
    "lento y constante|slow and steady|慢而稳",
    "esfuerzo de vagabundo|vagrant's endeavor|流浪者的努力",
    "modo extremo|hardcore mode|硬核模式",
    "transfiguración|transmog|幻化",
    "transfigurar|transmog|幻化",
    "tortuga de montar|riding turtle|骑乘乌龟",
    "fuego de supervivencia|survival fire|生存营火",
    "hacer fogata|survival fire|做营火",
    "glifo de la tortuga|glyph of the turtle|乌龟雕文",
    "glifo de la bestia|glyph of the beast|野兽雕文",

    -- Habilidades de Clase e Icónicos de Raid
    "golpe sagrado|holy strike|神圣打击",
    "golpe de sangre|bloodstrike|鲜血打击",
    "alivio presto|swiftmend|迅捷治愈",
    "estimulo a mi|innervate me|给我激活",
    "estimular al heal|innervate healer|给治疗激活",
    "infusion de poder|power infusion|能量灌注",
    "infusión de poder en mi|pi on me|给我灌注",
    "tótem marea de maná|mana tide totem|法力潮汐图腾",
    "totem marea de mana|mana tide totem|法力潮汐图腾",
    "tótem viento furioso|windfury totem|风怒图腾",
    "totem viento furioso|windfury totem|风怒图腾",
    "resguardo contra el miedo|fear ward|防恐结界",

    -- Chat Slang de Tiendas (Tents) y Utilidades de Turtle WoW
    "buscando tienda|looking for tent|找帐篷",
    "donde hay tienda|where is tent|帐篷在哪",
    "tienda colocada|tent is up|起帐篷了",
    "tienda en villadorada|tent in goldshire|闪金镇帐篷",
    "tienda en el cruce|tent in crossroads|十字路口帐篷",
    "tienda en camp taurajo|tent in camp taurajo|陶拉祖帐篷",
    "busco grupo para tienda|lft|找帐篷组",
    "modo de guerra|warmode|战争模式",
    "cooldown de tienda|tent cd|帐篷冷却",
    "banco de hermandad|guild bank|公会银行",
    "tienda de donaciones|donation shop|商城",
    "ficha de donación|donation token|捐赠代币",
    "ficha de donacion|donation token|捐赠代币",

    -- Mecánicas avanzadas de Raid
    "morir todos|wipe|灭团",
    "atraer monstruo|pull|拉怪",
    "medidor de amenaza|threat meter|仇恨列表",
    "saltar monstruos|skip|跳怪",
    "prueba de dps|dps check|DPS检测",
    "enfurecer|enrage|狂暴",
    "quitar maldición|decurse|解诅咒",
    "disipar magia|dispel|驱散",
    "limpiar veneno|cleanse|清洁",
    "quitar veneno|cure poison|祛毒"
  }

  -- Ejecutar la carga masiva en lotes comprimidos
  load_batch(spells_batch)
  load_batch(quests_batch)
  load_batch(items_batch)
  load_batch(slang_batch)
  load_batch(zones_batch)
  load_batch(mechanics_batch)
  load_batch(professions_batch)
  load_batch(turtle_custom_batch)
  load_batch(stats_talents_batch)
  load_batch(pvp_consumables_batch)
  load_batch(v10_turtle_legendary_es_en_zh)

  -- ============================================================
  -- LOTES v11 — EXPANSIÓN LEXICA ÉPICA
  -- Ítems legendarios, consumibles avanzados, jefes 5-man, AH
  -- ============================================================

  local v11_items_legendary = {
    -- Armas Legendarias y Emblemáticas
    "martillo de los antiguos reyes|hammer of the ancient kings|古代君王之锤",
    "sulfuras mano de ragnaros|sulfuras hand of ragnaros|硫磺之锤",
    "sulfuras|sulfuras|硫磺之锤",
    "thunderfury|thunderfury|雷怒",
    "truenofuria filo de los vientos|thunderfury blessed blade|雷怒祝福风刃",
    "atiesh|atiesh|阿迪斯",
    "atiesh baston|atiesh greatstaff|阿迪斯法杖",
    "espada de los mil años|corrupted ashbringer|腐化的安魂斩",
    "ashbringer corrompido|corrupted ashbringer|腐化的安魂斩",
    "ashbringer|ashbringer|安魂斩",
    "bendicion de los reyes de los vientos|blessing of the wind kings|风王祝福",
    "ojo de sulfuras|eye of sulfuras|苏拉玛之眼",
    "esencia del devorador oscuro|essence of the pure flame|纯粹火焰之精华",
    -- Ítems de Raid Icónicos Vanilla
    "cabeza de onyxia|onyxia's head|奥妮克希亚的头",
    "mano de justicia|hand of justice|正义之手",
    "fetiche de los dioses|trinket of the gods|神灵护符",
    "diente de sangre|bloodfang|血牙套装",
    "armadura de demonoexpurgador|doomguard|末日使者",
    "manto del arquero celestial|cloak of the shrouded mists|薄雾斗篷",
    "corona de destruccion|crown of destruction|毁灭之冠",
    "cetro de los señores de las mareas|scepter of the tide lords|潮汐领主权杖",
    "furia de ragnaros|rage of ragnaros|拉格纳罗斯之怒",
    "tejido de sombras del eterno|eternal shadowweave|永恒暗影织物",
    -- Ítems Custom de Turtle WoW
    "hacha de la tortuga|turtle axe|乌龟战斧",
    "capa de la expedicion|expedition cloak|远征披风",
    "anillo de la hermandad verde|emerald brotherhood ring|翡翠兄弟会戒指",
    "bendicion del druida guardian|blessing of the guardian druid|守护德鲁伊祝福",
    "baculo de raices ancestrales|staff of ancient roots|古老根茎法杖",
    "escudo de la tortuga ancestral|ancient turtle shield|古老乌龟盾牌"
  }

  local v11_consumables_advanced = {
    -- Consumibles de Raid Avanzados
    "pocion de fuego mayor|greater fire protection potion|高级防火药水",
    "pocion de hielo mayor|greater frost protection potion|高级防冰药水",
    "pocion de arcano mayor|greater arcane protection potion|高级防奥药水",
    "pocion de sombra mayor|greater shadow protection potion|高级防暗药水",
    "pocion de naturaleza mayor|greater nature protection potion|高级防自然药水",
    "proteccion de fuego mayor|greater fire protection|高级防火",
    "elixir del mongoose|elixir of the mongoose|猫鼬精华",
    "elixir de artes ocultas|elixir of shadow power|暗影力量精华",
    "elixir de fuerza del gigante|elixir of giants|巨人力量精华",
    "elixir de la sabiduria del brujo|elixir of the sages|贤者精华",
    "matraces de molten core|flasks of mc|熔火之心魔瓶",
    "frasco de poder supremo|flask of supreme power|至高力量魔瓶",
    "frasco de la fortaleza de la titanes|flask of the titans|泰坦魔瓶",
    "frasco de la fortaleza|flask of fortitude|坚韧魔瓶",
    "frasco del cronometrista de la destilacion|flask of distilled wisdom|凝练智慧魔瓶",
    -- Juju y Buffs Tribales
    "juju de poder|juju of power|力量祭品",
    "juju de flaqueza|juju of flurry|连击祭品",
    "juju de curación|juju of healing|治疗祭品",
    "juju de maldad|juju of offense|进攻祭品",
    -- Comida de Buff
    "carne asada de alturas|highlands game|高地烤肉",
    "salmón escalfado|poached sunscale salmon|水波太阳鳞鲑鱼",
    "pastel de queso|runn tum tuber surprise|菜肴惊喜",
    "comida de stamina|stamina food|耐力食物",
    "comida de fuerza|strength food|力量食物",
    "comida de agilidad|agility food|敏捷食物",
    "comida de intelecto|intellect food|智力食物",
    "carne tostada emparedada de grim|grilled squid|烤鱿鱼",
    "sopa de algas de playa|sagefish delight|鱼尾蛋糕"
  }

  local v11_dungeon_bosses = {
    -- Jefes de Mazmorras 5-man Faltantes (BRD, ST, DM)
    "general angerforge|general angerforge|愤怒锻造将军",
    "golem señor de cuarzo|golem lord argelmach|铸铁魔像领主",
    "senador flamelash|ambassador flamelash|炎鞭大使",
    "presidente saltrock|boss saltrock|盐岩老板",
    "moira thaurissan|moira thaurissan|莫伊拉·陶里桑",
    "emperador dagran thaurissan|emperor dagran thaurissan|达格兰·陶里桑皇帝",
    "bael gar|bael'gar|贝尔加",
    "magmus|magmus|岩浆姆斯",
    "arqueluuz|archaedas|考古达斯",
    "nefarian|nefarian|奈法利安",
    "onyxia|onyxia|奥妮克希亚",
    "lord kazzak|lord kazzak|卡扎克领主",
    "azuregos|azuregos|艾苏雷戈斯",
    "hakkar el dios sanguinario|hakkar the soulflayer|吸血鬼神哈卡尔",
    "hakkar|hakkar|哈卡尔",
    "marli sacerdotisa|high priestess mar'li|大女祭司玛尔里",
    "mandokir|bloodlord mandokir|血族领主曼多基尔",
    "thekal señor tigre|thekal|西卡尔",
    "jindo el cruel|jindo the hexxer|巫毒师金多",
    "princesa huhuran|princess huhuran|胡胡兰公主",
    "c'thun|c'thun|克苏恩",
    "viscidus|viscidus|粘液怪",
    "anub'rekhan|anub'rekhan|阿努布雷坎",
    "faerlina|faerlina|法尔琳娜",
    "maexxna|maexxna|玛克斯纳",
    "gluth|gluth|葛鲁斯",
    "thaddius|thaddius|萨迪斯",
    "sapphiron|sapphiron|萨菲隆",
    "kel'thuzad|kel'thuzad|克尔苏加德",
    "patchwerk|patchwerk|拼缝怪",
    "razuvious|instructor razuvious|拉苟维亚斯教官"
  }

  local v11_ah_economy = {
    -- Economía y Subasta
    "casa de subastas|auction house|拍卖行",
    "precio de subasta|auction price|拍卖价格",
    "precio de compra|buyout price|直购价",
    "puja inicial|starting bid|起拍价",
    "mejor oferta|best offer|最高报价",
    "vender todo|sell all|全部出售",
    "fijar precio|set price|设定价格",
    "poner a la venta|put up for sale|上架出售",
    "retirar oferta|cancel auction|取消拍卖",
    "cuantas pilas|how many stacks|多少叠",
    "pila de 20|stack of 20|20叠",
    "pila de 5|stack of 5|5个一叠",
    "precio unitario|unit price|单价",
    "precio por unidad|price per unit|每个多少钱",
    "en gremio|guild price|公会价格",
    "vendo barato|selling cheap|便宜卖",
    "busco mineral|lf ore|找矿石",
    "busco hierbas|lf herbs|找草药",
    "busco cueros|lf leather|找皮革",
    "busco tela|lf cloth|找布料",
    "vendo materiales|selling mats|卖材料",
    "vendo receta|selling recipe|卖配方",
    "negociable|negotiable|可议价",
    "precio fijo|fixed price|固定价格"
  }

  local v11_hardcore_rp = {
    -- Terminología Hardcore / Permadeath
    "muerte permanente|permadeath|永久死亡",
    "personaje hardcore|hardcore character|硬核角色",
    "restriccion hardcore|hardcore restriction|硬核限制",
    "gremio hardcore|hardcore guild|硬核公会",
    "correr solo|solo run|单人通关",
    "no usar piedra|no hearthstone|不用炉石",
    "sin resurreccion|no res|不复活",
    "nivel al morir|die to lose level|死亡掉级",
    "reglas del desafio|challenge rules|挑战规则",
    "primer muerto|first death|第一个死亡",
    -- Roleplay básico
    "interpretar personaje|roleplay|角色扮演",
    "en personaje|in character|角色内",
    "fuera de personaje|out of character|角色外",
    "hablar en personaje|ic speech|角色内对话",
    "escena de roleplay|rp scene|角色扮演场景",
    "trasfondo del personaje|character backstory|角色背景",
    "descripcion del personaje|character description|角色描述",
    "emote de roleplay|rp emote|角色扮演动作",
    "taberna para rp|rp tavern|角色扮演酒馆",
    "zona de roleplay|rp zone|角色扮演区域"
  }

  load_batch(v11_items_legendary)
  load_batch(v11_consumables_advanced)
  load_batch(v11_dungeon_bosses)
  load_batch(v11_ah_economy)
  load_batch(v11_hardcore_rp)

  local v12_slang_screenshots = {
    -- Slang, modismos y correcciones directas de reportes de usuario
    "preparar|prepare|准备",
    "conseguir|get|弄",
    "casillas|slots|格",
    "bolsa|bag|包包",
    "bolsa|bag|包",
    "grom|grom|格罗姆",
    "personaje normal|normal character|普通角色",
    "dejar|let|让",
    "cerrar servidor|server shutdown|关服",
    "cerrar|close|关",
    "monedas|tokens|代币",
    "original|original|原",
    "como|like|像",
    "lotería|lottery|抽奖",
    "debería|should|应该把",
    "reembolsar|refund|退",
    "color|color|色",
    "en|at|于",
    "recompensa|reward|奖励",
    "si|if|的话",
    "vida|life|命",
    "un|a|个",
    "título|title|称号",
    "apariencia|appearance|外貌",
    "malo|bad|差",
    "suerte|lucky|欧",
    "hacer|do|搞",
    "grupo|stack|组",
    "correo|mail|邮寄",
    "invita cordialmente a todos|cordially invites all|诚邀各界",
    "guerreros|warriors|士",
    "básicamente equipado|already brought|基本已携",
    "buen ambiente|good environment|环境适宜",
    "manteniendo|upholding|秉承",
    "diversión ante todo|fun first|娱乐至上",
    "todos son bienvenidos|all are welcome|者皆缘",
    "divertirse|have fun|嗨",
    "completar|clear|通",
    "todo tipo|all kinds|各种",
    "joder|wtf|尼玛",
    "por qué|why|为毛",
    "no poder|unable to|无法",
    "coger|take|拿",
    "cosa|thing|东西",
    "veterano|pro|大佬",
    "tipo|guy|佬",
    "arathi|arathi|阿拉希",
    "jugar|play|打",
    "crasheo|crash|闪退",
    "último|last|最后",
    "paso|step|步",
    "terminar|finish|完",
    "despegar|take off|起飞",
    "ayuda|help|帮忙"
  }
  load_batch(v12_slang_screenshots)

  local v13_slang_screenshots = {
    -- Slang, términos de las capturas del usuario y vocabulario bidireccional
    "modo vagabundo|vagrant mode|流浪",
    "vagabundo|vagrant|流浪",
    "banco móvil|mobile bank|移动仓库",
    "almacén móvil|mobile warehouse|移动仓库",
    "banco móvil|mobile bank|移动 banco",
    "volver a subir|reroll|重练",
    "volver a levear|relevel|重练",
    "recrear|reroll|重练",
    "subir otro personaje|level again|重练",
    "bot|bot|机器",
    "máquina|machine|机器",
    "burro|donkey|驴",
    "mula|mule|驴",
    "molesto|annoying|烦",
    "pesado|annoying|烦",
    "fastidioso|annoying|烦",
    "elegir|choose|选",
    "seleccionar|select|选",
    "tonterías|bullshit|毛线",
    "nada|nothing|毛线",
    "mierda|nonsense|毛线",
    "solo|only|只",
    "solamente|only|只",
    "generalmente|generally|般",
    "normalmente|normally|般",
    "tipos locos|sick cvnts|狂野小伙",
    "enfermos|sick cvnts|狂野小伙",
    "expatriados|expats|移民玩家",
    "extranjeros|expats|移民玩家",
    "soporte CJK|cjk support|CJK支持",
    "soporte de fuentes chinas|cjk support|CJK支持",
    "permitiendo|allowing|允许",
    "que presenta|featuring|包括",
    "con|featuring|包括",
    "configuración|setup|配置",
    "ajustes|setup|配置",
    "rendimiento|performance|性能",
    "guías|guides|指南",
    "guias|guides|指南",
    "veterano|veteran|老玩家",
    "comunidad|community|社区",
    "susurrar|whisper|私聊",
    "susurro|whisper|私聊",
    "todavía|yet|还",
    "aún|yet|还"
  }
  load_batch(v13_slang_screenshots)

  local v14_slang_refinements = {
    -- 1. Correcciones específicas de capturas de pantalla de chat
    "wc|wc|哀嚎",
    "cueva de los lamentos|wailing caverns|哀嚎洞穴",
    "cuevas de los lamentos|wailing caverns|哀嚎洞穴",
    "lamentos|wailing caverns|哀嚎",

    "trinquete|ratchet|棘齿城",
    "trinquete|ratchet|棘齿",
    "base trinquete|ratchet base|棘齿城基地",
    "base trinquete|ratchet base|棘齿基地",

    "maestros|pros|大佬们",
    "maestro|pro|大佬",
    "veteranos|veterans|大佬们",
    "veterano|veteran|大佬",
    "grande佬们|veterans|大佬们",
    "grande佬|veteran|大佬",
    "grande 佬们|veterans|大佬们",
    "grande 佬|veteran|大佬",

    "incompatibles|mutually exclusive|互斥",
    "no se acumulan|don't stack|互斥",
    "no se acumula|doesn't stack|互斥",

    "cazador|hunter|LR",
    "cazadores|hunters|LRs",

    "mascota|pet|宝爹",
    "mascotas|pets|宝爹们",

    "hay que subir|must level|得练",
    "tienes que subir|must level|得练",
    "hay que levear|must level|得练",
    "tienes que levear|must level|得练",

    "crear un personaje|make an alt|建个号",
    "hacerse un personaje|make an alt|建个号",
    "crearse un alter|make an alt|建个号",
    "crear un alter|make an alt|建个号",
    "crear personaje|create character|建号",
    "hacerse un personaje|create character|建号",

    "materiales|mats|物资",
    "suministros|supplies|物资",
    "recursos|resources|物资",

    "pedido de suministros de alquimia|order for alchemical goods|炼金货物的订单",
    "pedido de mercancías de alquimia|order for alchemical goods|炼金货物的订单",
    "[pedido de suministros de alquimia]|[order for alchemical goods]|[炼金货物的订单]",

    -- 2. Vocabulario de apoyo y abreviaciones comunes de inglés a español/chino (slang WoW)
    "busco grupo|looking for group|lfg",
    "busco mas|looking for more|lfm",
    "compro|want to buy|wtb",
    "vendo|want to sell|wts",
    "cambio|want to trade|wtt",
    "busco|looking for|lf",
    "necesito|need|need",
    "invita|invite|inv",
    "invitar|invite|invite",
    "susurrar|whisper|whisper",
    "susurrame|whisper me|whisper me",
    "susurrame por favor|whisper me please|whisper me please",
    "susurro|whisper|pst",
    "mazmorra|dungeon|dungeon",
    "banda|raid|raid",
    "grupo|party|party",
    "grupo|group|group",
    "tanque|tank|tank",
    "curador|healer|healer",
    "dps|dps|dps",
    "oro|gold|gold",
    "materiales|mats|mats",
    "suministros|supplies|supplies",
    "mula|mule|mule",
    "alter|alt|alt",
    "personaje|character|char",
    "personaje|character|character",
    "gente|people|people",
    "venir|come|come",
    "recibir|receive|receive",
    "hermandad|guild|hermandad",
    "quien|who|who",
    "usar|use|use",
    "entender|understand|understand",
    "jugador|player|player",
    "jugadores|players|players",
    "idioma|language|language",
    "hablar|speak|speak",
    "hablando|speaking|speaking",
    "hacer|do|do",
    "hacer|make|make",
    "saber|know|know",
    "ver|see|see",
    "para|for|for",
    "con|with|with",
    "pero|but|but",
    "porque|because|because",
    "cuando|when|when",
    "donde|where|where",
    "como|how|how",
    "que|what|what",
    "quien|who|who",
    "por que|why|why",
    "si|yes|yes",
    "no|no|no",
    "hola|hello|hello",
    "adios|goodbye|goodbye",
    "gracias|thanks|thanks",
    "gracias|thank you|thank you",
    "por favor|please|please",
    "por favor|pls|pls",
    "por favor|plz|plz",
    "lo siento|sorry|sorry",
    "bueno|good|good",
    "malo|bad|bad"
  }
  load_batch(v14_slang_refinements)

  -- ============================================================
  -- EXPANSION LEXICA v7.1 — VOCABULARIO WoW CHINO AMPLIADO
  -- Clases, roles, zonas, slang gaming, chat conversacional
  -- ============================================================

  -- Clases de personaje
  add("guerrero",                   "warrior",                   "战士")
  add("mago",                       "mage",                      "法师")
  add("picaro",                     "rogue",                     "盗贼")
  add("druida",                     "druid",                     "德鲁伊")
  add("cazador",                    "hunter",                    "猎人")
  add("sacerdote",                  "priest",                    "牧师")
  add("brujo",                      "warlock",                   "术士")
  add("paladin",                    "paladin",                   "圣骑士")
  add("chaman",                     "shaman",                    "萨满")

  -- Roles de raid/grupo
  add("tanque",                     "tank",                      "坦克")
  add("sanador",                    "healer",                    "奶妈")
  add("dps",                        "dps",                       "输出")
  add("dano",                       "damage",                    "伤害")
  add("curacion",                   "healing",                   "治疗")
  add("soporte",                    "support",                   "辅助")
  add("iniciador",                  "puller",                    "拉怪")

  -- Instancias clásicas
  add("minas de la muerte",         "deadmines",                 "死亡矿井")
  add("monasterio carmesi",         "scarlet monastery",         "血色修道院")
  add("ciudad de gnomeregan",       "gnomeregan",                "诺莫瑞根")
  add("altos del razorfen",         "razorfen downs",            "剃刀高地")
  add("maraudon",                   "maraudon",                  "玛拉顿")
  add("templo de atal'hakkar",      "sunken temple",             "沉没的神庙")
  add("profundidades de blackrock", "blackrock depths",          "黑石深渊")
  add("cumbre de blackrock",        "blackrock spire",           "黑石塔")
  add("stratholme",                 "stratholme",                "斯坦索姆")
  add("scholomance",                "scholomance",               "通灵学院")
  add("zul'farrak",                 "zul'farrak",                "祖尔法拉克")
  add("guarida de onyxia",          "onyxia's lair",             "熔火之心")
  add("nucleo de magma",            "molten core",               "熔火之心")
  add("bastión negro",              "blackwing lair",            "黑翼之巢")
  add("templo ahn'qiraj",           "temple of ahn'qiraj",       "安其拉神庙")
  add("ruinas de ahn'qiraj",        "ruins of ahn'qiraj",        "安其拉废墟")
  add("naxxramas",                  "naxxramas",                 "纳克萨玛斯")

  -- Instancias TBC
  add("karazhan",                   "karazhan",                  "卡拉赞")
  add("gruul",                      "gruul's lair",              "格鲁尔的巢穴")
  add("magtheridon",                "magtheridon's lair",        "玛瑟里顿的巢穴")
  add("templo serpiente",           "serpentshrine cavern",      "毒蛇神殿洞穴")
  add("cumbre del ojo",             "tempest keep",              "风暴要塞")
  add("monte hyjal",                "mount hyjal",               "海加尔山")
  add("fortaleza del sol negro",    "black temple",              "黑暗神殿")
  add("bastión del sol",            "sunwell plateau",           "太阳之井高地")
  add("bastillon del sol",          "sunwell",                   "太阳堡垒")

  -- Ciudades principales
  add("ciudad de tormenta",         "stormwind",                 "暴风城")
  add("ironforge",                  "ironforge",                 "铁炉堡")
  add("darnassus",                  "darnassus",                 "达纳苏斯")
  add("exodar",                     "the exodar",                "埃克索达")
  add("orgrimmar",                  "orgrimmar",                 "奥格瑞玛")
  add("villafría",                  "undercity",                 "幽暗城")
  add("cima del trueno",            "thunder bluff",             "雷霆崖")
  add("ciudad astral",              "silvermoon",                "银月城")
  add("shattrath",                  "shattrath city",            "沙塔斯城")

  -- Vocabulario gaming WoW (términos que aparecen con frecuencia en chat chino)
  add("nivel",                      "level",                     "等级")
  add("experiencia",                "experience",                "经验")
  add("subir nivel",                "level up",                  "升级")
  add("leveling",                   "leveling",                  "练级")
  add("grindear",                   "grinding",                  "刷怪")
  add("farmear",                    "farming",                   "刷素材")
  add("bot",                        "bot",                       "机器人")
  add("tramposo",                   "cheater",                   "外挂党")
  add("instancia",                  "dungeon",                   "副本")
  add("mazmorra",                   "dungeon",                   "地下城")
  add("banda",                      "raid",                      "团队副本")
  add("entrar instancia",           "enter dungeon",             "进副本")
  add("correr instancia",           "run dungeon",               "打副本")
  add("limpiar instancia",          "clear dungeon",             "通关副本")
  add("busco grupo",                "looking for group",         "求组队")
  add("formando grupo",             "forming group",             "组队中")
  add("grupo lleno",                "group full",                "满员了")
  add("reclutando",                 "recruiting",                "招募中")
  add("equipamiento",               "gear",                      "装备")
  add("objeto",                     "item",                      "物品")
  add("arma",                       "weapon",                    "武器")
  add("armadura",                   "armor",                     "护甲")
  add("anillo",                     "ring",                      "戒指")
  add("amuleto",                    "necklace",                  "项链")
  add("habilidad",                  "skill",                     "技能")
  add("talento",                    "talent",                    "天赋")
  add("jefe",                       "boss",                      "首领")
  add("monstruo",                   "mob",                       "怪物")
  add("elite",                      "elite",                     "精英")
  add("basura",                     "trash mob",                 "小怪")
  add("saqueo",                     "loot",                      "掉落")
  add("botín",                      "loot drop",                 "战利品")
  add("raro",                       "rare",                      "稀有")
  add("epico",                      "epic",                      "史诗")
  add("legendario",                 "legendary",                 "传说")
  add("necesito",                   "need roll",                 "需要摇")
  add("codicia",                    "greed roll",                "贪婪摇")
  add("encantamiento",              "enchant",                   "附魔")
  add("gema",                       "gem",                       "宝石")
  add("engaste",                    "socket",                    "宝石孔")
  add("tabla",                      "crafting table",            "工作台")

  -- Términos económicos WoW
  add("subasta",                    "auction house",             "拍卖行")
  add("en venta",                   "for sale",                  "出售")
  add("comprando",                  "buying",                    "收购")
  add("precio",                     "price",                     "价格")
  add("barato",                     "cheap",                     "便宜")
  add("caro",                       "expensive",                 "贵")
  add("intercambio",                "trade",                     "交易")
  add("intercambiar",               "exchange",                  "以物换物")
  add("envio",                      "mail",                      "邮寄")
  add("dinero de oro",              "gold",                      "金币")
  add("dinero de plata",            "silver",                    "银币")
  add("dinero de cobre",            "copper",                    "铜币")
  add("mercader",                   "vendor",                    "商人")

  -- Slang gaming chino WoW específico
  add("utilísimo",                  "very useful",               "好用")
  add("por qué no",                 "why not",                   "为啥")
  add("directamente",               "just go",                   "直接")
  add("elfo de sangre",             "blood elf",                 "血精灵")
  add("intendente",                 "quartermaster",             "军需官")
  add("interior exterior",          "inside outside",            "内外")
  add("sanador colega",             "healer",                    "奶妈")
  add("feria de la oscuridad",      "darkmoon faire",            "马戏团")
  add("villa de botín",             "booty bay",                 "闪金镇")
  add("casual",                     "casual",                    "休闲")
  add("compañero",                  "comrade",                   "同志")
  add("respeto",                    "respect",                   "尊敬")
  add("honor",                      "honor",                     "荣誉")
  add("gremio",                     "guild",                     "公会")
  add("lider de gremio",            "guild master",              "会长")
  add("miembro",                    "member",                    "成员")
  add("novato",                     "newbie",                    "萌新")
  add("veterano",                   "veteran",                   "老玩家")
  add("tramposo",                   "cheater",                   "外挂")
  add("campo de batalla",           "battleground",              "战场")
  add("arena",                      "arena",                     "竞技场")
  add("punto de honor",             "honor point",               "荣誉点")
  add("llave de mazmorra",          "dungeon key",               "副本钥匙")
  add("clase de personaje",         "character class",           "职业")
  add("raza",                       "race",                      "种族")
  add("servidor",                   "server",                    "服务器")
  add("alianza",                    "alliance",                  "联盟")
  add("horda",                      "horde",                     "部落")

  -- Chat conversacional chino en WoW
  add("hola a todos",               "hello everyone",            "大家好")
  add("bienvenido",                 "welcome",                   "欢迎")
  add("buen juego",                 "well played",               "打得好")
  add("bien hecho",                 "well done",                 "做得好")
  add("impresionante",              "awesome",                   "厉害")
  add("muy fuerte",                 "very strong",               "好强")
  add("genial",                     "great",                     "太好了")
  add("felicitaciones",             "congratulations",           "恭喜")
  add("empezar",                    "start",                     "开始")
  add("terminar",                   "finish",                    "结束")
  add("continuar",                  "continue",                  "继续")
  add("vamos",                      "let's go",                  "走吧")
  add("falló",                      "failed",                    "失败了")
  add("logrado",                    "succeeded",                 "成功了")
  add("listo",                      "ready",                     "准备好")
  add("esperando",                  "waiting",                   "等待中")
  add("llegando",                   "on my way",                 "快到了")
  add("entiendo",                   "I see",                     "明白了")
  add("no entiendo",                "don't understand",          "不明白")
  add("cuánto tiempo",              "how long",                  "多久")
  add("cuántos",                    "how many",                  "多少")
  add("cuándo empezamos",           "when do we start",          "什么时候开始")
  add("se puede",                   "is it possible",            "可以吗")
  add("sin problema",               "no problem",                "没问题")
  add("lo intento",                 "I'll try",                  "试试")
  add("no puedo",                   "I can't",                   "不行")
  add("ahora mismo",                "right now",                 "马上")
  add("de vuelta",                  "back",                      "回来了")
  add("me voy",                     "I'm leaving",               "下线了")
  add("buenas tardes",              "good afternoon",            "下午好")
  add("buenas noches",              "good night",                "晚上好")
  add("hasta luego",                "see you later",             "改天见")
  add("hasta mañana",               "see you tomorrow",          "明天见")
  add("qué pasa",                   "what's up",                 "怎么了")
  add("sin problema",               "no problem",                "没事儿")
  add("con cuidado",                "be careful",                "小心点")
  add("buena suerte",               "good luck",                 "加油")
  add("me alegra",                  "glad to hear",              "太好了")
  add("demasiado tiempo",           "too long",                  "太久了")
  add("hora",                       "hour",                      "小时")
  add("media hora",                 "half hour",                 "半小时")
  add("un momento",                 "one moment",                "稍等")
  add("tiempo real",                "real time",                 "时候")
  add("objetivo",                   "target",                    "目标")
  add("mision",                     "quest",                     "任务")
  add("recompensa",                 "reward",                    "奖励")
  add("completar mision",           "complete quest",            "完成任务")
  add("aceptar mision",             "accept quest",              "接任务")
  add("entregas de mision",         "quest turn in",             "交任务")
  add("hay alguien",                "is anyone there",           "有没有")
  add("nadie",                      "nobody",                    "没人")
  add("lo consigo",                 "I can get it",              "我去买")
  add("el jefe final",              "final boss",                "最终boss")
  add("el jefe difícil",            "hard boss",                 "难打")
  add("entrar ahora",               "enter now",                 "进来吧")
  add("afuera",                     "outside",                   "外面")
  add("zona de guerra",             "warzone",                   "战区")
  add("mundo abierto",              "open world",                "野外")
  add("pvp",                        "pvp",                       "玩家对战")
  add("pve",                        "pve",                       "副本挑战")

  -- ============================================================
  -- EXPANSION LEXICA v7.1 — FRASES VERBALES Y COMBATE
  -- ============================================================

  -- Frases de acción de 2 chars (verbos compuestos frecuentes en chat)
  add("saber",                      "know",                      "知道")
  add("entender",                   "understand",                "明白")
  add("llegar",                     "arrive",                    "到了")
  add("salir",                      "leave",                     "出去")
  add("entrar",                     "enter",                     "进去")
  add("volver",                     "return",                    "回来")
  add("ir",                         "go",                        "出发")
  add("esperar",                    "wait",                      "等等")
  add("ver",                        "see",                       "看看")
  add("intentar",                   "try",                       "试试")
  add("preparar",                   "prepare",                   "准备")
  add("cancelar",                   "cancel",                    "取消")
  add("confirmar",                  "confirm",                   "确认")
  add("terminar",                   "done",                      "完了")
  add("continuar",                  "continue",                  "继续")
  add("comenzar",                   "begin",                     "开始")
  add("finalizar",                  "end",                       "结束")
  add("unirse",                     "join",                      "加入")
  add("salir del grupo",            "leave group",               "退队")
  add("expulsar",                   "kick",                      "踢出")
  add("invitar",                    "invite",                    "邀请")
  add("rechazar",                   "decline",                   "拒绝")
  add("aceptar",                    "accept",                    "接受")
  add("ignorar",                    "ignore",                    "无视")
  add("reportar",                   "report",                    "举报")
  add("bloquear",                   "block",                     "屏蔽")
  add("conectarse",                 "login",                     "登录")
  add("desconectarse",              "logout",                    "下线")
  add("reconectar",                 "reconnect",                 "重连")
  add("recargar ui",                "reload ui",                 "重载UI")

  -- Estado del jugador
  add("en línea",                   "online",                    "在线")
  add("ocupado",                    "busy",                      "没空")
  add("libre",                      "free",                      "有空")
  add("ya regresé",                 "back",                      "回来了")
  add("me desconecté",              "disconnected",              "掉线了")
  add("tengo lag",                  "lagging",                   "卡顿")
  add("ya llegué",                  "I'm here",                  "到了")
  add("ya estoy",                   "I'm ready",                 "准备好")
  add("recién entré",               "just logged in",            "刚上线")
  add("me voy a dormir",            "going to sleep",            "去睡觉")
  add("vuelvo en un rato",          "be back soon",              "稍后回来")
  add("estoy cenando",              "eating dinner",             "吃饭中")
  add("ya me voy",                  "leaving now",               "下线了")
  add("mañana juego",               "playing tomorrow",          "明天再玩")

  -- Mecánicas de combate (2+ chars zh)
  add("cooldown",                   "cooldown",                  "冷却")
  add("en cooldown",                "on cooldown",               "冷却中")
  add("castear",                    "cast",                      "施法")
  add("interrumpir",                "interrupt",                 "打断")
  add("silencio",                   "silence",                   "沉默")
  add("aturdir",                    "stun",                      "眩晕")
  add("ralentizar",                 "slow",                      "减速")
  add("control",                    "cc",                        "控制")
  add("cc de masa",                 "aoe cc",                    "群控")
  add("rango",                      "range",                     "范围")
  add("daño en área",               "aoe damage",                "范围伤害")
  add("estallido",                  "burst",                     "爆发")
  add("escudo",                     "shield",                    "护盾")
  add("buff positivo",              "buff",                      "增益")
  add("debuff",                     "debuff",                    "减益")
  add("provocar",                   "taunt",                     "嘲讽")
  add("resucitar",                  "resurrect",                 "复活")
  add("golpe crítico",              "critical hit",              "暴击")
  add("bloqueo",                    "block",                     "格挡")
  add("esquivar",                   "dodge",                     "闪避")
  add("parar",                      "parry",                     "招架")
  add("acertar",                    "hit",                       "命中")
  add("fallar",                     "miss",                      "未命中")
  add("cantidad de vida",           "health points",             "血量")
  add("puntos de maná",             "mana points",               "法力")
  add("energía",                    "energy",                    "能量")
  add("furia",                      "rage",                      "怒气")
  add("concentración",              "focus",                     "集中")
  add("combo",                      "combo",                     "连击")
  add("emboscada",                  "ambush",                    "偷袭")
  add("sigilo",                     "stealth",                   "潜行")
  add("transformar",                "polymorph",                 "变形")
  add("domar",                      "tame",                      "驯服")
  add("mascota",                    "pet",                       "宠物")
  add("invocar conjuro",            "summon",                    "召唤")
  add("trampa",                     "trap",                      "陷阱")
  add("marcar",                     "mark",                      "标记")
  add("golpe",                      "hit",                       "击中")
  add("ataque especial",            "special attack",            "技能攻击")
  add("habilidad ultimate",         "ultimate ability",          "大招")
  add("tiempo de reutilización",    "reuse time",                "复用时间")

  -- Términos de PvP
  add("campo de batalla",           "battleground",              "战场")
  add("arena pvp",                  "arena",                     "竞技场")
  add("honorable",                  "honor",                     "荣誉")
  add("reputación pvp",             "pvp reputation",            "战场声望")
  add("rango de honor",             "honor rank",                "荣誉等级")
  add("asesino",                    "killer",                    "杀手")
  add("matar al objetivo",          "kill target",               "击杀目标")
  add("capturar bandera",           "capture flag",              "夺旗")
  add("defender base",              "defend base",               "守点")
  add("atacar base",                "attack base",               "打点")
  add("nodo",                       "node",                      "节点")
  add("flag carrier",               "flag carrier",              "旗手")
  add("curar al portador",          "heal fc",                   "奶旗手")
  add("matar al portador",          "kill fc",                   "打旗手")
  add("campo de batalla de warsong","warsong gulch",             "战歌峡谷")
  add("cuencas de arathi",          "arathi basin",              "阿拉希盆地")
  add("ojo de la tormenta",         "eye of the storm",          "风暴之眼")
  add("garganta alterac",           "alterac valley",            "奥山战役")
  add("batalla naval de strand",    "strand of the ancients",    "古代海滩")

  -- Profesiones (completo)
  add("herrería",                   "blacksmithing",             "锻造")
  add("sastrería",                  "tailoring",                 "裁缝")
  add("joyería",                    "jewelcrafting",             "珠宝加工")
  add("ingeniería",                 "engineering",               "工程学")
  add("alquimia",                   "alchemy",                   "炼金")
  add("encantamiento",              "enchanting",                "附魔")
  add("curtido",                    "leatherworking",            "制革")
  add("costura fina",               "fine tailoring",            "精细裁缝")
  add("herbología",                 "herbalism",                 "草药学")
  add("minería",                    "mining",                    "采矿")
  add("descuelleo",                 "skinning",                  "剥皮")
  add("pesca",                      "fishing",                   "钓鱼")
  add("cocina",                     "cooking",                   "烹饪")
  add("primeros auxilios",          "first aid",                 "急救")

  -- Materiales y crafting
  add("mineral de hierro",          "iron ore",                  "铁矿石")
  add("mineral de acero",           "steel ore",                 "钢铁矿石")
  add("mineral de mitril",          "mithril ore",               "秘银矿")
  add("mineral de thorium",         "thorium ore",               "奥铁矿")
  add("mineral de adamantita",      "adamantite ore",            "精金矿")
  add("mineral de fel iron",        "fel iron ore",              "魔铁矿")
  add("hierba de brionia",          "briarthorn",                "野玫瑰")
  add("hierba de leyenda",          "fadeleaf",                  "消逝叶")
  add("hierba de peacebloom",       "peacebloom",                "和平草")
  add("hierba de mageroyal",        "mageroyal",                 "法师草")
  add("materiales",                 "materials",                 "材料")
  add("mata hierba",                "herb gathering",            "采草药")
  add("cuero grueso",               "heavy leather",             "厚皮")
  add("tela de lino",               "linen cloth",               "亚麻布")
  add("tela de seda",               "silk cloth",                "丝绸布")
  add("tela rúnica",                "runecloth",                 "符文布")
  add("piel robusta",               "rugged leather",            "粗革皮")
  add("formula",                    "recipe",                    "配方")
  add("plano",                      "schematic",                 "设计图")
  add("patron",                     "pattern",                   "裁缝图纸")
  add("libro de hechizos",          "spellbook",                 "技能书")

  -- Economía WoW extendida
  add("precio de subasta",          "auction price",             "拍卖价格")
  add("comprar en subasta",         "buy from ah",               "从拍卖行买")
  add("vender en subasta",          "sell on ah",                "上拍卖行")
  add("precio de compra",           "buyout price",              "一口价")
  add("precio inicial",             "starting bid",              "起拍价")
  add("puja",                       "bid",                       "出价")
  add("el precio cayó",             "price dropped",             "价格降了")
  add("el precio subió",            "price went up",             "价格涨了")
  add("consejo de subasta",         "ah tip",                    "拍卖行技巧")
  add("trampa de precio",           "price trap",                "价格陷阱")
  add("revender",                   "resell",                    "倒卖")
  add("cuánto cuesta",              "how much",                  "多少钱")
  add("cuánto por",                 "how much for",              "多少钱一个")
  add("lo vendo a",                 "selling for",               "卖价")
  add("negociar",                   "negotiate",                 "谈价格")
  add("trato",                      "deal",                      "成交")
  add("ya pagué",                   "already paid",              "已经付钱")
  add("mandame el objeto",          "send the item",             "发邮件给我")

  -- Frases de guild/hermandad
  add("unirse al gremio",           "join guild",                "加入公会")
  add("fundador de gremio",         "guild founder",             "会长")
  add("oficial de gremio",          "guild officer",             "干部")
  add("miembro del gremio",         "guild member",              "成员")
  add("expulsado del gremio",       "guild kicked",              "踢出公会")
  add("gremio recluta",             "guild recruiting",          "公会招募")
  add("gremio casual",              "casual guild",              "休闲公会")
  add("gremio de raid",             "raiding guild",             "团本公会")
  add("gremio pvp",                 "pvp guild",                 "PVP公会")
  add("eventos del gremio",         "guild events",              "公会活动")
  add("banco del gremio",           "guild bank",                "公会银行")
  add("tabard del gremio",          "guild tabard",              "公会外袍")
  add("reputación del gremio",      "guild reputation",          "公会声望")
  add("chat del gremio",            "guild chat",                "公会频道")
  add("anuncio del gremio",         "guild notice",              "公会公告")
  add("necesitamos miembros",       "need members",              "缺人")
  add("somos pocos",                "we are few",                "人不够")
  add("ya somos suficientes",       "enough people",             "人够了")
  add("la raid empieza",            "raid starts",               "团本开始")
  add("registrate a la raid",       "sign up for raid",          "报名参加")
  add("confirmado para raid",       "confirmed for raid",        "确认参团")
  add("cancelar raid",              "raid cancelled",            "取消团本")
  add("raid pospuesta",             "raid postponed",            "推迟团本")

  -- Frases de server/eventos
  add("evento del servidor",        "server event",              "服务器活动")
  add("mantenimiento del servidor", "server maintenance",        "服务器维护")
  add("el servidor está caído",     "server is down",            "服务器崩了")
  add("el servidor se cayó",        "server crashed",            "掉服了")
  add("volver a conectar",          "reconnecting",              "重新连接")
  add("tiempo de servidor",         "server time",               "服务器时间")
  add("zona horaria del servidor",  "server timezone",           "服务器时区")
  add("feria de la oscuridad",      "darkmoon faire",            "暗月节")
  add("festival de invierno",       "winter veil",               "冬幕节")
  add("hallowsen",                  "hallow's end",              "万圣节")
  add("amor en el aire",            "love is in the air",        "爱在空气中")
  add("festival de fuego",          "midsummer fire",            "仲夏火焰节")
  add("festival de huevos",         "noblegarden",               "贵族花园")
  add("día de los niños",           "children's week",           "儿童节")
  add("fiesta de la cerveza",       "brewfest",                  "啤酒节")
  add("invasión de fuego elemental","elemental invasion",        "元素入侵")

  -- Frases de chat de rol/narrativo WoW
  add("horda para siempre",         "for the horde",             "为了部落")
  add("por la alianza",             "for the alliance",          "为了联盟")
  add("por el honor",               "for the honor",             "为了荣誉")
  add("listo para la pelea",        "ready to fight",            "准备战斗")
  add("defensas de la ciudad",      "city defense",              "守城")
  add("atacar la ciudad",           "attack the city",           "攻城")
  add("invasión de horda",          "horde invasion",            "部落入侵")
  add("invasión de alianza",        "alliance invasion",         "联盟入侵")
  add("matando facciones",          "faction killing",           "杀对立阵营")
  add("mundo compartido",           "shared world",              "公开地图")

  -- Frases conversacionales adicionales de WoW
  add("qué nivel eres",             "what level are you",        "你几级了")
  add("cuánto tiempo llevas",       "how long have you played",  "玩多久了")
  add("eres nuevo",                 "are you new",               "你是新人")
  add("recién empecé",              "just started",              "刚开始玩")
  add("llevo mucho jugando",        "playing for a long time",   "玩很久了")
  add("primera vez aquí",           "first time here",           "第一次来")
  add("cuántas veces fuiste",       "how many times did you go", "去了几次")
  add("limpié el raid",             "cleared the raid",          "通关团本")
  add("primera vez raideando",      "first raid",                "第一次团本")
  add("qué personaje juegas",       "what class do you play",    "你玩什么职业")
  add("soy tank",                   "I am tank",                 "我是坦克")
  add("soy healer",                 "I am healer",               "我是治疗")
  add("soy dps",                    "I am dps",                  "我是输出")
  add("tengo buen equipo",          "I have good gear",          "我装备好")
  add("mi equipo es malo",          "my gear is bad",            "我装备差")
  add("necesito mejorar",           "need to improve",           "需要加强")
  add("tengo muy buen equipo",      "fully geared",              "装备齐了")
  add("quiero instanciar",          "want to dungeon",           "想跑副本")
  add("quiero raidear",             "want to raid",              "想跑团本")
  add("quiero pvpear",              "want to pvp",               "想打PVP")
  add("soy malo en pvp",            "bad at pvp",                "PVP很菜")
  add("soy bueno en pvp",           "good at pvp",               "PVP很强")
  add("dónde te dropeó",            "where did it drop",         "哪里掉落")
  add("me dropeo algo bueno",       "got a good drop",           "掉了好东西")
  add("nada útil",                  "nothing useful",            "没好东西")
  add("todo gris",                  "all grey",                  "全是垃圾")
  add("saqué algo raro",            "got a rare",                "掉了稀有")
  add("saqué un épico",             "got an epic",               "掉了史诗")
  add("actualicé",                  "upgraded",                  "升级了")
  add("mejoré mi equipo",           "gear upgrade",              "装备升级")

  -- Términos de chat de Turtle WoW específico
  add("turtle wow",                 "turtle wow",                "乌龟WOW")
  add("servidor turtle",            "turtle server",             "乌龟服")
  add("servidor privado",           "private server",            "私服")
  add("servidor personalizado",     "custom server",             "自定义服务器")
  add("parche personalizado",       "custom patch",              "自定义补丁")
  add("contenido nuevo",            "new content",               "新内容")
  add("zona nueva",                 "new zone",                  "新区域")
  add("mazmorra nueva",             "new dungeon",               "新副本")
  add("clase nueva",                "new class",                 "新职业")
  add("raza nueva",                 "new race",                  "新种族")
  add("en el parche",               "in the patch",              "在补丁里")
  add("próxima actualización",      "next update",               "下次更新")
  add("nota de parche",             "patch notes",               "补丁说明")
  add("cambio de balance",          "balance change",            "平衡调整")
  add("nerf",                       "nerf",                      "削弱")
  add("buff de parche",             "buff",                      "加强")
  add("servidor estable",           "stable server",             "服务器稳定")
  add("sin lag",                    "no lag",                    "不卡")
  add("muchos jugadores",           "many players",              "人很多")
  add("pocos jugadores",            "few players",               "人很少")
  add("servidor lleno",             "server full",               "服务器满了")
  add("cola de entrada",            "login queue",               "排队等待")

  -- Abreviaturas y términos numéricos en chat chino WoW
  add("10 de nivel",                "level 10",                  "10级")
  add("20 de nivel",                "level 20",                  "20级")
  add("30 de nivel",                "level 30",                  "30级")
  add("40 de nivel",                "level 40",                  "40级")
  add("50 de nivel",                "level 50",                  "50级")
  add("60 de nivel",                "level 60",                  "60级")
  add("nivel máximo",               "max level",                 "满级")
  add("personaje de nivel max",     "max level character",       "满级号")
  add("personaje nuevo",            "new character",             "新号")
  add("personaje de alt",           "alt character",             "小号")
  add("cuenta nueva",               "new account",               "新账号")
  add("10 monedas de oro",          "10 gold",                   "10金")
  add("100 monedas de oro",         "100 gold",                  "100金")
  add("1000 monedas de oro",        "1000 gold",                 "1000金")
  add("precio en oro",              "gold price",                "金币价格")
  add("sin dinero",                 "no money",                  "没金币")
  add("rico en juego",              "wealthy in game",           "土豪")
  add("donador",                    "donor",                     "充值玩家")
  add("sin pagar",                  "free to play",              "不花钱")
  add("versión gratuita",           "free version",              "免费版本")


  -- ============================================================
  -- V8 EXPANSION: MASSIVE DICTIONARY — BOSSES, RAIDS, NPCS, EMOTES
  -- ============================================================

  local v8_bosses_raids = {
    -- MC Bosses
    "鲁西弗隆|lucifron|lucifron",
    "玛格曼达|magmadar|magmadar",
    "基赫纳斯|gehennas|gehennas",
    "加尔|garr|garr",
    "沙斯拉尔男爵|baron geddon|barón geddon",
    "戈多斯男爵|baron geddon|barón geddon",
    "迦顿男爵|baron geddon|barón geddon",
    "沙斯拉尔|shazzrah|shazzrah",
    "萨弗隆先驱者|sulfuron harbinger|sulfuron presagista",
    "管理者埃克索图斯|majordomo executus|mayordomo ejecutus",
    "拉格纳罗斯|ragnaros|ragnaros",

    -- BWL Bosses
    "狂野的拉佐格尔|razorgore|razorgore",
    "堕落的瓦拉斯塔兹|vaelastrasz|vaelastrasz",
    "勒什雷尔|broodlord lashlayer|señor de la prole",
    "费尔默|firemaw|firemaw",
    "埃博诺克|ebonroc|ebonroc",
    "弗莱格尔|flamegor|flamegor",
    "克洛玛古斯|chromaggus|chromaggus",
    "奈法利安|nefarian|nefarian",

    -- AQ20 / AQ40 Bosses
    "库林纳克斯|kurinnaxx|kurinnaxx",
    "拉贾克斯将军|general rajaxx|general rajaxx",
    "莫阿姆|moam|moam",
    "布鲁|buru|buru",
    "无疤者奥斯里安|ossirian|ossirian",
    "斯克里德|skeram|skeram",
    "三虫|bug trio|trío de insectos",
    "沙尔图拉|sartura|sartura",
    "范克里斯|fankriss|fankriss",
    "哈霍兰公主|princess huhuran|princesa huhuran",
    "双子帝|twin emperors|emperadores gemelos",
    "克苏恩|c'thun|c'thun",
    "维希度斯|viscidus|viscidus",
    "奥罗|ouro|ouro",

    -- Naxx Bosses
    "阿努布雷坎|anub'rekhan|anub'rekhan",
    "寡妇|grand widow faerlina|gran viuda faerlina",
    "迈克斯纳|maexxna|maexxna",
    "瘟疫使者诺斯|noth the plaguebringer|noth el trae-plagas",
    "肮脏的希尔盖|heigan the unclean|heigan el impuro",
    "洛欧塞布|loatheb|loatheb",
    "教官拉苏维奥斯|instructor razuvious|instructor razuvious",
    "哥特里克|gothik the harvester|gothik el cosechador",
    "四骑士|four horsemen|cuatro jinetes",
    "帕奇维克|patchwerk|patchwerk",
    "格罗布鲁斯|grobbulus|grobbulus",
    "格拉斯|gluth|gluth",
    "塔迪乌斯|thaddius|thaddius",
    "萨菲隆|sapphiron|sapphiron",
    "克尔苏加德|kel'thuzad|kel'thuzad",

    -- ZG Bosses
    "高级祭司耶克里克|high priestess jeklik|suma sacerdotisa jeklik",
    "高级祭司温诺克西斯|venoxis|venoxis",
    "高级祭司玛尔里|mar'li|mar'li",
    "高级祭司赛卡尔|thekal|thekal",
    "高级祭司阿洛克|arlokk|arlokk",
    "哈卡|hakkar|hakkar",
    "血领主曼多基尔|mandokir|mandokir",
    "魔书者金度|jin'do|jin'do",

    -- Onyxia
    "奥妮克希亚|onyxia|onyxia",

    -- World Bosses
    "艾索雷葛斯|azuregos|azuregos",
    "卡扎克|lord kazzak|lord kazzak",
    "祖格大祭司|emerald dragons|dragones esmeralda",
    "莱索恩|lethon|lethon",
    "艾梦|emeriss|emeriss",
    "泰拉尔|taerar|taerar",
    "伊索德雷|ysondre|ysondre"
  }

  local v8_dungeon_bosses = {
    -- Deadmines
    "艾德温·范克里夫|edwin vancleef|edwin vancleef",
    "饥饿的斯尼德|sneed|sneed",
    "吉尔尼斯先生|mr. smite|sr. smite",

    -- Scarlet Monastery
    "审讯者费尔班克斯|interrogator vishas|interrogador vishas",
    "血色指挥官莫格莱尼|mograine|mograine",
    "大检察官怀特迈恩|whitemane|whitemane",
    "猎犬统领洛克希|loksey|loksey",
    "烈焰使者|herod|herodes",

    -- BRD
    "达格兰·索瑞森大帝|emperor dagran|emperador dagran",
    "弗诺斯将军|general angerforge|general angerforge",
    "审讯官格斯塔恩|high interrogator gerstahn|alto interrogador gerstahn",

    -- Stratholme
    "瑞文戴尔男爵|baron rivendare|barón rivendare",
    "巴纳扎尔|balnazzar|balnazzar",
    "奥蕾莉亚|aurius|aurius",

    -- Scholomance
    "加丁|gandling|gandling",
    "拉丝琳|ras frostwhisper|ras sususrro de escarcha",
    "詹德斯·巴罗夫|jandice barov|jandice barov",

    -- UBRS/LBRS
    "达基萨斯将军|general drakkisath|general drakkisath",
    "统领洛克|warchief rend|jefe de guerra rend",
    "皮匠|the beast|la bestia"
  }

  local v8_races_factions = {
    -- Razas
    "人类|human|humano",
    "矮人|dwarf|enano",
    "暗夜精灵|night elf|elfo de la noche",
    "侏儒|gnome|gnomo",
    "兽人|orc|orco",
    "亡灵|undead|no-muerto",
    "牛头人|tauren|tauren",
    "巨魔|troll|trol",
    "血精灵|blood elf|elfo de sangre",
    "高等精灵|high elf|alto elfo",
    "地精|goblin|goblin",

    -- Facciones
    "联盟|alliance|alianza",
    "部落|horde|horda",
    "银色黎明|argent dawn|alba argéntea",
    "塞纳里奥议会|cenarion circle|círculo cenarion",
    "木喉熊怪|timbermaw|fauces de madera",
    "瑟银兄弟会|thorium brotherhood|hermandad del torio",
    "冰冻之力|hydraxian waterlords|señores del agua de hydraxis",
    "荆棘谷渔夫|stv fishing|pesca stv",
    "赞达拉|zandalar|zandalar",
    "血帆海盗|bloodsail|vela sangrienta",
    "热砂港|steamwheedle|manivapor",
    "藏宝海湾|booty bay|bahía del botín",
    "加基森|gadgetzan|gadgetzan",
    "棘齿城|ratchet|trinquete",
    "永望镇|everlook|vistalegre"
  }

  local v8_verbs_grammar = {
    -- Verbos compuestos chinos de alta frecuencia
    "看看|look|mira",
    "试试|try|intenta",
    "说说|say|dime",
    "问问|ask|pregunta",
    "想想|think|piensa",
    "走走|walk|camina",
    "聊聊|chat|hablemos",
    "做做|do|haz",
    "讲讲|tell|cuéntame",
    "听听|listen|escucha",

    -- Negaciones y afirmaciones chinas
    "不行|no way|no se puede",
    "不要|don't|no",
    "不用|no need|no hace falta",
    "不是|not|no es",
    "可以|ok/can|se puede",
    "可能|maybe|quizás",
    "当然|of course|por supuesto",
    "一定|must|seguro",
    "如果|if|si",
    "但是|but|pero",
    "因为|because|porque",
    "所以|so/therefore|entonces",
    "虽然|although|aunque",
    "不过|however|sin embargo",
    "而且|moreover|además",
    "或者|or|o",
    "还是|or/still|o/todavía",

    -- Adverbios de tiempo
    "刚刚|just now|recién",
    "已经|already|ya",
    "还没|not yet|aún no",
    "快要|about to|a punto de",
    "一直|always|siempre",
    "从来|never|nunca",
    "经常|often|seguido",
    "偶尔|sometimes|a veces",
    "每天|every day|todos los días",
    "每次|every time|cada vez",
    "马上|right away|ahora mismo",
    "以后|after|después",
    "以前|before|antes",
    "最近|recently|últimamente",
    "昨天|yesterday|ayer",
    "前天|day before yesterday|antier",
    "后天|day after tomorrow|pasado mañana",
    "晚上|night|noche",
    "早上|morning|mañana",
    "下午|afternoon|tarde",
    "中午|noon|mediodía",

    -- Adjetivos de alta frecuencia
    "大|big|grande",
    "小|small|pequeño",
    "多|many|muchos",
    "少|few|pocos",
    "快|fast|rápido",
    "慢|slow|lento",
    "新|new|nuevo",
    "旧|old|viejo",
    "长|long|largo",
    "短|short|corto",
    "高|high/tall|alto",
    "低|low|bajo",
    "难|hard|difícil",
    "容易|easy|fácil",
    "远|far|lejos",
    "近|near|cerca",
    "贵|expensive|caro",
    "便宜|cheap|barato",
    "有用|useful|útil",
    "没用|useless|inútil",
    "重要|important|importante",
    "厉害|awesome|increíble",
    "无聊|boring|aburrido",
    "开心|happy|feliz",
    "生气|angry|enojado",
    "害怕|scared|asustado",
    "着急|anxious|ansioso",
    "安全|safe|seguro",
    "危险|dangerous|peligroso"
  }

  local v8_emotes_social = {
    -- Emotes y expresiones
    "哈哈|haha|jaja",
    "哈哈哈|hahaha|jajaja",
    "呵呵|hehe|jeje",
    "嘻嘻|hehe|jiji",
    "加油|go go|ánimo",
    "牛逼|awesome|increíble",
    "卧槽|omg|ostia",
    "我去|wow|guau",
    "我靠|omg|madre mía",
    "真的吗|really|en serio",
    "真的|really|de verdad",
    "假的|fake|falso",
    "是的|yes|sí",
    "不是|no|no",
    "好的|ok|vale",
    "算了|forget it|olvídalo",
    "随便|whatever|lo que sea",
    "没问题|no problem|sin problema",
    "谢谢|thanks|gracias",
    "不客气|you're welcome|de nada",
    "对不起|sorry|perdón",
    "没关系|it's ok|no pasa nada",
    "拜拜|bye bye|adiós",
    "再见|goodbye|adiós",
    "晚安|good night|buenas noches",
    "你好|hello|hola",
    "老板|boss|jefe",
    "同学|classmate|compañero",
    "兄弟们|brothers|hermanos",
    "大家|everyone|todos",
    "各位|everyone|señores",
    "帅哥|handsome guy|guapo",
    "美女|pretty girl|guapa",
    "小姐姐|miss/sis|señorita",
    "老哥|bro|compa",
    "老铁|buddy|compadre",
    "哥们|bro|colega",
    "伙计|dude|tío",
    "亲|dear|querido",
    "宝|babe|cariño",
    "老大|boss|jefe",
    "师傅|master|maestro"
  }

  local v8_numbers_misc = {
    -- Números
    "一|one|uno",
    "二|two|dos",
    "三|three|tres",
    "四|four|cuatro",
    "五|five|cinco",
    "六|six|seis",
    "七|seven|siete",
    "八|eight|ocho",
    "九|nine|nueve",
    "十|ten|diez",
    "百|hundred|cien",
    "千|thousand|mil",
    "万|ten thousand|diez mil",

    -- Direcciones
    "左|left|izquierda",
    "右|right|derecha",
    "前|front|adelante",
    "后面|behind|atrás",
    "上面|above|arriba",
    "下面|below|abajo",
    "这里|here|aquí",
    "那里|there|allí",
    "旁边|beside|al lado",
    "对面|opposite|enfrente",
    "中间|middle|en medio",
    "外面|outside|afuera",
    "里面|inside|adentro",

    -- Medidas y cantidades
    "一个|one|uno",
    "两个|two|dos",
    "三个|three|tres",
    "几个|some|algunos",
    "很多个|many|muchos",
    "第一|first|primero",
    "第二|second|segundo",
    "第三|third|tercero",
    "最后|last|último",
    "下一个|next|siguiente",
    "上一个|previous|anterior"
  }

  local v8_wow_specific = {
    -- WoW Raid Loot
    "分配|distribute|distribuir",
    "金团|gdkp|gdkp",
    "G团|gdkp|gdkp",
    "需求|need|necesidad",
    "贪婪|greed|codicia",
    "放弃|pass|pasar",
    "roll|roll|tirar",
    "暗杀|ninja|ninja",
    "毛|ninja|ninja loot",
    "换装|respec|re-equip",
    "专精|specialization|especialización",
    "天赋|talents|talentos",
    "重置|reset|reiniciar",
    "洗天赋|respec|resetear talentos",
    "洗点|respec|resetear talentos",
    "节点|node|nodo",
    "矿点|mining node|nodo de minería",
    "草点|herb node|nodo de hierba",
    "鱼点|fishing spot|spot de pesca",

    -- WoW Gear specific
    "装等|gear score|puntaje de equipo",
    "装备等级|item level|nivel de objeto",
    "最佳|best in slot|mejor en su slot",
    "散件|off-set|fuera de set",
    "附魔师|enchanter|encantador",
    "珠宝|gems|gemas",
    "附魔|enchant|encantamiento",
    "耐久|durability|durabilidad",
    "修理|repair|reparar",
    "修理费|repair cost|costo de reparación",

    -- Turtle WoW specific extras
    "幻化|transmog|transfiguración",
    "造型|appearance|apariencia",
    "外观|look|aspecto",
    "乌龟服|turtle server|server tortuga",
    "乌龟WOW|turtle wow|turtle wow",
    "自定义|custom|personalizado",
    "龟速|turtle speed|velocidad tortuga",
    "一命|hardcore|una vida",
    "硬核|hardcore|hardcore",
    "流浪模式|vagrant mode|modo vagabundo",
    "帐篷|tent|tienda de campaña",
    "生存|survival|supervivencia",
    "跨阵营|cross faction|facciones cruzadas",
    "双阵营|cross faction|cruzar facción",

    -- Abbreviations used in LFG
    "来T|need tank|falta tanque",
    "来奶|need healer|falta healer",
    "来DPS|need dps|falta dps",
    "满了|full|lleno",
    "缺人|need people|falta gente",
    "开组|forming|formando grupo",
    "组满|group full|grupo completo",
    "散了|disbanded|se disolvió",
    "上线|online|en línea",
    "下线|offline|desconectado",
    "挂机|afk|ausente",
    "回来|back|de vuelta",
    "出发|go|vamos",
    "集合|gather|reunirse",
    "门口|at entrance|en la entrada",
    "门口等|waiting at entrance|esperando en la entrada",
    "石头|meeting stone|piedra de encuentro",
    "飞过去|fly there|volar allá",
    "跑过去|run there|correr allá",
    "传送|teleport|teletransporte",
    "开门|open portal|abrir portal",
    "点门|click portal|click portal"
  }

  load_batch_zh_en_es(v8_bosses_raids)
  load_batch_zh_en_es(v8_dungeon_bosses)
  load_batch_zh_en_es(v8_races_factions)
  load_batch_zh_en_es(v8_verbs_grammar)
  load_batch_zh_en_es(v8_emotes_social)
  load_batch_zh_en_es(v8_numbers_misc)
  load_batch_zh_en_es(v8_wow_specific)


  -- ============================================================
  -- RESCUED FROM ORPHANED BATCHES (V4-V7) — NOW INSIDE MODULE SCOPE
  -- These were previously outside end) and silently broken
  -- ============================================================
  add("guerrero", "warrior", "战")
  add("guerrero", "warrior", "战士")
  add("mago", "mage", "法")
  add("mago", "mage", "法师")
  add("sacerdote", "priest", "牧")
  add("sacerdote", "priest", "牧师")
  add("pícaro", "rogue", "贼")
  add("pícaro", "rogue", "潜行者")
  add("cazador", "hunter", "猎")
  add("cazador", "hunter", "猎人")
  add("druida", "druid", "德")
  add("druida", "druid", "小德")
  add("druida", "druid", "德鲁伊")
  add("brujo", "warlock", "术")
  add("brujo", "warlock", "术士")
  add("chamán", "shaman", "萨")
  add("chamán", "shaman", "萨满")
  add("paladín", "paladin", "骑")
  add("paladín", "paladin", "骑士")
  add("protección", "prot", "防")
  add("healer", "heal", "奶")
  add("reprensión", "ret", "惩戒")
  add("furia", "fury", "狂暴")
  add("sombras", "shadow", "暗牧")
  add("fuego", "fire", "火法")
  add("escarcha", "frost", "冰法")
  add("lamentos", "wc", "哀嚎")
  add("minas", "dm", "死矿")
  add("castillo oscuro", "sfk", "影牙")
  add("profundidades", "brd", "深渊")
  add("monasterio", "sm", "血色")
  add("rajamanto", "rfk", "剃刀")
  add("zarcas", "rfd", "高地")
  add("maraudon", "mara", "玛拉顿")
  add("templo", "st", "神庙")
  add("cumbre", "brs", "黑石")
  add("la masacre", "dm", "厄运")
  add("scholomance", "scholo", "通灵")
  add("stratholme", "strat", "斯坦索姆")
  add("zul'gurub", "zg", "祖格")
  add("ruinas", "aq20", "废墟")
  add("guarida de alanegra", "bwl", "黑翼")
  add("onyxia", "ony", "黑龙")
  add("hacer/pegar", "do/hit", "打")
  add("matar", "kill", "杀")
  add("ir", "go", "去")
  add("venir", "come", "来")
  add("dar", "give", "给")
  add("comprar", "buy", "买")
  add("vender", "sell", "卖")
  add("entrar", "enter", "进")
  add("salir", "leave", "退")
  add("esperar", "wait", "等")
  add("invitar", "invite", "组")
  add("comerciar", "trade", "交易")
  add("ayudar", "help", "帮忙")
  add("misión", "quest", "任务")
  add("subir de nivel", "level up", "升级")
  add("resucitar", "resurrect", "复活")
  add("invocar", "summon", "拉")
  add("correr", "run", "跑")
  add("morir", "die", "死")
  add("wipear", "wipe", "灭")
  add("abrir/empezar", "open/start", "开")
  add("yo", "i", "我")
  add("tú", "you", "你")
  add("él", "he", "他")
  add("ella", "she", "她")
  add("nosotros", "we", "我们")
  add("ustedes", "you", "你们")
  add("ellos", "they", "他们")
  add("hermano", "brother", "兄弟")
  add("pro", "pro", "大佬")
  add("noob", "noob", "菜鸟")
  add("chica", "girl", "妹子")
  add("esposa", "wife", "老婆")
  add("amigo", "friend", "朋友")
  add("gente", "people", "人")
  add("cómo", "how", "怎么")
  add("dónde", "where", "哪里")
  add("cuánto", "how much", "多少")
  add("por qué", "why", "为什么")
  add("qué", "what", "什么")
  add("cuándo", "when", "什么时候")
  add("quién", "who", "谁")
  add("ahora", "now", "现在")
  add("luego", "later", "等下")
  add("hoy", "today", "今天")
  add("mañana", "tomorrow", "明天")
  add("mucho", "a lot", "很多")
  add("un poco", "a little", "一点")
  add("todo", "all", "全部")
  add("nada", "none", "没有")
  add("sí/correcto", "yes/right", "对")
  add("equivocado", "wrong", "错")
  add("bien/ok", "good/ok", "好")
  add("mal/no", "bad/no", "不好")
  add("tortuga", "turtle", "乌龟")
  add("doble recolección", "double gathering", "双采")
  add("caparazón", "turtle shell", "龟壳")
  add("tienda", "tent", "帐篷")
  add("cola", "queue", "排队")
  add("facciones cruzadas", "crossfaction", "跨阵营")
  add("alianza", "alliance", "联盟")
  add("horda", "horde", "部落")
  add("tanque", "tank", "坦克")
  add("sanador", "healer", "治疗")
  add("dps", "dps", "输出")
  add("líder", "leader", "队长")
  add("oro", "gold", "金币")
  add("subasta", "ah", "拍卖行")
  add("banco", "bank", "银行")
  add("hermandad", "guild", "公会")
  add("canal", "channel", "频道")
  add("addon", "addon", "插件")
  add("kalimdor", "kalimdor", "卡利姆多")
  add("reinos del este", "eastern kingdoms", "东部王国")
  add("azeroth", "azeroth", "艾泽拉斯")
  add("ventormenta", "stormwind", "暴风城")
  add("forjaz", "ironforge", "铁炉堡")
  add("darnassus", "darnassus", "达纳苏斯")
  add("orgrimmar", "orgrimmar", "奥格瑞玛")
  add("cima del trueno", "thunder bluff", "雷霆崖")
  add("entrañas", "undercity", "幽暗城")
  add("bosque de elwynn", "elwynn forest", "艾尔文森林")
  add("dun morogh", "dun morogh", "丹莫罗")
  add("claros de tirisfal", "tirisfal glades", "提瑞斯法林地")
  add("loch modan", "loch modan", "洛克莫丹")
  add("bosque de argénteos", "silverpine forest", "银松森林")
  add("páramos de poniente", "westfall", "西部荒野")
  add("montañas crestagrana", "redridge mountains", "赤脊山")
  add("bosque del ocaso", "duskwood", "暮色森林")
  add("laderas de trabacolina", "hillsbrad foothills", "希尔斯布莱德丘陵")
  add("los humedales", "wetlands", "湿地")
  add("montañas de alterac", "alterac mountains", "奥特兰克山脉")
  add("tierras altas de arathi", "arathi highlands", "阿拉希高地")
  add("vega de tuercespina", "stranglethorn vale", "荆棘谷")
  add("tierras inhóspitas", "badlands", "荒芜之地")
  add("pantano de las penas", "swamp of sorrows", "悲伤沼泽")
  add("tierras del interior", "the hinterlands", "辛特兰")
  add("garganta de fuego", "searing gorge", "灼热峡谷")
  add("las estepas ardientes", "burning steppes", "燃烧平原")
  add("tierras de la peste del oeste", "western plaguelands", "西瘟疫之地")
  add("tierras de la peste del este", "eastern plaguelands", "东瘟疫之地")
  add("paso de la muerte", "deadwind pass", "逆风小径")
  add("las tierras devastadas", "blasted lands", "诅咒之地")
  add("durotar", "durotar", "杜隆塔尔")
  add("mulgore", "mulgore", "莫高雷")
  add("teldrassil", "teldrassil", "泰达希尔")
  add("costa oscura", "darkshore", "黑海岸")
  add("los baldíos", "the barrens", "贫瘠之地")
  add("sierra espolón", "stonetalon mountains", "石爪山脉")
  add("vallefresno", "ashenvale", "灰谷")
  add("las mil agujas", "thousand needles", "千针石林")
  add("desolace", "desolace", "凄凉之地")
  add("marjal revolcafango", "dustwallow marsh", "尘泥沼泽")
  add("feralas", "feralas", "菲拉斯")
  add("tanaris", "tanaris", "塔纳利斯")
  add("azshara", "azshara", "艾萨拉")
  add("cráter de un'goro", "un'goro crater", "安戈洛环形山")
  add("frondavil", "felwood", "费伍德森林")
  add("cuna del invierno", "winterspring", "冬泉谷")
  add("silithus", "silithus", "希利苏斯")
  add("monte hyjal", "mount hyjal", "海加尔山")
  add("claro de la luna", "moonglade", "月光林地")
  add("alquimia", "alchemy", "炼金术")
  add("alquimia", "alchemy", "炼金")
  add("herrería", "blacksmithing", "锻造")
  add("encantamiento", "enchanting", "附魔")
  add("ingeniería", "engineering", "工程学")
  add("ingeniería", "engineering", "工程")
  add("herboristería", "herbalism", "草药学")
  add("herboristería", "herbalism", "采药")
  add("peletería", "leatherworking", "制皮")
  add("minería", "mining", "采矿")
  add("desuello", "skinning", "剥皮")
  add("sastrería", "tailoring", "裁缝")
  add("cocina", "cooking", "烹饪")
  add("pesca", "fishing", "钓鱼")
  add("primeros auxilios", "first aid", "急救")
  add("equitación", "riding", "骑术")
  add("loto negro", "black lotus", "黑莲花")
  add("cristal arcano", "arcane crystal", "奥术水晶")
  add("barra de arcanita", "arcanite bar", "奥金锭")
  add("orbe de rectitud", "righteous orb", "正义宝珠")
  add("paño rúnico", "runecloth", "符文布")
  add("paño de tejido mágico", "mageweave cloth", "魔纹布")
  add("paño de seda", "silk cloth", "丝绸")
  add("paño de lana", "wool cloth", "毛料")
  add("paño de lino", "linen cloth", "亚麻布")
  add("mena de torio", "thorium ore", "瑟银矿石")
  add("mena de mitril", "mithril ore", "秘银矿石")
  add("mena de hierro", "iron ore", "铁矿石")
  add("mena de cobre", "copper ore", "铜矿石")
  add("mena de estaño", "tin ore", "锡矿石")
  add("piedra burda", "rough stone", "劣质的石头")
  add("piedra burda", "rough stone", "劣质石头")
  add("piedra basta", "coarse stone", "粗糙的石头")
  add("piedra basta", "coarse stone", "粗糙石头")
  add("piedra pesada", "heavy stone", "沉重的石头")
  add("piedra pesada", "heavy stone", "沉重石头")
  add("piedra sólida", "solid stone", "坚固的石头")
  add("piedra sólida", "solid stone", "坚固石头")
  add("piedra densa", "dense stone", "致密的石头")
  add("piedra densa", "dense stone", "致密石头")
  add("ojo de tigre", "tigerseye", "虎眼石")
  add("malaquita", "malachite", "孔雀石")
  add("pellejo ligero", "light hide", "轻型毛皮")
  add("pellejo ligero", "light hide", "轻毛皮")
  add("pellejo medio", "medium hide", "中型毛皮")
  add("pellejo medio", "medium hide", "中毛皮")
  add("pellejo pesado", "heavy hide", "重型毛皮")
  add("pellejo pesado", "heavy hide", "重毛皮")
  add("pellejo grueso", "thick hide", "厚重毛皮")
  add("pellejo basto", "rugged hide", "粗糙毛皮")
  add("pellejo", "hide", "毛皮")
  add("cuero", "leather", "皮")
  add("cuero ligero", "light leather", "轻皮")
  add("cuero medio", "medium leather", "中皮")
  add("cuero pesado", "heavy leather", "重皮")
  add("cuero grueso", "thick leather", "厚皮")
  add("cuero basto", "rugged leather", "硬甲皮")
  add("cuero de demosaurio", "devilsaur leather", "魔暴龙皮")
  add("esencia de tierra", "essence of earth", "大地精华")
  add("esencia de agua", "essence of water", "水之精华")
  add("esencia de fuego", "essence of fire", "火焰精华")
  add("esencia de aire", "essence of air", "空气精华")
  add("esencia de no-muerto", "essence of undeath", "死灵精华")
  add("esencia de vida", "essence of life", "生命精华")
  add("fragmento luminoso grande", "large brilliant shard", "大块魔光碎片")
  add("fragmento luminoso pequeño", "small brilliant shard", "小块魔光碎片")
  add("esencia eterna superior", "greater eternal essence", "强效不灭精华")
  add("esencia eterna inferior", "lesser eternal essence", "次级不灭精华")
  add("polvo de ilusión", "illusion dust", "幻影之尘")
  add("polvo de los sueños", "dream dust", "梦境之尘")
  add("poción de sanación sublime", "major healing potion", "极效治疗药水")
  add("poción de maná sublime", "major mana potion", "极效法力药水")
  add("elixir de la mangosta", "elixir of the mongoose", "猫鼬药剂")
  add("elixir arcano superior", "greater arcane elixir", "强效奥法药剂")
  add("elixir de poder de fuego superior", "elixir of greater firepower", "强效火力药剂")
  add("elixir de poder de las sombras", "elixir of shadow power", "暗影之力药剂")
  add("elixir de entereza", "elixir of fortitude", "坚韧药剂")
  add("elixir de gigantes", "elixir of giants", "巨人药剂")
  add("elixir de agilidad superior", "elixir of greater agility", "强效敏捷药剂")
  add("poción de sangre de mago", "mageblood potion", "魔血药剂")
  add("poción de acción libre", "free action potion", "自由行动药水")
  add("poción de acción viva", "living action potion", "活力行动药水")
  add("poción de invulnerabilidad limitada", "limited invulnerability potion", "有限无敌药水")
  add("frasco de petrificación", "flask of petrification", "化石药水")
  add("frasco de los titanes", "flask of the titans", "泰坦合剂")
  add("frasco de sabiduría destilada", "flask of distilled wisdom", "精炼智慧合剂")
  add("frasco de poder supremo", "flask of supreme power", "超级能量合剂")
  add("frasco de resistencia cromática", "flask of chromatic resistance", "多重抗性合剂")
  add("bufos de mundo", "world buffs", "世界buff")
  add("bufo de onyxia", "onyxia buff", "龙头")
  add("bufo de hakkar", "hakkar buff", "哈卡")
  add("flor cantarina", "songflower", "轻歌花")
  add("bufos de la masacre", "dire maul buffs", "厄运buff")
  add("feria de la luna negra", "darkmoon faire", "马戏团")
  add("cenarion", "cenarion", "塞纳里奥")
  add("alba argéntea", "argent dawn", "银色黎明")
  add("bastión fauces de madera", "timbermaw hold", "木喉要塞")
  add("zandalar", "zandalar", "赞达拉")
  add("crítico", "crit", "暴击")
  add("esquivar", "dodge", "躲闪")
  add("parar", "parry", "招架")
  add("bloquear", "block", "格挡")
  add("fallo", "miss", "未击中")
  add("resistir", "resist", "抵抗")
  add("inmune", "immune", "免疫")
  add("armadura", "armor", "护甲")
  add("poder de ataque", "attack power", "攻击强度")
  add("ap", "ap", "攻强")
  add("poder de hechizos", "spell power", "法术强度")
  add("sp", "sp", "法强")
  add("sanación", "healing", "治疗量")
  add("mp5", "mp5", "五回")
  add("golpe", "hit", "命中")
  add("amenaza/aggro", "threat/aggro", "仇恨")
  add("oom/sin maná", "oom", "没蓝")
  add("ausente", "afk", "暂离")
  add("pullear", "pull", "拉怪")
  add("add", "add", "ADD")
  add("kitear", "kite", "风筝")
  add("oveja", "sheep", "羊")
  add("porrazo", "sap", "闷棍")
  add("miedo", "fear", "恐惧")
  add("nova", "nova", "冰环")
  add("ceguera", "blind", "致盲")
  add("cargar", "charge", "冲锋")
  add("interceptar", "intercept", "拦截")
  add("cubo de hielo", "ice block", "冰箱")
  add("pompa", "bubble/immune", "无敌")
  add("provocar", "taunt", "嘲讽")
  add("interrumpir", "interrupt", "打断")
  add("disipar", "dispel", "驱散")
  add("curar veneno", "cure poison", "解毒")
  add("quitar maldición", "remove curse", "解诅咒")
  add("resucitar", "rez", "复活")
  add("rez en combate", "combat rez", "战复")
  add("piedra de alma", "soulstone", "灵魂石")
  add("piedra de salud", "healthstone", "糖")
  add("invocar", "summon", "拉人")
  add("cabeza", "head", "头盔")
  add("cuello", "neck", "项链")
  add("hombros", "shoulder", "肩膀")
  add("capa", "cloak", "披风")
  add("pecho", "chest", "衣服")
  add("pecho", "chest", "胸甲")
  add("muñecas", "wrist", "护腕")
  add("manos", "hands", "手套")
  add("cintura", "waist", "腰带")
  add("piernas", "legs", "裤子")
  add("piernas", "legs", "腿甲")
  add("pies", "feet", "鞋子")
  add("pies", "feet", "靴子")
  add("anillo", "ring", "戒指")
  add("abalorio", "trinket", "饰品")
  add("mano principal", "main hand", "主手")
  add("mano izquierda", "off hand", "副手")
  add("dos manos", "two hand", "双手")
  add("a distancia", "ranged", "远程")
  add("varita", "wand", "魔杖")
  add("escudo", "shield", "盾牌")
  add("arma", "weapon", "武器")
  add("pobre", "poor", "灰色")
  add("común", "common", "白色")
  add("poco común", "uncommon", "绿色")
  add("raro", "rare", "蓝色")
  add("épico", "epic", "紫色")
  add("legendario", "legendary", "橙色")
  add("legendario", "legendary", "传说")
  add("tier/set", "tier/set", "套装")
  add("bis", "bis", "毕业")
  add("bis", "bis", "极品")
  add("necesidad", "need", "需求")
  add("codicia", "greed", "贪婪")
  add("pasar", "pass", "放弃")
  add("ninja", "ninja", "全需")
  add("mala suerte", "bad luck", "黑手")
  add("buena suerte", "good luck", "红手")
  add("cosas", "things", "东西") -- Evita que se traduzca como "este oeste"
  add("bot", "bot", "机器人") -- Evita que se traduzca como "máquina gente"
  add("beneficio", "benefit", "好处")
  add("vagabundo", "vagrant", "流浪")
  add("ilusión", "floating cloud", "浮云")
  add("estafador", "scammer", "奸商")
  add("niños", "children", "儿童")
  add("devolver", "return", "退货")
  add("volver a la ciudad", "hearth", "回城")
  add("qué", "what", "啥")
  add("el más", "most", "最")
  add("demasiado", "too", "太")
  add("además", "also", "又")
  add("primero", "first", "先")
  add("tiene que", "must", "得")
  add("en", "in", "里")
  add("terminado", "finish", "完")
  add("originalmente", "original", "原")
  add("seguro", "definitely", "肯定")
  add("elegir", "choose", "选")
  add("olvidar", "forget", "忘")
  add("levelear", "level", "练")
  add("subir", "rise", "涨")
  add("hacer cola", "queue", "排")
  add("conseguir", "get", "弄个")
  add("fichas", "tokens", "代币")
  add("recompensa", "reward", "奖励")
  add("banco", "bank", "仓库")
  add("sugerencia", "suggest", "建议")
  add("momento", "time", "时候")
  add("cuando", "when", "的时候")
  add("qué hacer", "what to do", "怎么办")
  add("personaje", "alt", "号")
  add("se busca", "wanted", "通缉")
  add("elfo", "elf", "精")
  add("alto elfo", "high elf", "高等精灵")
  add("jefe", "boss", "佬")
  add("pro", "pro", "大佬")
  add("sin censura", "uncensored", "高清无马")
  add("hd", "hd", "高清")
  add("joder", "wtf/damn", "尼玛")
  add("maldición", "damn it", "TNND")
  add("qué pasa", "what happened", "怎么回事")
  add("significado", "meaning", "意思")
  add("sombras y ruina", "shadow-ruin", "暗毁") -- Spec de Brujo
  add("intendente", "quartermaster", "军需官")
  add("entregar", "turn in", "交")
  add("casillas", "slots", "格")
  add("materiales", "materials", "材料")
  add("amani", "amani", "阿曼尼")
  add("parche", "patch/version", "版本")
  add("demonio", "demonology", "恶魔")
  add("normal", "normal", "普通")
  add("manual", "manual", "手册")
  add("palabra clave", "keyword", "关键词")
  add("la próxima vez", "next time", "下次")
  add("mucho tiempo", "long time", "久")
  add("después", "after/later", "后")
  add("primera vez", "first time", "首次")
  add("dónde", "where", "哪")
  add("oportunidad", "chance", "机会")
  add("básicamente", "basically", "基本")
  add("juntar", "gather all", "凑齐")
  add("solo", "solo", "单")
  add("inicio", "start", "开局")
  add("especial", "special", "特殊")
  add("oh", "oh", "哦")
  add("parece", "seems", "好像")
  add("parece", "like", "像")
  add("cambio", "change", "变化")
  add("asunto", "matter", "回事")
  add("sabe", "knows/can", "会")
  add("nombrar", "name", "取名")
  add("debería", "should", "应该")
  add("no poder juntar", "cannot gather", "凑不齐")
  add("fragmento brillante", "glowing shard", "发光碎片")
  add("macro de invitar", "invite macro", "加人宏")
  add("invitar gente", "invite people", "加人")
  add("solo para probar", "just testing", "意思一下")
  add("revantusk", "revantusk", "恶齿")
  add("revantusk", "revantusk", "鹅翅") -- Typo común de los chinos por "alitas de ganso"
  add("frustrado", "frustrated", "压抑")
  add("volverse loco", "go crazy", "发疯")
  add("volverse loco", "go crazy", "加疯") -- Typo de 發瘋
  add("mascota", "pet", "宝宝")
  add("juntar", "gather", "凑")
  add("fragmento", "shard", "碎片")
  add("configuración", "settings", "设置")
  add("sin cambiar", "unchanged", "没改")
  add("cambiar", "change", "改")
  add("El Castillo de la Tempestad", "tempest keep", "风暴要塞")
  add("Valle Frostmane", "frostmane valley", "霜鬃谷")
  add("Frostmane", "frostmane", "霜鬃")
  add("anillo", "ring", "戒指")
  add("anillo de", "ring of", "之戒")
  add("cinturón", "belt", "腰带")
  add("solo", "just", "只是")
  add("usar", "use", "用")
  add("abrir", "open", "打开")
  add("juego", "game", "游戏")
  add("acelerador de ping", "booster/vpn", "加速器")
  add("diferente", "different", "不同")
  add("no puede", "cannot", "不能")
  add("paladín", "paladin", "骑士")
  add("invocar", "summon", "召唤")
  add("invocación grupal", "mass summon", "群召唤")
  add("doble especialización", "dual spec", "双技能")
  add("doble especialización", "dual spec", "双天赋")
  add("doble", "double", "双")
  add("habilidad", "skill", "技能")
  add("sería mejor", "might as well", "还不如")
  add("entonces", "then", "那")
  add("herboristería", "herbalism", "采花")
  add("desencantar", "disenchant", "分解")
  add("Paladín Protección", "prot paladin", "防骑")
  add("Paladín Sagrado", "holy paladin", "奶骑")
  add("Paladín Reprensión", "ret paladin", "惩戒骑")
  add("Guerrero Furia", "fury warrior", "狂暴战")
  add("Guerrero Protección", "prot warrior", "防战")
  add("Guerrero Armas", "arms warrior", "武器战")
  add("Sacerdote Sombras", "shadow priest", "暗牧")
  add("Sacerdote Sagrado", "holy priest", "神牧")
  add("Sacerdote Disciplina", "disc priest", "戒律牧")
  add("Druida Restauración", "resto druid", "奶德")
  add("Druida Feral", "feral druid", "野德")
  add("Druida Guardián", "guardian druid", "熊德")
  add("Druida Equilibrio", "balance druid", "鸟德")
  add("Lechúcico", "moonkin", "咕咕")
  add("Cazador Bestias", "bm hunter", "兽王猎")
  add("Cazador Puntería", "mm hunter", "射击猎")
  add("Cazador Supervivencia", "survival hunter", "生存猎")
  add("Pícaro Combate", "combat rogue", "战斗贼")
  add("Pícaro Asesinato", "assassination rogue", "刺杀贼")
  add("Pícaro Sutileza", "subtlety rogue", "敏锐贼")
  add("Mago Escarcha", "frost mage", "冰法")
  add("Mago Fuego", "fire mage", "火法")
  add("Mago Arcano", "arcane mage", "奥法")
  add("Brujo Aflicción", "affliction warlock", "痛苦术")
  add("Brujo Destrucción", "destruction warlock", "毁灭术")
  add("Brujo Demonología", "demonology warlock", "恶魔术")
  add("Chamán Elemental", "ele shaman", "元素萨")
  add("Chamán Mejora", "enh shaman", "增强萨")
  add("Chamán Restauración", "resto shaman", "奶萨")
  add("Chamán Restauración", "resto shaman", "恢复萨")


  -- ============================================================
  -- V9 EXPANSION: COLOSSAL BATCHES (TBC ZONES, TBC DUNGEONS, STATS, HSK 1-3)
  -- ============================================================
    local v9_hsk_intermediate_4 = {
    "安全|safe|seguro",
    "按时|on time|a tiempo",
    "按照|according to|según",
    "百分之|percent|por ciento",
    "棒|wonderful|estupendo",
    "包子|steamed bun|bollo al vapor",
    "保护|protect|proteger",
    "保证|guarantee|garantizar",
    "报道|report|informar",
    "报名|sign up|inscribirse",
    "抱歉|sorry|lo siento/disculpa",
    "倍|times|veces/doble",
    "本来|originally|originalmente",
    "笨|stupid|tonto/torpe",
    "比如|for example|por ejemplo",
    "毕业|graduate|graduarse",
    "遍|times|veces",
    "标准|standard|estándar",
    "表格|form|formulario",
    "表示|express|expresar",
    "表演|perform|actuar/representar",
    "表扬|praise|elogiar/alabar",
    "饼干|biscuit|galleta",
    "并且|and/also|y además",
    "博士|doctor (phd)|doctor",
    "不得不|have to|no tener más remedio que",
    "不管|no matter|no importar",
    "不过|however|sin embargo",
    "不仅|not only|no solo",
    "部分|part|parte",
    "擦|wipe|limpiar/frotar",
    "猜|guess|adivinar",
    "材料|material|material",
    "参观|visit|visitar",
    "差不多|almost|casi",
    "长城|great wall|gran muralla",
    "长江|yangtze river|río yangtsé",
    "尝|taste|probar",
    "场|field/match|campo/partido",
    "超过|exceed|superar",
    "成功|successful|exitoso",
    "诚实|honest|honesto",
    "成熟|mature|maduro",
    "成为|become|convertirse en",
    "乘坐|ride|tomar (transporte)",
    "吃惊|surprised|sorprendido",
    "重新|again|de nuevo",
    "抽烟|smoke|fumar",
    "出差|business trip|viaje de negocios",
  }

  local v9_hsk_intermediate_5 = {
    "出发|depart|partir/salir",
    "出生|born|nacer",
    "出现|appear|aparecer",
    "消息|news|noticias",
    "意见|opinion|opinión",
    "注意|pay attention|prestar atención",
    "准备|prepare|preparar",
    "准确|accurate|preciso",
    "自己|myself|uno mismo",
    "总是|always|siempre",
    "总统|president|presidente",
    "租|rent|alquilar",
    "最好|had better|mejor/lo mejor es",
    "最后|final|finalmente",
    "尊重|respect|respetar",
    "左右|around|alrededor de",
    "作家|writer|autor/escritor",
    "作用|effect|efecto/función",
    "作者|author|autor",
    "座位|seat|asiento",
    "申请|apply|solicitar",
    "使|make|hacer/causar",
    "世纪|century|siglo",
    "世界|world|mundo",
    "市场|market|mercado",
    "适合|suit|adecuado/adaptarse",
    "世纪|century|siglo",
    "收|receive|recibir",
    "收入|income|ingresos",
    "收拾|tidy up|ordenar",
    "首都|capital|capital",
    "首先|first|primero/en primer lugar",
    "受不了|unbearable|insoportable",
    "受到|receive|recibir/sufrir",
    "售货员|salesperson|vendedor",
    "输|lose|perder",
    "熟悉|familiar|familiarizarse",
    "数量|quantity|cantidad",
    "数字|number|número",
    "帅|handsome|guapo",
    "顺便|by the way|de paso",
    "顺利|smoothly|exitosamente",
    "顺序|order|orden/secuencia",
    "说明|explain|explicar",
    "硕士|master|maestría/máster",
    "死|die|morir",
    "速度|speed|velocidad",
    "塑料袋|plastic bag|bolsa de plástico",
    "酸|sour|ácido",
    "算|calculate|calcular",
  }

  local v9_hsk_advanced_1 = {
    "唉|sigh|ay/uf",
    "爱护|take good care of|cuidar",
    "爱惜|treasure|valorar",
    "爱心|love/compassion|amor/compasión",
    "安静|quiet|tranquilo",
    "安排|arrange|organizar",
    "安全|security|seguridad",
    "安慰|comfort|consolar",
    "安装|install|instalar",
    "岸|shore|orilla",
    "暗|dark|oscuro",
    "按|press|presionar",
    "把握|grasp|agarrar/sostener",
    "白菜|cabbage|col/repollo",
    "班主任|class teacher|tutor",
    "半夜|midnight|medianoche",
    "棒|wonderful|fantástico",
    "包裹|package|paquete",
    "包含|contain|contener",
    "包括|include|incluir",
    "薄|thin|delgado",
    "宝贝|baby/treasure|tesoro/bebé",
    "宝贵|valuable|valioso",
    "保持|maintain|mantener",
    "保存|save|guardar/conservar",
    "保护|protect|proteger",
    "保留|reserve|reservar/conservar",
    "保险|insurance|seguro",
    "保证|guarantee|garantizar",
    "抱|hug|abrazar",
    "抱歉|sorry|lo siento",
    "报道|report|informar",
    "报告|report|reportar",
    "报名|sign up|inscribirse",
    "悲观|pessimistic|pesimista",
    "背景|background|fondo",
    "被子|quilt|manta/edredón",
    "本领|ability|habilidad/capacidad",
    "本质|essence|esencia",
    "比例|proportion|proporción",
    "彼此|each other|el uno al otro",
    "必然|inevitable|inevitable",
    "必要|necessary|necesario",
    "毕竟|after all|después de todo",
    "避免|avoid|evitar",
    "编辑|editor|editor/editar",
    "鞭炮|firecrackers|petardos",
    "便|then/easy|entonces/fácil",
    "辩论|debate|debatir",
    "标点|punctuation|puntuación",
  }

  local v9_hsk_advanced_2 = {
    "哪怕|even if|incluso si",
    "内科|internal medicine|medicina interna",
    "嫩|tender|tierno",
    "能干|capable|capaz",
    "能量|energy|energía",
    "泥土|soil|tierra/barro",
    "年代|era|década/era",
    "年纪|age|edad",
    "年轻|young|joven",
    "念|read aloud|leer en voz alta",
    "宁可|would rather|preferir",
    "牛仔裤|jeans|vaqueros",
    "浓|dense|espeso/concentrado",
    "农村|countryside|campo/zona rural",
    "农产品|agricultural products|productos agrícolas",
    "农业|agriculture|agricultura",
    "弄|do/manage|hacer/manejar",
    "暖和|warm|cálido",
    "偶然|accidental|accidental",
    "爬山|climb mountain|escalar montaña",
    "拍|clap/shoot|aplaudir/grabar",
    "排队|queue|hacer cola",
    "排列|arrange|ordenar",
    "排球|volleyball|voleibol",
    "派|send|enviar",
    "盼望|look forward to|anhelar",
    "赔偿|compensate|compensar",
    "培养|cultivate|cultivar/criar",
    "佩服|admire|admirar",
    "配合|cooperate|cooperar/coordinar",
    "盆|basin/pot|maceta/palangana",
    "碰|touch/meet|tocar/chocar",
    "披|drape|cubrirse",
    "批|approve|aprobar/lote",
    "批准|approve|aprobar",
    "皮鞋|leather shoes|zapatos de cuero",
    "啤酒|beer|cerveza",
    "疲劳|fatigue|fatiga/cansancio",
    "脾气|temper|temperamento/carácter",
    "偏|leaning|sesgado",
    "偏差|deviation|desviación",
    "偏见|prejudice|prejuicio",
    "便宜|cheap|barato",
    "骗|cheat|engañar",
    "骗子|cheat/liar|mentiroso/estafador",
    "片|slice|rebanada/trozo",
    "片面|one-sided|unilateral",
    "飘|float|flotar/ondear",
    "拼搏|struggle|luchar",
    "拼音|pinyin|pinyin",
  }

  local v9_wow_factions_cities = {
    "联盟|alliance|alianza",
    "部落|horde|horda",
    "奥格瑞玛|orgrimmar|orgrimmar",
    "暴风城|stormwind|ventormenta",
    "铁炉堡|ironforge|forjadhierro",
    "幽暗城|undercity|entrañas",
    "雷霆崖|thunder bluff|cima del trueno",
    "达纳苏斯|darnassus|darnassus",
    "埃索达|exodar|exodar",
    "银月城|silvermoon|ciudad de lunargenta",
    "暴风城地牢|stormwind stockade|mazmorra de ventormenta",
    "塞纳里奥议会|cenarion circle|círculo cenarion",
    "银色黎明|argent dawn|alba argenta",
    "水之协力|hydraxian waterlords|señores del agua de hydraxis",
    "瑟银兄弟会|thorium brotherhood|hermandad del torio",
    "木喉要塞|timbermaw hold|bastión de fauces de madera",
    "吉尔吉斯半人马|gelkis centaur|centauros gelkis",
    "马格拉姆半人马|magram centaur|centauros magram",
    "诺兹多姆的子嗣|brood of nozdomu|linaje de nozdomu",
    "拉文霍德|ravenholdt|ravenholdt",
    "辛德拉|shen'dralar|shen'dralar",
  }

  local v9_wow_expansions_continents = {
    "卡利姆多|kalimdor|kalimdor",
    "东部王国|eastern kingdoms|reinos del este",
    "外域|outland|terracallende",
    "诺森德|northrend|rasganorte",
    "潘达利亚|pandaria|pandaria",
    "德拉诺|draenor|draenor",
    "破碎群岛|broken isles|islas quebradas",
    "阿古斯|argus|argus",
    "赞达拉|zandalar|zandalar",
    "库尔提拉斯|kul tiras|kul tiras",
    "暗影界|shadowlands|tierras sombrías",
    "巨龙群岛|dragon isles|islas dragón",
    "无尽之海|great sea|mar grande",
    "迷雾之海|veiled sea|mar velado",
    "禁忌离岛|forbidden reach|confín olvidado",
    "萨拉赞盆地|sholazar basin|cuenca de sholazar",
    "嚎风峡湾|howling fjord|fiordo aquilonal",
    "北风苔原|borean tundra|tundra boreal",
    "龙骨荒野|dragonblight|cementerio de dragones",
    "灰熊丘陵|grizzly hills|colinas pardas",
    "祖达克|zul'drak|zul'drak",
    "风暴峭壁|storm peaks|cumbres tormentosas",
    "冰冠冰川|icecrown glacier|glaciar corona de hielo",
  }

  local v9_additional_gaming = {
    "网络|network|red",
    "连接|connect|conectar",
    "重连|reconnect|reconectar",
    "服务器|server|servidor",
    "客户端|client|cliente",
    "延迟|delay/latency|retraso/latencia",
    "高延迟|high latency|alta latencia",
    "低延迟|low latency|baja latencia",
    "卡顿|stuttering|tirones",
    "掉帧|fps drop|caída de fps",
    "死机|freeze/crash|congelado",
    "断开连接|disconnect|desconectado",
    "自动登录|autologin|login automático",
    "更新|update|actualización",
    "下载|download|descargar",
    "安装|install|instalar",
    "设置|settings|ajustes",
    "选项|options|opciones",
    "分辨率|resolution|resolución",
    "画质|graphics quality|calidad gráfica",
    "音效|sound effects|efectos de sonido",
    "背景音乐|bgm|música de fondo",
    "插件|addon/plugin|addon/plugin",
    "宏|macro|macro",
    "快捷键|shortcut/keybind|keybind",
    "鼠标|mouse|ratón",
    "键盘|keyboard|teclado",
    "手柄|controller|mando/gamepad",
    "麦克风|mic|micrófono",
    "语音|voice|voz",
    "聊天框|chat box|caja de chat",
    "频道|channel|canal",
  }

  local v10_turtle_legendary_zh_en_es = {
    -- Traducción Inversa de Zonas Custom de Turtle WoW
    "翡翠圣地|emerald sanctum|sagrario esmeralda",
    "卡拉赞下层|lower karazhan|karazhan inferior",
    "黑木废墟|blackwood ruins|ruinas de bosquenegro",
    "阳光林地|sunnyglade|claro del sol",
    "拉皮迪斯岛|lapidis isle|isla de lapidis",
    "吉利吉姆岛|gillijim's isle|isla de gillijim",
    "迷雾群岛|misty islands|islas de bruma",
    "阿兰纳谷|alanah valley|valle de alanah",
    "萨拉斯高地|thalassian highlands|tierras altas de thalassian",

    -- Modos Custom y Gameplay
    "硬核模式|hardcore mode|modo extremo",
    "慢而稳|slow and steady|lento y constante",
    "流浪者的努力|vagrant's endeavor|esfuerzo de vagabundo",
    "骑乘乌龟|riding turtle|tortuga de montar",
    "生存营火|survival fire|fuego de supervivencia",
    "做营火|make survival fire|hacer fogata",
    "乌龟雕文|glyph of the turtle|glifo de la tortuga",
    "野兽雕文|glyph of the beast|glifo de la bestia",
    "幻化|transmog|transfiguración",

    -- Clases y Habilidades Icónicas
    "神圣打击|holy strike|golpe sagrado",
    "鲜血打击|bloodstrike|golpe de sangre",
    "迅捷治愈|swiftmend|alivio presto",
    "给我激活|innervate me|estimulo a mi",
    "给治疗激活|innervate healer|estimular al heal",
    "能量灌注|power infusion|infusion de poder",
    "给我灌注|pi on me|infusión de poder en mi",
    "法力潮汐图腾|mana tide totem|tótem marea de maná",
    "风怒图腾|windfury totem|tótem viento furioso",
    "防恐结界|fear ward|resguardo contra el miedo",

    -- Tiendas, Tents y Donaciones (Economía Turtle)
    "找帐篷|looking for tent|buscando tienda",
    "帐篷在哪|where is tent|donde hay tienda",
    "起帐篷了|tent is up|tienda colocada",
    "闪金镇帐篷|tent in goldshire|tienda en villadorada",
    "十字路口帐篷|tent in crossroads|tienda en el cruce",
    "陶拉祖帐篷|tent in camp taurajo|tienda en camp taurajo",
    "找帐篷组|lft (looking for tent)|busco grupo para tienda",
    "战争模式|warmode|modo de guerra",
    "帐篷冷却|tent cd|cooldown de tienda",
    "公会银行|guild bank|banco de hermandad",
    "商城|donation shop|tienda de donaciones",
    "捐赠代币|donation token|ficha de donación",

    -- Frases de Raid avanzadas y Tácticas
    "灭团|wipe|morir todos",
    "拉怪|pull|atraer monstruo",
    "仇恨列表|threat meter|medidor de amenaza",
    "跳怪|skip|saltar monstruos",
    "dps检测|dps check|prueba de dps",
    "狂暴|enrage|enfurecer",
    "解诅咒|decurse|quitar maldición",
    "驱散|dispel|disipar magia",
    "清洁|cleanse|limpiar veneno",
    "祛毒|cure poison|quitar veneno"
  }
  load_batch_zh_en_es(v10_turtle_legendary_zh_en_es)

local v9_zones_tbc = {
    "地狱火半岛|hellfire peninsula|península del fuego devastador",
    "赞加沼泽|zangarmarsh|marisma de zangar",
    "泰罗卡森林|terokkar forest|bosque de terokkar",
    "纳格兰|nagrand|nagrand",
    "刀锋山|blade's edge mountains|montañas de filo de espada",
    "虚空风暴|netherstorm|tormenta de vacio",
    "影月谷|shadowmoon valley|valle sombraluna",
    "沙塔斯|shattrath|shattrath",
    "沙塔斯城|shattrath city|ciudad de shattrath",
    "基尔加丹王座|throne of kil'jaeden|trono de kil'jaeden",
    "萨尔玛|thrallmar|thrallmar",
    "荣耀堡|honor hold|bastión del honor",
    "塞纳里奥远征队营地|cenarion refuge|refugio cenarion",
    "赞加沼泽孢子村|sporeggar|esporagar",
    "奥蕾莉亚要塞|allerian stronghold|bastión allerian",
    "裂石堡|stonebreaker hold|bastión rompepiedras",
    "加拉达尔|garadar|garadar",
    "日蚀岗哨|sunspring post|puesto del sol",
    "风暴要塞|tempest keep|el castillo de la tempestad",
    "奥金顿|auchenindoun|auchenindoun",
    "黑暗神殿|black temple|templo oscuro",
    "影月府|shadowmoon village|aldea sombraluna",
    "库雷尼|kurenai|kurenai",
    "玛格汉|mag'har|mag'har",
  }

  local v9_dungeons_tbc = {
    "地狱火堡垒|hellfire citadel|ciudadela del fuego devastador",
    "地狱火城墙|hellfire ramparts|murallas del fuego devastador",
    "鲜血熔炉|the blood furnace|el horno de sangre",
    "破碎大厅|the shattered halls|las salas arrasadas",
    "玛瑟里顿的巢穴|magtheridon's lair|guarida de magtheridon",
    "盘牙水库|coilfang reservoir|reserva colmillo torcido",
    "幽暗沼泽|the underbog|el sotobosque",
    "奴隶围栏|the slave pens|recinto de los esclavos",
    "蒸汽地窖|the steamvault|la cámara de vapor",
    "毒蛇神殿|serpentshrine cavern|caverna santuario de serpientes",
    "法力陵墓|mana-tombs|tumbas de maná",
    "奥金尼地穴|auchenai crypts|criptas auchenai",
    "塞斯克大厅|sethekk halls|salas sethekk",
    "暗影迷宫|shadow labyrinth|laberinto de las sombras",
    "时光之穴|caverns of time|cavernas del tiempo",
    "旧希尔斯布莱德丘陵|old hillsbrad foothills|antiguas laderas de trabacolina",
    "黑色沼泽|the black morass|la ciénaga negra",
    "海加尔山之战|battle for mount hyjal|la batalla del monte hyjal",
    "风暴要塞|tempest keep|el castillo de la tempestad",
    "生态船|the botanica|el botánico",
    "能源舰|the mechanar|el mecanar",
    "禁魔监狱|the arcatraz|el arcatraz",
    "黑暗神殿|black temple|el templo oscuro",
    "祖阿曼|zul'aman|zul'aman",
    "太阳之井高地|sunwell plateau|meseta de la fuente del sol",
    "魔导师平台|magisters' terrace|bancal del magister",
  }

  local v9_quest_phrases = {
    "击杀|kill|matar",
    "打败|defeat|derrotar",
    "消灭|destroy|destruir",
    "收集|collect|recolectar",
    "获得|get|conseguir",
    "寻找|find|buscar",
    "探索|explore|explorar",
    "拯救|rescue|rescatar",
    "护送|escort|escoltar",
    "谈话|talk to|hablar con",
    "对话|talk to|hablar con",
    "报告|report|reportar",
    "交任务|turn in quest|entregar misión",
    "接任务|take quest|aceptar misión",
    "任务线|questline|cadena de misiones",
    "日常任务|daily quest|misión diaria",
    "周常任务|weekly quest|misión semanal",
    "精英任务|elite quest|misión élite",
    "悬赏|wanted|se busca",
    "通缉令|wanted poster|cartel de se busca",
    "护送任务|escort quest|misión de escolta",
    "寻找水源|find water|buscar agua",
    "清理怪物|clear monsters|limpiar monstruos",
  }

  local v9_stats_combat = {
    "法术穿透|spell penetration|penetración de hechizos",
    "急速|haste|celeridad",
    "急速等级|haste rating|índice de celeridad",
    "命中等级|hit rating|índice de golpe",
    "暴击等级|crit rating|índice de golpe crítico",
    "韧性|resilience|temple",
    "韧性等级|resilience rating|índice de temple",
    "防御等级|defense rating|índice de defensa",
    "精准|expertise|pericia",
    "精准等级|expertise rating|índice de pericia",
    "闪避等级|dodge rating|índice de esquive",
    "招架等级|parry rating|índice de parada",
    "格挡等级|block rating|índice de bloqueo",
    "格挡值|block value|valor de bloqueo",
    "智力|intellect|intelecto",
    "精神|spirit|espíritu",
    "耐力|stamina|aguante",
    "敏捷|agility|agilidad",
    "力量|strength|fuerza",
    "法抗|spell resist|resistencia mágica",
    "火抗|fire resist|resistencia al fuego",
    "冰抗|frost resist|resistencia a la escarcha",
    "暗抗|shadow resist|resistencia a las sombras",
    "自然抗|nature resist|resistencia a la naturaleza",
    "奥抗|arcane resist|resistencia a lo arcano",
  }

  local v9_consumables_mats = {
    "魔草|felweed|hierba vil",
    "梦露草|dreaming glory|gloria de ensueño",
    "泰罗果|terocone|terocono",
    "虚空花|netherbloom|flor abisal",
    "噩梦藤|nightmare vine|pesadilla",
    "法力蓟|mana thistle|cardo de maná",
    "古代地衣|ancient lichen|liquen antiguo",
    "黄金参|golden sansam|sansam dorado",
    "山鼠草|mountain silversage|salvia plateada de montaña",
    "瘟疫花|plaguebloom|flor de peste",
    "冰盖草|icecap|hojahielo",
    "梦叶草|dreamfoil|sueñamaleza",
    "魔铁矿石|fel iron ore|mena de hierro vil",
    "精金矿石|adamantite ore|mena de adamantita",
    "氪金矿石|khorium ore|mena de khorium",
    "永恒金矿石|eternium ore|mena de eternio",
    "魔铁锭|fel iron bar|barra de hierro vil",
    "精金锭|adamantite bar|barra de adamantita",
    "氪金锭|khorium bar|barra de khorium",
    "永恒金锭|eternium bar|barra de eternio",
    "源土锭|hardened adamantite bar|barra de adamantita endurecida",
    "灵纹布|netherweave cloth|paño de tejido de la tiniebla",
    "结缔皮|knothide leather|cuero de nudo",
    "厚结缔皮|heavy knothide leather|cuero de nudo pesado",
  }

  local v9_emotes_social = {
    "我的错|my bad|mi culpa",
    "我的问题|my bad|mi culpa",
    "没关系|no problem|no hay problema",
    "谢谢大家|thanks everyone|gracias a todos",
    "辛苦了|good job|buen trabajo",
    "辛苦|good job|buen trabajo",
    "打得漂亮|well played|bien jugado",
    "漂亮|nice|bien jugado",
    "厉害|awesome|increíble",
    "太牛了|so pro|demasiado pro",
    "笑死我了|lmao|muerto de risa",
    "别介意|don't mind|no te preocupes",
    "不要紧|don't worry|no pasa nada",
    "我拉人|summoning|invocando",
    "等我吃口饭|eating|comiendo",
    "等我喝水|drinking|bebiendo",
    "等喝水|mana break|bebiendo",
    "等补buff|buffing|bufando",
    "开打|start pull|empezar pull",
    "准备好|ready|listo",
    "就绪确认|ready check|comprobación de listos",
    "没蓝了|oom|sin maná",
    "没血了|low hp|poca vida",
  }

  local v9_hsk_basic_1 = {
    "爱|love|amor",
    "八|eight|ocho",
    "爸爸|father|papá",
    "杯子|cup|vaso",
    "北京|beijing|pekin",
    "本|volume|tomo/ejemplar",
    "客气|polite|cortés",
    "不|no|no",
    "菜|vegetable|verdura/plato",
    "茶|tea|té",
    "吃|eat|comer",
    "出租车|taxi|taxi",
    "打电话|make phone call|llamar por teléfono",
    "大|big|grande",
    "的|possessive particle|de",
    "点|o'clock|hora",
    "电脑|computer|computadora",
    "电视|television|televisión",
    "电影|movie|película",
    "东西|thing|cosa",
    "都|all|todos",
    "读|read|leer",
    "对不起|sorry|lo siento",
    "多|many|mucho",
    "多少|how much|cuánto",
    "儿子|son|hijo",
    "二|two|dos",
    "饭馆|restaurant|restaurante",
    "飞机|airplane|avión",
    "分钟|minute|minuto",
    "高兴|happy|feliz",
    "个|generic measure word|unidad",
    "工作|work|trabajo",
    "汉语|chinese|chino",
    "好|good|bueno",
    "号|date/number|número/día",
    "喝|drink|beber",
    "和|and|y",
    "很|very|muy",
    "后面|behind|detrás",
    "回|return|volver",
    "会|can|poder/saber",
    "几|how many|cuántos",
    "家|home|casa",
    "叫|call|llamar/llamarse",
    "今天|today|hoy",
  }

  local v9_hsk_basic_2 = {
    "九|nine|nueve",
    "开|open|abrir",
    "看|see|ver/mirar",
    "看见|see|ver",
    "块|piece/currency|pedazo/yuan",
    "来|come|venir",
    "老师|teacher|profesor",
    "了|completed action particle|ya",
    "冷|cold|frío",
    "里|inside|dentro",
    "零|zero|cero",
    "六|six|seis",
    "妈妈|mother|mamá",
    "吗|question particle|acaso",
    "买|buy|comprar",
    "猫|cat|gato",
    "没关系|no problem|no importa",
    "没有|not have|no tener",
    "米饭|rice|arroz cooked",
    "明天|tomorrow|mañana",
    "名字|name|nombre",
    "哪|which|cuál",
    "哪里|where|dónde",
    "那|that|ese",
    "呢|interrogative particle|y qué",
    "能|can|poder",
    "你|you|tú",
    "年|year|año",
    "女儿|daughter|hija",
    "朋友|friend|amigo",
    "漂亮|beautiful|bonito",
    "苹果|apple|manzana",
    "七|seven|siete",
    "钱|money|dinero",
    "前面|front|adelante",
    "请|please|por favor",
    "去|go|ir",
    "热|hot|caliente",
    "人|person|persona",
    "认识|know|conocer",
  }

  local v9_hsk_basic_3 = {
    "三|three|tres",
    "商店|shop|tienda",
    "上午|morning|mañana",
    "少|few|poco",
    "谁|who|quién",
    "什么|what|qué",
    "十|ten|diez",
    "时候|time|momento",
    "是|be|ser",
    "书|book|libro",
    "水|water|agua",
    "水果|fruit|fruta",
    "睡觉|sleep|dormir",
    "说话|speak|hablar",
    "四|four|cuatro",
    "岁|year of age|año de edad",
    "他|he|él",
    "她|she|ella",
    "太|too|demasiado",
    "天气|weather|clima",
    "听|listen|escuchar",
    "同学|classmate|compañero",
    "喂|hey/hello|hola (teléfono)",
    "我们|we|nosotros",
    "五|five|cinco",
    "喜欢|like|gustar",
    "下|down|abajo",
    "下午|afternoon|tarde",
    "下雨|rain|llover",
    "先生|sir|señor",
    "现在|now|ahora",
    "想|want|querer",
    "小|small|pequeño",
    "小姐|miss|señorita",
    "些|some|algunos",
    "写|write|escribir",
    "谢谢|thanks|gracias",
    "星期|week|semana",
    "学生|student|estudiante",
    "学习|study|estudiar",
    "学校|school|escuela",
    "一|one|uno",
    "衣服|clothes|ropa",
    "医生|doctor|médico",
    "医院|hospital|hospital",
    "椅子|chair|silla",
    "有|have|tener",
    "月|month|mes",
    "再见|goodbye|adiós",
    "在|at|en",
    "怎么|how|cómo",
    "怎么样|how is it|qué tal",
    "这|this|este",
    "中国|china|china",
    "中午|noon|mediodía",
    "住|live|vivir",
    "桌子|table|mesa",
    "字|character|letra/carácter",
    "昨天|yesterday|ayer",
    "坐|sit|sentarse",
    "做|do|hacer",
  }

  local v9_hsk_intermediate_1 = {
    "吧|suggestion particle|vale",
    "白|white|blanco",
    "百|hundred|cien",
    "帮助|help|ayudar",
    "报纸|newspaper|periódico",
    "比|compare|comparar con",
    "别|don't|no (imperativo)",
    "宾馆|hotel|hotel",
    "长|long|largo",
    "唱歌|sing|cantar",
    "出|exit|salir",
    "穿|wear|vestir/ponerse",
    "次|times|veces",
    "从|from|desde",
    "错|wrong|equivocado",
    "打篮球|play basketball|jugar baloncesto",
    "大家|everyone|todos",
    "到|arrive|llegar",
    "得|particle|de",
    "等|wait|esperar",
    "弟弟|younger brother|hermano menor",
    "第一|first|primero",
    "懂|understand|entender",
    "对|correct|correcto",
    "房间|room|habitación",
    "非常|very|muy/sumamente",
    "服务员|waiter|camarero",
    "高|high|alto",
    "告诉|tell|decir",
    "哥哥|older brother|hermano mayor",
    "给|give|dar/para",
    "公共汽车|bus|autobús",
    "公司|company|empresa",
    "狗|dog|perro",
    "贵|expensive|caro",
    "过|past particle|pasar/haber hecho",
    "还|still|todavía/además",
    "孩子|child|niño",
    "好吃|delicious|rico/sabroso",
    "黑|black|negro",
    "红|red|rojo",
    "欢迎|welcome|bienvenido",
    "回答|answer|responder",
    "机场|airport|aeropuerto",
    "鸡蛋|egg|huevo",
    "件|measure word for clothes|pieza",
    "教室|classroom|aula",
    "姐姐|older sister|hermana mayor",
    "介绍|introduce|presentar",
    "近|near|cerca",
  }

  local v9_hsk_intermediate_2 = {
    "进|enter|entrar",
    "近|near|cerca",
    "经常|often|a menudo",
    "觉得|feel/think|creer/parecer",
    "开始|start|empezar",
    "考试|exam|examen",
    "可能|maybe|posiblemente",
    "旅游|travel|viajar",
    "绿|green|verde",
    "卖|sell|vender",
    "慢|slow|lento",
    "忙|busy|ocupado",
    "妹妹|younger sister|hermana menor",
    "门|door|puerta",
    "男|male|varón/masculino",
    "您|you (polite)|usted",
    "牛奶|milk|leche",
    "女|female|mujer/femenino",
    "旁|side|lado",
    "跑步|run|correr",
    "便宜|cheap|barato",
    "票|ticket|billete/boleto",
    "妻子|wife|esposa",
    "起床|get up|levantarse de la cama",
    "千|thousand|mil",
    "晴|sunny|despejado/soleado",
    "去年|last year|el año pasado",
    "让|let|dejar/permitir",
    "上班|go to work|ir a trabajar",
    "身体|body/health|cuerpo/salud",
    "生病|fall ill|enfermarse",
    "生日|birthday|cumpleaños",
    "时间|time|tiempo",
    "事情|matter|asunto/cosa",
    "手表|watch|reloj de pulsera",
    "手机|mobile phone|móvil/celular",
    "送|give as gift|regalar/entregar",
    "虽然|although|aunque",
    "但是|but|pero",
    "踢足球|play soccer|jugar fútbol",
    "题|question/topic|pregunta/tema",
    "跳舞|dance|bailar",
    "外|outside|fuera/exterior",
    "完|finish|terminar",
    "玩|play|jugar",
    "晚上|evening|noche",
    "为什么|why|por qué",
    "问|ask|preguntar",
    "问题|problem|pregunta/problema",
    "西瓜|watermelon|sandía",
  }

  local v9_hsk_intermediate_3 = {
    "希望|hope|esperar/desear",
    "洗|wash|lavar",
    "小时|hour|hora",
    "笑|laugh|reír/sonreír",
    "新|new|nuevo",
    "姓|surname|apellido/apellidarse",
    "休息|rest|descansar",
    "雪|snow|nieve",
    "颜色|color|color",
    "眼睛|eyes|ojos",
    "羊肉|mutton|cordero",
    "药|medicine|medicina",
    "要|want|querer/deber",
    "也|also|también",
    "一下|once/a bit|un momento/un poco",
    "一起|together|juntos",
    "已经|already|ya",
    "意思|meaning|significado",
    "因为|because|porque",
    "阴|cloudy|nublado",
    "右边|right side|lado derecho",
    "鱼|fish|pescado/pez",
    "员|member/staff|miembro",
    "远|far|lejos",
    "运动|sports|deporte/ejercicio",
    "再|again|otra vez",
    "早上|morning|mañana temprano",
    "张|measure word for paper/bed|hoja/pieza",
    "丈夫|husband|esposo",
    "找|find|buscar",
    "这儿|here|aquí",
    "着|action particle|estado continuo",
    "真|really|de verdad",
    "正在|in process of|en proceso de",
    "知道|know|saber",
    "准备|prepare|preparar",
    "自行车|bicycle|bicicleta",
    "走|walk|caminar/irse",
    "最|most|el más",
    "左边|left side|lado izquierdo",
  }

  -- V9 Load Calls
  load_batch_zh_en_es(v9_zones_tbc)
  load_batch_zh_en_es(v9_dungeons_tbc)
  load_batch_zh_en_es(v9_quest_phrases)
  load_batch_zh_en_es(v9_stats_combat)
  load_batch_zh_en_es(v9_consumables_mats)
  load_batch_zh_en_es(v9_emotes_social)
  load_batch_zh_en_es(v9_hsk_basic_1)
  load_batch_zh_en_es(v9_hsk_basic_2)
  load_batch_zh_en_es(v9_hsk_basic_3)
  load_batch_zh_en_es(v9_hsk_intermediate_1)
  load_batch_zh_en_es(v9_hsk_intermediate_2)
  load_batch_zh_en_es(v9_hsk_intermediate_3)
  load_batch_zh_en_es(v9_hsk_intermediate_4)
  load_batch_zh_en_es(v9_hsk_intermediate_5)
  load_batch_zh_en_es(v9_hsk_advanced_1)
  load_batch_zh_en_es(v9_hsk_advanced_2)
  load_batch_zh_en_es(v9_wow_factions_cities)
  load_batch_zh_en_es(v9_wow_expansions_continents)
  load_batch_zh_en_es(v9_additional_gaming)

  local v15_colossal_expansion = {
    -- Caso del screenshot ("oce base hermandad featuring expats de dos y epoch...")
    "oce base hermandad featuring expats de dos y epoch|oce guild base featuring expats from dos and epoch|oce基地公会，由来自dos和epoch的流亡成员组成",
    
    -- Expresiones de reclutamiento y hermandad fluidas (ES -> EN -> ZH)
    "busco hermandad que haga raids|looking for guild that raids|找打本的公会",
    "hermandad latina recluta dps y heal|latin guild recruiting dps and healers|拉美公会招收输出和治疗",
    "hermandad hispana activa recluta|active spanish guild recruiting|活跃的西语公会招人",
    "reclutamos de cara a classic tbc|recruiting for classic tbc|为TBC怀旧服招人",
    "busco hermandad hispana|looking for spanish guild|寻找西语公会",
    "gremio hispanohablante recluta|spanish speaking guild recruiting|西语公会招募",
    "hermandad de habla hispana|spanish speaking guild|西班牙语公会",
    "tenemos core activo y discord|we have active core and discord|我们有活跃的开荒群 and 语音",
    "hacemos raids los fines de semana|we raid on weekends|我们周末打团本",
    "busco gremio social y casual|looking for social and casual guild|找休闲社交公会",
    "busco clan activo|looking for active clan|寻找活跃公会",
    "gremio pvp y pve activo|active pvp and pve guild|活跃的PVP和PVE公会",
    "buscamos jugadores activos|looking for active players|招募活跃玩家",
    "hermandad amigable recluta novatos|friendly guild recruiting newbies|友好公会招收萌新",
    "ayudamos a levear y hacer misiones|we help leveling and questing|我们提供升级和任务帮助",
    "sistema de botin dkp|dkp loot system|DKP分配系统",
    "sistema de botin gdkp|gdkp loot system|金团分配系统",
    "loot por prioridad de rol|loot by roll priority|按天赋优先分装",
    "reclutamiento abierto para todos|recruitment open for all|面向所有人招募",
    "busco hermandad de habla hispana para levear|looking for spanish guild to level|找个西语公会一起升级",
    
    -- Expresiones cotidianas y slang de WoW (ES -> EN -> ZH)
    "alguien me ayuda con esta mision|anyone help me with this quest|有人帮我做这个任务吗",
    "quien vende tienda de campaña|who sells survival tent|谁卖生存帐篷",
    "quien vende tienda de campana|who sells survival tent|谁卖生存帐篷",
    "compro tienda de campaña|buy survival tent|买生存帐篷",
    "compro tienda de campana|buy survival tent|买生存帐篷",
    "tengo materiales para la tienda|i have mats for tent|我有帐篷的材料",
    "donde se planta la tienda|where is the tent planted|帐篷在哪里放",
    "planta la tienda por favor|plant the tent please|请放个帐篷",
    "tienda de campamento lista|tent ready|帐篷好了",
    "tira la carpa por favor|put the tent please|放个帐篷谢谢",
    "necesito curas por favor|need heals please|需要治疗谢谢",
    "el tanque no tiene agro|tank has no aggro|坦没有仇恨",
    "cuidado con el agro|careful with aggro|注意仇恨",
    "no peguen antes que el tanque|don't hit before tank|坦拉稳再打",
    "dejen que el tanque jale|let tank pull|让坦拉怪",
    "limpien los mobs de atras|clear the back mobs|清掉后面的怪",
    "pull accidental lo siento|accidental pull sorry|不小心引到怪了抱歉",
    "add accidental|accidental add|引到怪了",
    "cuidado con los patrulleros|watch out for patrols|小心巡逻怪",
    "patrulla viniendo cuidado|patrol coming watch out|巡逻来了小心",
    "esperen que pase la patrulla|wait for patrol to pass|等巡逻过去",
    "necesito comprar agua y comida|need to buy water and food|我去买点水和食物",
    "mi equipamiento esta roto|my gear is broken|我装备红了",
    "tengo que ir a reparar|need to go repair|我要去修理",
    "alguien tiene robot de reparacion|anyone has repair bot|有人放修理机器人吗",
    "tienen piedra de hogar lista|is your hearthstone ready|炉石好了吗",
    "mi piedra de hogar esta en cd|my hearthstone is on cd|炉石冷却中",
    "nos vemos en la taberna|see you in the tavern|旅馆见",
    "tengo la mochila llena|my bag is full|我包满了",
    "necesito ir al banco a guardar cosas|need to go to bank|我要去银行存东西",
    "alguien que me haga port a orgrimmar|anyone port to orgrimmar|求开奥格瑞玛的门",
    "alguien que me haga port a ventormenta|anyone port to stormwind|求开暴风城的门",
    
    -- MMO general y ayuda (ES -> EN -> ZH)
    "como llego a esa zona|how do i get to that zone|怎么去那个地图",
    "esta bloqueada la entrada|the entrance is blocked|入口被堵住了",
    "el servidor se cayo|server crashed|服务器崩了",
    "tengo problemas de conexion|connection issues|我连接有问题",
    "me sacó del servidor|disconnected me from server|掉线了",
    "hay mucho lag de mundo|high world lag|世界延迟太高了",
    "mi ping es aceptable|my ping is ok|我延迟还行",
    "juego a sesenta fps|playing at 60 fps|帧率60帧",
    "este addon es increible|this addon is amazing|这个插件太好用了",
    "gracias por la traduccion|thanks for the translation|谢谢翻译",
    "la traduccion funciona muy bien|translation works very well|翻译功能运行良好",
    "no entiendo ingles pero con esto si|i don't know english but with this i do|我不懂英语但用这个懂了",
    "gracias creadores del addon|thanks addon creators|谢谢插件作者",
    "el chat es trilingue ahora|chat is trilingual now|聊天频道现在是三语的了",
    "puedo hablar en mi idioma|i can speak in my language|我可以用我的母语说话了",
    "los demas me entienden|others understand me|别人能听懂我的话",
    "puedo entender a los chinos|i can understand chinese players|我能看懂中文玩家的话",
    "puedo entender a los ingleses|i can understand english players|我能看懂英语玩家的话",
    "que gran comunidad tenemos|what a great community we have|多么棒的的社区",
    "viva turtle wow|long live turtle wow|乌龟服万岁",
    
    -- Slang inglés MMO expandido (EN -> ES -> ZH)
    "i do not know|no lo se|我不知道",
    "i cannot go|no puedo ir|我不能去",
    "i am ready|estoy listo|我好了",
    "it is fine|esta bien|没事",
    "it is ok|no pasa nada|没关系",
    "i will go|yo ire|我去",
    "you are welcome|de nada|不客气",
    "they are coming|ya vienen|他们来了",
    "we are ready|estamos listos|我们准备好了",
    "he is coming|ya viene|他来了",
    "she is coming|ya viene|她来了",
    "will not wipe|no moriremos|不会灭",
    "did not hit|no golpee|没打中",
    "is not ready|no esta listo|没准备好",
    "was not me|no fui yo|不是我",
    "were not there|no estabamos ahi|没在那",
    "are not here|no estan aqui|不在那",
    "have not seen|no he visto|没见过",
    "has not dropped|no ha caido|没掉落",
    "had not started|no habia empezado|还没开始",
    "would not believe|no lo creeria|不相信",
    "could not do|no pude hacerlo|做不到",
    "should not pull|no deberias jalar|不该拉怪",
    "let us go|vamos|走吧",
    "do not pull|no jales|别拉怪",
    "do not hit|no pegues|别打",
    "do not run|no corras|别跑",
    "do not die|no mueras|别死",
    
    -- Frases y expresiones de Turtle WoW adicionales
    "busco grupo para mazmorra de nivel bajo|lfg for low level dungeon|求组低级副本",
    "hacemos mazmorras clasicas|we run classic dungeons|我们打经典地下城",
    "quien quiere hacer grupo para misiones|who wants to party for quests|谁想组队做任务",
    "grupo para matar elites|party to kill elites|精英任务求组",
    "necesito ayuda con boss elite|need help with elite boss|求助精英BOSS",
    "estoy haciendo misiones en bosque oscuro|questing in duskwood|在暮色森林做任务",
    "alguien por paramos de poniente|anyone in westfall|西部荒野有人吗",
    "alguien por bosque de elwynn|anyone in elwynn forest|艾尔文森林有人吗",
    "busco healer para curar en mazmorra|looking for healer for dungeon|副本求奶妈",
    "busco tanque para aguantar los golpes|looking for tank to hold aggro|副本求坦",
    "dps listo para pegar duro|dps ready to hit hard|输出准备就绪",
    "dame invi por favor|give me invite please|请组我谢谢",
    "me uno al grupo con gusto|gladly joining the group|很高兴加入队伍",
    "saludos cordiales a todos|warm regards to everyone|大家好",
    "que tengan un excelente dia de juego|have a great gaming day|祝大家游戏愉快",
    "buena suerte con el loot de hoy|good luck with today's loot|祝今天掉落好运",
    "felicidades por tu nueva pieza de equipo|grats on your new gear|恭喜拿新装备",
    "gracias por la ayuda de verdad|thanks for the help really|非常感谢你的帮助",
    "eres un gran jugador|you are a great player|你是个优秀的玩家",
    "excelente grupo muy limpio|excellent group very clean|打得非常干净的队伍",
    "es un placer jugar con ustedes|pleasure playing with you|和你们一起玩很开心",
    "hasta la proxima amigos|until next time friends|下次见朋友们",
    "suerte en sus aventuras por azeroth|luck in your adventures in azeroth|祝你在艾泽拉斯冒险顺利",
  }
  load_batch(v15_colossal_expansion)

  local v16_giga_dictionary_expansion = {
    -- 1. Abreviaturas de chat de WoW (ES -> EN -> ZH)
    "busco grupo|lfg|求组",
    "busco mas|lfm|求人/来人",
    "busco más|lfm|求人/来人",
    "lfg|lfg|求组",
    "lfm|lfm|求人/来人",
    "susurrar|pst|请私聊",
    "pst|pst|请私聊",
    "compro|wtb|求购",
    "wtb|wtb|求购",
    "vendo|wts|出售",
    "wts|wts|出售",
    "cambio|wtt|交换",
    "wtt|wtt|交换",
    "invitame|inv|组我/邀请",
    "invítame|inv|组我/邀请",
    "inv|inv|组我/邀请",
    "invitar|invite|邀请",
    "invite|invite|邀请",
    "en camino|omw|在路上",
    "omw|omw|在路上",
    "ya vuelvo|brb|马上回来",
    "brb|brb|马上回来",
    "ausente|afk|暂离",
    "afk|afk|暂离",
    "buena partida|gg|好游戏",
    "gg|gg|好游戏",
    "gracias|thanks|谢谢",
    "thanks|thanks|谢谢",
    "ty|thanks|谢谢",
    "thx|thanks|谢谢",
    "de nada|no problem|不用谢/不客气",
    "no pasa nada|no problem|没关系/没事",
    "np|no problem|没关系/没事",
    "jajaja|lol|哈哈",
    "lol|lol|哈哈",
    "por favor|please|请",
    "porfa|please|请",
    "please|please|请",
    "plz|please|请",
    "pls|please|请",

    -- 2. Comandos y Tácticas de Mazmorras (ES -> EN -> ZH)
    "tanque|tank|坦/坦克",
    "tank|tank|坦/坦克",
    "curador|healer|治疗/奶妈",
    "sanador|healer|治疗/奶妈",
    "healer|healer|治疗/奶妈",
    "dps|dps|输出/伤害",
    "jalar|pull|拉怪",
    "atraer|pull|拉怪",
    "pull|pull|拉怪",
    "pulling|pulling|拉怪中",
    "agro|aggro|仇恨",
    "aggro|aggro|仇恨",
    "amenaza|aggro|仇恨",
    "adds|adds|小怪",
    "patrulla|patrol|巡逻",
    "patrullero|patrol|巡逻怪",
    "patrol|patrol|巡逻",
    "wipe|wipe|灭团",
    "morir todos|wipe|灭团",
    "resucitar|resurrect|复活",
    "revivir|resurrect|复活",
    "res|res|拉人/复活",
    "beber|drink|喝水",
    "drink|drink|喝水",
    "comer|eat|吃面包",
    "eat|eat|吃/食物",
    "oom|oom|没蓝了",
    "sin mana|oom|没蓝了",
    "sin maná|oom|没蓝了",
    "buffs|buffs|增益/状态",
    "foco|focus|焦点",
    "focus|focus|焦点/集火",
    "enfocar|focus|集火",
    "marcar|mark|标记",
    "mark|mark|标记",

    -- 3. Vocabulario conversacional y pronombres comunes (ES -> EN -> ZH)
    "yo|i|我",
    "i|i|我",
    "tu|you|你",
    "tú|you|你",
    "you|you|你",
    "nosotros|we|我们",
    "we|we|我们",
    "ellos|they|他们",
    "they|they|他们",
    "el|he|他",
    "él|he|他",
    "he|he|他",
    "ella|she|她",
    "she|she|她",
    "mi|my|我的",
    "my|my|我的",
    "tu|your|你的",
    "your|your|你的",
    "nuestro|our|我们的",
    "our|our|我们的",
    "esto|this|这个",
    "this|this|这个",
    "eso|that|那个",
    "that|that|那个",
    "aqui|here|这里",
    "aquí|here|这里",
    "here|here|这里",
    "alla|there|那里",
    "allá|there|那里",
    "there|there|那里",
    "quien|who|谁",
    "quién|who|谁",
    "who|who|谁",
    "que|what|什么",
    "qué|what|什么",
    "what|what|什么",
    "donde|where|哪里",
    "dónde|where|哪里",
    "where|where|哪里",
    "cuando|when|什么时候",
    "cuándo|when|什么时候",
    "when|when|什么时候",
    "porque|because|因为",
    "because|because|因为",
    "por qué|why|为什么",
    "why|why|为什么",
    "como|how|怎么",
    "cómo|how|怎么/如何",
    "how|how|怎么/如何",

    -- 4. Verbos comunes del juego (ES -> EN -> ZH)
    "ir|go|去",
    "go|go|去",
    "vamos|let's go|出发/走吧",
    "venir|come|来",
    "come|come|来",
    "correr|run|跑",
    "run|run|跑",
    "ayudar|help|帮助",
    "help|help|帮助/救命",
    "matar|kill|杀",
    "kill|kill|杀/击杀",
    "hacer|do|做",
    "do|do|做",
    "necesitar|need|需要",
    "need|need|需要",
    "querer|want|想要",
    "want|want|想要",
    "tener|have|有",
    "have|have|有",
    "poder|can|能/可以",
    "can|can|能/可以",
    "saber|know|知道",
    "know|know|知道",
    "ver|see|看",
    "see|see|看",
    "mirar|look|看",
    "look|look|看",
    "dar|give|给",
    "give|give|给",
    "tomar|take|拿",
    "take|take|拿",
    "abrir|open|开",
    "open|open|开",
    "cerrar|close|关",
    "close|close|关",
    "comprar|buy|买",
    "buy|buy|买",
    "vender|sell|卖",
    "sell|sell|卖",
    "esperar|wait|等",
    "wait|wait|等",
    "parar|stop|停",
    "stop|stop|停",
    "morir|die|死",
    "die|die|死",

    -- 5. Adjetivos y adverbios comunes (ES -> EN -> ZH)
    "si|yes|是的",
    "yes|yes|是的",
    "no|no|不",
    "bien|well/good|好/不错",
    "good|good|好/不错",
    "well|well|好/不错",
    "mal|bad|坏/差",
    "bad|bad|坏/差",
    "listo|ready|准备好了",
    "ready|ready|准备好了",
    "nuevo|new|新",
    "new|new|新",
    "viejo|old|老",
    "old|old|老",
    "rapido|fast|快",
    "rápido|fast|快",
    "fast|fast|快",
    "lento|slow|慢",
    "slow|slow|慢",
    "grande|big|大",
    "big|big|大",
    "pequeño|small|小",
    "pequeno|small|小",
    "small|small|小",
    "mucho|much|多",
    "much|much|多",
    "many|many|多",
    "poco|little|少",
    "little|little|少",
    "few|few|少",
    "muy|very|非常/很",
    "very|very|非常/很",
    "mas|more|更多",
    "más|more|更多",
    "more|more|更多",
    "menos|less|更少",
    "less|less|更少",

    -- 6. Frases cortas cotidianas (ES -> EN -> ZH)
    "ayuda por favor|help please|请帮忙",
    "invitame al grupo|inv me|组我",
    "invítame al grupo|inv me|组我",
    "necesito tanque|need tank|需要坦克",
    "necesito healer|need healer|需要治疗/奶妈",
    "necesito dps|need dps|需要输出",
    "mazmorra lista|dungeon ready|副本就绪",
    "vamos a empezar|let's start|我们开始吧",
    "un momento por favor|one moment please|请等一下",
    "buen intento chicos|nice try guys|大家尽力了",
    "felicidades|congrats|恭喜",
    "congrats|congrats|恭喜",
    "de nada amigo|you are welcome friend|不客气朋友",
    "gracias por el grupo|thanks for the group|谢谢队伍",
    "nos vemos luego|see you later|回见",
    "cuidado con los adds|watch out for adds|小心引怪",
    "no tengo mana|no mana|没蓝了",
    "no tengo maná|no mana|没蓝了",
    "espera que recupere mana|wait for mana|等回蓝",
    "espera que recupere maná|wait for mana|等回蓝",
    "abre el cofre|open chest|开宝箱",
    "puedes revivirme|can you res me|能复活我吗",
    "donde esta la entrada|where is the entrance|入口在哪里",
    "dónde está la entrada|where is the entrance|入口在哪里",
  }
  load_batch(v16_giga_dictionary_expansion)

  -- ============================================================
  -- LOTE V17: ADICIONES DE LA COMUNIDAD (ZH -> EN -> ES)
  -- ============================================================
  local v17_community_additions_zh_en_es = {
    "木柴|firewood|leña",
    "墓碑|gravestone|lápida",
    "屁|nothing/crap|nada/mierda",
    "挖槽|holy crap|joder/mierda",
    "卧槽|holy crap|joder/mierda",
    "旅馆|inn|taberna/posada",
    "弹窗|popup|ventana emergente",
    "告知|inform|avise/dígame",
    "恶心|disgusting|asco/repugnante",
    "皮甲|leather|cuero",
    "地方|place|lugar",
    "调|adjust/change|configurar/ajustar",
    "调整|adjust/change|configurar/ajustar",
    "土匪|bandit|bandido",
    "私信|private message|mensaje privado/susurro",
    "私聊|private message|mensaje privado/susurro",
    "哈|haha|jaja",
    "唤起魔友|Recall a Friend|Llamar a un amigo/Recluta a un amigo",
    "现已|already/now|ya/ahora",
    "区建|built in zone|creado en zona/canal",
    "主|main/leader|principal/líder",
    "已|already|ya",
    "放|put/drop|poner/colocar",
    "荆齿城|Ratchet|Trinquete",
    "棘齿城|Ratchet|Trinquete",
    "句|sentence/phrase|frase/palabra",
    "神|god/insane|dios/increíble",
    "咱们|we/us|nosotros",
    "浅|shallow/a bit|ligero/un poco",
    "圈|circle/lap|círculo/vuelta",
    "刚|just now|acabo de",
    "刚刚|just now|acabo de",
    "非|must|tiene que/debe",
    "非得|must|tiene que/debe",
    "仪祭|ritual/rite|ritual/rito",
    "阿兰起亚|Aran'thya|Aran'thya",
    "大地母亲仪祭|Rites of the Earthmother|Ritual de la Tierra Madre",
    "大地母亲的仪祭|Rites of the Earthmother|Ritual de la Tierra Madre",
    "原神|Genshin|Genshin",
    "布甲|cloth|tela",
    "锁甲|mail|malla",
    "板甲|plate|placas",
    "营火|campfire|hoguera/fuego",
    "野外|outdoor/world|mundo/afueras",
    "升级|level up|subir de nivel",
    "经验|experience/xp|experiencia",
    "日常|daily|diario",
    "周常|weekly|semanal",
    "排队|queue|cola",
    "延迟|latency/ping|latencia",
    "掉线|disconnect|desconectar"
  }
  load_batch_zh_en_es(v17_community_additions_zh_en_es)

  -- ============================================================
  -- LOTE V18: MITIGACIÓN DE ESTILO TARZÁN Y LÉXICO COMUNITARIO (ZH -> EN -> ES)
  -- ============================================================
  local v18_tarzan_mitigation_community = {
    -- 1. WoW Lugares y Zonas Clásicas
    "雷霆崖有飞艇吗|Zeppelin to Thunder Bluff?|¿hay zepelín en Thunder Bluff?",
    "雷霆崖有飞艇|Zeppelin to Thunder Bluff|hay zepelín en Thunder Bluff",
    "雷霆崖|Thunder Bluff|Thunder Bluff",
    "奥格瑞玛|Orgrimmar|Orgrimmar",
    "奥格|Orgrimmar|Orgrimmar",
    "去奥格吗|going to Orgrimmar?|¿vas a Orgrimmar?",
    "去奥格|going to Orgrimmar|ir a Orgrimmar",
    "去奥格瑞玛|going to Orgrimmar|ir a Orgrimmar",
    "暴风城监狱|Stormwind Stockade|Cárcel de Ventormenta",
    "暴风城|Stormwind|Ventormenta",
    "暴风|Stormwind|Ventormenta",
    "监狱|Stockade/Prison|Cárcel/Mazmorras",
    "血精灵主城|Silvermoon City|Ciudad de Lunargenta",
    "主城|Capital City|capital/ciudad principal",
    "阿尔萨斯|Arthas|Arthas",
    "阿尔萨斯在哪|Where is Arthas?|¿dónde está Arthas?",

    -- 2. Mitigación de Expresiones Literales (Tarzán) y Jerga
    "飞艇|zeppelin|zepelín",
    "有飞艇|is there a zeppelin|¿hay zepelín?",
    "有啊|yes/of course|sí/claro que sí/sí hay",
    "看球不懂|does not understand a thing|no entiende un carajo/no entiende nada",
    "看不懂|cannot understand/illegible|no entender nada/no entiendo",
    "看懂|understand|entender",
    "哎呦我去|holy crap/oh my|¡joder!/¡madre mía!",
    "哎呦|oh my/ouch|¡madre mía!/¡ay!",
    "跑着去奥格|running to Orgrimmar|ir corriendo a Orgrimmar/caminando a Orgrimmar",
    "跑着去|running to/walking to|yendo a pie a/corriendo a",
    "跑着|running/walking|corriendo/a pie",
    "我还跑着|I am still running|todavía voy a pie/sigo corriendo",
    "我还跑着去奥格|I am still running to Orgrimmar|aún voy a pie a Orgrimmar/sigo corriendo a Orgrimmar",
    "代工|crafting/crafting service|crafteo/fabricación por encargo/hago gratis",
    "丝线自备|bring your own threads|traer hilos/traer hilos propios",
    "自备|bring your own|traer propios/traer materiales",
    "M人|whisper me/pst|susurrar/mandar pm/susúrrame",
    "交任务|handing in quests|entregar misión/entregar misiones",
    "挺好的|pretty good/quite nice|bastante bien/está muy bien",
    "什么鬼|what the hell|¡qué demonios!/¿qué cojones?",
    "有人需要吗|anyone needs this?|¿alguien lo necesita?",
    "小伙|buddy/mate|compañero/amigo",
    "小伙伴|buddies/friends|compañeros/amigos",
    "毛料|wool cloth|paño de lana/lana",
    "包邮|shipping included|envío incluido/envío gratis",
    "3G包邮|3G shipping included|3G con envío incluido/3 de oro envío gratis",
    "包邮吗|is shipping included?|¿es con envío incluido?",
    "全属性|all stats|todos los atributos/todas las estadísticas",
    "快速升级|fast leveling|subir de nivel rápido/levear rápido/leveo veloz",
    "要的MM|whisper if you want|interesados susurrar/susurrar si lo quieres",
    "要的M|whisper if you want|interesados susurrar/susurrar si lo quieres",
    "来奶|LF healer|busco healer/se busca sanador",
    "来dps|LF dps|busco dps/se busca dps",
    "来奶 and dps|LF healer and dps|busco healer y dps/se busca sanador y dps",
    "来奶和dps|LF healer and dps|busco healer y dps/se busca sanador y dps",
    "有拉|have summon|tenemos invocación/hay invocador",
    "接任务|accepting quest|tomar misión/coger la misión",
    "在哪接|where to accept|¿dónde se toma?/¿dónde se acepta?",
    "在哪里接|where to accept|¿dónde se acepta?/¿dónde se toma?",
    "跑吐了|running till exhaustion|correr hasta el cansancio",
    "要跑吐了|will run till exhaustion|me voy a cansar de tanto correr",
    "蘑菇孢子|mushroom spore|espora de champiñón/esporas de hongo",
    "只能NPC买吗|can only buy from NPC?|¿solo se puede comprar en NPC?/¿solo lo vende el NPC?",
    "魔友|summoned friend/companion|compañero/amigo/invocación",

    -- 3. Hechizos e Items Clave
    "强效魔法杖|Greater Magic Wand|Varita mágica superior",
  }
  load_batch_zh_en_es(v18_tarzan_mitigation_community)

  -- ============================================================
  -- LOTE V19: MITIGACIÓN TARZÁN AVANZADA Y MODISMOS DE CHAT (ZH -> EN -> ES)
  -- ============================================================
  local v19_tarzan_mitigation_advanced = {
    -- 1. Expresiones de Lag y Congelamientos (Evitar "sabe lag vivir" que viene de 会卡住)
    "会卡住|will freeze/lags|se congela/da lag/va con lag",
    "经常卡住|often freezes/often lags|se congela a menudo/da lag seguido",
    "卡皮|Light's Hope Chapel/Capi|Capilla de la Esperanza de la Luz/Capi",
    "卡了|lagged/frozen|con lag/congelado/se trabó",
    "太卡了|too laggy/freezing too much|demasiado lag/va súper trabado",

    -- 2. Modismos de Leveo y Generaciones Hardcore
    "一世|first generation/Gen 1|primera generación/Generación 1/I generación",
    "二世|second generation/Gen 2|segunda generación/Generación 2/II generación",
    "三世|third generation/Gen 3|tercera generación/Generación 3/III generación",
    "噶了|died/ripped|murió/la palmó/falleció",
    "噶了呀|died already/ripped already|ya la palmó/ya murió",
    "怂了|chickened out/scared|se acobardó/le dio miedo/se cagó",
    "怂了呀|chickened out already|ya se acobardó/le dio miedo",
    "乌龟服|Turtle WoW/Turtle server|servidor Turtle WoW/servidor tortuga",
    "35级|level 35|nivel 35",
    "35q|level 35|nivel 35",
    "18级|level 18|nivel 18",
    "19级|level 19|nivel 19",
    "18级就可以去接了|can go accept at level 18|a nivel 18 ya se puede ir a tomar",
    "去哪里升级啊|where to level up?|¿a dónde ir a subir de nivel?/¿dónde leveo?",
    "去接|go accept/go take|ir a aceptar/ir a tomar misión",
    "去接了|went to accept/already accepted|ir a aceptarla/ir a cogerla",
    "出蛋|egg drop/drops the egg|cae el huevo/suelta el huevo",
    "打娜迦出蛋|kill nagas to drop the egg|matar nagas para que caiga el huevo",
    "打娜迦|kill nagas/farming nagas|matar nagas/farmear nagas",

    -- 3. Zonas de Juego Traducidas
    "月溪镇|Moonbrook|Moonbrook/Arroyo de la Luna",
    "月溪镇怪物多吗|are there many mobs in Moonbrook?|¿hay muchos monstruos en Moonbrook?",
    "灰谷|Ashenvale|Valle de Fresno/Ashenvale",
    "灰谷最东边|extreme east Ashenvale/far east Ashenvale|el extremo este de Ashenvale/zona este de Valle de Fresno",
    "闪金镇|Goldshire|Villadorada/Goldshire",
    "闪金镇马戏团|Goldshire circus|circo de Villadorada/circo de Goldshire",
    "剃刀沼泽|Razorfen Kraul|Razorfen Kraul/Zul'Kraul",
    "剃刀高地|Razorfen Downs|Razorfen Downs/Zul'Farrak",
    "剃刀沼泽缺dps|Razorfen Kraul needs dps|Razorfen Kraul busca dps/falta dps en RFK",
    "藏宝海湾|Booty Bay|Bahía del Botín/Booty Bay",

    -- 4. Expresiones de Reclutamiento de Mazmorras y Canales
    "4等1|4 looking for 1/4L1|4 busca 1/somos 4 y falta 1",
    "4Q1|4 looking for 1/4L1|4 busca 1/somos 4 y falta 1",
    "4q1|4 looking for 1/4L1|4 busca 1/somos 4 y falta 1",
    "监狱来个奶|Stockade needs healer|Cárcel busca healer/Cárcel busca sanador",
    "有来的没|anyone coming?|¿alguien se une?/¿alguien viene?",
    "35q去哪里升级啊|where to level up at 35?|¿a dónde ir a subir de nivel a nivel 35?",
    "有没有哪种|is there a kind of/does anyone have a|¿alguien tiene algún tipo de/saben de algún",
    "有没有哪种addon|does anyone know of a bag/quest addon?|¿alguien tiene algún addon de ese tipo?",
    "新地图任务指引|new map quest guide|guía de misiones del nuevo mapa",
    "任务指引|quest guide/quest directions|guía de misiones/indicación de misiones",

    -- 5. Monturas y Hechizos
    "乌龟坐骑|turtle mount|montura de tortuga",
    "乌龟坐骑任务|turtle mount quest|misión de la montura de tortuga",
    "马戏团|circus|circo/Feria de la Luna Negra",
    "是不是只能在马戏团接|is it only acceptable at the circus?|¿solo se puede aceptar en el circo?/¿solo se toma en el circo?",

    -- 6. WoW Términos Conversacionales
    "这家伙|this guy/this mob|este chaval/este bicho/este mob",
    "这个家伙|this guy/this mob|este chaval/este bicho/este mob",
    "召唤|summon/invocar|invocar/invocación",
    "刷了|spawned/dropped|apareció/reapareció/salió/dropeó",
    "给我包|give me bags|dame bolsas/dame mochilas",
    "给你包|give you bags|darte bolsas/darte mochilas",
    "他说需要给你包|he says he needs to give you bags|dice que hay que darte bolsas",
    "九街|Nine Street|Calle Nueve/Nine Street",
    "老玩家|veteran player/old school player|jugador veterano/veterano/viejo jugador",
    "携手闯|venture together/explore together|aventurarse juntos/explorar juntos",
    "怀旧|nostalgia/retro/classic|nostalgia/retro/recuerdo classic/recordar viejos tiempos",
    "有缘人|destined people/kindred spirits|almas afines/gente con afinidad/destinados a encontrarse",
    "吉米8.0|Jimi 8.0|Jimi 8.0",
    "背包插件|bag addon|addon de bolsas",
    "反而觉得|feel instead/actually feel|por el contrario siento/más bien siento"
  }
  load_batch_zh_en_es(v19_tarzan_mitigation_advanced)

  -- ============================================================
  -- RE-INDEXACIÓN DE BUCKETS POST-CARGA DE BASE DE DATOS
  -- ============================================================
  -- Dado que translator_dict ya inicializó los buckets, re-construimos
  -- los buckets para incluir los nuevos elementos inyectados de Spells & Quests.
  local p_keys = { "es_en", "en_es", "zh_en", "en_zh", "zh_es", "es_zh" }
  for _, p in ipairs(p_keys) do
    table.sort(pfUI.translator_dicts[p .. "_keys"], function(a, b) return strlen(a) > strlen(b) end)

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
    DEFAULT_CHAT_FRAME:AddMessage("|cff33ffcc[TR]|r Base de Datos v7.1 cargada. Clases, roles, zonas clasicas/TBC, ciudades, gaming WoW, economía, slang chino y conversacional indexados.")
  end

end)
