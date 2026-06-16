import std/options
import std/json

import ../../src/semba/api_stable/follow
import ../../src/semba/protojson
import ./utils


proc testFollowSearch() =
  var ctx = getInMemorySembaCtx()

  let resJson = ctx.sembaCall("/follow/search", %*{"userId": "123456789123"})

  let res = protoJsonTo(resJson, Option[FollowSearchResponse])

  doAssert(res.isSome())
  doAssert(res.get().user.userId == 123456789123.ProtoJsonInt64)


proc testSuiteFollow*(savesDir: string) =
  testFollowSearch()