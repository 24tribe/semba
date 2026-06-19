import std/strutils
import std/sequtils

import db_connector/db_sqlite


type AreaGroup* = object
  areaGroupId*: int


proc getAreaGroups*(db: DbConn): seq[AreaGroup] =
  db.getAllRows(sql"SELECT areaGroupId FROM areaGroups").mapIt(AreaGroup(
    areaGroupId: parseInt(it[0]),
  ))


proc addAreaGroup*(db: DbConn, areaGroupId: int) =
  db.exec(sql"""
    INSERT INTO areaGroups (areaGroupId) VALUES
    (?)
    ON CONFLICT (areaGroupId) DO NOTHING
  """, areaGroupId)