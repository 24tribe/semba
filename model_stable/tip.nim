import std/json
import std/strutils
import std/options

import ../db_connector/db_sqlite

import timestamp


type Tip* = object
  tipId*: int
  releasedAt*: Timestamp


proc addTip*(db: DbConn, tip: JsonNode) =
  let tipId = tip["tipId"].getInt()
  let releasedAt = tip["releasedAt"].getStr()
  db.exec(sql"INSERT INTO tips (tipId, releasedAt) VALUES (?, ?)", tipId, releasedAt)


proc getTips*(db: DbConn): seq[JsonNode] =
  let tipsRows = db.getAllRows(sql"""
    SELECT tipId, releasedAt
    FROM tips
  """)

  # Lux Phantasma first tip
  result.add(%*{
    "tipId": 3027,
    "releasedAt": "2025-09-10T02:17:06Z"
  })

  for tipRow in tipsRows:
    let tipId = parseInt(tipRow[0])
    let releasedAt = tipRow[1]

    result.add(%*{
      "tipId": tipId,
      "releasedAt": releasedAt
    })

proc getFirstTipIdNotInDb*(db: DbConn, tipIds: openArray[int]): Option[int] = 
  for tipId in tipIds:
    let row = db.getRow(sql"SELECT tipId FROM tips WHERE tipId = ?", tipId)
    if row[0] == "":
      return some(tipId)