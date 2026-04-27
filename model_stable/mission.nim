import std/json
import std/strutils
import std/options
import std/sequtils

import ../db_connector/db_sqlite
import ../extsqlite

import timestamp


type FlowerMarkLevel* = object
  requiredFlowerMark*: int
  characterMaxLevel*: int

type Mission* = object
  missionId*: int
  count*: Option[int]
  receivedStepCount*: Option[int]
  resetAt*: Option[Timestamp]
  clearedAt*: Option[Timestamp]

type MdMissionStep* = object
  count*: int
  reward_set_id*: int

type MdMission* = object
  id*: int
  cityId*: Option[int]
  steps*: seq[MdMissionStep]


proc getAttackTestMissionsForCity*(db: DbConn, cityId: int): seq[MdMission] =
  let rows = db.getAllRows(sql"""
    SELECT id, steps FROM mdMission
    WHERE id IN (1041041, 1041042, 1041043, 1041044, 1041335, 1041345, 1041346, 1041438, 1041439, 1041440)
      AND cityId = ?
  """, cityId)

  for row in rows:
    result.add(MdMission(
      id: parseInt(row[0]),
      cityId: some(cityId),
      steps: to(parseJson(row[1]), seq[MdMissionStep])
    ))


proc getMdMissionsWithIds*(db: DbConn, ids: openArray[int]): seq[MdMission] = 
  let rows = db.getAllRows(sql("SELECT id, steps, cityId FROM mdMission WHERE id IN " & sqlIntTuple(ids)))

  result = rows.mapIt(MdMission(
    id: parseInt(it[0]),
    steps: to(parseJson(it[1]), seq[MdMissionStep]),
    cityId: tryParseInt(it[2]),
  )).toSeq()


proc getAttackTestMissionMinChars*(missionId: int): int =
  case missionId:
  of 1041041: 1
  of 1041042: 2
  else: 3


proc getMissionsWithIds*(db: DbConn, missionIds: openArray[int]): seq[Mission] =
  let rows = db.getAllRows(sql("""
    SELECT missionId, count, receivedStepCount, resetAt, clearedAt FROM missions
    WHERE missionId IN (""" & missionIds.mapIt($it).join(", ") & """)
  """))

  for row in rows:
    result.add(Mission(
      missionId: parseInt(row[0]),
      count: tryParseInt(row[1]),
      receivedStepCount: tryParseInt(row[2]),
      resetAt: if row[3] != "": some(row[3].Timestamp) else: none(Timestamp),
      clearedAt: if row[4] != "": some(row[4].Timestamp) else: none(Timestamp),
    ))


proc updateMissions*(db: DbConn, missions: openArray[Mission]) =
  for mission in missions:
    db.exec(
      sql"""
        INSERT INTO missions (missionId, count, receivedStepCount, resetAt, clearedAt)
        VALUES (?, ?, ?, ?, ?)
        ON CONFLICT (missionId) DO
        UPDATE SET
          count = excluded.count, receivedStepCount = excluded.receivedStepCount,
          resetAt = excluded.resetAt, clearedAt = excluded.clearedAt
      """,
      mission.missionId, mission.count.get(0), mission.receivedStepCount.get(0),
      mission.resetAt.get("".Timestamp), mission.clearedAt.get("".Timestamp)
    )


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