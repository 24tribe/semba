import std/options
import std/json
import std/strutils

import ../db_connector/db_sqlite

import timestamp


type ChallengeProgressState* = enum 
  challengeProgressStateStarted = 2,
  challengeProgressStateCleared = 3

type ChallengeProgress* = object
  challengeProgressId*: int
  state*: int
  clearedAt*: Option[Timestamp]


const clearHealthyOutlawsChallengeProgressId* = 1010173


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


proc updateChallengeProgresses*(db: DbConn, challengeProgresses: JsonNode) =
  for challengeProgress in challengeProgresses:
    let challengeProgressId = challengeProgress["challengeProgressId"].getInt()
    let clearedAt = challengeProgress.getOrDefault("clearedAt")
    let state = challengeProgress["state"].getInt()

    let clearedAtStr = if clearedAt != nil: clearedAt.getStr() else: ""

    db.exec(sql"""
      INSERT INTO challengeProgresses (challengeProgressId, clearedAt, state)
      VALUES (?, ?, ?)
      ON CONFLICT (challengeProgressId) DO UPDATE SET clearedAt = ?, state = ?
    """, challengeProgressId, clearedAtStr, state, clearedAtStr, state)


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