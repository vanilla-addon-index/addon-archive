#!/usr/bin/python3
from string import Template
import sys
import os.path
import glob
from src.parser import parse_file

expansion = 0
world_db_name = "tw_world_ptr"
turtle_version = 0

LUA_FILE = 'CharacterProfiler.lua'
LUA_PATTERN = 'CharacterProfiler*.lua'

if sys.stdin and sys.stdin.isatty():
    if len(sys.argv) == 2:
        if sys.argv[1].isdecimal():
            expansion = sys.argv[1]
    elif len(sys.argv) == 3:
        if sys.argv[1].isdecimal():
            expansion = int(sys.argv[1])
        if not sys.argv[2].isdecimal():
            world_db_name = sys.argv[2]
    elif len(sys.argv) == 4:
        if sys.argv[1].isdecimal():
            expansion = int(sys.argv[1])
        if not sys.argv[2].isdecimal():
            world_db_name = sys.argv[2]
        if sys.argv[3].isdecimal():
            turtle_version = int(sys.argv[3])

def process_files():
    lua_files = glob.glob(LUA_PATTERN)
    
    if not lua_files:
        print("No Lua files found!")
        return

    for file_path in lua_files:
        print(f"Processing: {file_path}")

        try:
            if os.path.isfile(file_path):
                with open(file_path, encoding='utf8') as file:
                    parse_file(file.read(), expansion, world_db_name, turtle_version)

        except Exception as e:
            print(f"Parsing error in {file_path}: {e}")

process_files()
