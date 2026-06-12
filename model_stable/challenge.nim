import std/json
import std/strutils
import std/options

import ../db_connector/db_sqlite

import ../extsqlite
import ../semba_error
import timestamp


type ChallengeState* = enum
  challengeStateStarted = 5
  challengeStateCompleted = 6

type Challenge* = object
  challengeId*: int
  state*: int
  clearedAt*: Option[Timestamp]
  expiresAt*: Option[Timestamp]


proc updateChallenges*(db: DbConn, challenges: seq[JsonNode]) =
  for challenge in challenges:
    let challengeId = challenge["challengeId"].getInt()
    let state = challenge["state"].getInt()
    let clearedAt = challenge.getOrDefault("clearedAt").getStr()
    let expiresAt = challenge.getOrDefault("expiresAt").getStr()
    db.exec(sql"""
      INSERT INTO challenges (challengeId, state, clearedAt, expiresAt)
      VALUES (?, ?, ?, ?)
      ON CONFLICT (challengeId) DO
      UPDATE SET state = excluded.state,
                 clearedAt = excluded.clearedAt,
                 expiresAt = excluded.expiresAt
    """, challengeId, state, clearedAt, expiresAt)


proc upsertChallenges*(db: DbConn, challenges: openArray[Challenge]) =
  for chal in challenges:
    db.exec(sql"""
      INSERT INTO challenges (challengeId, state, clearedAt, expiresAt)
      VALUES (?, ?, ?, ?)
      ON CONFLICT (challengeId) DO
      UPDATE SET state = excluded.state,
                 clearedAt = excluded.clearedAt,
                 expiresAt = excluded.expiresAt
    """, chal.challengeId, chal.state, optionToSqlArg(chal.clearedAt), optionToSqlArg(chal.expiresAt))


proc getChallengeFirstProgressId*(db: DbConn, challengeId: int): int =
  let row = db.getRow(sql"SELECT firstProgressId FROM mdChallenge WHERE id = ?", challengeId)

  if row[0] == "":
    raise newException(SembaError, "Couldn't get firstProgressId for challengeId=" & $challengeId)

  result = parseInt(row[0])


proc getChallenges*(db: DbConn): seq[JsonNode] =
  let query = sql"SELECT challengeId, state, clearedAt, expiresAt FROM challenges"

  for row in db.getAllRows(query):
    let challengeId = parseInt(row[0])
    let state = parseInt(row[1])
    let clearedAt = row[2]
    let expiresAt = row[3]

    let challenge = %*{
      "challengeId": challengeId,
      "state": state
    }

    if clearedAt != "":
      challenge["clearedAt"] = %*clearedAt

    if expiresAt != "":
      challenge["expiresAt"] = %*expiresAt

    result.add(challenge)