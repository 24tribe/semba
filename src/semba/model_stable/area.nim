import std/json
import std/strutils
import std/options
import std/sequtils

import db_connector/db_sqlite

import ../semba_error
import ./area_change_lock


type Area* = object
  areaId*: int
  isDark*: bool

type AreaBgm* = object
  id*: int
  eventName*: Option[string]

type AreaBehavior* = object
  actionSequenceId*: int


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


proc getAreaBgm*(db: DbConn, areaId: int): AreaBgm =
  let areaBgmRow = db.getRow(sql"SELECT id, eventName FROM areaBgm WHERE areaId = ?", areaId)

  if areaBgmRow[0] == "":
    raise newException(SembaError, "Couldn't find areaBgm for areaId=" & $areaId)

  result.id = parseInt(areaBgmRow[0])
  let eventName = areaBgmRow[1]

  if eventName != "":
    result.eventName = some(eventName)


proc getAreaChangeLocksForAreaId*(db: DbConn, areaId: int): seq[AreaChangeLock] =
  db.getAllRows(sql"""
    SELECT areaChangeLockId
    FROM areaChangeLocks INNER JOIN mdAreaChangeLock ON areaChangeLockId = id
    WHERE areaId = ?;
  """, areaId).mapIt(AreaChangeLock(
    areaChangeLockId: parseInt(it[0]),
  ))


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


proc getAreas*(db: DbConn): seq[Area] =
  # FIXME: save/load isDark
  db.getAllRows(sql"SELECT areaId FROM areas").mapIt(Area(
    areaId: parseInt(it[0]),
  ))


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