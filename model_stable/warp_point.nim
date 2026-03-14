import std/json
import std/strutils

import ../db_connector/db_sqlite


proc getWarpPoints*(db: DbConn): seq[JsonNode] =
  for row in db.getAllRows(sql"SELECT warpPointId FROM warpPoints"):
    let warpPointId = parseInt(row[0])
    result.add(%*{
      "warpPointId": warpPointId
    })


proc hasWarpPoint*(db: DbConn, warpPointId: int): bool =
  let row = db.getRow(sql"SELECT warpPointId FROM warpPoints WHERE warpPointId=?", warpPointId)
  return row[0] != ""


proc addWarpPoint*(db: DbConn, warpPointId: int) =
  db.exec(sql"""
    INSERT INTO warpPoints (warpPointId) VALUES (?)
    ON CONFLICT (warpPointId) DO NOTHING
  """, warpPointId)