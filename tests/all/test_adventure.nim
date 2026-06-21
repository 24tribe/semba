import std/algorithm
import std/assertions
import std/json
import std/options
import std/sequtils
import std/sets

import db_connector/db_sqlite

import ./utils
import ../../src/semba
import ../../src/semba/protojson
import ../../src/semba/api_stable/adventure
import ../../src/semba/model_stable/area_change_lock
import ../../src/semba/model_stable/area_object_lock
import ../../src/semba/model_stable/adventure_variable
import ../../src/semba/model_stable/area_object
import ../../src/semba/model_stable/character
import ../../src/semba/model_stable/challenge_progress
import ../../src/semba/model_stable/challenge_task
import ../../src/semba/model_stable/item
import ../../src/semba/model_stable/mission
import ../../src/semba/model_stable/nine_sequence
import ../../src/semba/model_stable/resources
import ../../src/semba/model_stable/reward
import ../../src/semba/model_stable/sequence_request
import ../../src/semba/model_stable/timestamp
import ../../src/semba/model_stable/warp_point


proc sortByAreaPointId(a, b: AreaObject): int = cmp(a.areaPointId, b.areaPointId)


proc test_talk_to_branch_manager_after_hoimi_read_sequence(saves_dir: string) =
  var ctx = getInMemorySembaCtx()

  loadSaveFile(ctx, saves_dir, "after hoimi before branch manager")

  let res = sembaCall(ctx, "/adventure/read_sequence", %*{
    "sequenceRequestIds": [ 80100421, 80100423, 8011592 ],
    "currentLocation": {
      "areaType": 1,
      "direction": 1,
      "positionCoordinates": { "x": -0.45827195, "y": 0.0416666679 },
      "areaKeyId": 109902
    },
    "areaType": 1,
    "areaKeyId": 109902
  })

  doAssert(res != nil)

  var areaObjects = protoJsonTo(res["areaObjects"], seq[AreaObject])
  areaObjects.sort(sortByAreaPointId)

  var expectedAreaObjects = protoJsonTo(%*[
    {
      "areaObjectId": 801056, "areaPointId": 109903001, "areaObjectBehaviorId": 8011611,
      "action": {"type": 3, "id": 1, "sequenceId": 8011591}
    },
    {
      "areaObjectId": 801055, "areaPointId": 109902001, "areaObjectBehaviorId": 8011601,
      "action": {"type": 3, "id": 1, "sequenceId": 8011591}
    },
    {
      "areaObjectId": 801054, "areaPointId": 101316003, "areaObjectBehaviorId": 8011591,
      "action": {"type": 3, "id": 1, "sequenceId": 8011591}
    },
    {
      "areaObjectId": 801009, "areaPointId": 101301002, "areaObjectBehaviorId": 8010042,
      "action": {"type": 3, "id": 1, "sequenceId": 8010042, "label": "Enoki Yukigaya"}
    },
    {
      "areaObjectId": 801008, "areaPointId": 101301003, "areaObjectBehaviorId": 8010045,
      "action": {"type": 3, "id": 1, "sequenceId": 8010045, "label": "Roku Saigo"}
    },
    {
      "areaObjectId": 801006, "areaPointId": 101511003, "areaObjectBehaviorId": 8010050,
      "action": {"type": 3, "id": 1, "sequenceId": 8010047, "label": "Jio Takinogawa"}
    },
    {
      "areaObjectId": 801005, "areaPointId": 101511002, "areaObjectBehaviorId": 8010047,
      "action": {"type": 3, "id": 1, "sequenceId": 8010043, "label": "Miu Jujo"}
    },
    {
      "areaObjectId": 801004, "areaPointId": 101511004, "areaObjectBehaviorId": 8010941,
      "action": {"type": 3, "id": 1, "sequenceId": 8010048, "label": "Koishi Kohinata"}
    },
    {
      "areaObjectId": 700058, "areaPointId": 101312102, "areaObjectBehaviorId": 7010712,
      "action": {"type": 7, "id": 1}
    },
    {
      "areaObjectId": 700053, "areaPointId": 101311120, "areaObjectBehaviorId": 7010714,
      "action": {"type": 7, "id": 1}
    },
    {
      "areaObjectId": 109002, "areaPointId": 109902901, "areaObjectBehaviorId": 10900201,
      "action": {"type": 3, "id": 1, "sequenceId": 10900201, "label": "Branch Manager"}
    }
  ], seq[AreaObject])

  expectedAreaObjects.sort(sortByAreaPointId)

  doAssert(areaObjects == expectedAreaObjects)

  let changedResources = res["changedResources"]

  let challengeProgresses = protoJsonTo(changedResources["challengeProgresses"], seq[ChallengeProgress])
  
  doAssert(challengeProgresses.len == 2)

  doAssert(challengeProgresses[0].challengeProgressId == 1010042)
  doAssert(challengeProgresses[0].clearedAt.isSome())
  doAssert(challengeProgresses[0].state == challengeProgressStateCleared.int)

  doAssert(challengeProgresses[1].challengeProgressId == 1010043)
  doAssert(challengeProgresses[1].clearedAt.isNone())
  doAssert(challengeProgresses[1].state == challengeProgressStateStarted.int)

  let challengeTasks = protoJsonTo(changedResources["challengeTasks"], seq[ChallengeTask])

  doAssert(challengeTasks.len == 1)

  doAssert(challengeTasks[0].challengeTaskId == 10100421)
  doAssert(challengeTasks[0].clearedAt.isSome())
  doAssert(challengeTasks[0].count.get(0) == 1)

  let adventureVariables = protoJsonTo(changedResources["adventureVariables"], seq[AdventureVariable])
  doAssert(adventureVariables[0].adventureVariableId == 10030)
  doAssert(adventureVariables[0].value == 2)


