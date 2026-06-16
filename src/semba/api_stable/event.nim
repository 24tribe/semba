import std/json

import db_connector/db_sqlite

import ../model_stable/lux_phantasma


proc event_FinishNode*(db: DbConn, jsonReq: JsonNode): JsonNode =
  let eventFloorNodeId = jsonReq["eventFloorNodeId"].getInt()
  let questResult = jsonReq{"questResult"}.getStr("success")
  let clearedAchievementIds: JsonNode = jsonReq{"clearedAchievementIds"}

  result = %*{
    "changedResources": {
    }
  }

  if questResult == "success":
    let score = jsonReq["result"]["score"].getInt()
    let questStates = updateQuestStates(db, eventFloorNodeId, score)
    result["changedResources"]["questStates"] = %*questStates

    var ids: set[uint16] = {}
    if clearedAchievementIds != nil:
      for id in clearedAchievementIds:
        ids.incl(id.getInt().uint16)

    let eventFloorNodes = updateEventFloorNodes(db, eventFloorNodeId, ids)
    result["changedResources"]["eventFloorNodes"] = %*eventFloorNodes


proc event_ListNode*(db: DbConn): JsonNode =
  let eventFloorNodes = getEventFloorNodes(db)
  return %*{
    "changedResources": {
      "eventFloorNodes": eventFloorNodes,
    }
  }