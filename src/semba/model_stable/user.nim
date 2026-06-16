import std/json

import db_connector/db_sqlite


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