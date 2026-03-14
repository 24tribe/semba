import std/json
import std/strutils
import std/math

import ../db_connector/db_sqlite

import ../semba_error


proc getAreaBgms*(db: DbConn): seq[JsonNode] =
  let rows = db.getAllRows(sql"SELECT areaId, id, eventName FROM areaBgm")

  for row in rows:
    let areaId = parseInt(row[0])
    let id = parseInt(row[1])
    let eventName = row[2]

    result.add(%*{
      "areaId": areaId,
      "id": id,
      "eventName": eventName
    })


proc addAreaBgm*(db: DbConn, areaBgm: JsonNode) =
  let areaId = areaBgm["areaId"].getInt()
  let id = areaBgm["id"].getInt()
  let eventName = areaBgm["eventName"].getStr()

  db.exec(sql"""
    INSERT INTO areaBgm (areaId, id, eventName) VALUES (?, ?, ?)
  """, areaId, id, eventName)


proc hasArea*(db: DbConn, areaId: int): bool =
  let row = db.getRow(sql"SELECT areaId FROM areas WHERE areaId=?", areaId)
  return row[0] != ""


proc addArea*(db: DbConn, areaId: int) =
  db.exec(sql"""
    INSERT INTO areas (areaId) VALUES (?)
    ON CONFLICT DO NOTHING
  """, areaId)


proc calcDistance(x1: float, y1: float, z1: float, x2: float, y2: float, z2: float): float =
  return sqrt(pow(x2-x1, 2) + pow(y2-y1, 2) + pow(z2-z1, 2))


proc getAreaBgm*(db: DbConn, areaId: int): JsonNode =
  let areaBgmRow = db.getRow(sql"SELECT id, eventName FROM areaBgm WHERE areaId = ?", areaId)

  if areaBgmRow[0] == "":
    raise newException(SembaError, "Couldn't find areaBgm for areaId=" & $areaId)

  let areaBgmId = parseInt(areaBgmRow[0])
  let eventName = areaBgmRow[1]

  result = %*{"id": areaBgmId}

  if eventName != "":
    result["eventName"] = %*eventName


proc updatePos*(db: DbConn, status: var JsonNode, fromAreaId: int, toAreaId: int) =
  let gatesRows = db.getAllRows(sql"""
    SELECT fromPosX, fromPosY, fromPosZ, toPosX, toPosY, toPosZ, toDirection
    FROM gates
    WHERE fromAreaId = ? AND toAreaId = ?
  """, fromAreaId, toAreaId)

  let currentPosX = status["currentPositionCoordinates"]["x"].getFloat()
  let currentPosY = status["currentPositionCoordinates"]["y"].getFloat()
  let currentPosZ = status["currentPositionCoordinates"]["z"].getFloat()

  var hasDist = false
  var smallestDist = 0.0
  var foundToPosX = 0.0
  var foundToPosY = 0.0
  var foundToPosZ = 0.0
  var foundToDirection = 0

  for gateRow in gatesRows:
    let fromPosX = parseFloat(gateRow[0])
    let fromPosY = parseFloat(gateRow[1])
    let fromPosZ = parseFloat(gateRow[2])

    let dist = calcDistance(fromPosX, fromPosY, fromPosZ, currentPosX, currentPosY, currentPosZ)

    if not hasDist or dist < smallestDist:
      hasDist = true
      smallestDist = dist
      foundToPosX = parseFloat(gateRow[3])
      foundToPosX = parseFloat(gateRow[4])
      foundToPosX = parseFloat(gateRow[5])
      foundToDirection = parseInt(gateRow[6])

  if not hasDist:
    echo "[SembaCall] Warning: updatePos couldn't find a gate..."
  else:
    status["currentPositionCoordinates"] = %*{"x": foundToPosX, "y": foundToPosY, "z": foundToPosZ}


proc getAreaChangeLocksForAreaId*(db: DbConn, areaId: int): seq[JsonNode] =
  let rows = db.getAllRows(sql"""
    SELECT areaChangeLockId
    FROM areaChangeLocks INNER JOIN mdAreaChangeLock ON areaChangeLockId = id
    WHERE areaId = ?;
  """, areaId)

  for row in rows:
    let areaChangeLockId = parseInt(row[0])
    result.add(%*{
      "areaChangeLockId": areaChangeLockId
    })


proc getAreaActionSequenceIds*(db: DbConn): seq[JsonNode] =
  let rows = db.getAllRows(sql"SELECT areaId, actionSequenceId FROM areaActionSequenceIds")

  for row in rows:
    let areaId = parseInt(row[0])
    let actionSequenceId = parseInt(row[1])
    result.add(%*{
      "areaId": areaId,
      "actionSequenceId": actionSequenceId,
    })


proc addAreaActionSequenceId*(db: DbConn, areaActionSequenceId: JsonNode) =
  let areaId = areaActionSequenceId["areaId"].getInt()
  let actionSequenceId = areaActionSequenceId["actionSequenceId"].getInt()

  db.exec(sql"""
    INSERT INTO areaActionSequenceIds (areaId, actionSequenceId) VALUES (?, ?)
    ON CONFLICT (areaId) DO
    UPDATE SET actionSequenceId = excluded.actionSequenceId
  """, areaId, actionSequenceId)


proc getActionSequenceId*(db: DbConn, areaId: int): int =
  let row = db.getRow(sql"SELECT actionSequenceId FROM areaActionSequenceIds WHERE areaId = ?", areaId)
  result = if row[0] != "": parseInt(row[0]) else: 0


proc getAreas*(db: DbConn): seq[JsonNode] =
  for row in db.getAllRows(sql"SELECT areaId FROM areas"):
    let areaId = parseInt(row[0])
    result.add(%*{
      "areaId": areaId
    })


proc updateActionSequenceId*(db: DbConn, areaId: int, actionSequenceId: int) =
  db.exec(sql"""
    INSERT INTO areaActionSequenceIds (areaId, actionSequenceId) VALUES (?, ?)
    ON CONFLICT (areaId) DO
    UPDATE SET actionSequenceId = excluded.actionSequenceId
  """, areaId, actionSequenceId)


proc getReadSequenceAreaAction*(db: DbConn, sequenceRequestId: int): tuple[areaId: int, actionSequenceId: int] =
  let row = db.getRow(
    sql"SELECT areaId, actionSequenceId FROM readSequenceAreaAction WHERE sequenceRequestId = ?",
    sequenceRequestId
  )

  if row[0] == "":
    return (0, 0)

  return (parseInt(row[0]), parseInt(row[1]))


proc getReadSequenceAreaBgm*(db: DbConn, seqReqId: int): tuple[areaId: int, id: int, eventName: string] =
  let row = db.getRow(
    sql"SELECT areaId, id, eventName FROM readSequenceAreaBgm WHERE sequenceRequestId = ?",
    seqReqId
  )

  if row[0] == "":
    return (0, 0, "")

  let areaId = parseInt(row[0])
  let id = parseInt(row[1])
  let eventName = row[2]

  return (areaId, id, eventName)


proc updateAreaBgm*(db: DbConn, areaId: int, id: int, eventName: string) =
  db.exec(
    sql"UPDATE areaBgm SET id = ?, eventName = ? WHERE areaId = ?",
    id, eventName, areaId
  )