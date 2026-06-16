import std/json
import std/options
import std/sequtils

import ./utils
import ../../src/semba/protojson
import ../../src/semba/api_stable/happy_worker
import ../../src/semba/model_stable/area_object
import ../../src/semba/model_stable/challenge_progress
import ../../src/semba/model_stable/challenge_task


proc testHappyWorkerStart() =
  var ctx = getInMemorySembaCtx()

  let happyWorkerItemId = 1000003

  let resJson = ctx.sembaCall("/happy_worker/start", %*{"happyWorkerItemId": happyWorkerItemId})

  doAssert(resJson != nil)

  let res = protoJsonTo(resJson, HappyWorkerStartResponse)

  doAssert(res.happyWorkerItem.happyWorkerItemId == happyWorkerItemId)
  doAssert(res.happyWorkerItem.state == 5)

  let challenges = res.changedResources.challenges
  doAssert(challenges.len == 1)
  doAssert(challenges[0].challengeId == 105021)
  doAssert(challenges[0].state == 5)
  doAssert(challenges[0].expiresAt.isSome())

  doAssert(res.changedResources.challengeProgresses == @[ChallengeProgress(
    challengeProgressId: 10502101, state: 2
  )])

  doAssert(res.changedResources.challengeTasks == @[ChallengeTask(
    challengeTaskId: 105021011
  )])


proc testHappyWorkerCancelAreaObjects(saves_dir: string) =
  var ctx = getInMemorySembaCtx()

  ctx.loadSaveFile(saves_dir, "after accept haywired drone challenge")

  let haywiredDroneHWItemId = 1000005

  let droneAOB = 10000301

  doAssert(getAreaObjectsInArea(ctx.db, 101001).findIt(it.areaObjectBehaviorId == some(droneAOB)) != -1)

  let res = protoJsonTo(ctx.sembaCall("/happy_worker/cancel", %*{
    "happyWorkerItemId": haywiredDroneHWItemId
  }), Option[HappyWorkerCancelResponse])

  doAssert(res.isSome)
  doAssert(getAreaObjectsInArea(ctx.db, 101001).findIt(it.areaObjectBehaviorId == some(droneAOB)) == -1)


proc testSuiteHappyWorker*(savesDir: string) =
  testHappyWorkerStart()
  testHappyWorkerCancelAreaObjects(savesDir)