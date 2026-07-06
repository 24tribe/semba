import std/options
import std/json

import db_connector/db_sqlite

import ../extsqlite


const userLanguageEnglish* = 2
const userLanguageKey* = "userLanguage"


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


proc getUserLanguage*(db: DbConn): int =
  let row = db.getRow(sql"""
    SELECT val FROM userData WHERE keyName = ?
  """, userLanguageKey)

  row[0].tryParseInt.get(userLanguageEnglish)


proc setUserLanguage*(db: DbConn, userLanguage: int) =
  db.exec(sql"""
    INSERT INTO userData (keyName, val) VALUES (?, ?)
    ON CONFLICT (keyName) DO
    UPDATE SET val = excluded.val
  """, userLanguageKey, userLanguage)
