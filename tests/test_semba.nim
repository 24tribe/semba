import std/cmdline

import test_adventure
import test_battle
import test_character
import test_extra
import test_follow
import test_graffiti_art
import test_reward
import test_semba_private
import test_tip
import test_mission
import test_status
import test_shop
import test_happy_worker
import test_dungeon
import test_tension_card


let saves_dir = paramStr(1)
testSuiteExtra()
testSuiteAdventure(saves_dir)
testSuiteBattle(saves_dir)
testSuiteCharacter()
testSuiteReward()
testSuiteSembaPrivate()
testSuiteTip()
testSuiteGraffitiArt()
testSuiteMission(saves_dir)
testSuiteStatus()
testSuiteShop()
testSuiteHappyWorker(saves_dir)
testSuiteFollow()
testSuiteDungeon()
testSuiteTensionCard()