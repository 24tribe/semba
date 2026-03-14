import std/json
import std/strutils

import ../db_connector/db_sqlite


type FlowerMarkLevel* = object
  requiredFlowerMark*: int
  characterMaxLevel*: int


proc getMissions*(db: DbConn): seq[JsonNode] =
  let rows = db.getAllRows(sql"""
    SELECT missionId, count, receivedStepCount, resetAt, clearedAt FROM missions
  """)

  for row in rows:
    let missionId = parseInt(row[0])
    let count = parseInt(row[1])
    let receivedStepCount = parseInt(row[2])
    let resetAt = row[3]
    let clearedAt = row[4]

    let mission = %*{
      "missionId": missionId,
      "count": count,
      "receivedStepCount": receivedStepCount,
    }

    if resetAt != "":
      mission["resetAt"] = %*resetAt

    if clearedAt != "":
      mission["clearedAt"] = %*clearedAt

    result.add(mission)


proc getFlowerMarkLevels*(db: DbConn): seq[FlowerMarkLevel] =
  let rows = db.getAllRows(sql"""
  SELECT requiredFlowerMark, characterMaxLevel FROM mdFlowerMarkLevel
  ORDER BY requiredFlowerMark DESC
  """)

  for row in rows:
    let requiredFlowerMark = parseInt(row[0])
    let characterMaxLevel = parseInt(row[1])
    result.add(FlowerMarkLevel(
      requiredFlowerMark: requiredFlowerMark,
      characterMaxLevel: characterMaxLevel
    ))