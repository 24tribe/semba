import std/options
import std/strutils
import std/json
import std/sequtils

import ../db_connector/db_sqlite

import ../extsqlite
import timestamp


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
  count*: Option[int]
  clearedAt*: Option[Timestamp]


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


proc upsertChallengeTasks*(db: DbConn, challengeTasks: openArray[ChallengeTask]) =
  for ct in challengeTasks:
    db.exec(sql"""
      INSERT INTO challengeTasks (challengeTaskId, clearedAt, count)
      VALUES (?, ?, ?)
      ON CONFLICT (challengeTaskId) DO UPDATE SET clearedAt = excluded.clearedAt, count = excluded.count
    """, ct.challengeTaskId, optionToSqlArg(ct.clearedAt), optionToSqlArg(ct.count))


proc getChallengeTaskIdsForChallengeProgressIds*(db: DbConn, challengeProgressIds: openArray[int]): seq[int] =
  let rows = db.getAllRows(sql("""
    SELECT id FROM mdChallengeTask WHERE challengeProgressId IN """ & sqlIntTuple(challengeProgressIds)
  ))

  result = rows.mapIt(parseInt(it[0]))


proc getChallengeTasks*(db: DbConn): seq[ChallengeTask] =
  let rows = db.getAllRows(sql"SELECT challengeTaskId, clearedAt, count FROM challengeTasks")
  result = rows.mapIt(ChallengeTask(
    challengeTaskId: parseInt(it[0]),
    clearedAt: tryParseTimestamp(it[1]),
    count: tryParseInt(it[2]),
  ))


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