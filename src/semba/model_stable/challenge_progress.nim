import std/options
import std/json
import std/strutils
import std/sequtils

import db_connector/db_sqlite

import ../extsqlite
import ../semba_error
import timestamp

export timestamp


type ChallengeProgressState* = enum 
  challengeProgressStateNotStarted = 1
  challengeProgressStateStarted = 2
  challengeProgressStateCleared = 3

type ChallengeProgress* = object
  challengeProgressId*: int
  state*: int
  clearedAt*: Option[Timestamp]


const clearHealthyOutlawsChallengeProgressId* = 1010173
const lastTutorialChallengeProgressId* = 1000161


proc isChallengeProgressComplete*(db: DbConn, challengeProgressId: int): bool =
  db.getRow(sql"""
    SELECT state FROM challengeProgresses WHERE challengeProgressId = ?
  """, challengeProgressId)[0] == $(challengeProgressStateCleared.int)


proc getChallengeProgresses*(db: DbConn): seq[ChallengeProgress] =
  db.getAllRows(sql"""
    SELECT challengeProgressId, clearedAt, state
    FROM challengeProgresses
  """).mapIt(ChallengeProgress(
    challengeProgressId: parseInt(it[0]),
    clearedAt: tryParseTimestamp(it[1]),
    state: parseInt(it[2]),
  ))


proc getNextChallengeProgress*(db: DbConn, challengeProgressId: int): Option[int] =
  let row = db.getRow(
    sql"SELECT nextProgressId FROM mdChallengeRoute WHERE currentProgressId = ?",
    challengeProgressId
  )

  if row[0] != "":
    result = some(parseInt(row[0]))


proc updateChallengeProgresses*(db: DbConn, challengeProgresses: openArray[ChallengeProgress]) =
  for challengeProgress in challengeProgresses:
    db.exec(sql"""
      INSERT INTO challengeProgresses (challengeProgressId, clearedAt, state)
      VALUES (?, ?, ?)
      ON CONFLICT (challengeProgressId) DO UPDATE SET clearedAt = excluded.clearedAt, state = excluded.state
    """, challengeProgress.challengeProgressId, optionToSqlArg(challengeProgress.clearedAt), challengeProgress.state)


proc upsertChallengeProgresses*(db: DbConn, challengeProgresses: openArray[ChallengeProgress]) =
  for chalProg in challengeProgresses:
    db.exec(sql"""
      INSERT INTO challengeProgresses (challengeProgressId, clearedAt, state)
      VALUES (?, ?, ?)
      ON CONFLICT (challengeProgressId) DO UPDATE SET clearedAt = excluded.clearedAt, state = excluded.state
    """, chalProg.challengeProgressId, optionToSqlArg(chalProg.clearedAt), chalProg.state)


proc getChallengeProgressIds*(db: DbConn, challengeId: int): seq[int] =
  let rows = db.getAllRows(sql"SELECT id FROM mdChallengeProgress WHERE challengeId = ?", challengeId)
  result = rows.mapIt(parseInt(it[0]))


proc getChallengeId*(db: DbConn, challengeProgressId: int): int =
  let row = db.getRow(sql"SELECT challengeId FROM mdChallengeProgress WHERE id = ?", challengeProgressId)

  if row[0] == "":
    raise newException(SembaError, "Couldn't get challengeId for challengeProgressId " & $challengeProgressId)

  result = parseInt(row[0])