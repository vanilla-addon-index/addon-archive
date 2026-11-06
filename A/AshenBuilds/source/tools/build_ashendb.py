#!/usr/bin/env python3
from __future__ import annotations
import argparse, brotli, datetime as dt, json, os, re, shutil, sqlite3, sys, urllib.request
from pathlib import Path

REPO = "Xian55/tortoise-db-viewer"
VERSION_URL = f"https://raw.githubusercontent.com/{REPO}/cdn/data/version.json"

SLOT_MAP = {
  1:"HEAD",2:"NECK",3:"SHOULDER",4:"SHIRT",5:"CHEST",6:"WAIST",7:"LEGS",8:"FEET",
  9:"WRIST",10:"HANDS",11:"FINGER",12:"TRINKET",13:"WEAPON",14:"SHIELD",15:"RANGED",
  16:"BACK",17:"TWOHAND",18:"BAG",19:"TABARD",20:"ROBE",21:"MAINHAND",22:"OFFHAND",
  23:"HOLDABLE",24:"AMMO",25:"THROWN",26:"RANGEDRIGHT",28:"RELIC"
}
EQUIPPABLE = set(SLOT_MAP)
STAT_KEY = {
 "str":"str","agi":"agi","sta":"sta","int":"int","spi":"spi","armor":"armor",
 "firRes":"fireRes","natRes":"natureRes","froRes":"frostRes","shaRes":"shadowRes","arcRes":"arcaneRes",
 "ap":"ap","rangedAp":"rap","feralAp":"feralAp","heal":"healing","sp":"spellPower",
 "spHoly":"holyPower","spFire":"firePower","spNature":"naturePower","spFrost":"frostPower",
 "spShadow":"shadowPower","spArcane":"arcanePower","mp5":"mp5","hp5":"hp5","block":"block",
 "crit":"crit","spCrit":"spellCrit","hit":"hit","spHit":"spellHit","parry":"parry","dodge":"dodge",
 "haste":"haste","def":"defense","wSwords":"swordSkill","wAxes":"axeSkill","wMaces":"maceSkill",
 "wDaggers":"daggerSkill","wPolearms":"polearmSkill","w2hSwords":"twoHandSwordSkill",
 "w2hAxes":"twoHandAxeSkill","w2hMaces":"twoHandMaceSkill","wBows":"bowSkill","wGuns":"gunSkill",
 "wCrossbows":"crossbowSkill","leech":"leech","runSpeed":"runSpeed","swimSpeed":"swimSpeed",
 "mountSpeed":"mountSpeed","dps":"dps","fishing":"fishing"
}

CLASS_NAMES = {0:"Consumable",1:"Container",2:"Weapon",3:"Gem",4:"Armor",5:"Reagent",6:"Projectile",7:"Trade Goods",8:"Generic",9:"Recipe",10:"Money",11:"Quiver",12:"Quest",13:"Key",14:"Permanent",15:"Miscellaneous"}


def getcol(row, *names, default=0):
    keys = row.keys()
    for n in names:
        if n in keys and row[n] is not None: return row[n]
    return default

def lua_str(v):
    s = str(v or "").replace("\\", "\\\\").replace('"','\\"').replace("\r"," ").replace("\n"," ")
    return '"'+s+'"'

def download(url: str, path: Path):
    print("Downloading", url)
    req = urllib.request.Request(url, headers={"User-Agent":"AshenDB-Builder/0.1"})
    with urllib.request.urlopen(req, timeout=120) as r, path.open("wb") as f:
        shutil.copyfileobj(r, f)

def fetch_database(work: Path, keep=False) -> tuple[Path,str]:
    meta_path = work/"version.json"
    download(VERSION_URL, meta_path)
    meta = json.loads(meta_path.read_text("utf-8"))
    version = meta["version"]
    br = work/"tortoise.sqlite.br"
    db = work/"tortoise.sqlite"
    url = f"https://cdn.jsdelivr.net/gh/{REPO}@cdn-v{version}/data/tortoise.sqlite.br"
    download(url, br)
    print("Decompressing database...")
    db.write_bytes(brotli.decompress(br.read_bytes()))
    if not keep: br.unlink(missing_ok=True)
    return db, version

