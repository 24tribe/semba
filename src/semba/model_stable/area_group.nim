import std/json
import std/strutils

import db_connector/db_sqlite


type AreaGroup* = object
  areaGroupId*: int


proc getAreaGroups*(db: DbConn): seq[JsonNode] =
  for row in db.getAllRows(sql"SELECT areaGroupId FROM areaGroups"):
    let areaGroupId = parseInt(row[0])
    result.add(%*{
      "areaGroupId": areaGroupId
    })


proc addAreaGroup*(db: DbConn, areaGroupId: int) =
  db.exec(sql"""
    INSERT INTO areaGroups (areaGroupId) VALUES
    (?)
    ON CONFLICT (areaGroupId) DO NOTHING
  """, areaGroupId)