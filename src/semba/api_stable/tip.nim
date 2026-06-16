import std/json
import std/strutils
import std/options

import db_connector/db_sqlite

import ../model_stable/resources
import ../model_stable/tip
import ../model_stable/timestamp
import ../semba_error


export timestamp


type TipReleaseByBattleRequest* = object
  battleResult: Option[string]


proc tip_ReleaseByBattle*(db: DbConn, req: TipReleaseByBattleRequest): ChangedResourcesResponse =
  if req.battleResult.isNone() or req.battleResult.get() != "lost":
    raise newException(SembaError, "battleResult != 'lost' !!!!") 

  let tipIds = [1014, 1048, 1049, 1050, 1051]

  let tipId = getFirstTipIdNotInDb(db, tipIds)

  if tipId.isSome():
    let tip = Tip(tipId: tipId.get(), releasedAt: getTimestampNow())
    addTip(db, %*tip)
    result.changedResources.tips = some(@[tip])


proc tip_Release*(db: DbConn, jsonReq: JsonNode): JsonNode =
  var tips = newSeq[JsonNode]()
  var areaObjects = newSeq[JsonNode]()

  for node in jsonReq["tipIds"]:
    let tipId = node.num

    let tip = %*{"tipId": tipId, "releasedAt": "2025-09-10T02:17:06Z"}
    addTip(db, tip)
    tips.add(tip)

    let newAreaObjects = db.getAllRows(sql"""
      SELECT areaObjectId, newAreaPointId, newAreaObjectBehaviorId, newAction
      FROM tipRelease
      WHERE tipId = ?
    """, tipId)

    for areaObject in newAreaObjects:
      areaObjects.add(%*{
        "areaObjectId": parseInt(areaObject[0]),
        "areaPointId": parseInt(areaObject[1]),
        "areaObjectBehaviorId": parseInt(areaObject[2]),
        "action": parseJson(areaObject[3]),
      })

    db.exec(sql"""
      UPDATE areaObjects
      SET areaPointId = t.newAreaPointId,
          areaObjectBehaviorId = t.newAreaObjectBehaviorId,
          action = t.newAction
      FROM tipRelease as t
      WHERE t.tipId = ? AND areaObjects.areaObjectId = t.areaObjectId
    """, tipId)

  return %*{
    "changedResources": {"tips": tips},
    "areaObjects": areaObjects
  }