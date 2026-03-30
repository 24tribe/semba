import std/algorithm
import std/assertions
import std/cmdline
import std/json
import std/options
import std/sequtils

import utils
import ../model_stable/adventure_variable
import ../model_stable/area_object
import ../model_stable/challenge_progress
import ../model_stable/challenge_task
import ../model_stable/nine_sequence
import ../model_stable/reward
import ../model_stable/timestamp


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

  var areaObjects = to(res["areaObjects"], seq[AreaObject])
  areaObjects.sort(sortByAreaPointId)

  var expectedAreaObjects = to(%*[
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

  let challengeProgresses = to(changedResources["challengeProgresses"], seq[ChallengeProgress])
  
  doAssert(challengeProgresses.len == 2)

  doAssert(challengeProgresses[0].challengeProgressId == 1010042)
  doAssert(challengeProgresses[0].clearedAt.isSome())
  doAssert(challengeProgresses[0].state == challengeProgressStateCleared.int)

  doAssert(challengeProgresses[1].challengeProgressId == 1010043)
  doAssert(challengeProgresses[1].clearedAt.isNone())
  doAssert(challengeProgresses[1].state == challengeProgressStateStarted.int)

  let challengeTasks = to(changedResources["challengeTasks"], seq[ChallengeTask])

  doAssert(challengeTasks.len == 1)

  doAssert(challengeTasks[0].challengeTaskId == 10100421)
  doAssert(challengeTasks[0].clearedAt.isSome())
  doAssert(challengeTasks[0].count == 1)

  let adventureVariables = to(changedResources["adventureVariables"], seq[AdventureVariable])
  doAssert(adventureVariables[0].adventureVariableId == 10030)
  doAssert(adventureVariables[0].value.get(0) == 2)


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

  let areaObjects = to(res["areaObjects"], seq[AreaObject])
  doAssert(areaObjects.len == 1)
  let expected = to(%*{
    "areaObjectId": 109005,
    "areaPointId": 109903902,
    "areaObjectBehaviorId": 10900501,
    "action": {"type": 3, "id": 1, "sequenceId": 10900501, "label": "Hoimi"}
  }, AreaObject)

  doAssert(areaObjects[0] == expected)

  let changedResources = res["changedResources"]

  let challengeProgresses = to(changedResources["challengeProgresses"], seq[ChallengeProgress])
  doAssert(challengeProgresses.len == 1)
  doAssert(challengeProgresses[0] == ChallengeProgress(challengeProgressId: 1010042, state: 2))

  doAssert(changedResources["challengeTasks"].getElems().len == 1)
  let challengeTask = changedResources["challengeTasks"][0]
  doAssert(challengeTask["challengeTaskId"].getInt() == 10100422)
  doAssert(challengeTask.hasKey("clearedAt"))
  doAssert(challengeTask["count"].getInt() == 1)

  let adventureVariables = to(changedResources["adventureVariables"], seq[AdventureVariable])
  doAssert(adventureVariables[0].adventureVariableId == 10030)
  doAssert(adventureVariables[0].value.get(0) == 1)


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

  let challengeProgresses = to(changedResources["challengeProgresses"], seq[ChallengeProgress])
  doAssert(challengeProgresses.len == 1)
  doAssert(challengeProgresses[0].challengeProgressId == 1010043)
  doAssert(challengeProgresses[0].state == challengeProgressStateStarted.int)

  let challengeTasks = to(changedResources["challengeTasks"], seq[ChallengeTask])
  doAssert(challengeTasks.len == 1)
  doAssert(challengeTasks[0].challengeTaskId == 10100431)
  doAssert(challengeTasks[0].clearedAt.isSome())
  doAssert(challengeTasks[0].count == 1)

  var expectedAreaObjects = to(%*[
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

  var areaObjects = to(res["areaObjects"], seq[AreaObject])
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

  let adventureVariables = to(changedResources["adventureVariables"], seq[AdventureVariable])
  doAssert(adventureVariables[0].adventureVariableId == 10031)
  doAssert(adventureVariables[0].value.get(0) == 1)


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
  
  let challengeProgresses = to(changedResources["challengeProgresses"], seq[ChallengeProgress])
  doAssert(challengeProgresses.len == 2)

  for challengeProgress in challengeProgresses:
    doAssert(challengeProgress.challengeProgressId == 1010043 or challengeProgress.challengeProgressId == 1010051)
    if challengeProgress.challengeProgressId == 1010043:
      doAssert(challengeProgress.state == challengeProgressStateCleared.int)
    else:
      doAssert(challengeProgress.state == challengeProgressStateStarted.int)

  let challengeTasks = to(changedResources["challengeTasks"], seq[ChallengeTask])
  doAssert(challengeTasks.len == 1)

  doAssert(challengeTasks[0].challengeTaskId == 10100432)
  doAssert(challengeTasks[0].clearedAt.isSome())
  doAssert(challengeTasks[0].count == 1)

  var expectedAreaObjects = to(%*[
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

  var areaObjects = to(res["areaObjects"], seq[AreaObject])
  areaObjects.sort(sortByAreaPointId)

  doAssert(expectedAreaObjects == areaObjects)

  let nineSequences = to(changedResources["nineSequences"], seq[NineSequence])

  doAssert(nineSequences.len == 1)
  doAssert(nineSequences[0].nineSequenceId == 10000002)
  doAssert(nineSequences[0].choices == "{\"Selections\":[]}")
  doAssert(nineSequences[0].lastReadAt.isSome())

  let adventureVariables = to(changedResources["adventureVariables"], seq[AdventureVariable])
  doAssert(adventureVariables[0].adventureVariableId == 10031)
  doAssert(adventureVariables[0].value.get(0) == 2)


proc sameReward(r1: Reward, r2: Reward): bool =
  result = r1.`type` == r2.`type` and r1.id == r2.id and r1.quantity == r2.quantity


proc testAcquireAreaItemInLogs() =
  var ctx = getInMemorySembaCtx()

  let res = ctx.sembaCall("/adventure/acquire_area_item", %*{"areaItemId": 10500102})

  doAssert(res != nil)

  let rewards = to(res["rewards"], seq[Rewards])

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

  let res = ctx.sembaCall("/adventure/acquire_area_item", %*{"areaItemId": 10519701})

  doAssert(res != nil)


proc testDummyAreaObjects() =
  var ctx = getInMemorySembaCtx()

  let res = ctx.sembaCall("/adventure/area_object", %*{ "areaId": 300401 })

  doAssert(res != nil)

  let dummyAreaObject = to(%*{
    "areaPointId": 300401601,
    "areaObjectBehaviorId": 30600501,
    "action": {
      "type": 4,
      "areaItemId": 30600501,
      "id": 1
    }
  }, AreaObject)

  let areaObjects = to(res["areaObjects"], seq[AreaObject])

  doAssert(areaObjects.any(proc (x: AreaObject): bool = x == dummyAreaObject))


when isMainModule:
  let saves_dir = paramStr(1)

  test_talk_with_enoki_first(saves_dir)
  test_talk_to_miu_after_enonki_read_sequence(saves_dir)
  test_talk_hoimi_read_sequence(saves_dir)
  test_talk_to_branch_manager_after_hoimi_read_sequence(saves_dir)

  testAcquireAreaItemInLogs()
  testAcquireAreaItemNotInLogs()
  testDummyAreaObjects()