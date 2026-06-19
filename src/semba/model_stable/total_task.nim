import std/strutils
import std/sequtils
import std/options

import db_connector/db_sqlite

import ../protojson
import ../extsqlite

export protojson


const flowerMarksTotalTaskConditionId* = 1016


type TotalTask* = object
  conditionId*: int
  count*: ProtoJsonInt64


proc upsertTotalTask*(db: DbConn, totalTask: TotalTask) =
  db.exec(sql"""
    INSERT INTO totalTasks (conditionId, count) VALUES (?, ?)
    ON CONFLICT (conditionId) DO
    UPDATE SET count = excluded.count
  """, totalTask.conditionId, totalTask.count)


proc upsertTotalTasks*(db: DbConn, totalTasks: openArray[TotalTask]) =
  for tt in totalTasks:
    upsertTotalTask(db, tt)


proc getTotalTasks*(db: DbConn): seq[TotalTask] =
  db.getAllRows(sql"SELECT conditionId, count FROM totalTasks").mapIt(TotalTask(
    conditionId: parseInt(it[0]),
    count: tryParseInt(it[1]).get(0).ProtoJsonInt64,
  ))