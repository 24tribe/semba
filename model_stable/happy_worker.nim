import std/options
import std/sequtils
import std/strutils

import ../db_connector/db_sqlite

import ../extsqlite


type HappyWorkerItem* = object
  happyWorkerItemId*: int
  isCleared*: Option[bool]
  state*: int


proc getHappyWorkerItems*(db: DbConn, cityIds: openArray[int]): seq[HappyWorkerItem] =
  let rows = db.getAllRows(sql("""
    SELECT id, isCleared, state FROM happyWorkerItems WHERE id IN """ & sqlIntTuple(cityIds) & """
  """))

  result = rows.mapIt(HappyWorkerItem(
    happyWorkerItemId: parseInt(it[0]),
    isCleared: some(it[1] == "true"),
    state: parseInt(it[2]),
  ))