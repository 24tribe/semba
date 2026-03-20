import std/json

import ../db_connector/db_sqlite

import ../model_stable/tension_card


proc tensionCard_LimitBreakEnhance*(db: DbConn, jsonReq: JsonNode): JsonNode =
  let entityId = jsonReq["entityId"].getInt()
  let consumedEntityIds = jsonReq["consumedEntityIds"]

  let tensionCard = getTensionCard(db, entityId)
  let limitBreak = tensionCard.getOrDefault("limitBreak").getInt() + consumedEntityIds.len
  tensionCard["limitBreak"] = %*limitBreak
  updateTensionCardLimitBreak(db, entityId, limitBreak)

  for consumedEntityId in consumedEntityIds:
    db.exec(sql"DELETE FROM tensionCards WHERE entityId = ?", consumedEntityId.getInt())
    db.exec(sql"DELETE FROM tensionCardLimitBreaks WHERE entityId = ?", consumedEntityId.getInt())

  result = %*{
    "changedResources": {
      "tensionCards": [tensionCard],
    },
    "deletedResources": {
      "tensionCardEntityIds": consumedEntityIds,
    }
  }


proc tensionCard_Lock*(db: DbConn, jsonReq: JsonNode): JsonNode =
  let isLock = jsonReq.getOrDefault("isLock").getBool()
  let entityIds = jsonReq["entityIds"]

  var tensionCards = newSeq[JsonNode]()

  for entityId in entityIds:
    let tensionCard = getTensionCard(db, entityId.getInt())
    tensionCard["isLocked"] = %*isLock
    tensionCards.add(tensionCard)
    let isLocked = if isLock: 1 else: 0
    db.exec(
      sql"UPDATE tensionCards SET isLocked = ? WHERE entityId = ?",
      isLocked, entityId.getInt()
    )

  result = %*{
    "changedResources": {
      "tensionCards": tensionCards,
    }
  }