import std/json
import std/options

import ../db_connector/db_sqlite

import ../semba_error
import ../protojson
import ../model_stable/xb
import ../model_stable/resources


proc xb_Formation*(db: DbConn, jsonReq: JsonNode): JsonNode =
  let xbId = jsonReq["xbId"].getInt()

  let row = db.getRow(sql"SELECT content FROM xbFormations WHERE xbId=?", xbId)

  if row[0] == "":
    raise newException(SembaError, "Couldn't find formation for xbId=" & $xbId)

  let res = parseJson(row[0])

  return res


proc xb_Play*(db: DbConn, jsonReq: JsonNode): JsonNode =
  let xbId = jsonReq["xbId"].getInt()
  let zoneAreaIndex = jsonReq.getOrDefault("zoneAreaIndex").getInt()

  var fakeNextAtBatGameInfo: JsonNode = nil
  var changedResources: Option[Resources]
  var fakeCurrentAtBatGameInfo: JsonNode = nil
  popCurrentXbPlayData(db, xbId, fakeNextAtBatGameInfo, changedResources, fakeCurrentAtBatGameInfo)

  let lastCurrentAtBatGameInfo = getGameInfo(db, xbId)
  
  let currentAtBatGameInfo = createCurrentAtBatGameInfo(zoneAreaIndex, lastCurrentAtBatGameInfo, fakeCurrentAtBatGameInfo)
  
  var nextAtBatGameInfo: JsonNode = nil

  if fakeNextAtBatGameInfo != nil:
    nextAtBatGameInfo = createNextAtBatGameInfo(currentAtBatGameInfo, fakeNextAtBatGameInfo)
    updateGameInfo(db, xbId, nextAtBatGameInfo)

  result = %*{
    "currentAtBatGameInfo": currentAtBatGameInfo,
  }

  if nextAtBatGameInfo != nil:
    result["nextAtBatGameInfo"] = nextAtBatGameInfo

  if changedResources.isSome():
    updateResources(db, changedResources.get())
    result["changedResources"] = toProtoJson(changedResources.get())

  if protoJsonGetBool(currentAtBatGameInfo["currentAtBatEventInfo"]["afterGameSituation"], "isGameSet"):
    result["result"] = %*"xb_result_lost" # xbId == 10001


proc xb_UpdateTension*(db: DbConn, jsonReq: JsonNode): JsonNode =
  let xbId = jsonReq["xbId"].getInt()
  let tensionFluctuationIds = jsonReq["tensionFluctuationIds"]

  if tensionFluctuationIds.len != 1:
    raise newException(SembaError, "tensionFluctuationIds.len != 1")

  let tensionFluctuationId = tensionFluctuationIds[0].getInt()

  let gameInfo = getGameInfo(db, xbId)

  var playerTensionInfos: JsonNode = nil
  var enemyTensionInfos: JsonNode = nil

  updateTension(db, tensionFluctuationId, gameInfo, playerTensionInfos, enemyTensionInfos)
  
  updateGameInfo(db, xbId, gameInfo)

  result = %*{
    "currentAtBatGameInfo": gameInfo,
  }

  if playerTensionInfos != nil:
    result["playerTensionInfos"] = playerTensionInfos.copy()
    if tensionFluctuationId != 10001:
      result["playerTensionInfos"][0]["skitIndex"] = %*popGlobalSkitIndex(db)

  if enemyTensionInfos != nil:
    result["enemyTensionInfos"] = enemyTensionInfos.copy()
    if tensionFluctuationId != 10001:
      result["enemyTensionInfos"][0]["skitIndex"] = %*popGlobalSkitIndex(db)


proc xb_Start*(db: DbConn, jsonReq: JsonNode): JsonNode =
  let xbId = jsonReq["xbId"].getInt()

  updateCurrentXbPlayDataIdx(db, xbId, 0)
  setGlobalSkitIndex(db, 0)

  let startGameInfo = getStartGameInfo(db, xbId)
  updateGameInfo(db, xbId, startGameInfo)

  db.exec(sql"""
    INSERT INTO xbGameInfos (xbId, content) VALUES (?, ?)
    ON CONFLICT (xbId) DO UPDATE SET content = excluded.content
  """, xbId, $startGameInfo)

  return %*{
    "nextAtBatGameInfo": startGameInfo
  }