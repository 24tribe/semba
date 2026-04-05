import std/json
import std/strutils

import ../db_connector/db_sqlite


type MdAreaLocator* = object
  id*: int
  areaId*: int


proc getMdAreaLocatorsForAreaId(db: DbConn, areaId: int): seq[MdAreaLocator] =
  let rows = db.getAllRows(sql"SELECT id FROM mdAreaLocator WHERE areaId = ? ORDER BY id", areaId)

  for row in rows:
    result.add(MdAreaLocator(id: parseInt(row[0]), areaId: areaId))


proc getRetireAreaLocatorId*(db: DbConn, status: JsonNode): int =
  let areaId = status.getOrDefault("currentAreaKeyId").getInt()
  let areaLocators = getMdAreaLocatorsForAreaId(db, areaId)
  result = areaLocators[areaLocators.high].id