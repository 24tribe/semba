import std/json
import std/strutils

import ../db_connector/db_sqlite
import ../semba_error


type MdWarpPoint* = object
  id*: int
  areaLocatorId*: int

type WarpPoint* = object
  warpPointId*: int


proc getLastWarpPoint*(db: DbConn): MdWarpPoint =
  let row = db.getRow(sql"""
    SELECT mdWarpPoint.id, mdWarpPoint.areaLocatorId
    FROM mdWarpPoint INNER JOIN warpPoints ON mdWarpPoint.id = warpPoints.warpPointId
    ORDER BY warpPoints.warpPointId DESC
  """)

  if row[0] == "":
    raise newException(SembaError, "Failed to get last warp point")

  result = MdWarpPoint(id: parseInt(row[0]), areaLocatorId: parseInt(row[1]))


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


proc getWarpPointAreaId*(db: DbConn, warpPointId: int): int =
  let row = db.getRow(sql"""
    SELECT mdAreaLocator.areaId
    FROM mdWarpPoint INNER JOIN mdAreaLocator ON mdWarpPoint.areaLocatorId = mdAreaLocator.id
    WHERE mdWarpPoint.id = ?
  """, warpPointId)

  if row[0] == "":
    raise newException(SembaError, "Couldn't find areaId for warpPoint with id=" & $warpPointId)

  result = parseInt(row[0])


proc warpPointIdToCityId*(warpPointId: int): int = warpPointId div 10000