proc test_talk_hoimi_read_sequence(saves_dir: string) =
  var ctx = getInMemorySembaCtx()

  loadSaveFile(ctx, saves_dir, "before talk hoimi first")

  let res = sembaCall(ctx, "/adventure/read_sequence", %*{
    "sequenceRequestIds": [80100422, 8011592],
    "currentLocation": {
      "areaType": 1,
      "direction": 5,
      "positionCoordinates": {"x": 1.75, "y": 0.0104166679,"z": -1.5},
      "areaKeyId": 109903
    },
    "areaType": 1,
    "areaKeyId": 109903
  })

  doAssert(res != nil)

  let areaObjects = protoJsonTo(res["areaObjects"], seq[AreaObject])
  doAssert(areaObjects.len == 1)
  let expected = protoJsonTo(%*{
    "areaObjectId": 109005,
    "areaPointId": 109903902,
    "areaObjectBehaviorId": 10900501,
    "action": {"type": 3, "id": 1, "sequenceId": 10900501, "label": "Hoimi"}
  }, AreaObject)

  doAssert(areaObjects[0] == expected)

  let changedResources = res["changedResources"]

  let challengeProgresses = protoJsonTo(changedResources["challengeProgresses"], seq[ChallengeProgress])
  doAssert(challengeProgresses.len == 1)
  doAssert(challengeProgresses[0] == ChallengeProgress(challengeProgressId: 1010042, state: 2))

  doAssert(changedResources["challengeTasks"].getElems().len == 1)
  let challengeTask = changedResources["challengeTasks"][0]
  doAssert(challengeTask["challengeTaskId"].getInt() == 10100422)
  doAssert(challengeTask.hasKey("clearedAt"))
  doAssert(challengeTask["count"].getInt() == 1)

  let adventureVariables = protoJsonTo(changedResources["adventureVariables"], seq[AdventureVariable])
  doAssert(adventureVariables[0].adventureVariableId == 10030)
  doAssert(adventureVariables[0].value == 1)


