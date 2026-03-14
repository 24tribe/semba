import std/json

import ../db_connector/db_sqlite

import ../semba_error


type AreaItemContentType* = enum
  kaneContentType = 3,
  gearContentType = 6,
  itemContentType = 7,
  charExpContentType = 13


proc getAreaItemRewards*(db: DbConn, areaItemId: int): JsonNode =
  let row = db.getRow(sql"SELECT rewards FROM areaItemRewards WHERE areaItemId = ?", areaItemId);

  if row[0] == "":
    raise newException(SembaError, "Couldn't find rewards for areaItemId=" & $areaItemId)

  return parseJson(row[0])