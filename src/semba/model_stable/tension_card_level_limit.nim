import std/strutils
import std/json

import db_connector/db_sqlite

import ../semba_error
import ../protojson
import ./item


type MdTensionCardLevelLimit* = object
  tensionCardId*: int 
  goldCost*: int
  maxLevel*: int
  itemCosts*: seq[MdItem]


proc getNextTCLevelLimit*(db: DbConn, tensionCardId: int, maxLevel: int): MdTensionCardLevelLimit =
  let row = db.getRow(sql"""
    SELECT maxLevel, goldCost, itemCosts FROM mdTensionCardLevelLimit
    WHERE tensionCardId = ? AND maxLevel > CAST (? as INTEGER)
  """, tensionCardId, maxLevel)

  if row[0] == "":
    raise newException(
      SembaError, "Couldn't get next TCLevelLimit for id=" & $tensionCardId & " and maxLevel=" & $maxLevel
    )

  MdTensionCardLevelLimit(
    tensionCardId: tensionCardId,
    maxLevel: parseInt(row[0]),
    goldCost: parseInt(row[1]),
    itemCosts: parseJson(row[2]).protoJsonTo(seq[MdItem]),
  )
