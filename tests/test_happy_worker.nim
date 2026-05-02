import std/json

import utils


proc testHappyWorkerStart() =
  var ctx = getInMemorySembaCtx()

  let res = ctx.sembaCall("/happy_worker/start", %*{"happyWorkerItemId": 1000003})

  doAssert(res != nil)


proc testSuiteHappyWorker*() =
  testHappyWorkerStart()