def weapon_type(item):
    cls = int(getcol(item,"class",default=0) or 0)
    sub = int(getcol(item,"subclass",default=0) or 0)
    if cls != 2: return ""
    return {0:"Axe",1:"Two-Hand Axe",2:"Bow",3:"Gun",4:"Mace",5:"Two-Hand Mace",6:"Polearm",7:"Sword",8:"Two-Hand Sword",10:"Staff",13:"Fist",15:"Dagger",16:"Thrown",18:"Crossbow",19:"Wand",20:"Fishing Pole"}.get(sub, "Weapon")

def export(db_path: Path, addon: Path, db_version: str, shard_size=750):
    con = sqlite3.connect(str(db_path)); con.row_factory = sqlite3.Row
    tables = {r[0] for r in con.execute("select name from sqlite_master where type='table'")}
    if "items" not in tables or "item_stats" not in tables:
        raise RuntimeError("Database is missing items/item_stats tables")
    stats = {}
    skipped_stats = 0
    for r in con.execute("select item, stat, value from item_stats"):
        item_id, stat_name, stat_value = r[0], r[1], r[2]
        if item_id is None or stat_name is None or stat_value is None:
            skipped_stats += 1
            continue
        key = STAT_KEY.get(str(stat_name))
        if key and stat_value != 0:
            stats.setdefault(int(item_id), {})[key] = stat_value
    icons = {}
    if "item_display_info" in tables:
        for r in con.execute("select ID, icon from item_display_info"):
            if r[0] is None:
                continue
            icons[int(r[0])] = r[1] or "INV_Misc_QuestionMark"
    sources = {}
    skipped_sources = 0
    if "item_sources" in tables:
        for r in con.execute("select item, source from item_sources order by item, source"):
            item_id, source = r[0], r[1]
            if item_id is None or source is None:
                skipped_sources += 1
                continue
            source = str(source).strip()
            if not source:
                skipped_sources += 1
                continue
            sources.setdefault(int(item_id), []).append(source)
    items=[]
    for r in con.execute("select * from items order by entry"):
        inv = int(getcol(r,"inventory_type","InventoryType",default=0) or 0)
        if inv not in EQUIPPABLE: continue
        iid=int(getcol(r,"entry","id"));
        if not iid: continue
        name=getcol(r,"name",default=f"Item {iid}")
        disp=int(getcol(r,"display_id","displayid",default=0) or 0)
        item={
          "id":iid,"name":name,"quality":int(getcol(r,"quality",default=1) or 1),"slot":SLOT_MAP[inv],
          "req":int(getcol(r,"required_level","requiredlevel",default=0) or 0),
          "ilvl":int(getcol(r,"item_level","itemlevel",default=0) or 0),"icon":icons.get(disp,"INV_Misc_QuestionMark"),
          "class":int(getcol(r,"class",default=0) or 0),"subclass":int(getcol(r,"subclass",default=0) or 0),
          "armor":int(getcol(r,"armor",default=0) or 0),"set":int(getcol(r,"set_id","itemset",default=0) or 0),
          "allowClass":int(getcol(r,"allowable_class","allowableclass",default=-1) or -1),
          "allowRace":int(getcol(r,"allowable_race","allowablerace",default=-1) or -1),
          "bind":int(getcol(r,"bonding",default=0) or 0),"unique":int(getcol(r,"max_count","maxcount",default=0) or 0),
          "delay":int(getcol(r,"delay",default=0) or 0),"dmin":float(getcol(r,"dmg_min1",default=0) or 0),
          "dmax":float(getcol(r,"dmg_max1",default=0) or 0),"weapon":weapon_type(r),
          "stats":stats.get(iid,{}),"sources":sources.get(iid,[])
        }
        items.append(item)
    data_dir=addon/"Data"/"Items"
    if data_dir.exists(): shutil.rmtree(data_dir)
    data_dir.mkdir(parents=True)
    toc_lines=["## Interface: 11200","## Title: AshenDB","## Notes: Shared Turtle WoW database for Ashen addons","## Author: Casey / The Ashen Banner","## Version: 0.1.0","## SavedVariables: AshenDB_Settings","Core.lua","Data/Manifest.lua"]
    order=[]
    for start in range(0,len(items),shard_size):
        shard=items[start:start+shard_size]
        n=start//shard_size+1
        fn=f"Data/Items/Items_{n:03d}.lua"; toc_lines.append(fn)
        with (addon/fn).open("w",encoding="utf-8",newline="\n") as f:
            f.write("local I = AshenDB.Items\n")
            for x in shard:
                st="{"+",".join(f"{k}={v:g}" for k,v in sorted(x["stats"].items()))+"}"
                src="{"+",".join(lua_str(s) for s in x["sources"])+"}"
                # compact positional format: name,q,slot,req,ilvl,icon,class,subclass,armor,set,classMask,raceMask,bind,unique,delay,dmin,dmax,weapon,stats,sources
                f.write(f'I[{x["id"]}]={{{lua_str(x["name"])},{x["quality"]},{lua_str(x["slot"])},{x["req"]},{x["ilvl"]},{lua_str(x["icon"])},{x["class"]},{x["subclass"]},{x["armor"]},{x["set"]},{x["allowClass"]},{x["allowRace"]},{x["bind"]},{x["unique"]},{x["delay"]},{x["dmin"]:g},{x["dmax"]:g},{lua_str(x["weapon"])},{st},{src}}}\n')
                order.append(x["id"])
    order_file=addon/"Data"/"ItemOrder.lua"; toc_lines.append("Data/ItemOrder.lua")
    with order_file.open("w",encoding="utf-8",newline="\n") as f:
        f.write("AshenDB.ItemOrder={")
        for i in range(0,len(order),500): f.write("\n"+",".join(map(str,order[i:i+500]))+",")
        f.write("\n}\n")
    manifest={"database":"Tortoise-WoW","version":db_version,"itemCount":len(items),"shards":(len(items)+shard_size-1)//shard_size,"generatedAt":dt.datetime.now(dt.timezone.utc).isoformat()}
    (addon/"Data"/"Manifest.lua").write_text("AshenDB.Manifest="+json.dumps(manifest,separators=(",",":" )).replace('"database"','database').replace('"version"','version').replace('"itemCount"','itemCount').replace('"shards"','shards').replace('"generatedAt"','generatedAt')+"\n",encoding="utf-8")
    (addon/"AshenDB.toc").write_text("\n".join(toc_lines)+"\n",encoding="utf-8")
    print(f"Exported {len(items):,} equippable items in {manifest['shards']} shards")
    if skipped_stats:
        print(f"Skipped {skipped_stats:,} incomplete item-stat rows")
    if skipped_sources:
        print(f"Skipped {skipped_sources:,} incomplete item-source rows")
    return manifest

def main():
    ap=argparse.ArgumentParser(description="Download Tortoise DB and build AshenDB item addon")
    ap.add_argument("--addon-dir",default=str(Path(__file__).resolve().parents[1]/"Data"/"AshenDB"))
    ap.add_argument("--database",help="Use an existing tortoise.sqlite instead of downloading")
    ap.add_argument("--keep",action="store_true")
    args=ap.parse_args()
    addon=Path(args.addon_dir).resolve(); work=Path(__file__).resolve().parent/"work"; work.mkdir(parents=True,exist_ok=True)
    if args.database: db=Path(args.database).resolve(); version="local"
    else: db,version=fetch_database(work,args.keep)
    export(db,addon,version)
    print("Item database written to", addon)
if __name__=="__main__": main()
