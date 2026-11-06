import re
import ast
import json
import os
import glob

# Configuration
LUA_FILE = 'CharacterProfiler.lua'
LUA_PATTERN = 'CharacterProfiler*.lua'
HTML_FILE = 'dashboard.html'
ICON_BASE_PATH = 'assets/images/icons/large/'

def process_files():
    # Находим все файлы по маске
    lua_files = glob.glob(LUA_PATTERN)
    
    if not lua_files:
        print("No Lua files found!")
        return

    for file_path in lua_files:
        print(f"Processing: {file_path}")
        
        # Генерируем имя выходного HTML файла на основе имени LUA
        # Например: CharacterProfiler_Admin.lua -> CharacterDashboard_Admin.html
        base_name = os.path.splitext(file_path)[0]
        output_html = base_name.replace('CharacterProfiler', 'CharacterDashboard') + '.html'
        
        try:
            with open(file_path, 'r', encoding='utf-8') as f:
                content = f.read()
            
            if 'myProfile =' not in content:
                print(f"Skipping {file_path}: 'myProfile =' not found.")
                continue
                
            data_string = content.split('myProfile =')[1].strip()
            if data_string.endswith(';'):
                data_string = data_string[:-1].strip()

            # Конвертация Lua -> Python dict
            python_str = re.sub(r'\["(.*?)"\]\s*=', r'"\1":', data_string)
            python_str = re.sub(r'\[(\d+)\]\s*=', r'\1:', python_str)
            python_str = re.sub(r'\btrue\b', '1', python_str)
            python_str = re.sub(r'\bfalse\b', '0', python_str)
            python_str = re.sub(r'\bnil\b', 'None', python_str)
            
            profile_data = ast.literal_eval(python_str)
            
            # Генерируем дашборд именно для этого файла
            generate_dashboard(profile_data, output_html)
            print(f"Created: {output_html}")
            
        except Exception as e:
            print(f"Parsing error in {file_path}: {e}")

