import std/json
import std/strutils
import std/options
import std/sequtils

import db_connector/db_sqlite

import ./timestamp


type Tip* = object
  tipId*: int
  releasedAt*: Timestamp


proc addTip*(db: DbConn, tip: JsonNode) =
  let tipId = tip["tipId"].getInt()
  let releasedAt = tip["releasedAt"].getStr()
  db.exec(sql"INSERT INTO tips (tipId, releasedAt) VALUES (?, ?)", tipId, releasedAt)


proc addTipTypeSafe*(db: DbConn, tip: Tip) =
  db.exec(sql"INSERT INTO tips (tipId, releasedAt) VALUES (?, ?)", tip.tipId, tip.releasedAt)


proc addTips*(db: DbConn, tips: openArray[Tip]) =
  for tip in tips:
    addTipTypeSafe(db, tip)


proc getTips*(db: DbConn): seq[Tip] =
  result = db.getAllRows(sql"""
    SELECT tipId, releasedAt
    FROM tips
  """).mapIt(Tip(
    tipId: parseInt(it[0]),
    releasedAt: it[1].Timestamp,
  ))

  # Lux Phantasma first tip
  result.add(Tip(tipId: 3027, releasedAt: "2025-09-10T02:17:06Z".Timestamp))


proc getFirstTipIdNotInDb*(db: DbConn, tipIds: openArray[int]): Option[int] = 
  for tipId in tipIds:
    let row = db.getRow(sql"SELECT tipId FROM tips WHERE tipId = ?", tipId)
    if row[0] == "":
      return some(tipId)