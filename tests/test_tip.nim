import std/assertions
import std/json

import utils


proc testTipReleaseByBattle() =
    var ctx = getInMemorySembaCtx()

    let res = sembaCall(ctx, "/tip/release_by_battle", %*{ "battleResult": "lost" })

    doAssert res != nil

    doAssert res.hasKey("changedResources")

    if res["changedResources"]["tips"] != nil:
        let tips = res["changedResources"]["tips"].getElems()
        doAssert(tips.len == 1)
        doAssert(tips[0].hasKey("releasedAt"))
        let tipIds: set[int16] = {1014, 1048, 1049, 1050, 1051}
        doAssert(tips[0]["tipId"].getInt().int16 in tipIds)


when isMainModule:
    testTipReleaseByBattle()