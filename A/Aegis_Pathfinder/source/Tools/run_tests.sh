#!/bin/sh
# Every check that can run without a WoW client.
#
#   sh Tools/run_tests.sh
#
# Run from the repository root. Exits non-zero if anything fails.
set -e

cd "$(dirname "$0")/.."

echo "== static verification =="
python3 Tools/verify.py

echo
echo "== profession source document =="
python3 Tools/build/convert_professions.py --check

echo
echo "== talent builds against the game's trees =="
python3 Tools/build/talent_builds.py --check

echo
echo "== lua tests =="
lua5.1 Tools/tests/test_load.lua
lua5.1 Tools/tests/test_theme.lua
lua5.1 Tools/tests/test_professions.lua
lua5.1 Tools/tests/test_guideengine.lua
lua5.1 Tools/tests/test_navcallout.lua
lua5.1 Tools/tests/test_dungeons.lua
lua5.1 Tools/tests/test_dungeonguides.lua
lua5.1 Tools/tests/test_classguides.lua
lua5.1 Tools/tests/test_attunements.lua
lua5.1 Tools/tests/test_filtertags.lua
lua5.1 Tools/tests/test_smartskip.lua
lua5.1 Tools/tests/test_yourplace.lua
lua5.1 Tools/tests/test_itemscore.lua
lua5.1 Tools/tests/test_gearframe.lua
lua5.1 Tools/tests/test_gearadvisor.lua
lua5.1 Tools/tests/test_gearfinder.lua
lua5.1 Tools/tests/test_automation.lua
lua5.1 Tools/tests/test_maps.lua
lua5.1 Tools/tests/test_extras.lua
lua5.1 Tools/tests/test_talentadvisor.lua
lua5.1 Tools/tests/test_talentwindow.lua
lua5.1 Tools/tests/test_talentmodern.lua
lua5.1 Tools/tests/test_guidelist.lua
lua5.1 Tools/tests/test_guidebrowser.lua
lua5.1 Tools/tests/test_materials.lua
lua5.1 Tools/tests/test_craftplanner.lua
lua5.1 Tools/tests/test_craftroute.lua
lua5.1 Tools/tests/test_partysync.lua
lua5.1 Tools/tests/test_activeframes.lua
lua5.1 Tools/tests/test_nextguide.lua
lua5.1 Tools/tests/test_routes.lua
lua5.1 Tools/tests/test_zoneguide.lua
lua5.1 Tools/tests/test_setup.lua
lua5.1 Tools/tests/test_objectivetabs.lua
lua5.1 Tools/tests/test_objectivepanel.lua
lua5.1 Tools/tests/test_options.lua
lua5.1 Tools/tests/test_stacking.lua
lua5.1 Tools/tests/test_scrolling.lua
lua5.1 Tools/tests/test_minimap.lua
lua5.1 Tools/tests/test_navigation.lua
lua5.1 Tools/tests/test_professionsteps.lua

echo
echo "All offline checks passed."
echo "Not covered here: anything that needs a running 1.12 client -- whether the"
echo "UI actually looks like the concept, whether textures load, whether the"
echo "bundled fonts render. Those need an in-game pass."
