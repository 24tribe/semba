import std/json
import std/strutils
import std/options
import std/sequtils

import db_connector/db_sqlite

import ../semba_error
import ./area_change_lock
import ./challenge_progress


type Area* = object
  areaId*: int
  isDark*: bool

type AreaBgm* = object
  id*: int
  eventName*: Option[string]

type AreaBehavior* = object
  actionSequenceId*: int

# same as AreaObjectBehaviorConditionType?
type MdAreaBehaviorConditionType* = enum
  mdABCStartedChallengeProgress = 1
  mdABCClearedChallengeProgress = 2
  mdABCHospital = 10


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


proc getAreas*(db: DbConn): seq[Area] =
  # FIXME: save/load isDark
  db.getAllRows(sql"SELECT areaId FROM areas").mapIt(Area(
    areaId: parseInt(it[0]),
  ))


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


proc getAreaBehavior*(db: DbConn, areaId: int): Option[AreaBehavior] = 
  let row = db.getRow(
    sql"""
      SELECT actionSequenceId
      FROM mdAreaBehavior
        JOIN challengeProgresses ON challengeProgresses.challengeProgressId = mdAreaBehavior.conditionId
      WHERE areaId = ? AND ((conditionType = ? AND state = ?) OR (conditionType = ? AND state = ?))
      ORDER BY CAST(priority AS INT) DESC
    """,
    areaId,
    mdABCStartedChallengeProgress.int, challengeProgressStateStarted.int,
    mdABCClearedChallengeProgress.int, challengeProgressStateCleared.int
  )

  if row[0] != "":
    result = some(AreaBehavior(actionSequenceId: parseInt(row[0])))


proc getAreaBehaviorHospital*(db: DbConn, areaId: int): Option[AreaBehavior] =
  let row = db.getRow(sql"""
    SELECT actionSequenceId FROM mdAreaBehavior WHERE areaId = ? AND conditionType = ?
  """, areaId, mdABCHospital.int)

  if row[0] != "":
    result = some(AreaBehavior(actionSequenceId: parseInt(row[0])))
