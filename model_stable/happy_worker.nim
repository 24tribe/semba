import std/options
import std/sequtils
import std/strutils

import ../db_connector/db_sqlite

import ../extsqlite
import ../semba_error


type HappyWorkerItem* = object
  happyWorkerItemId*: int
  isCleared*: Option[bool]
  state*: int


proc getHappyWorkerItems*(db: DbConn, cityIds: openArray[int]): seq[HappyWorkerItem] =
  let rows = db.getAllRows(sql("""
    SELECT id, isCleared, state FROM happyWorkerItems WHERE cityId IN """ & sqlIntTuple(cityIds) & """
  """))

  result = rows.mapIt(HappyWorkerItem(
    happyWorkerItemId: parseInt(it[0]),
    isCleared: some(it[1] == "true"),
    state: parseInt(it[2]),
  ))


proc updateHappyWorkerItem*(db: DbConn, happyWorkerItem: HappyWorkerItem) =
  db.exec(sql"""
    UPDATE happyWorkerItems SET isCleared = ?, state = ? WHERE id = ?
  """, happyWorkerItem.isCleared.get(false), happyWorkerItem.state, happyWorkerItem.happyWorkerItemId)


proc updateHappyWorkerItems*(db: DbConn, happyWorkerItems: openArray[HappyWorkerItem]) =
  for it in happyWorkerItems:
    updateHappyWorkerItem(db, it)


proc getHappyWorkerItemChallengeId*(db: DbConn, happyWorkerItemId: int): int =
  let row = db.getRow(sql"SELECT challengeId FROM mdHappyWorkerItem WHERE id = ?", happyWorkerItemId)

  if row[0] == "":
    raise newException(SembaError, "Failed to get challengeId for happyWorkerItemId=" & $happyWorkerItemId)

  result = parseInt(row[0])


proc getChallengeAreaObjectIds*(db: DbConn, challengeId: int): seq[int] =
  let rows = db.getAllRows(sql"""
    SELECT mdAreaObjectBehavior.areaObjectId
    FROM mdChallengeProgress
    JOIN mdChallenge ON mdChallenge.id = mdChallengeProgress.challengeId
    JOIN mdAreaObjectBehavior ON mdAreaObjectBehavior.challengeProgressId = mdChallengeProgress.id
    WHERE mdChallenge.id = ?
  """, challengeId)

  result = rows.mapIt(parseInt(it[0]))


proc isHappyWorkerChallenge*(db: DbConn, challengeId: int): bool =
  db.getRow(
    sql"SELECT challengeId FROM mdHappyWorkerItem WHERE challengeId = ?", challengeId
  )[0] != ""