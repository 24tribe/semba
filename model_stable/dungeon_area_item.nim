import std/options
import std/sequtils
import std/strutils
import std/json

import ../db_connector/db_sqlite

import ../protojson
import ../extsqlite
import timestamp


type MdDungeonAreaItem* = object
  dungeonAreaItemId*: int
  areaItemRewardIds*: seq[int]

type DungeonAreaItem* = object
  entityId*: int
  dungeonAreaItemId*: int
  dungeonPieceId*: int
  dungeonPieceX*: int
  dungeonPieceY*: int
  dungeonPieceIndex*: int
  acquiredAt*: Option[Timestamp]


proc getMdDungeonAreaItemsForCity*(db: DbConn, cityId: int): seq[MdDungeonAreaItem] =
  db.getAllRows(sql"""
    SELECT id, areaItemRewardIds FROM mdDungeonAreaItem
    WHERE id/1000 = CAST(? as INTEGER) OR id/1000 = CAST(? as INTEGER)
  """, cityId, 300 + cityId).mapIt(MdDungeonAreaItem(
    dungeonAreaItemId: parseInt(it[0]),
    areaItemRewardIds: protoJsonTo(parseJson(it[1]), seq[int]),
  ))


proc getDungeonAreaItems*(db: DbConn, dungeonId: int): seq[DungeonAreaItem] =
  db.getAllRows(sql"""
    SELECT
      entityId, dungeonAreaItemId, dungeonPieceId,
      dungeonPieceX, dungeonPieceY, dungeonPieceIndex, acquiredAt
    FROM dungeonAreaItems WHERE dungeonId = ?
  """, dungeonId).mapIt(DungeonAreaItem(
    entityId: parseInt(it[0]),
    dungeonAreaItemId: parseInt(it[1]),
    dungeonPieceId: parseInt(it[2]),
    dungeonPieceX: parseInt(it[3]),
    dungeonPieceY: parseInt(it[4]),
    dungeonPieceIndex: parseInt(it[5]),
    acquiredAt: tryParseTimestamp(it[6]),
  ))


proc addDungeonAreaItem(db: DbConn, dungeonId: int, dai: DungeonAreaItem) =
  db.exec(
    sql"""
    INSERT INTO dungeonAreaItems (
      dungeonId, entityId, dungeonAreaItemId, dungeonPieceId,
      dungeonPieceX, dungeonPieceY, dungeonPieceIndex, acquiredAt
    ) VALUES (?, ?, ?, ?, ?, ?, ?, ?)
    """,
    dungeonId, dai.entityId, dai.dungeonAreaItemId, dai.dungeonPieceId,
    dai.dungeonPieceX, dai.dungeonPieceY, dai.dungeonPieceIndex, dai.acquiredAt.optionToSqlArg
  )


proc setDungeonAreaItems*(db: DbConn, dungeonId: int, dungeonAreaItems: openArray[DungeonAreaItem]) =
  db.exec(sql"DELETE FROM dungeonAreaItems WHERE dungeonId = ?", dungeonId)

  for dungeonAreaItem in dungeonAreaItems:
    addDungeonAreaItem(db, dungeonId, dungeonAreaItem)