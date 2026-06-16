import ./all/test_adventure
import ./all/test_battle
import ./all/test_character
import ./all/test_dungeon
import ./all/test_extra
import ./all/test_follow
import ./all/test_graffiti_art
import ./all/test_happy_worker
import ./all/test_mission
import ./all/test_reward
import ./all/test_semba_private
import ./all/test_shop
import ./all/test_status
import ./all/test_tension_card
import ./all/test_tip


when isMainModule:
  let savesDir = "test_saves"
  testSuiteAdventure(savesDir)
  testSuiteBattle(savesDir)
  testSuiteCharacter(savesDir)
  testSuiteDungeon(savesDir)
  testSuiteExtra(savesDir)
  testSuiteFollow(savesDir)
  testSuiteGraffitiArt(savesDir)
  testSuiteHappy_worker(savesDir)
  testSuiteMission(savesDir)
  testSuiteReward(savesDir)
  testSuiteSembaPrivate(savesDir)
  testSuiteShop(savesDir)
  testSuiteStatus(savesDir)
  testSuiteTensionCard(savesDir)
  testSuiteTip(savesDir)