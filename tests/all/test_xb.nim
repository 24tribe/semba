import std/sequtils
import std/options

import ../../src/semba/model_stable/challenge_progress
import ../../src/semba/model_stable/challenge_task
import ../../src/semba/model_stable/resources

import ./utils


proc testCompleteIchinoseXb(savesDir: string) =
  var ctx = getInMemorySembaCtx()

  ctx.loadSaveFile(savesDir, "before ichinose xb")

  let (_, chals, chalProgs, chalTasks, _) = ctx.db.getCompletedIchinoseXbChangedResources()

  doAssert(chals.len == 0)

  doAssert(chalProgs.len == 2)

  doAssert(chalProgs.findIt(
    it.challengeProgressId == 1010311 and it.clearedAt.isSome and it.state == 3
  ) != -1)

  doAssert(chalProgs.findIt(
    it.challengeProgressId == 1010323 and it.clearedAt.isNone and it.state == 2
  ) != -1)

  doAssert(chalTasks.len == 1)

  doAssert(chalTasks[0].challengeTaskId == 10103111)
  doAssert(chalTasks[0].clearedAt.isSome)
  doAssert(chalTasks[0].count == some(1))


proc testSuiteXb*(savesDir: string) =
  testCompleteIchinoseXb(savesDir)
