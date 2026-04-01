import std/assertions
import std/json
import std/options
import std/algorithm

import utils
import ../model_stable/battle
import ../model_stable/challenge_task
import ../model_stable/challenge_progress


proc test_endrone_battle_start(saves_dir: string) =
  var ctx = getInMemorySembaCtx()

  loadSaveFile(ctx, saves_dir, "before endrone fight bug")

  let res = sembaCall(ctx, "/battle/start", %*{
    "battleEntryIds": [ 1000004 ],
    "lineCharacterIds": [ 101101, 100801, 100201 ],
    "battleTriggers": [ { "triggerType": "action_sequence" } ],
    "currentLocation": {
      "areaType": 1,
      "direction": 1,
      "positionCoordinates": { "x": 99.96959, "y": 11.0309982, "z": 0.120423831 },
      "areaKeyId": 300401
    },
    "bloodStainLocation": {
      "areaKeyId": 300401,
      "areaType": 1,
      "positionCoordinates": { "x": 99.96959, "y": 11.0309982, "z": 0.120423831 }
    }
  })

  doAssert(res != nil)

  let battleParameters = to(res["battleParameters"], seq[BattleParameter])

  doAssert(battleParameters == to(%*[{
    "id": 1000004,
    "enemies": [
      {
        "id": 257101,
        "attack": 210,
        "defense": 100,
        "hp": 85536,
        "hpStackCount": 3
      }
    ]
  }], seq[BattleParameter]))


proc test_battle_finish_challenge_data(saves_dir: string) =
  var ctx = getInMemorySembaCtx()

  loadSaveFile(ctx, saves_dir, "before first tutorial battle")

  discard sembaCall(ctx, "/battle/start", %*{
    "battleEntryIds": [ 1000001 ],
    "lineCharacterIds": [ 100101 ],
    "battleTriggers": [ { "triggerType": "action_sequence" } ],
    "currentLocation": {
      "areaType": 1, "direction": 5,
      "positionCoordinates": { "x": -7.554892, "y": 25.024178, "z": -19.684603 },
      "areaKeyId": 300203
    },
    "bloodStainLocation": {
      "areaKeyId": 300203, "areaType": 1,
      "positionCoordinates": { "x": -6.513234, "y": 25.024178, "z": -25.30114 }
    }
  })

  let res = sembaCall(ctx, "/battle/finish", %*{
    "characterUpdates": [ { "characterId": 100101, "hp": 424 } ],
    "battleTaskTopics": [ { "type": "qte", "count": 1 } ],
    "encounteredEnemyIds": [ 250108, 224105 ],
    "battleTimeSecond": 45,
    "taskConditionResult": {
      "usedSkills": [ { "characterSkillId": 1001016, "count": 1 } ],
      "enemyStabilityBreaks": [ { "enemyId": 224105, "count": 1 } ]
    }
  })

  doAssert(res != nil)

  let changedResources = res["changedResources"]

  let challengeTasks = to(changedResources["challengeTasks"], seq[ChallengeTask])

  doAssert(challengeTasks.len == 1)
  doAssert(challengeTasks[0].challengeTaskId == 10001011)
  doAssert(challengeTasks[0].clearedAt.isSome())
  doAssert(challengeTasks[0].count == 1)

  var challengeProgresses = to(changedResources["challengeProgresses"], seq[ChallengeProgress])

  doAssert(challengeProgresses.len == 2)
  challengeProgresses.sort(
    proc (chPr1, chPr2: ChallengeProgress): int = cmp(chPr1.challengeProgressId, chPr2.challengeProgressId)
  )

  doAssert(challengeProgresses[0].challengeProgressId == 1000101)
  doAssert(challengeProgresses[0].clearedAt.isSome())
  doAssert(challengeProgresses[0].state == 3)

  doAssert(challengeProgresses[1].challengeProgressId == 1000111)
  doAssert(challengeProgresses[1].clearedAt.isNone())
  doAssert(challengeProgresses[1].state == 2)


proc testLostBattleFinish() =
  var ctx = getInMemorySembaCtx()

  discard sembaCall(ctx, "/battle/start", %*{
    "battleEntryIds": [ 2000042 ],
    "lineCharacterIds": [ 100101 ],
    "battleTriggers": [ { "triggerType": "area_object", "triggerIds": [ 30701301 ] } ],
    "advantageType": "disadvantage",
    "currentLocation": {
      "areaType": 1, "direction": 4,
      "positionCoordinates": { "x": 18.253134, "y": 42.189922, "z": -21.34115 },
      "areaKeyId": 300401
    },
    "bloodStainLocation": {
      "areaKeyId": 300401, "areaType": 1,
      "positionCoordinates": { "x": 18.666283, "y": 41.85231, "z": -21.550146 }
    }
  })

  let res = sembaCall(ctx, "/battle/finish", %*{
    "battleResult": "lost",
    "characterUpdates": [ { "characterId": 100101 } ],
    "encounteredEnemyIds": [ 224303 ], "battleTimeSecond": 24, "taskConditionResult": { }
  })

  doAssert(res != nil)

  for key in res["changedResources"].keys():
    if key != "status":
      let resource = res["changedResources"][key]
      doAssert(resource.kind == JNull)


proc testSuiteBattle*(saves_dir: string) =
    test_endrone_battle_start(saves_dir)
    test_battle_finish_challenge_data(saves_dir)
    testLostBattleFinish()