import std/json
import std/options

import utils

import ../protojson
import ../model_stable/item
import ../model_stable/resources
import ../model_stable/status
import ../model_stable/tension_card


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


proc testSuiteTensionCard*() =
  testTensionCardEnhance()