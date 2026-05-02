import std/cmdline

import test_adventure
import test_battle
import test_character
import test_extra
import test_graffiti_art
import test_reward
import test_semba_private
import test_tip
import test_mission
import test_status
import test_shop
import test_happy_worker


let saves_dir = paramStr(1)
testSuiteAdventure(saves_dir)
testSuiteBattle(saves_dir)
testSuiteCharacter()
testSuiteExtra()
testSuiteReward()
testSuiteSembaPrivate()
testSuiteTip()
testSuiteGraffitiArt()
testSuiteMission()
testSuiteStatus()
testSuiteShop()
testSuiteHappyWorker()