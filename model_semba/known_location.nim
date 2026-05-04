import std/strutils

import ../db_connector/db_sqlite

import ../semba_error


type KnownLocation* = object
  areaId*: int
  x*: float
  y*: float
  z*: float
  direction*: int


proc getKnownLocation*(db: DbConn, areaId: int): KnownLocation =
  let row = db.getRow(sql"SELECT areaId, x, y, z, direction FROM knownLocations WHERE areaId = ?", areaId)

  if row[0] == "":
    raise newException(SembaError, "Couldn't get known location for areaId=" & $areaId)

  result = KnownLocation(
    areaId: areaId,
    x: parseFloat(row[1]), y: parseFloat(row[2]), z: parseFloat(row[3]),
    direction: parseInt(row[4])
  )