import std/strutils
import std/sequtils

import ../db_connector/db_sqlite


type AreaChangeLock* = object
  areaChangeLockId*: int


proc addAreaChangeLock*(db: DbConn, areaChangeLockId: int) =
  db.exec(sql"""
    INSERT INTO areaChangeLocks (areaChangeLockId) VALUES (?)
    ON CONFLICT DO NOTHING
  """, areaChangeLockId)


proc getAreaChangeLocks*(db: DbConn): seq[AreaChangeLock] =
  let rows = db.getAllRows(sql"SELECT areaChangeLockId FROM areaChangeLocks")
  result = rows.mapIt(AreaChangeLock(areaChangeLockId: parseInt(it[0])))


proc updateAreaChangeLocks*(db: DbConn, areaChangeLocks: seq[AreaChangeLock]) =
  for areaChangeLock in areaChangeLocks:
    addAreaChangeLock(db, areaChangeLock.areaChangeLockId)