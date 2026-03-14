import std/json
import std/strutils

import ../db_connector/db_sqlite
 

proc getMagicOrbs*(db: DbConn): seq[JsonNode] =
  let rows = db.getAllRows(sql"SELECT magicOrbId FROM magicOrbs")

  for row in rows:
    let magicOrbId = parseInt(row[0])
    result.add(%*{
      "magicOrbId": magicOrbId,
    })


proc addMagicOrb*(db: DbConn, magicOrbId: int) =
  db.exec(sql"""
    INSERT INTO magicOrbs (magicOrbId) VALUES (?)
    ON CONFLICT DO NOTHING
  """, magicOrbId)


proc updateMagicOrbs*(db: DbConn, magicOrbs: seq[JsonNode]) =
  for magicOrb in magicOrbs:
    let magicOrbId = magicOrb["magicOrbId"].getInt()
    addMagicOrb(db, magicOrbId)