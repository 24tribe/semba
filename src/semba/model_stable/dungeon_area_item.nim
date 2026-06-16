import std/options
import std/sequtils
import std/strutils
import std/json

import db_connector/db_sqlite

import ../protojson
import ../extsqlite
import ../semba_error
import timestamp


type MdDungeonAreaItem* = object
  dungeonAreaItemId*: int
  areaItemRewardIds*: seq[int]
  areaItemBaseId*: int

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
    SELECT id, areaItemRewardIds, areaItemBaseId FROM mdDungeonAreaItem
    WHERE id/1000 = CAST(? as INTEGER) OR id/1000 = CAST(? as INTEGER)
  """, cityId, 300 + cityId).mapIt(MdDungeonAreaItem(
    dungeonAreaItemId: parseInt(it[0]),
    areaItemRewardIds: protoJsonTo(parseJson(it[1]), seq[int]),
    areaItemBaseId: parseInt(it[2]),
  ))


proc getMdDungeonAreaItem*(db: DbConn, dungeonAreaItemId: int): MdDungeonAreaItem =
  let row = db.getRow(sql"""
    SELECT areaItemRewardIds, areaItemBaseId FROM mdDungeonAreaItem WHERE id = ?
  """, dungeonAreaItemId)

  if row[0] == "":
    raise newException(SembaError, "Couldn't get mdDungeonAreaItem with id " & $dungeonAreaItemId)

  MdDungeonAreaItem(
    dungeonAreaItemId: dungeonAreaItemId,
    areaItemRewardIds: parseJson(row[0]).protoJsonTo(seq[int]),
    areaItemBaseId: parseInt(row[1]),
  )


proc getDungeonAreaItems*(db: DbConn, dungeonId: int, filterEntityIds: openArray[int] = @[]): seq[DungeonAreaItem] =
  let filterSql =
    if filterEntityIds.len > 0:
      "AND entityId IN " & sqlIntTuple(filterEntityIds)
    else:
      ""

  db.getAllRows(sql("""
    SELECT
      entityId, dungeonAreaItemId, dungeonPieceId,
      dungeonPieceX, dungeonPieceY, dungeonPieceIndex, acquiredAt
    FROM dungeonAreaItems WHERE dungeonId = ? """ & filterSql 
  ), dungeonId).mapIt(DungeonAreaItem(
    entityId: parseInt(it[0]),
    dungeonAreaItemId: parseInt(it[1]),
    dungeonPieceId: parseInt(it[2]),
    dungeonPieceX: parseInt(it[3]),
    dungeonPieceY: parseInt(it[4]),
    dungeonPieceIndex: parseInt(it[5]),
    acquiredAt: tryParseTimestamp(it[6]),
  ))


proc upsertDungeonAreaItem*(db: DbConn, dungeonId: int, dai: DungeonAreaItem) =
  db.exec(
    sql"""
    INSERT INTO dungeonAreaItems (
      dungeonId, entityId, dungeonAreaItemId, dungeonPieceId,
      dungeonPieceX, dungeonPieceY, dungeonPieceIndex, acquiredAt
    ) VALUES (?, ?, ?, ?, ?, ?, ?, ?)
    ON CONFLICT (dungeonId, entityId) DO
    UPDATE SET
      dungeonAreaItemId = excluded.dungeonAreaItemId, dungeonPieceId = excluded.dungeonPieceId,
      dungeonPieceX = excluded.dungeonPieceX, dungeonPieceY = excluded.dungeonPieceY,
      dungeonPieceIndex = excluded.dungeonPieceIndex, acquiredAt = excluded.acquiredAt
    """,
    dungeonId, dai.entityId, dai.dungeonAreaItemId, dai.dungeonPieceId,
    dai.dungeonPieceX, dai.dungeonPieceY, dai.dungeonPieceIndex, dai.acquiredAt.optionToSqlArg
  )


proc setDungeonAreaItems*(db: DbConn, dungeonId: int, dungeonAreaItems: openArray[DungeonAreaItem]) =
  db.exec(sql"DELETE FROM dungeonAreaItems WHERE dungeonId = ?", dungeonId)

  for dungeonAreaItem in dungeonAreaItems:
    upsertDungeonAreaItem(db, dungeonId, dungeonAreaItem)