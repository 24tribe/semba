import std/assertions
import std/json
import std/options

import ../model_stable/resources
import ../model_stable/character
import utils


proc testCharacterEquip() =
    var ctx = getInMemorySembaCtx()

    let gearId = 10000
    let res = ctx.sembaCall("/character/equip", %*{ "characterId": 101101, "gearSlot3": gearId })

    doAssert(res != nil)

    let crRes = to(res, ChangedResourcesResponse)

    let characters = to(%*(crRes.changedResources.characters.get()), seq[Character])

    doAssert(characters.len == 1)
    doAssert(characters[0].gearSlot1.isNone())
    doAssert(characters[0].gearSlot2.isNone())
    doAssert(characters[0].gearSlot3.get() == gearId)

    let res2 = ctx.sembaCall("/character/equip", %*{ "characterId": 101101 })

    let crRes2 = to(res2, ChangedResourcesResponse)

    let characters2 = to(%*(crRes2.changedResources.characters.get()), seq[Character])

    doAssert(characters2.len == 1)
    doAssert(characters2[0].gearSlot1.isNone())
    doAssert(characters2[0].gearSlot2.isNone())
    doAssert(characters2[0].gearSlot3.isNone())

    # TODO: should check status updates?


when isMainModule:
    testCharacterEquip()