import std/options
import std/json
import std/sequtils

import ../../src/semba/protojson
import ../../src/semba/api_stable/battle
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

  doAssert(clearDungeonMission.count == 1)

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


proc testDungeonBossDropsDungeonItems(savesDir: string) =
  var ctx = getInMemorySembaCtx()

  loadSaveFile(ctx, savesDir, "savedungeon")

  const dungeonId = 109202

  const bossEntityId = 5

  doAssert(isDungeonBossBattle(ctx.db, dungeonId, [bossEntityId]))

  doAssert(ctx.sembaCall("/dungeon/battle/start", %*{
    "dungeonDifficultyId": 10920201, "entityIds": [ 5 ],
    "lineCharacterIds": [ 101101, 100801, 100201 ], "advantageType": "advantage", "isAttackHit": true
  }) != nil)

  let res = ctx.sembaCall("/battle/finish", %*{
    "characterUpdates": [ { "characterId": 100201, "hp": 470 }, { "characterId": 101101 }, { "characterId": 100801 } ],
    "battleTaskTopics": [
      { "type": "qte", "count": 20 }, { "type": "heal_hp", "count": 50 }, { "type": "special_attack", "count": 4 }
    ],
    "encounteredEnemyIds": [ 209204, 209104 ],
    "battleTimeSecond": 59,
    "taskConditionResult": {
      "usedSkills": [
        { "characterSkillId": 1011016, "count": 4 }, { "characterSkillId": 1008016, "count": 3 },
        { "characterSkillId": 1002016, "count": 13 }, { "characterSkillId": 1008014, "count": 1 },
        { "characterSkillId": 1002014, "count": 3 }
      ],
      "enemyStabilityBreaks": [ { "enemyId": 209104, "count": 3 }, { "enemyId": 209204, "count": 11 } ]
    }
  }).protoJsonTo(Option[BattleFinishResponse])

  doAssert(res.isSome)

  let changedResources = res.get().changedResources

  doAssert(changedResources.items.findIt(it.itemId == 3101 and it.quantity == 2) != -1)
  doAssert(changedResources.items.findIt(it.itemId == 3102 and it.quantity == 2) != -1)
  doAssert(changedResources.items.findIt(it.itemId == 3103 and it.quantity == 2) != -1)
  doAssert(changedResources.items.findIt(it.itemId == 3104 and it.quantity == 2) != -1)


proc testSuiteDungeon*(savesDir: string) =
  testDungeonFinish()
  testGetMdDungeonAreaItemsForCity()
  testDungeonBossDropsDungeonItems(savesDir)
