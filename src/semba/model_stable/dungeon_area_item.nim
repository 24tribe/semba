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


proc parseDungeonAreaItem(
  entityId, dungeonAreaItemId, dungeonPieceId,
  dungeonPieceX, dungeonPieceY, dungeonPieceIndex, acquiredAt: string
): DungeonAreaItem =
  DungeonAreaItem(
    entityId: parseInt(entityId),
    dungeonAreaItemId: parseInt(dungeonAreaItemId),
    dungeonPieceId: parseInt(dungeonPieceId),
    dungeonPieceX: parseInt(dungeonPieceX),
    dungeonPieceY: parseInt(dungeonPieceY),
    dungeonPieceIndex: parseInt(dungeonPieceIndex),
    acquiredAt: tryParseTimestamp(acquiredAt),
  )


proc dumpDungeonAreaItems*(db: DbConn): seq[tuple[dungeonId: int, item: DungeonAreaItem]] =
  db.getAllRows(sql"""
    SELECT
      dungeonId, entityId, dungeonAreaItemId, dungeonPieceId,
      dungeonPieceX, dungeonPieceY, dungeonPieceIndex, acquiredAt
    FROM dungeonAreaItems
  """).mapIt((
    parseInt(it[0]), parseDungeonAreaItem(it[1], it[2], it[3], it[4], it[5], it[6], it[7])
  ))


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
  ), dungeonId).mapIt(parseDungeonAreaItem(it[0], it[1], it[2], it[3], it[4], it[5], it[6]))


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


proc loadDungeonAreaItems*(db: DbConn, items: openArray[tuple[dungeonId: int, item: DungeonAreaItem]]) =
  db.exec(sql"DELETE FROM dungeonAreaItems")
  for (dungeonId, dungeonAreaItem) in items:
    upsertDungeonAreaItem(db, dungeonId, dungeonAreaItem)


proc setDungeonAreaItems*(db: DbConn, dungeonId: int, dungeonAreaItems: openArray[DungeonAreaItem]) =
  db.exec(sql"DELETE FROM dungeonAreaItems WHERE dungeonId = ?", dungeonId)

  for dungeonAreaItem in dungeonAreaItems:
    upsertDungeonAreaItem(db, dungeonId, dungeonAreaItem)