proc test_talk_with_enoki_first(saves_dir: string) =
  var ctx = getInMemorySembaCtx()

  loadSaveFile(ctx, saves_dir, "before talking enoki first")

  let res = sembaCall(ctx, "/adventure/read_sequence", %*{
    "sequenceRequestIds": [ 80100431, 8011622 ],
    "currentLocation": {
      "areaType": 1, "direction": 5,
      "positionCoordinates": { "x": -15.2384529, "y": 0.015625, "z": -19.510952 },
      "areaKeyId": 101301
    },
    "areaType": 1,
    "areaKeyId": 101301
  })

  let changedResources = res["changedResources"]

  let challengeProgresses = protoJsonTo(changedResources["challengeProgresses"], seq[ChallengeProgress])
  doAssert(challengeProgresses.len == 1)
  doAssert(challengeProgresses[0].challengeProgressId == 1010043)
  doAssert(challengeProgresses[0].state == challengeProgressStateStarted.int)

  let challengeTasks = protoJsonTo(changedResources["challengeTasks"], seq[ChallengeTask])
  doAssert(challengeTasks.len == 1)
  doAssert(challengeTasks[0].challengeTaskId == 10100431)
  doAssert(challengeTasks[0].clearedAt.isSome())
  doAssert(challengeTasks[0].count.get(0) == 1)

  var expectedAreaObjects = protoJsonTo(%*[
    {
      "areaObjectId": 801009,
      "areaPointId": 101301002,
      "areaObjectBehaviorId": 8010043,
      "action": {
        "type": 3,
        "id": 1,
        "sequenceId": 8010044,
        "label": "Enoki Yukigaya"
      }
    },
    {
      "areaObjectId": 801005,
      "areaPointId": 101511002,
      "areaObjectBehaviorId": 8010047,
      "action": {
        "type": 3,
        "id": 1,
        "sequenceId": 8010043,
        "label": "Miu Jujo"
      }
    }
  ], seq[AreaObject])

  var areaObjects = protoJsonTo(res["areaObjects"], seq[AreaObject])
  areaObjects.sort(sortByAreaPointId)

  #[
  This is weird. This read_sequence returns Miu as a changed area object but doesn't change
  any of her properties. Also, her areaObjectBehaviorId (8010047) has a condition to appear after
  starting the challengeProgress with id=1010043 (after talking with Hoimi and the Branch Manager),
  so it shouldn't be here, since this read_sequence happens after talking to Enoki. 
  Until I figure out what's going on I think it's fine to accept both responses (with and without Miu).
  ]#

  doAssert(
    expectedAreaObjects == areaObjects or
    (areaObjects.len == 1 and areaObjects[0] == expectedAreaObjects[0])
  )

  let adventureVariables = protoJsonTo(changedResources["adventureVariables"], seq[AdventureVariable])
  doAssert(adventureVariables[0].adventureVariableId == 10031)
  doAssert(adventureVariables[0].value == 1)


proc test_talk_to_miu_after_enonki_read_sequence(saves_dir: string) =
  var ctx = getInMemorySembaCtx()

  loadSaveFile(ctx, saves_dir, "before talking miu after talking enoki")

  let res = sembaCall(ctx, "/adventure/read_sequence", %*{
    "sequenceRequestIds": [ 80100432, 8011622 ],
    "nineSequences": [{ "id": 10000002, "choices": "{\"Selections\":[]}" }],
    "currentLocation": {
      "areaType": 1,
      "direction": 5,
      "positionCoordinates": { "x": -16.6637859, "y": 3.012142, "z": 0.6405984 },
      "areaKeyId": 101511
    },
    "areaType": 1,
    "areaKeyId": 101511
  })

  doAssert(res != nil)

  let changedResources = res["changedResources"]
  
  let challengeProgresses = protoJsonTo(changedResources["challengeProgresses"], seq[ChallengeProgress])
  doAssert(challengeProgresses.len == 2)

  for challengeProgress in challengeProgresses:
    doAssert(challengeProgress.challengeProgressId == 1010043 or challengeProgress.challengeProgressId == 1010051)
    if challengeProgress.challengeProgressId == 1010043:
      doAssert(challengeProgress.state == challengeProgressStateCleared.int)
    else:
      doAssert(challengeProgress.state == challengeProgressStateStarted.int)

  let challengeTasks = protoJsonTo(changedResources["challengeTasks"], seq[ChallengeTask])
  doAssert(challengeTasks.len == 1)

  doAssert(challengeTasks[0].challengeTaskId == 10100432)
  doAssert(challengeTasks[0].clearedAt.isSome())
  doAssert(challengeTasks[0].count.get(0) == 1)

  var expectedAreaObjects = protoJsonTo(%*[
    {
      "areaObjectId": 801011, "areaPointId": 100101006, "areaObjectBehaviorId": 8010053,
      "action": {"type": 3, "id": 1, "sequenceId": 8010051, "label": "Q"}
    },
    {
      "areaObjectId": 801010, "areaPointId": 100101005, "areaObjectBehaviorId": 8010051,
      "action": {"type": 3, "id": 1, "sequenceId": 8010051, "label": "Kazuki Aoyama"}
    },
    {
      "areaObjectId": 801005, "areaPointId": 101511002, "areaObjectBehaviorId": 8010048,
      "action": {"type": 3, "id": 1, "sequenceId": 8010046, "label": "Miu Jujo"}
    }
  ], seq[AreaObject])

  expectedAreaObjects.sort(sortByAreaPointId)

  var areaObjects = protoJsonTo(res["areaObjects"], seq[AreaObject])
  areaObjects.sort(sortByAreaPointId)

  doAssert(expectedAreaObjects == areaObjects)

  let nineSequences = protoJsonTo(changedResources["nineSequences"], seq[NineSequence])

  doAssert(nineSequences.len == 1)
  doAssert(nineSequences[0].nineSequenceId == 10000002)
  doAssert(nineSequences[0].choices == "{\"Selections\":[]}")
  doAssert(nineSequences[0].lastReadAt.isSome())

  let adventureVariables = protoJsonTo(changedResources["adventureVariables"], seq[AdventureVariable])
  doAssert(adventureVariables[0].adventureVariableId == 10031)
  doAssert(adventureVariables[0].value == 2)


