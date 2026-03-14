import std/strutils
import std/json

import ../db_connector/db_sqlite


proc addAreaChangeLock*(db: DbConn, areaChangeLockId: int) =
  db.exec(sql"""
    INSERT INTO areaChangeLocks (areaChangeLockId) VALUES (?)
    ON CONFLICT DO NOTHING
  """, areaChangeLockId)

proc getAreaChangeLocks*(db: DbConn): seq[JsonNode] =
  let rows = db.getAllRows(sql"SELECT areaChangeLockId FROM areaChangeLocks")

  for row in rows:
    let areaChangeLockId = parseInt(row[0])
    result.add(%*{
      "areaChangeLockId": areaChangeLockId,
    })

proc updateAreaChangeLocks*(db: DbConn, areaChangeLocks: seq[JsonNode]) =
  for areaChangeLock in areaChangeLocks:
    let areaChangeLockId = areaChangeLock["areaChangeLockId"].getInt()
    addAreaChangeLock(db, areaChangeLockId)