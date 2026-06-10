import std/strutils
import std/sequtils

import ../db_connector/db_sqlite


const shinagawaMagicOrbIds* = 100000..100005
const minatoMagicOrbIds* = 100020..100026
const chiyodaMagicOrbIds* = 114011..114071


type MagicOrb* = object
  magicOrbId*: int


proc getMagicOrbs*(db: DbConn): seq[MagicOrb] =
  let rows = db.getAllRows(sql"SELECT magicOrbId FROM magicOrbs")

  result = rows.mapIt(MagicOrb(magicOrbId: parseInt(it[0])))


proc addMagicOrb*(db: DbConn, magicOrbId: int) =
  db.exec(sql"""
    INSERT INTO magicOrbs (magicOrbId) VALUES (?)
    ON CONFLICT DO NOTHING
  """, magicOrbId)


proc updateMagicOrbs*(db: DbConn, magicOrbs: openArray[MagicOrb]) =
  for magicOrb in magicOrbs:
    addMagicOrb(db, magicOrb.magicOrbId)