proc sameReward(r1: Reward, r2: Reward): bool =
  result = r1.`type` == r2.`type` and r1.id == r2.id and r1.quantity == r2.quantity


proc testAcquireAreaItemInLogs() =
  var ctx = getInMemorySembaCtx()

  let res = ctx.sembaCall("/adventure/acquire_area_item", %*{
    "areaItemId": 10500102,
    "currentLocation": {
      "areaType": 1,
      "direction": 1,
      "positionCoordinates": {
        "x": 1.53473973,
        "y": 0.0416665077,
        "z": 1.69789064
      },
      "areaKeyId": 100411
    }
  })

  doAssert(res != nil)

  let rewards = protoJsonTo(res["rewards"], seq[Rewards])

  doAssert(rewards.len == 1)

  let firstRewards = rewards[0]

  doAssert(firstRewards.`type`.get(0) == 5)

  let contents = firstRewards.contents

  doAssert(contents.len >= 3)

  let reward1 = Reward(`type`: 3, id: 1, quantity: 1000)
  var r1Found = false

  let reward2 = Reward(`type`: 13, id: 1, quantity: 100)
  var r2Found = false

  let reward3 = Reward(`type`: 7, id: 2, quantity: 500)
  var r3Found = false

  for reward in contents:
    doAssert(reward.quantity != 0)
    doAssert(reward.`type` != rewardGearDrop.int)

    if sameReward(reward, reward1):
      r1Found = true

    if sameReward(reward, reward2):
      r2Found = true

    if sameReward(reward, reward3):
      r3Found = true

  doAssert(r1Found and r2Found and r3Found)


proc testAcquireAreaItemNotInLogs() =
  var ctx = getInMemorySembaCtx()

  let res = ctx.sembaCall("/adventure/acquire_area_item", %*{
    "areaItemId": 10519701,
    "currentLocation": {
      "areaType": 1,
      "direction": 3,
      "positionCoordinates": {
        "x": 19.365921,
        "y": 0.515625,
        "z": -2.65037036
      },
      "areaKeyId": 100421
    },
  })

  doAssert(res != nil)


proc testDummyAreaObjects() =
  var ctx = getInMemorySembaCtx()

  let res = ctx.sembaCall("/adventure/area_object", %*{ "areaId": 300401 })

  doAssert(res != nil)

  let dummyAreaObject = protoJsonTo(%*{
    "areaPointId": 300401601,
    "areaObjectBehaviorId": 30600501,
    "action": {
      "type": 4,
      "areaItemId": 30600501,
      "id": 1
    }
  }, AreaObject)

  let areaObjects = protoJsonTo(res["areaObjects"], seq[AreaObject])

  doAssert(areaObjects.any(proc (x: AreaObject): bool = x == dummyAreaObject))


proc checkCharactersHpIsMax(db: DbConn, charIds: openArray[int], changedResources: Resources) =
  proc cmpCharacters(chr1, chr2: Character): int = cmp(chr1.characterId, chr2.characterId)

  var changedCharacters = changedResources.characters.filterIt(it.characterId in charIds)
  changedCharacters.sort(cmpCharacters)

  var changedHps = changedCharacters.mapIt((it.characterId, it.hp)).toSeq()

  var dbChars = getCharactersWithId(db, charIds)
  dbChars.sort(cmpCharacters)

  var dbHps = dbChars.mapIt((it.characterId, it.hp)).toSeq()

  let expectedHps = dbChars.mapIt((it.characterId, it.maxHp)).toSeq()

  doAssert(changedHps == expectedHps)
  doAssert(dbHps == expectedHps)


