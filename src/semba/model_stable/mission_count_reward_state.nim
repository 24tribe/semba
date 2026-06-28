import std/options
import std/sequtils
import std/strutils

import db_connector/db_sqlite

import ../extsqlite
import ./timestamp


type MissionCountRewardState* = object
  missionCountRewardId*: int
  receivedStepCount*: int
  resetAt*: Option[Timestamp]


proc getMissionCountRewardStates*(db: DbConn): seq[MissionCountRewardState] =
  db.getAllRows(sql"""
    SELECT missionCountRewardId, receivedStepCount, resetAt FROM missionCountRewardStates
  """).mapIt(MissionCountRewardState(
    missionCountRewardId: parseInt(it[0]), 
    receivedStepCount: parseInt(it[1]),
    resetAt: tryParseTimestamp(it[2]),
  ))


proc getMissionCountRewardState*(db: DbConn, missionCountRewardId: int): MissionCountRewardState =
  result.missionCountRewardId = missionCountRewardId

  let row = db.getRow(sql"""
    SELECT receivedStepCount, resetAt FROM missionCountRewardStates
  """)

  if row[0] != "":
    result.receivedStepCount = parseInt(row[0])
    result.resetAt = tryParseTimestamp(row[1])


proc upsertMissionCountRewardState*(db: DbConn, mcrs: MissionCountRewardState) =
  db.exec(sql"""
    INSERT INTO missionCountRewardStates (missionCountRewardId, receivedStepCount, resetAt)
    VALUES (?, ?, ?)
    ON CONFLICT (missionCountRewardId)
    DO UPDATE SET 
      receivedStepCount = excluded.receivedStepCount,
      resetAt = excluded.resetAt
  """, mcrs.missionCountRewardId, mcrs.receivedStepCount, optionToSqlArg(mcrs.resetAt))


proc upsertMissionCountRewardStates*(db: DbConn, missionCountRewardStates: openArray[MissionCountRewardState]) =
  for mcrs in missionCountRewardStates:
    upsertMissionCountRewardState(db, mcrs)
