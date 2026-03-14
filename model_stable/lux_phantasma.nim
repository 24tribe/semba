import std/strutils
import std/json
import std/sequtils

import ../db_connector/db_sqlite


const minEventFloorNodeId = 113101
const maxEventFloorNodeId = 113128


proc getEventLiftAreaObject(areaPointId: int): JsonNode =
  return %*{
    "areaObjectId": 141001,
    "areaPointId": areaPointId,
    "areaObjectBehaviorId": 14100101,
    "action": {
        "type": 10,
        "id": 1,
        "eventLiftId": 14100101
    }
  }


proc getLuxPhantasmaAreaObjects*(): seq[JsonNode] =
  # 130801921: event lift
  # 130801922: bar counter
  # 130801923: kazuki first encounter in event
  result.add(getEventLiftAreaObject(130801921))


proc addClearedAchievement*(db: DbConn, clearedAchievement: JsonNode) =
  let id = clearedAchievement["id"].getInt()
  let eventFloorNodeId = clearedAchievement["eventFloorNodeId"].getInt()

  db.exec(
    sql"INSERT INTO clearedAchievements (id, eventFloorNodeId) VALUES (?, ?)",
    id, eventFloorNodeId
  )


proc getClearedAchievements*(db: DbConn): seq[JsonNode] =
  let rows = db.getAllRows(sql"SELECT id, eventFloorNodeId FROM clearedAchievements")

  for row in rows:
    let id = parseInt(row[0])
    let eventFloorNodeId = parseInt(row[1])
    result.add(%*{"id": id, "eventFloorNodeId": eventFloorNodeId})


proc getClearedAchievementIds(db: DbConn, eventFloorNodeId: int): set[uint16] =
  let rows = db.getAllRows(
    sql"SELECT id FROM clearedAchievements WHERE eventFloorNodeId = ?", eventFloorNodeId
  )

  for row in rows:
    let clearedAchievementId = parseInt(row[0])
    result.incl(clearedAchievementId.uint16)


proc getEventFloorNodes*(db: DbConn): seq[JsonNode] =
  for eventFloorNodeId in minEventFloorNodeId..maxEventFloorNodeId:
    var eventFloorNode = %*{
      "eventFloorNodeId": eventFloorNodeId,
      "unlockedAt": "2025-03-20T18:56:05Z"
    }

    let clearedAchievementIds = toSeq(getClearedAchievementIds(db, eventFloorNodeId))

    if clearedAchievementIds.len > 0:
      eventFloorNode["clearedAchievementIds"] = %*clearedAchievementIds

    result.add(eventFloorNode)


proc updateQuestStates*(db: DbConn, questId: int, score: int): seq[JsonNode] =
  let row = db.getRow(sql"SELECT clearCount, bestScore FROM questStates WHERE questId = ?", questId)

  var clearCount = 1
  var bestScore = score

  if row[0] == "":
    db.exec(sql"""
      INSERT INTO questStates (questId, clearCount, bestScore)
      VALUES (?, 1, ?)
    """, questId, bestScore)
  else:
    clearCount += parseInt(row[0])
    let lastBestScore = parseInt(row[1])
    if lastBestScore > bestScore:
      bestScore = lastBestScore
    else:
      db.exec(
        sql"UPDATE questStates SET clearCount = ?, bestScore = ? WHERE questId = ?",
        clearCount, bestScore, questId
      )

  result.add(%*{
    "questId": questId,
    "clearCount": clearCount,
    "bestScore": bestScore
  })


proc addQuestState*(db: DbConn, questState: JsonNode) =
  let questId = questState["questId"].getInt()
  let clearCount = questState["clearCount"].getInt()
  let bestScore = questState["bestScore"].getInt()

  db.exec(
    sql"INSERT INTO questStates (questId, clearCount, bestScore) VALUES (?, ?, ?)",
    questId, clearCount, bestScore
  )

proc getQuestStates*(db: DbConn): seq[JsonNode] =
  let rows = db.getAllRows(sql"SELECT questId, clearCount, bestScore FROM questStates")

  for row in rows:
    let questId = parseInt(row[0])
    let clearCount = parseInt(row[1])
    let bestScore = parseInt(row[2])

    result.add(%*{
      "questId": questId,
      "clearCount": clearCount,
      "bestScore": bestScore
    })


proc updateEventFloorNodes*(db: DbConn, eventFloorNodeId: int, clearedAchievementIds: set[uint16]): seq[JsonNode] =
  let ids = clearedAchievementIds + getClearedAchievementIds(db, eventFloorNodeId)

  for id in ids:
    db.exec(sql"""
      INSERT INTO clearedAchievements (id, eventFloorNodeId)
      VALUES (?, ?)
      ON CONFLICT (id) DO
      UPDATE SET eventFloorNodeId = excluded.eventFloorNodeId
    """, id, eventFloorNodeId)

  let res = %*{
    "eventFloorNodeId": eventFloorNodeId,
    "unlockedAt": "2025-03-20T18:56:05Z",
  }

  res["clearedAchievementIds"] = %*toSeq(ids)

  result.add(res)