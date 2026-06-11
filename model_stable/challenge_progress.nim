import std/options
import std/json
import std/strutils
import std/sequtils

import ../db_connector/db_sqlite

import ../extsqlite
import timestamp


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


proc isChallengeProgressComplete*(challengeProgress: JsonNode): bool =
  result = challengeProgress != nil and challengeProgress.getOrDefault("state").getInt() == 3


proc addChallengeProgress*(db: DbConn, challengeProgress: JsonNode) =
  let challengeProgressId = challengeProgress["challengeProgressId"].getInt()
  let clearedAt = challengeProgress.getOrDefault("clearedAt").getStr()
  let state = challengeProgress["state"].getInt()

  db.exec(sql"""
    INSERT INTO challengeProgresses (challengeProgressId, clearedAt, state)
    VALUES (?, ?, ?)
  """, challengeProgressId, clearedAt, state)


proc getChallengeProgresses*(db: DbConn): seq[JsonNode] =
  let challengeProgressesRows = db.getAllRows(sql"""
    SELECT challengeProgressId, clearedAt, state
    FROM challengeProgresses
  """)

  for challengeProgressRow in challengeProgressesRows:
    let challengeProgressId = parseInt(challengeProgressRow[0])
    let clearedAt = challengeProgressRow[1]
    let state = parseInt(challengeProgressRow[2])

    if clearedAt != "":
      result.add(%*{
        "challengeProgressId": challengeProgressId,
        "clearedAt": clearedAt,
        "state": state
      })
    else:
      result.add(%*{
        "challengeProgressId": challengeProgressId,
        "state": state
      })


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


proc getChallengeProgress*(db: DbConn, challengeProgressId: int): JsonNode =
  let row = db.getRow(sql"""
    SELECT challengeProgressId, clearedAt, state FROM challengeProgresses
    WHERE challengeProgressId = ?
  """, challengeProgressId)

  if row[0] != "":
    let clearedAt = row[1]
    let state = parseInt(row[2])
    result = %*{"challengeProgressId": challengeProgressId, "state": state}
    if clearedAt != "":
      result["clearedAt"] = %*clearedAt