import std/options
import std/strutils
import std/json

import ../db_connector/db_sqlite

import ../extsqlite


type TaskConditionType* = enum
  taskConditionTypeSequenceRequest = 1
  taskConditionTypeBattleFinish = 2

type MdChallengeTask* = object
  challengeProgressId*: int
  count*: Option[int]
  id*: int
  summaryChallengeId*: Option[int]
  targetAreaObjectBehaviorId*: Option[int]
  targetAreaPointId*: Option[int]
  targetNineSequenceId*: Option[int]
  targetRadius*: Option[int]
  taskConditionKeyId*: Option[int]
  taskConditionType*: Option[int]
  totalTaskConditionId*: Option[int]

type ChallengeTask* = object
  challengeTaskId*: int
  count*: int
  clearedAt*: Option[string]


proc getOtherChallengeTasks*(db: DbConn, challengeTask: MdChallengeTask): seq[MdChallengeTask] =
  let rows = db.getAllRows(sql"""
    SELECT count, id, summaryChallengeId, targetAreaObjectBehaviorId,
           targetAreaPointId, targetNineSequenceId, targetRadius, totalTaskConditionId,
           taskConditionType, taskConditionKeyId
    FROM mdChallengeTask
    WHERE challengeProgressId = ? AND id != ?
  """, challengeTask.challengeProgressId, challengeTask.id)

  for row in rows:
    result.add(MdChallengeTask(
      challengeProgressId: challengeTask.challengeProgressId,
      count: tryParseInt(row[0]),
      id: parseInt(row[1]),
      summaryChallengeId: tryParseInt(row[2]),
      targetAreaObjectBehaviorId: tryParseInt(row[3]),
      targetAreaPointId: tryParseInt(row[4]),
      targetNineSequenceId: tryParseInt(row[5]),
      targetRadius: tryParseInt(row[6]),
      totalTaskConditionId: tryParseInt(row[7]),
      taskConditionType: tryParseInt(row[8]),
      taskConditionKeyId: tryParseInt(row[9]),
    ))


proc isChallengeTaskComplete*(db: DbConn, challengeTaskId: int): bool =
  # Note: challengeTaskStateCleared == 3
  let row = db.getRow(
    sql"SELECT challengeTaskId FROM challengeTasks WHERE challengeTaskId = ? AND clearedAt != ''",
    challengeTaskId
  )
  result = row[0] != ""


proc updateChallengeTasks*(db: DbConn, challengeTasks: JsonNode) =
  for challengeTask in challengeTasks:
    let challengeTaskId = challengeTask["challengeTaskId"].getInt()
    let clearedAt = challengeTask["clearedAt"].getStr()
    let count = challengeTask["count"].getInt()

    db.exec(sql"""
      INSERT INTO challengeTasks (challengeTaskId, clearedAt, count)
      VALUES (?, ?, ?)
      ON CONFLICT (challengeTaskId) DO UPDATE SET clearedAt = ?, count = ?
    """, challengeTaskId, clearedAt, count, clearedAt, count)


proc addChallengeTask*(db: DbConn, challengeTask: JsonNode) =
  let challengeTaskId = challengeTask["challengeTaskId"].getInt()
  let clearedAt = challengeTask["clearedAt"].getStr()
  let tmpCount = challengeTask.getOrDefault("count")
  let count = if tmpCount != nil: $tmpCount.getInt() else: ""

  db.exec(
    sql"INSERT INTO challengeTasks (challengeTaskId, clearedAt, count) VALUES (?, ?, ?)",
    challengeTaskId, clearedAt, count
  )


proc getChallengeTasks*(db: DbConn): seq[JsonNode] =
  for row in db.getAllRows(sql"SELECT challengeTaskId, clearedAt, count FROM challengeTasks"):
    let challengeTaskId = parseInt(row[0])
    let clearedAt = row[1]
    
    let challengeTask = %*{"challengeTaskId": challengeTaskId, "clearedAt": clearedAt}

    if row[2] != "":
      let count = parseInt(row[2])
      challengeTask["count"] = %*count

    result.add(challengeTask)


proc getMdChallengeTaskWithCondition*(
  db: DbConn, conditionType: TaskConditionType, conditionKeyId: int
): Option[MdChallengeTask] =
  let row = db.getRow(sql"""
    SELECT challengeProgressId, count, id, summaryChallengeId, targetAreaObjectBehaviorId,
           targetAreaPointId, targetNineSequenceId, targetRadius, totalTaskConditionId
    FROM mdChallengeTask
    WHERE taskConditionType = ? AND taskConditionKeyId = ?
  """, conditionType.int, conditionKeyId)

  if row[0] != "":
    result = some(MdChallengeTask(
      challengeProgressId: parseInt(row[0]),
      count: tryParseInt(row[1]),
      id: parseInt(row[2]),
      summaryChallengeId: tryParseInt(row[3]),
      targetAreaObjectBehaviorId: tryParseInt(row[4]),
      targetAreaPointId: tryParseInt(row[5]),
      targetNineSequenceId: tryParseInt(row[6]),
      targetRadius: tryParseInt(row[7]),
      totalTaskConditionId: tryParseInt(row[8]),
      taskConditionType: some(conditionType.int),
      taskConditionKeyId: some(conditionKeyId),
    ))


proc getMdChallengeTaskForSequenceRequestId*(db: DbConn, seqReqId: int): Option[MdChallengeTask] =
  result = getMdChallengeTaskWithCondition(db, taskConditionTypeSequenceRequest, seqReqId)


proc getMdChallengeTaskForBattleEntryId*(db: DbConn, battleEntryId: int): Option[MdChallengeTask] =
  result = getMdChallengeTaskWithCondition(db, taskConditionTypeBattleFinish, battleEntryId)