def generate_dashboard(myProfile, output_filename):
    json_data = json.dumps(myProfile)
    
    html_template = """
<!DOCTYPE html>
<html>
<head>
    <title>WoW Profile Dashboard</title>
    <style>
        body { font-family: 'Segoe UI', sans-serif; background: #0c0c0c; color: #d1d1d1; display: flex; margin: 0; height: 100vh; overflow: hidden; }
        #sidebar { width: 280px; background: #161616; border-right: 1px solid #333; padding: 20px; overflow-y: auto; flex-shrink: 0; }
        #main { flex: 1; padding: 30px; overflow-y: auto; scroll-behavior: smooth; }
        
        .char-link { 
            display: block; padding: 12px; color: #fff; background: #222; 
            margin-bottom: 10px; border-radius: 8px; cursor: pointer; 
            border: 1px solid #333; transition: transform 0.3s ease; 
        }
        .char-link:hover { border-color: #ffb400; background: #2a2a2a; transform: translateX(12px); }
        
        .char-header { margin-bottom: 20px; padding: 15px; background: #1a1a1a; border-radius: 8px; border-left: 4px solid #ffb400; }
        .char-meta { font-size: 1.1em; color: #eee; margin-bottom: 8px; display: flex; gap: 15px; }
        .resource-container { display: flex; gap: 20px; margin: 10px 0; flex-wrap: wrap; }
        .location-box { font-size: 0.9em; color: #ffb400; margin-top: 5px; }
        .time-box { font-size: 0.85em; color: #888; margin-top: 5px; }
        
        h2 { color: #ffb400; border-bottom: 2px solid #444; padding-bottom: 5px; margin-top: 30px; text-transform: uppercase; font-size: 1.1em; }
        table { width: 100%; border-collapse: collapse; background: #111; margin-bottom: 20px; border: 1px solid #222; table-layout: fixed; }
        td { padding: 10px; border-bottom: 1px solid #222; vertical-align: middle; word-wrap: break-word; }
        
        .item-container { display: flex; align-items: center; gap: 12px; position: relative; }
        .icon-img { width: 40px; height: 40px; border: 1px solid #444; border-radius: 4px; background: #000; flex-shrink: 0; }
        
        .tooltip-box { 
            display: none; width: 320px; background: rgba(7, 12, 33, 0.98); color: #fff; 
            border: 2px solid #a335ee; border-radius: 6px; padding: 15px;
            position: absolute; z-index: 10000; left: 50px; top: 40px; pointer-events: none;
            box-shadow: 0 10px 40px rgba(0,0,0,0.9); font-size: 13px; font-weight: normal;
        }
        .item-container:hover .tooltip-box { display: block; }
        
        .bar-container { display: flex; flex-direction: column; gap: 4px; width: 50%; }
        .bar-bg { background: #111; height: 14px; border-radius: 2px; overflow: hidden; border: 1px solid #333; }
        .bar-fill { height: 100%; width: 100%; } 
        
        details { background: #1a1a1a; padding: 8px; border-radius: 4px; margin: 4px 0; border: 1px solid #333; }
        summary { cursor: pointer; color: #5bc0de; font-weight: bold; }
        .key-label { color: #888; font-size: 0.85em; font-weight: bold; width: 140px; text-transform: capitalize; }
        .hidden-label { display: none; }
        .icon-wrapper {
            position: relative;
            display: inline-block;
            width: 40px;
            height: 40px;
            flex-shrink: 0;
        }

        .item-quantity {
            position: absolute;
            bottom: 1px;
            right: 2px;
            color: #ffffff;
            font-size: 12px;
            font-weight: bold;
            text-shadow: 1px 1px 1px #000, -1px -1px 1px #000, 1px -1px 1px #000, -1px 1px 1px #000;
            pointer-events: none; /* Чтобы текст не мешал наведению мыши */
        }
    </style>
</head>
<body>
    <div id="sidebar"><h3>Characters</h3><div id="menu"></div></div>
    <div id="main"><h1 id="charHeading">Select a character</h1><div id="content"></div></div>
    <script>
        const profileData = DATA_PLACEHOLDER;
        const iconBase = 'ICON_PATH_PLACEHOLDER';

        const slotOrder = ["head", "neck", "shoulder", "shirt", "chest", "waist", "legs", "feet", "wrist", "hands", "finger0", "finger1", "trinket0", "trinket1", "back", "tabard", "mainhand", "offhand", "relic", "ranged"];
        const repColors = { "Exalted": "#08ffff", "Revered": "#05ffc1", "Honored": "#00ff88", "Friendly": "#17dc00", "Neutral": "#f1ff04", "Unfriendly": "#ee5121", "Hostile": "#c30400", "Hated": "#cc2121" };

        function getLocalIcon(texturePath, name="") {
            if (name === "Backpack") return iconBase + "inv_misc_bag_08.png";
            if (name == "Keyring") return iconBase + "inv_misc_key_12.png";
            if (!texturePath) return '';
            const filename = texturePath.split(/[\\\\\\/]/).pop().toLowerCase();
            return iconBase + filename + '.png';
        }

        // 4) Convert Seconds to Days/Hours/Mins
        function formatTime(seconds) {
            if (!seconds || isNaN(seconds)) return "0m";
            let s = parseInt(seconds);
            let d = Math.floor(s / 86400);
            let h = Math.floor((s % 86400) / 3600);
            let m = Math.floor((s % 3600) / 60);
            return (d > 0 ? d + "d " : "") + (h > 0 ? h + "h " : "") + m + "m";
        }

        function formatStat(key, val) {
            if (typeof val !== 'string' || !val.includes(':')) return val;
            const p = val.split(':');
            if (key === "Armor") return p[0];
            return "<font " + (p[2] > 0 ? "style='color:#17dc00'>" : "style='color:white'>") + p[1] + "</font> (" + p[0] + " + <font " + (p[2] > 0 ? "style='color:#17dc00'>" : "style='color:white'>") + p[2] + "</font>)";
        }

        function formatMoney(copper) {
            if (copper === undefined || copper === null || copper === "") return "0 🟠";
            
            let totalCopper = parseInt(copper);
            if (isNaN(totalCopper)) return copper;

            let gold = Math.floor(totalCopper / 10000);
            let silver = Math.floor((totalCopper % 10000) / 100);
            let cp = totalCopper % 100;

            let result = [];
            if (gold > 0) result.push(`${gold} 🟡`);
            if (silver > 0 || gold > 0) result.push(`${silver} ⚪`);
            result.push(`${cp} 🟠`);

            return result.join(' ');
        }

        function hasEqualNumbers(str) {
            const regex = /\b(\d+)\s*\/\s*(?:.*?\1.*)\b/g;
            return regex.test(str);
        }

        function renderProgressBar(label, text, percent, color) {
            return `
            <div class="quest-obj-progress" style="margin-bottom: 8px; width: 50%;">
                <div style="display: flex; justify-content: space-between; font-size: 0.85em; margin-bottom: 2px;">
                    <span>${label}</span>
                    <b style="color: ${color};">${text}</b>
                </div>
                <div class="bar-bg" style="background: rgba(0,0,0,0.3); height: 6px; border-radius: 3px; overflow: hidden; border: 1px solid #333;">
                    <div class="bar-fill" style="width: ${percent}% !important; background: ${color}; height: 100%;"></div>
                </div>
            </div>`;
        }

        function formatWoWText(text) {
            if (!text) return "";

            let formatted = text;

            formatted = formatted.replace(/\\n/g, '<br/>').replace(/<br>/g, '<br/>');

            formatted = formatted.replace(/\|c[a-fA-F0-9]{2}([a-fA-F0-9]{6})(.*?)\|r/g, (match, hex, content) => {
                // ВАЖНО: Экранируем скобки < > внутри текста, чтобы они не стали тегами
                let safeContent = content
                    .replace(/</g, '&lt;')
                    .replace(/>/g, '&gt;');
                    
                return `<span style="color: #${hex};">${safeContent}</span>`;
            });

            return formatted;
        }

        function buildRow(key, val, sectionName) {
            if (key === "Order" || key === "Count" || key === "Texture" || key === "Background" || key === "CoinIcon") return '';
            let content = '';
            let hideLabel = false;

            // Reputation / Skills Progress Bars
            if (val && typeof val === 'object' && (val.Standing || (val.Value && val.Value.includes('/')))) {
                parts = (val.Value || "0/1").split('/');
                const percent = Math.min(100, (parseInt(parts[0]) / (parseInt(parts[1]) || 1)) * 100);
                const color = val.Standing ? (repColors[val.Standing] || "#4a90e2") : "#e2a04a";
                hideLabel = true;
                content = `<div class="bar-container"><strong>${key}${val.Standing ? ': ' + val.Standing : ''}</strong><div class="bar-bg"><div class="bar-fill" style="width: ${percent}%; background: ${color}"></div></div><small>${val.Value}</small></div>`;
            }
            // 1) SpellBook Flattening & Item Logic
            else if (val && typeof val === 'object' && (val.Texture || val.Tooltip || val["Spells"])) {
                const iconPath = getLocalIcon(val.Texture, val.Name || key);
                const hexColor = val.Color ? '#' + val.Color.substring(2) : '#a335ee';
                const quantity = parseInt(val.Quantity || 0);

                let rawTip = (val.Tooltip || '').replace(/<br>/g, '<br/>');

                // 1. First, handle quotes (the original data)
                rawTip = rawTip.replace(/"([^"]+)"/g, '<span style="color:#f1ff04">"$1"</span>');

                // 2. Then, handle Equip lines (adding HTML attributes)
                rawTip = rawTip.replace(/Equip:\s*([^<]+)/gi, 'Equip: <span style="color:#17dc00">$1</span>');

                // 3. Optional: If you want to color "Use:" effects too (usually white or green)
                rawTip = rawTip.replace(/Use:\s*([^<]+)/gi, 'Use: <span style="color:#17dc00">$1</span>');

                // 4. Optional: If you want to color "Chance on hit:" effects too (usually white or green)
                rawTip = rawTip.replace(/Chance on hit:\s*([^<]+)/gi, 'Chance on hit: <span style="color:#17dc00">$1</span>');

                if (sectionName !== "Equipment" && key !== "Item") hideLabel = true;

                replaceString = val.Name+'<br/>';
                rawTip = rawTip.replace(replaceString, '');
                replaceString = key+'<br/>';
                rawTip = rawTip.replace(replaceString, '');

                rawTip = formatWoWText(rawTip);
                
                content = `<div class="item-container"><div class="icon-wrapper"><img src="${iconPath}" class="icon-img" onerror="this.style.opacity='0.2'">${quantity > 1 ? `<span class="item-quantity">${quantity}</span>` : ''}</div><div><span style="color:${hexColor}; font-weight:bold;">${val.Name || key} ${val.Rank || ''}</span><div class="tooltip-box" style="border-color:${hexColor}"><b style="color:${hexColor}">${val.Name || key}</b><br/>${rawTip}</div></div></div>`;
                
                // If it has "Open Spells", skip the "Details" metadata layer
                if (val["Spells"]) {
                    content += '<details><summary>View Spells</summary>' + buildTable(val["Spells"], "Spells") + '</details>';
                } else if (val.Contents) {
                    const itemCount = Object.keys(val.Contents).length;
                    if (itemCount > 0)
                    {
                        content += '<details><summary>Open Contents</summary>' + buildTable(val.Contents, "Contents") + '</details>';
                    }
                    else
                    {
                        content += '<details><summary>Empty</summary></details>';
                    }
                } else if (Object.keys(val).some(k => typeof val[k] === 'object')) {
                    content += '<details><summary>Details</summary>' + buildTable(val, "Sub") + '</details>';
                }
            } 
            else if (val && typeof val === 'object' && val !== null) {

                if (sectionName !== "Equipment" && key !== "Item") hideLabel = true;
                if (sectionName === "MailBox")
                {
                    key = 'Mail #' + key;
                    if (val.Coin) val.Coin = formatMoney(val.Coin);
                    if (val.Item.Quantity === 0) val.Item = 'None';
                }
                if (val.Title && key.match(/^\d+$/) && sectionName !== "AvailableTitles")
                { 
                    // Если ключ — это число (1, 2, 3), пробуем взять Title
                    let questDisplayName = val.Title || `Quest ${key}`;
                    
                    levelHtml = '';
                    if (val.Level > 1)
                    {
                        levelHtml += `<div style="margin-bottom:2px;">Level: ${val.Level}`;
                    }

                    let rewardsHtml = '';
                    const rewardSource = val.Choice || val.Reward || val.Rewards || val.RewardMoney;
                    
                    if (val.Tasks)
                    {
                        rewardsHtml += '<div style="margin-top:5px; padding-left:10px; border-left: 2px solid #555;">';
                        rewardsHtml += `<b style="font-size:0.8em; color:#aaa;">Objectives:</b><br/>`;
                        
                        Object.values(val.Tasks).forEach(task => {
                            const progressMatch = task.Note.match(/(.+):\s*(\d+)\s*\/\s*(\d+)/);
                            const statusMatch = !progressMatch ? task.Note.match(/(.+):\s*([a-zA-Zа-яА-ЯёЁ\s]+)\s*\/\s*([a-zA-Zа-яА-ЯёЁ\s]+)/) : null;

                            if (progressMatch) {
                                const itemName = progressMatch[1];
                                const current = parseInt(progressMatch[2]);
                                const max = parseInt(progressMatch[3]);
                                const percent = Math.min(100, (current / max) * 100);
                                const barColor = current >= max ? '#17dc00' : '#ffb400';

                                rewardsHtml += renderProgressBar(itemName, `${current} / ${max}`, percent, barColor);

                            } else if (statusMatch) {
                                const itemName = statusMatch[1];
                                const currentStatus = statusMatch[2].trim();
                                const targetStatus = statusMatch[3].trim();
                                
                                const isDone = currentStatus.toLowerCase() === targetStatus.toLowerCase();
                                const percent = isDone ? 100 : 50; // Можно поставить 50% если еще в процессе
                                const barColor = isDone ? '#17dc00' : '#4a90e2'; // Синий для процесса репутации

                                rewardsHtml += renderProgressBar(itemName, `${currentStatus} / ${targetStatus}`, percent, barColor);

                            } else {
                                rewardsHtml += `<p style="font-size: 0.9em; margin: 2px 0; color: #ccc;">• ${task.Note}</p>`;
                            }
                        });
                        rewardsHtml += '</div>';
                    }

                    if (rewardSource)
                    {
                        rewardsHtml += '<div style="margin-top:5px; padding-left:10px; border-left: 2px solid #555;">';
                        rewardsHtml += `<b style="font-size:0.8em; color:#aaa;">${val.Choice ? 'Reward Choice:' : 'Rewards:'}</b><br/>`;
                        
                        Object.values(rewardSource).forEach(item => {
                            const hexColor = item.Color ? '#' + item.Color.substring(2) : '#ffffff';
                            const qty = parseInt(item.Quantity || 1);

                            rewardsHtml += `
                                <div class="item-container" style="margin-bottom:2px; background: rgba(0,0,0,0.2);">
                                    <span style="color:${hexColor}; font-size:0.9em;">${qty > 1 ? `${qty} x </span>` : ''}[${item.Name}]</span>
                                </div>`;
                        });
                        if (val.RewardMoney)
                        {
                            const money = formatMoney(val.RewardMoney);
                            rewardsHtml += `<span>${money}</span>`;
                        }
                        rewardsHtml += '</div>';
                    }

                    if (val.Complete === 1)
                    {
                        rewardsHtml += `<span style="color:green;">Completed</span>`;
                    }

                    content = `
                        <details style="margin-bottom: 5px;">
                            <summary><b>${questDisplayName}</b> <span style="color:#888; font-size:0.8em;">${val.Tag || ''}</span></summary>
                            <div style="padding: 5px 15px;">
                                <p style="font-style:italic; color:#ccc; margin:0;">${val.Header || ''}</p>
                                ${levelHtml}
                                ${rewardsHtml}
                            </div>
                        </details>`;
                }
                else
                {
                    content = '<details><summary>' + key + '</summary>' + buildTable(val, key) + '</details>';
                }
                // content = '<details><summary>' + key + '</summary>' + buildTable(val, key) + '</details>';
            }
            else if (val && typeof val === 'string' && val.includes(':') && (sectionName === "Professions" || sectionName === "Class Skills" || sectionName === "Secondary Skills" || sectionName === "Weapon Skills" || sectionName === "Armor Proficiencies" || sectionName === "Languages")) {
                const parts = val.split(':');
                const current = parseInt(parts[0]);
                const max = parseInt(parts[1]);
                
                // Вычисляем процент заполнения
                const percent = Math.min(100, (current / (max || 1)) * 100);
                
                // Скрываем текстовую метку слева, чтобы сделать полосу на всю ширину
                hideLabel = true; 
                
                content = `
                    <div class="bar-container" style="margin: 5px 0;">
                        <div style="display: flex; justify-content: space-between; font-size: 0.9em; margin-bottom: 2px;">
                            <b style="color: #eee;">${key.replace(/_/g, ' ')}</b>
                            <span style="color: #ffb400;">${current} / ${max}</span>
                        </div>
                        <div class="bar-bg" style="background: #000; height: 10px; border: 1px solid #333;">
                            <div class="bar-fill" style="width: ${percent}% !important; background: #e2a04a; height: 100%;"></div>
                        </div>
                    </div>`;
            }
            else if (sectionName === "Money")
            {
                hideLabel = true;
                if (key === "Gold") val = val + ' 🟡';
                if (key === "Silver") val = val + ' ⚪';
                if (key === "Copper") val = val + ' 🟠';
                content = val;
            }
            else
            { 
                content = (sectionName === "Stats" || sectionName === "Resists") ? formatStat(key, val) : val; 
            }
            
            return `<tr><td class="${hideLabel ? 'hidden-label' : 'key-label'}">${key.replace(/_/g, ' ')}</td><td colspan="${hideLabel ? '2' : '1'}">${content}</td></tr>`;
        }

        function buildTable(data, sectionName) {
            if (!data || typeof data !== 'object') return '';
            let html = '<h2>' + sectionName + '</h2><table>';
            let keys = Object.keys(data);

            keys.sort((a, b) => {
                if (a === "PointsSpent") return -1;
                if (b === "PointsSpent") return 1;
                const orderA = data[a]?.Order ? parseInt(data[a].Order) : 999;
                const orderB = data[b]?.Order ? parseInt(data[b].Order) : 999;
                return orderA - orderB;
            });

            if (sectionName === "Equipment") {
                slotOrder.forEach(slot => {
                    let f = keys.find(k => k.toLowerCase() === slot.toLowerCase());
                    if (f) html += buildRow(f, data[f], sectionName);
                });
            } else if (sectionName === "QuestsCompleted") {
                html = '<h2>' + sectionName + '</h2>';
                html += '<details><summary>Open List</summary><table>';
                keys.forEach(k => {
                    html += buildRow(k, data[k], sectionName);
                });
                return html += '</table></details>';
            } else {
                keys.forEach(k => {
                    if (sectionName === "Reputation" && k === "Count") return;
                    html += buildRow(k, data[k], sectionName);
                });
            }
            return html + '</table>';
        }

        const menu = document.getElementById('menu');
        Object.keys(profileData).forEach(realm => {
            Object.keys(profileData[realm]).forEach(name => {
                const card = document.createElement('div');
                card.className = 'char-link';
                card.innerHTML = `<strong>${name}</strong><br><small>${realm}</small>`;
                card.onclick = () => {
                    const d = profileData[realm][name];
                    document.getElementById('charHeading').innerText = name;
                    
                    const pType = d.Power || 'Mana';
                    const pColor = pType === 'Rage' ? '#cc2121' : (pType === 'Energy' ? '#f1ff04' : '#4a90e2');
                    
                    // 2 & 3) Pulled Stats to Header
                    let posX = d.coordX ? parseFloat(d.coordX).toFixed(1) : null;
                    let posY = d.coordY ? parseFloat(d.coordY).toFixed(1) : null;
                    let coordsText = (posX && posY) ? ` [${posX} : ${posY}]` : "";
                    let header = `
                        <div class="char-header">
                            <div class="char-meta">
                                <span><b>Level ${d.Level || '??'}</b> ${d.Sex || ''} ${d.Race || ''} ${d.Class || ''}</span>
                                <span ${d.Faction === 'Alliance' ? "style='color:#4a90e2'" : "style='color:#ff0000'"}>${d.Faction ? '&lt;' + d.Faction + '&gt;' : ''}</span>
                            </div>
                            <div class="resource-container">
                                <div class="bar-container"><strong>Health</strong><div class="bar-bg"><div class="bar-fill" style="background:#17dc00"></div></div><small>${d.Health || ''}</small></div>
                                <div class="bar-container"><strong>${pType}</strong><div class="bar-bg"><div class="bar-fill" style="background:${pColor}"></div></div><small>${d['Mana'] || ''}</small></div>
                            </div>
                            <div class="location-box">📍 ${d.Zone || ''} ${d.SubZone ? ' - ' + d.SubZone : ''} ${coordsText}</div> <div class="location-box"> 🟢 ${'Hearthstone - ' + d.Hearth || ''} </div>
                            <div class="time-box">/PLAYED 🕒 Total: ${formatTime(d.TimePlayed)} | Level: ${formatTime(d.TimeLevelPlayed)}</div>
                        </div>`;

                    let out = header;
                    const priority = ['Stats', 'Resists', 'Equipment', 'Inventory', 'Money', 'Bank', 'MailBox', 'Skills', 'SpellBook', 'Talents', 'Buffs', 'Professions', 'Pets', 'Reputation', 'Quests', 'QuestsCompleted', 'Guild', 'Honor', 'Melee Attack', 'MailDateUTC'];
                    priority.forEach(s => {
                        if(d[s]) {

                            if (s !== 'Money') {
                                out += buildTable(d[s], s);
                            }

                            if (s === 'Money') {
                                // Собираем всё в медь: золото * 10000 + серебро * 100 + медь
                                const totalCopper = 
                                    (parseInt(d[s].Gold) || 0) * 10000 + 
                                    (parseInt(d[s].Silver) || 0) * 100 + 
                                    (parseInt(d[s].Copper) || 0);

                                out += `
                                <table style="margin-top: -21px; border-top: none;">
                                    <tr>
                                        <td>${formatMoney(totalCopper)}</td>
                                    </tr>
                                </table>`;
                                
                                // out += `<p><b>Money:</b> ${formatMoney(totalCopper)}</p>`;
                            }

                            if (s === 'Stats') {
                                out += `
                                <table style="margin-top: -21px; border-top: none;">
                                    <tr>
                                        <td class="key-label">Crit Chance</td>
                                        <td style="color: ${parseFloat(d["CritPercent"]) > 0 ? '#17dc00' : '#ffffff'};">${d["CritPercent"] ? d["CritPercent"] + '%' : '0%'}</td>
                                    </tr>
                                    <tr>
                                        <td class="key-label">Dodge Chance</td>
                                        <td style="color: ${parseFloat(d["DodgePercent"]) > 0 ? '#17dc00' : '#ffffff'};">${d["DodgePercent"] ? d["DodgePercent"] + '%' : '0%'}</td>
                                    </tr>
                                    ${d["BlockPercent"] ? `
                                    <tr>
                                        <td class="key-label">Block Chance</td>
                                        <td style="color: ${parseFloat(d["BlockPercent"]) > 0 ? '#17dc00' : '#ffffff'};">${d["BlockPercent"] ? d["BlockPercent"] + '%' : '0%'}</td>
                                    </tr>` : ''}
                                    <tr>
                                        <td class="key-label">Dmg Mitigation</td>
                                        <td style="color: ${parseFloat(d["MitigationPercent"]) > 0 ? '#17dc00' : '#ffffff'};">${d["MitigationPercent"] ? d["MitigationPercent"] + '%' : '0%'}</td>
                                    </tr>
                                    <tr>
                                        <td class="key-label">Defense</td>
                                        <td style="color: ${d["Defense"] > 0 ? '#17dc00' : '#ffffff'};">${d["Defense"] ? d["Defense"] : '0'}</td>
                                    </tr>
                                    <tr>
                                        <td class="key-label">Talent Points</td>
                                        <td style="color: ${d["TalentPoints"] > 0 ? '#17dc00' : '#ffffff'};">${d["TalentPoints"] ? d["TalentPoints"] : '0'}</td>
                                    </tr>
                                    <tr>
                                        <td class="key-label">Updated</td>
                                        <td>${d["DateUpdated"] || ''}</td>
                                    </tr>
                                </table>`;
                                // out += `<div class="time-box">/PLAYED 🕒 Total: ${formatTime(d.TimePlayed)} | Level: ${formatTime(d.TimeLevelPlayed)}</div>`
                            }
                        }
                    });
                    
                    Object.keys(d).forEach(k => {
                        const skip = [...priority, 'Race','Class','Level','Sex','Health','Mana','Rage','Energy','Power','Zone','SubZone','TimePlayed','TimeLevelPlayed'];
                        if(!skip.includes(k)) {
                            if(typeof d[k] === 'object') out += buildTable(d[k], k);
                            else out += `<p><b>${k}:</b> ${d[k]}</p>`;
                        }
                    });
                    document.getElementById('content').innerHTML = out;
                };
                menu.appendChild(card);
            });
        });
    </script>
</body>
</html>
"""
    final_html = html_template.replace('DATA_PLACEHOLDER', json_data).replace('ICON_PATH_PLACEHOLDER', ICON_BASE_PATH)
    with open(output_filename, 'w', encoding='utf-8') as f:
        f.write(final_html)

process_files()