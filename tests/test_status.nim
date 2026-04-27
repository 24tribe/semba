import std/json

import ../model_stable/status
import utils


proc testStatus() =
  var ctx = getInMemorySembaCtx()

  let status = getUserStatusTypeSafe(ctx.db)

  setUserStatusTypeSafe(ctx.db, status)


proc testSuiteStatus*() =
  testStatus()