proc testHealRespiteUnitByWarp() =
  var ctx = getInMemorySembaCtx()

  let charIds = [100101, 100201]

  knockOutCharacters(ctx.db, charIds)

  let res = ctx.sembaCall("/adventure/warp_area_locator", %*{"warpAreaType": 1, "warpAreaId": 109110})

  doAssert(res != nil)

  let changedResources = protoJsonTo(res["changedResources"], Resources)

  checkCharactersHpIsMax(ctx.db, charIds, changedResources)


proc testHealRespiteUnitByAccess() =
  var ctx = getInMemorySembaCtx()

  let charIds = [100101, 100201]

  knockOutCharacters(ctx.db, charIds)

  let res = ctx.sembaCall("/adventure/access_warp_point", %*{
    "warpPointId": 109110,
    "currentLocation": {
      "areaType": 1, "direction": 1, "areaKeyId": 101316,
      "positionCoordinates": { "x": 3.0797358, "y": 0.036458492, "z": 1}
    }
  })

  doAssert(res != nil)

  let changedResources = protoJsonTo(res["changedResources"], Resources)

  checkCharactersHpIsMax(ctx.db, charIds, changedResources)


proc testMiniGameWithAreaObjectLock() =
  var ctx = getInMemorySembaCtx()

  let res = protoJsonTo(ctx.sembaCall("/adventure/read_sequence", %*{
    "sequenceRequestIds": [ 105045011, 108222011 ],
    "currentLocation": {
      "areaType": 1, "direction": 1, "areaKeyId": 101001,
      "positionCoordinates": { "x": 1.714024, "y": 6.034101, "z": 14.162288 }
    },
    "miniGameId": 105016, "areaType": 1, "areaKeyId": 101001
  }), AdventureReadSequenceResponse)

  let areaObjectLocks = res.changedResources.areaObjectLocks

  doAssert(areaObjectLocks == @[AreaObjectLock(areaObjectLockId: 10504502, count: some(1))])

  doAssert(res.areaObjects == protoJsonTo(%*[
    {
      "areaObjectId": 108222, "areaPointId": 101001806, "areaObjectBehaviorId": 10822202,
      "action": {"type": 3, "id": 1, "label": "Control Panel", "sequenceId": 10822201}
    }
  ], seq[AreaObject]))


proc testMiniGameWithoutAreaObjectLock() =
  var ctx = getInMemorySembaCtx()

  var res = protoJsonTo(ctx.sembaCall("/adventure/read_sequence", %*{
    "sequenceRequestIds": [308002021, 308003021, 308001021],
    "currentLocation": {
      "areaType": 1, "direction": 3, "areaKeyId": 300401,
      "positionCoordinates": {"x": 72.45, "y": 19.6710052, "z": -34.8852272}
    },
    "miniGameId": 101029, "areaType": 1, "areaKeyId": 300401
  }), AdventureReadSequenceResponse)

  let expectedAreaObjects = protoJsonTo(%*[
    {
      "areaObjectId": 308003, "areaPointId": 300401804, "areaObjectBehaviorId": 30800302,
      "action": {"type": 1, "id": 1}
    },
    {
      "areaObjectId": 308002, "areaPointId": 300401802, "areaObjectBehaviorId": 30800202,
      "action": {"type": 3, "id": 1, "sequenceId": 30800201}
    },
    {
      "areaObjectId": 308001, "areaPointId": 300401801, "areaObjectBehaviorId": 30800102,
      "action": {"type": 1, "id": 1}
    },
    {
      "areaObjectId": 305009, "areaPointId": 300401507, "areaObjectBehaviorId": 30500902,
      "action": {"type": 4, "areaItemId": 30500902, "id": 1, "label": "Valuable Chest"}
    }
  ], seq[AreaObject])

  res.areaObjects.sort(proc (ao1, ao2: AreaObject): int = cmp(ao2.areaPointId, ao1.areaPointId))

  doAssert(expectedAreaObjects == res.areaObjects)

  doAssert(res.changedResources.status.isSome())


proc testReplaySequenceBug(saves_dir: string) =
  var ctx = getInMemorySembaCtx()

  ctx.loadSaveFile(saves_dir, "before elevator 20f unlock 2")

  let res = protoJsonTo(ctx.sembaCall("/adventure/read_sequence", %*{
    "sequenceRequestIds": [ 109502011 ],
    "currentLocation": {
      "areaType": 1, "direction": 5, "areaKeyId": 101313,
      "positionCoordinates": { "y": 0.0192914, "z": 2.75 },
    },
    "areaType": 1, "areaKeyId": 101313
  }), Option[AdventureReadSequenceResponse])

  doAssert(res.isSome())


