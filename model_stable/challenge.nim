import std/json
import std/strutils

import ../db_connector/db_sqlite


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