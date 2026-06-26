import std/options
import std/json
import std/sequtils

import ../../src/semba/protojson
import ../../src/semba/model_stable/resources
import ../../src/semba/model_stable/mission
import ../../src/semba/model_stable/dungeon
import ../../src/semba/model_stable/dungeon_area_item
import ../../src/semba/model_stable/city
import ./utils


proc testDungeonFinish() =
  var ctx = getInMemorySembaCtx()
  let res = protoJsonTo(ctx.sembaCall("/dungeon/finish", %*{
    "dungeonDifficultyId": 10920201
  }), Option[ChangedResourcesResponse])

  doAssert(res.isSome)

  let changedResources = res.get().changedResources

  let clearDungeonMissionIdx = changedResources.missions.findIt(it.missionId == 1041049)

  doAssert(clearDungeonMissionIdx != -1)

  let clearDungeonMission = changedResources.missions[clearDungeonMissionIdx]

  doAssert(clearDungeonMission.count == some(1))

  doAssert(getMissionsWithIds(ctx.db, [clearDungeonMission.missionId]) == @[clearDungeonMission])


proc testGetMdDungeonAreaItemsForCity() =
  var ctx = getInMemorySembaCtx()

  let res = getMdDungeonAreaItemsForCity(ctx.db, cityIdShinagawa.int)

  doAssert(res.findIt(
    it.dungeonAreaItemId == 10101 and it.areaItemRewardIds == @[90301, 91301, 201, 971001]
  ) != -1)

  doAssert(res.findIt(
    it.dungeonAreaItemId == 310101 and it.areaItemRewardIds == @[310101, 302, 401, 501]
  ) != -1)


proc testIsDungeonBossBattle(savesDir: string) =
  var ctx = getInMemorySembaCtx()

  loadSaveFile(ctx, savesDir, "savedungeon")

  const dungeonId = 109202

  const bossEntityId = 5

  doAssert(isDungeonBossBattle(ctx.db, dungeonId, [bossEntityId]))


proc testSuiteDungeon*(savesDir: string) =
  testDungeonFinish()
  testGetMdDungeonAreaItemsForCity()
  testIsDungeonBossBattle(savesDir)