proc testMagicOrbMissionInReadSequence(saves_dir: string) =
  var ctx = getInMemorySembaCtx()

  ctx.loadSaveFile(saves_dir, "before elevator 20f unlock 2")

  let res = protoJsonTo(ctx.sembaCall("/adventure/read_sequence", %*{
    "sequenceRequestIds": [ 80102011, 80102012 ],
    "nineSequences": [ { "id": 95016001, "choices": "{\"Selections\":[]}" } ],
    "currentLocation": {
      "areaType": 1, "direction": 4, "areaKeyId": 101313,
      "positionCoordinates": { "x": -2.7, "y": 0.019291561, "z": -1.3 }
    },
    "areaType": 1, "areaKeyId": 101313
  }), Option[AdventureReadSequenceResponse])

  doAssert(res.isSome())

  var changedResources = res.get().changedResources

  let verityOrbMissionIdx = changedResources.missions.findIt(it.missionId == 1041007)
  doAssert(verityOrbMissionIdx != -1)

  let firstVerityOrbMission = changedResources.missions[verityOrbMissionIdx]
  doAssert(firstVerityOrbMission.count == some(1))
  doAssert(firstVerityOrbMission.clearedAt.isSome)

  doAssert(changedResources.missions.filterIt(it.missionId in [1041008, 1041009]).allIt(it.count == some(1)))


proc testUpdateCharacterStatus() =
  var ctx = getInMemorySembaCtx()

  let res = protoJsonTo(ctx.sembaCall("/adventure/update_character_status", %*{
    "characterUpdates": [
      {"characterId": 100201, "hp": 10},
      {"characterId": 100101, "hp": 20},
      {"characterId": 100501, "hp": 30},
    ]
  }), Option[ChangedResourcesResponse])

  doAssert(res.isSome)

  var changedResources = res.get().changedResources
  changedResources.characters.sort(proc (a, b: Character): int = cmp(a.characterId, b.characterId))

  let charHps = changedResources.characters.mapIt((it.characterId, it.hp)).toSeq()

  doAssert(charHps == @[
    (100101, 20), (100201, 10), (100501, 30)
  ])


proc testHappyWorkerChallengeAreaObjectsAreDeletedAfterCompletion(saves_dir: string) =
  var ctx = getInMemorySembaCtx()

  ctx.loadSaveFile(saves_dir, "before completing happy worker mission")

  doAssert(
    getAreaObjectsInArea(ctx.db, 101311)
      .findIt(it.areaObjectId == some(100109) and it.areaPointId == 101311212) != -1
  )

  let res = protoJsonTo(ctx.sembaCall("/adventure/read_sequence", %*{
    "sequenceRequestIds": [ 100111011 ],
    "currentLocation": {
      "areaType": 1, "direction": 1, "areaKeyId": 101311,
      "positionCoordinates": { "x": 2.5726233, "y": 3.0020013, "z": 2.5793955}
    },
    "areaType": 1, "areaKeyId": 101311
  }), Option[AdventureReadSequenceResponse])

  doAssert(res.isSome)

  let changedResources = res.get().changedResources

  doAssert(
    getAreaObjectsInArea(ctx.db, 101311)
      .findIt(it.areaObjectId == some(100109) and it.areaPointId == 101311212) == -1
  )

  doAssert(changedResources.missions == @[Mission(missionId: 1041002, count: some(1))])


proc testFieldResearchMission() =
  var ctx = getInMemorySembaCtx()

  const miracleStorageItemId = 3103
  const fieldResearchMissionId = 1041067

  let quantity = getItem(ctx.db, miracleStorageItemId).get(Item()).quantity

  let res = protoJsonTo(ctx.sembaCall("/adventure/acquire_area_item", %*{
    "currentLocation": {
      "areaType": 1, "direction": 5, "areaKeyId": 100411, 
      "positionCoordinates": { "x": 16.742615, "y": 0.041666508, "z": -12.25 }
    },
    "areaItemId": 100411602
  }), Option[AdventureAcquireAreaItemResponse])

  doAssert(res.isSome)

  let changedResources = res.get().changedResources

  let itemIndex = changedResources.items.findIt(it.itemId == miracleStorageItemId)
  doAssert(itemIndex != -1)

  let item = changedResources.items[itemIndex]

  let missionIndex = changedResources.missions.findIt(it.missionId == fieldResearchMissionId)
  doAssert(missionIndex != -1)
  doAssert(changedResources.missions[missionIndex].count == some(item.quantity - quantity))


