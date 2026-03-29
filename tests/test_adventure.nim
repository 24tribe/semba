import std/json
import std/assertions

import test_semba


proc testAcquireAreaItem() =
    var ctx = getInMemorySembaCtx()

    let res = ctx.sembaCall("/adventure/acquire_area_item", %*{"areaItemId": 10519701})

    doAssert(res != nil)


when isMainModule:
    testAcquireAreaItem()