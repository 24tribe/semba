import std/tables
import std/options

import ../api_stable/follow
import ../protojson
import utils


proc testFollowSearch() =
  var ctx = getInMemorySembaCtx()

  let resJson = ctx.sembaCall("/follow/search", toJson({"userId": "123456789123"}.toTable))

  let res = protoJsonTo(resJson, Option[FollowSearchResponse])

  doAssert(res.isSome())
  doAssert(res.get().user.userId == 123456789123.ProtoJsonInt64)


proc testSuiteFollow*() =
  testFollowSearch()