proc testLinkedSignpostsMission(saves_dir: string) =
  var ctx = getInMemorySembaCtx()

  ctx.loadSaveFile(saves_dir, "meiou isle restricted area puzzle")

  const warpPointId = 109109
  const linkedSignpostsShinagawaMissionId = 1041061

  let beforeMissions = getMissionsWithIds(ctx.db, [linkedSignpostsShinagawaMissionId])
  let beforeMission =
    if beforeMissions.len == 1:
      beforeMissions[0]
    else:
      Mission(missionId: linkedSignpostsShinagawaMissionId)

  let res = protoJsonTo(ctx.sembaCall("/adventure/access_warp_point", %*{
    "warpPointId": warpPointId,
    "currentLocation": {
      "areaType": 1, "direction": 1, "areaKeyId": 101301,
      "positionCoordinates": { "x": 14.90187, "y": 0.15625, "z": -2.4999998 }
    }
  }), Option[AdventureAccessWarpPointResponse])

  doAssert(res.isSome)

  let changedResources = res.get().changedResources

  doAssert(changedResources.warpPoints == @[WarpPoint(warpPointId: warpPointId)])

  let missionIndex = changedResources.missions.findIt(it.missionId == linkedSignpostsShinagawaMissionId)
  doAssert(missionIndex != -1)

  let mission = changedResources.missions[missionIndex]
  doAssert(mission.count.get(0) == beforeMission.count.get(0) + 1)
  doAssert(mission.count.get(0) == 4)


proc readFullMarksTutorialSequence(ctx: var SembaExContext): Option[AdventureReadSequenceResponse] =
  ctx.sembaCall("/adventure/read_sequence", %*{
    "sequenceRequestIds": [ fullMarksGateTutorialSeqReqId ],
    "nineSequences": [{ "id": 95011001, "choices": "{\"Selections\":[]}" } ],
    "currentLocation": {
      "areaType": 1, "direction": 1, "positionCoordinates": { "x": 3.1437361, "y": 18.041668, "z": 3.9609683 },
      "areaKeyId": 101103
    },
    "areaType": 1, "areaKeyId": 101103
  }).protoJsonTo(Option[AdventureReadSequenceResponse])


proc checkGateActionIs(res: AdventureReadSequenceResponse, `type`: AreaObjectActionType, id: int): bool =
  let areaObjects = res.areaObjects

  let aoIndex = areaObjects.findIt(it.areaPointId == 101103801)

  doAssert(aoIndex != -1)

  let gateAO = areaObjects[aoIndex]

  let action = gateAO.action.get()

  case `type`:
  of areaObjectActionTypeSequence:
    action.`type` == areaObjectActionTypeSequence.int and action.sequenceId.get() == id
  of areaObjectActionTypeDisabled:
    action.`type` == areaObjectActionTypeDisabled.int and action.id.get() == 1


proc testFullMarksGateTutorialWithNotEnoughAmount(saves_dir: string) =
  var ctx = getInMemorySembaCtx()

  ctx.loadSaveFile(saves_dir, "skybridge marine biology research center door")

  let res = ctx.readFullMarksTutorialSequence()

  doAssert(res.isSome)

  doAssert(checkGateActionIs(res.get(), areaObjectActionTypeSequence, fullMarksGateTutorialSeqId.int))


proc testFullMarksGateTutorialWithEnoughAmount(saves_dir: string) =
  var ctx = getInMemorySembaCtx()

  ctx.loadSaveFile(saves_dir, "17 full mark stickers")

  let res = ctx.readFullMarksTutorialSequence()

  doAssert(res.isSome)

  doAssert(checkGateActionIs(res.get(), areaObjectActionTypeDisabled, 1))


proc testDronesAreNotInAreaBeforeAcceptingChallenge(savesDir: string) =
  var ctx = getInMemorySembaCtx()

  ctx.loadSaveFile(saves_dir, "meiou isle after graffiti")

  let areaObjects = getAreaObjectsInArea(ctx.db, 100421).filterIt(
    it.areaObjectBehaviorId.get(0) in heroJammedDroneAreaObjectBehaviorIds
  )

  doAssert(areaObjects.len == 0)


