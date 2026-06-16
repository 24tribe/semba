import ../../src/semba/model_stable/status
import ./utils


proc testStatus() =
  var ctx = getInMemorySembaCtx()

  let status = getUserStatusTypeSafe(ctx.db)

  setUserStatusTypeSafe(ctx.db, status)


proc testSuiteStatus*(savesDir: string) =
  testStatus()