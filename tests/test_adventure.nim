import std/json
import std/assertions
import std/options

import test_semba
import ../model_stable/reward


proc sameReward(r1: Reward, r2: Reward): bool =
    result = r1.`type` == r2.`type` and r1.id == r2.id and r1.quantity == r2.quantity


proc testAcquireAreaItemInLogs() =
    var ctx = getInMemorySembaCtx()

    let res = ctx.sembaCall("/adventure/acquire_area_item", %*{"areaItemId": 10500102})

    doAssert(res != nil)

    let rewards = to(res["rewards"], seq[Rewards])

    doAssert(rewards.len == 1)

    let firstRewards = rewards[0]

    doAssert(firstRewards.`type`.get(0) == 5)

    let contents = firstRewards.contents

    doAssert(contents.len in {3, 4}) # the forth one is random

    let reward1 = Reward(`type`: 3, id: 1, quantity: 1000)
    var r1Found = false

    let reward2 = Reward(`type`: 13, id: 1, quantity: 100)
    var r2Found = false

    let reward3 = Reward(`type`: 7, id: 2, quantity: 500)
    var r3Found = false

    for reward in contents:
        if sameReward(reward, reward1):
            r1Found = true

        if sameReward(reward, reward2):
            r2Found = true

        if sameReward(reward, reward3):
            r3Found = true

    doAssert(r1Found and r2Found and r3Found)


proc testAcquireAreaItemNotInLogs() =
    var ctx = getInMemorySembaCtx()

    let res = ctx.sembaCall("/adventure/acquire_area_item", %*{"areaItemId": 10519701})

    doAssert(res != nil)


when isMainModule:
    testAcquireAreaItemInLogs()
    testAcquireAreaItemNotInLogs()