import std/options

import ../db_connector/db_sqlite

import ../model_stable/item
import ../model_stable/resources
import ../model_stable/tension_card
import ../model_stable/status


type TensionCardEnhanceRequest* = object
  consumedItems*: seq[ConsumedItem]
  entityId*: int

type TensionCardLimitBreakEnhanceRequest* = object
  entityId*: int
  consumedEntityIds*: seq[int]
  consumedItem*: ConsumedItem

type TensionCardLimitBreakEnhanceResponse* = object
  changedResources*: Resources
  deletedResources*: ResourceEntities

type TensionCardLockRequest* = object
  entityIds*: seq[int]
  isLock*: bool


proc tensionCard_LimitBreakEnhance*(db: DbConn, req: TensionCardLimitBreakEnhanceRequest): TensionCardLimitBreakEnhanceResponse =
  var tensionCard = getTensionCards(db, [req.entityId])[0]
  tensionCard.limitBreak += req.consumedEntityIds.len
  upsertTensionCard(db, tensionCard)

  deleteTensionCards(db, req.consumedEntityIds)

  result = TensionCardLimitBreakEnhanceResponse(
    changedResources: Resources(tensionCards: @[tensionCard]),
    deletedResources: ResourceEntities(tensionCardEntityIds: req.consumedEntityIds),
  )


proc tensionCard_Lock*(db: DbConn, req: TensionCardLockRequest): ChangedResourcesResponse =
  var tensionCards = getTensionCards(db, req.entityIds)

  for tensionCard in tensionCards.mitems:
    tensionCard.isLocked = req.isLock

  upsertTensionCards(db, tensionCards)
  result.changedResources.tensionCards = tensionCards


proc tensionCard_Enhance*(db: DbConn, req: TensionCardEnhanceRequest): ChangedResourcesResponse =
  var changedResources: Resources

  let exp = req.consumedItems[0].quantity
  let kane = (exp*3) div 10

  var status = getUserStatusTypeSafe(db)
  status.gold -= kane
  setUserStatusTypeSafe(db, status)
  changedResources.status = some(status)

  var item = getItem(db, tcExpItemId).get(Item(itemId: tcExpItemId))
  item.quantity -= exp
  changedResources.items = @[item]
  updateItems(db, changedResources.items)

  result.changedResources = changedResources