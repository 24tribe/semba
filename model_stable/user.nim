import std/json

import ../db_connector/db_sqlite


proc updateStatusFromCurrentLocation*(status: var JsonNode, currentLocation: JsonNode) =
  status["currentAreaType"] = currentLocation["areaType"]
  status["currentDirection"] = currentLocation["direction"]
  status["currentPositionCoordinates"] = currentLocation["positionCoordinates"]
  status["currentAreaKeyId"] = currentLocation["areaKeyId"]


proc updateStatusFromStatusLocation*(status: var JsonNode, otherStatus: JsonNode) =
  status["currentAreaType"] = otherStatus["currentAreaType"]
  status["currentDirection"] = otherStatus["currentDirection"]
  status["currentPositionCoordinates"] = otherStatus["currentPositionCoordinates"]
  status["currentAreaKeyId"] = otherStatus["currentAreaKeyId"]


proc getUserData*(db: DbConn): seq[JsonNode] =
  let rows = db.getAllRows(sql"SELECT keyName, val FROM userData WHERE keyName != 'status'")
  
  for row in rows:
    result.add(%*{
      "keyName": row[0],
      "val": row[1],
    })


proc updateUserData*(db: DbConn, keyName: string, val: string) =
  db.exec(sql"""
    INSERT INTO userData (keyName, val) VALUES (?, ?)
    ON CONFLICT (keyName) DO
    UPDATE SET val = excluded.val
  """, keyName, val)


proc getShopProducts*(db: DbConn): seq[JsonNode] =
  let shopProductsRows = db.getAllRows(sql"SELECT val FROM shopProducts")

  for shopProductRow in shopProductsRows:
    result.add(parseJson(shopProductRow[0]))