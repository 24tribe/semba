import std/json
import std/options

import utils
import ../protojson
import ../api_stable/happy_worker
import ../model_stable/challenge_progress
import ../model_stable/challenge_task


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


proc testSuiteHappyWorker*() =
  testHappyWorkerStart()