import std/options
import std/strutils
import std/sequtils

import db_connector/db_sqlite

import ../semba_error


type AreaObjectLock* = object
  areaObjectLockId*: int
  count*: Option[int]

type AreaObjectLockTrigger* = enum
  aolTriggerBattle = 1
  aolTriggerMiniGame = 2


proc getAreaObjectLock*(db: DbConn, areaObjectLockId: int): AreaObjectLock =
  let row = db.getRow(sql"SELECT count FROM areaObjectLocks WHERE areaObjectLockId = ?", areaObjectLockId)

  if row[0] == "":
    raise newException(SembaError, "Couldn't get areaObjectLock for id=" & $areaObjectLockId)

  result = AreaObjectLock(areaObjectLockId: areaObjectLockId, count: some(parseInt(row[0])))


proc upsertAreaObjectLocks*(db: DbConn, locks: openArray[AreaObjectLock]) =
  for lock in locks:
    db.exec(sql"""
      INSERT INTO areaObjectLocks (areaObjectLockId, count) VALUES (?, ?)
      ON CONFLICT (areaObjectLockId) DO
      UPDATE SET count = excluded.count
    """, lock.areaObjectLockId, lock.count.get(0))


proc getAreaObjectLocks*(db: DbConn): seq[AreaObjectLock] =
  let rows = db.getAllRows(sql"SELECT areaObjectLockId, count FROM areaObjectLocks")
  result = rows.mapIt(AreaObjectLock(areaObjectLockId: parseInt(it[0]), count: some(parseInt(it[1]))))


proc getAreaObjectLockId(db: DbConn, triggerType: AreaObjectLockTrigger, triggerId: int): Option[int] =
  let row = db.getRow(sql"""
    SELECT areaObjectLockId FROM areaObjectLockTriggers WHERE triggerType = ? AND triggerId = ?
  """, triggerType.int, triggerId)

  if row[0] != "":
    result = some(parseInt(row[0]))


proc getAreaObjectLockIdForBattle*(db: DbConn, battleTriggerId: int): Option[int] =
  getAreaObjectLockId(db, aolTriggerBattle, battleTriggerId)


proc getAreaObjectLockIdForMiniGame*(db: DbConn, areaId: int, miniGameId: int): Option[int] =
  if miniGameId == 105055: # this one is non-unique...
    if areaId == 141001:
      some(14530401)
    else: # 141002
      some(14531301)
  else:
    getAreaObjectLockId(db, aolTriggerMiniGame, miniGameId)