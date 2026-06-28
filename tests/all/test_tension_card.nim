import std/json
import std/options
import std/sequtils
import std/sets

import ./utils
import ../../src/semba/protojson
import ../../src/semba/model_stable/item
import ../../src/semba/model_stable/resources
import ../../src/semba/model_stable/status
import ../../src/semba/model_stable/tension_card
import ../../src/semba/model_stable/tension_card_level_limit

proc testTensionCardEnhance() =
  var ctx = getInMemorySembaCtx()

  var beforeStatus = getUserStatusTypeSafe(ctx.db)
  beforeStatus.gold = 10000
  setUserStatusTypeSafe(ctx.db, beforeStatus)

  const tcExp = 10000
  updateItems(ctx.db, [Item(itemId: 2, quantity: tcExp)])

  const tcEntityId = 5
  var beforeTensionCard = getTensionCards(ctx.db, [tcEntityId])[0]

  const consumedTcExp = 2100

  let res = ctx.sembaCall("/tension_card/enhance", %*{
    "consumedItems": [ { "itemId": 2, "quantity": consumedTcExp } ], "entityId": tcEntityId
  }).protoJsonTo(Option[ChangedResourcesResponse])

  doAssert(res.isSome)

  let changedResources = res.get().changedResources

  const expectedConsumedKane = 630
  doAssert(changedResources.status.get().gold == beforeStatus.gold - expectedConsumedKane)

  doAssert(changedResources.items[0].itemId == 2)
  doAssert(changedResources.items[0].quantity == tcExp - consumedTcExp)

  let tcIndex = changedResources.tensionCards.findIt(it.entityId == tcEntityId)
  doAssert(tcIndex != -1)

  let tc = changedResources.tensionCards[tcIndex]
  doAssert(tc.exp == beforeTensionCard.exp + consumedTcExp)


proc testGetNextTCLevelLimit() =
  var ctx = getInMemorySembaCtx()
  let tensionCardId = 20001
  let levelLimit = getNextTCLevelLimit(ctx.db, tensionCardId, 10)

  doAssert(levelLimit.maxLevel == 20)
  doAssert(levelLimit.goldCost == 10000)

  doAssert(levelLimit.itemCosts.toHashSet == [
    MdItem(itemId: 50061, quantity: 5),
    MdItem(itemId: 3103, quantity: 3),
    MdItem(itemId: 5011, quantity: 1),
  ].toHashSet)

    
proc testTensionCardLevelLimitEnhance(savesDir: string) =
  var ctx = getInMemorySembaCtx()

  ctx.loadSaveFile(savesDir, "before lvl break tc")

  let status = getUserStatusTypeSafe(ctx.db)

  let res = ctx.sembaCall("/tension_card/level_limit_enhance", %*{
    "entityId": 4
  }).protoJsonTo(Option[ChangedResourcesResponse])

  doAssert(res.isSome)

  let changedResources = res.get().changedResources

  doAssert(changedResources.tensionCards.len == 1)
  doAssert(changedResources.tensionCards[0].maxLevel == 20)

  doAssert(status.gold - 10000 == changedResources.status.get().gold)

  # FIXME: check consumed items
  # FIXME: check consumed mission 1041039


proc testSuiteTensionCard*(savesDir: string) =
  testTensionCardEnhance()
  testGetNextTCLevelLimit()
  testTensionCardLevelLimitEnhance(savesDir)
