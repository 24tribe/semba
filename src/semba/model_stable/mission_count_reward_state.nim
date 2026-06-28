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