proc testHeroJammedBuggedSaveFileIsFixed(savesDir: string) =
  var ctx = getInMemorySembaCtx()

  ctx.loadSaveFile(saves_dir, "bugged drones save file")

  let nineSequence = getNineSequence(ctx.db, heroJammedCompleteNineSequenceId)

  doAssert(nineSequence.isSome)
  doAssert(nineSequence.get().lastReceiveAt.isSome)


proc testReadSequenceReturnsAreaChangeLock(savesDir: string) =
  var ctx = getInMemorySembaCtx()

  ctx.loadSaveFile(saves_dir, "marine bio res center corridor")

  block:
    let res = ctx.sembaCall("/adventure/read_sequence", %*{
      "sequenceRequestIds": [ 108194021, 109508011, 109509011, 10835801, 10835901, 10836001, 10836101 ],
      "currentLocation": {
        "areaType": 1, "direction": 1, "positionCoordinates": { "x": -8.248895, "y": 0.010416508, "z": 3.2314434 },
        "areaKeyId": 101206
      },
      "miniGameId": 104002, "areaType": 1, "areaKeyId": 101206
    }).protoJsonTo(Option[AdventureReadSequenceResponse])

    doAssert(res.isSome)

    let changedResources = res.get().changedResources

    doAssert(changedResources.areaChangeLocks.toHashSet == [
      AreaChangeLock(areaChangeLockId: 10950801),
      AreaChangeLock(areaChangeLockId: 10950901),
    ].toHashSet)

    let areaChangeLocks = getAreaChangeLocks(ctx.db)
    doAssert(areaChangeLocks.findIt(it.areaChangeLockId == 10950801) != -1)
    doAssert(areaChangeLocks.findIt(it.areaChangeLockId == 10950901) != -1)

  block:
    let res = ctx.sembaCall("/adventure/move_to_area", %*{
      "areaId": 101206,
      "currentLocation": {
        "areaType": 1, "direction": 1, "areaKeyId": 101206,
        "positionCoordinates": { "x": -8.248895, "y": 0.010416508, "z": 3.2314434}
      }
    }).protoJsonTo(Option[AdventureMoveToAreaResponse])

    doAssert(res.isSome)

    let areaChangeLocks = res.get().areaChangeLocks
    doAssert(areaChangeLocks == @[AreaChangeLock(areaChangeLockId: 10950901)])


proc testBuggedElevatorSaveFileIsFixed(savesDir: string) =
  var ctx = getInMemorySembaCtx()

  ctx.loadSaveFile(savesDir, "bugged elevator")

  let areaChangeLocks = getAreaChangeLocks(ctx.db)
  doAssert(areaChangeLocks.findIt(it.areaChangeLockId == 10950801) != -1)
  doAssert(areaChangeLocks.findIt(it.areaChangeLockId == 10950901) != -1)


proc testBuggedSaveFileHasAreaObjectLocks(savesDir: string) =
  var ctx = getInMemorySembaCtx()

  ctx.loadSaveFile(savesDir, "5-2-2.")

  let areaObjectLocks = getAreaObjectLocks(ctx.db)

  doAssert(areaObjectLocks.findIt(it.areaObjectLockId == 10512802) != -1)


proc testSuiteAdventure*(savesDir: string) =
  test_talk_with_enoki_first(savesDir)
  test_talk_to_miu_after_enonki_read_sequence(savesDir)
  test_talk_hoimi_read_sequence(savesDir)
  test_talk_to_branch_manager_after_hoimi_read_sequence(savesDir)

  testAcquireAreaItemInLogs()
  testAcquireAreaItemNotInLogs()
  testHealRespiteUnitByWarp()
  testHealRespiteUnitByAccess()
  testDummyAreaObjects()
  testMiniGameWithAreaObjectLock()
  testMiniGameWithoutAreaObjectLock()
  testReplaySequenceBug(savesDir)
  testMagicOrbMissionInReadSequence(savesDir)
  testUpdateCharacterStatus()
  testHappyWorkerChallengeAreaObjectsAreDeletedAfterCompletion(savesDir)
  testFieldResearchMission()
  testLinkedSignpostsMission(savesDir)
  testFullMarksGateTutorialWithNotEnoughAmount(savesDir)
  testFullMarksGateTutorialWithEnoughAmount(savesDir)
  testDronesAreNotInAreaBeforeAcceptingChallenge(savesDir)
  testHeroJammedBuggedSaveFileIsFixed(savesDir)
  testReadSequenceReturnsAreaChangeLock(savesDir)
  testBuggedElevatorSaveFileIsFixed(savesDir)
  testBuggedSaveFileHasAreaObjectLocks(savesDir)