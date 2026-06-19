import std/options
import std/strutils
import std/json
import std/random
import std/sequtils

import db_connector/db_sqlite

import ../dungeongen
import ../semba_error
import ../protojson
import timestamp
import city
import dungeon_area_item


type Dungeon* = object
  dungeonId*: int
  isFinished*: bool

type DungeonDifficultyPiece = DungeonPiece

type DungeonState* = object
  dungeonDifficultyId*: int
  dungeonPieces*: seq[DungeonDifficultyPiece]

type MdDungeonEnemyRate* = object
  id*: int
  dungeonEnemyRateSetId*: int
  areaEnemyId*: int
  battleEntryId*: int

type MdDungeonDifficulty = object
  id: int
  bonusRatedRewardSetIds: seq[int]
  bossRatedRewardSetIds: seq[int]
  enemyLevel: int
  enemyTrainingScoreId: int
  goalEnemyRateSetId: int

type DungeonEnemy* = object
  entityId*: int
  dungeonEnemyRateId*: int
  isBoss*: bool
  dungeonPieceId*: int
  dungeonPieceX*: int
  dungeonPieceY*: int
  dungeonPieceIndex*: int
  defeatedAt*: Option[string]


const healthyOutlawsDungeonId* = 109202


proc updateDungeonEnemies*(db: DbConn, dungeonId: int, dungeonEnemies: seq[DungeonEnemy]) =
  db.exec(sql"DELETE FROM dungeonEnemies WHERE dungeonId = ?", dungeonId)

  for dungeonEnemy in dungeonEnemies:
    db.exec(
      sql"""
        INSERT INTO dungeonEnemies
        (dungeonId, entityId, dungeonEnemyRateId, dungeonPieceId,
         dungeonPieceX, dungeonPieceY, dungeonPieceIndex, defeatedAt, isBoss)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
      """,
      dungeonId, dungeonEnemy.entityId, dungeonEnemy.dungeonEnemyRateId, dungeonEnemy.dungeonPieceId,
      dungeonEnemy.dungeonPieceX, dungeonEnemy.dungeonPieceY, dungeonEnemy.dungeonPieceIndex,
      if dungeonEnemy.defeatedAt.isSome(): dungeonEnemy.defeatedAt.get() else: "",
      dungeonEnemy.isBoss
    )


proc getDungeonEnemies*(db: DbConn, dungeonId: int): seq[DungeonEnemy] =
  let rows = db.getAllRows(sql"""
    SELECT entityId, dungeonEnemyRateId, dungeonPieceId,
           dungeonPieceX, dungeonPieceY, dungeonPieceIndex, defeatedAt, isBoss
    FROM dungeonEnemies
    WHERE dungeonId = ?
  """, dungeonId)

  for row in rows:
    result.add(DungeonEnemy(
      entityId: parseInt(row[0]),
      dungeonEnemyRateId: parseInt(row[1]),
      dungeonPieceId: parseInt(row[2]),
      dungeonPieceX: parseInt(row[3]),
      dungeonPieceY: parseInt(row[4]),
      dungeonPieceIndex: parseInt(row[5]),
      defeatedAt: if row[6] != "": some(row[6]) else: none(string),
      isBoss: row[7] == "true",
    ))


proc removeDungeonEnemy*(db: DbConn, dungeonId: int, triggerId: int) =
  db.exec(sql"""
    UPDATE dungeonEnemies
    SET defeatedAt = ?
    WHERE dungeonId = ? AND entityId = ?
  """, getDateNow(), dungeonId, triggerId)


proc updateDungeonState*(db: DbConn, dungeonId: int, dungeonState: DungeonState) =
  db.exec(sql"DELETE FROM dungeonStates WHERE dungeonId = ?", dungeonId)

  for dungeonPiece in dungeonState.dungeonPieces:
    db.exec(
      sql"""
        INSERT INTO dungeonStates
        (dungeonId, dungeonDifficultyId, dungeonPieceX, dungeonPieceY, dungeonPieceRotate, dungeonPieceId)
        VALUES
        (?, ?, ?, ?, ?, ?)
      """,
      dungeonId, dungeonState.dungeonDifficultyId,
      dungeonPiece.x, dungeonPiece.y, dungeonPiece.rotate, dungeonPiece.dungeonPieceId
    )


proc getDungeonState*(db: DbConn, dungeonId: int): DungeonState =
  let rows = db.getAllRows(sql"""
    SELECT dungeonDifficultyId, dungeonPieceX, dungeonPieceY, dungeonPieceRotate, dungeonPieceId
    FROM dungeonStates
    WHERE dungeonId = ?
  """, dungeonId)

  var dungeonPieces = newSeq[DungeonDifficultyPiece]()
  var dungeonDifficultyId = 0

  for row in rows:
    dungeonDifficultyId = parseInt(row[0])
    dungeonPieces.add(DungeonDifficultyPiece(
      x: parseInt(row[1]),
      y: parseInt(row[2]),
      rotate: parseInt(row[3]),
      dungeonPieceId: parseInt(row[4]),
    ))

  result = DungeonState(
    dungeonDifficultyId: dungeonDifficultyId,
    dungeonPieces: dungeonPieces
  )


proc getDungeonDifficulty(db: DbConn, dungeonDifficultyId: int): MdDungeonDifficulty =
  let row = db.getRow(sql"""
    SELECT bonusRatedRewardSetIds, bossRatedRewardSetIds,
           enemyLevel, enemyTrainingScoreId, goalEnemyRateSetId
    FROM mdDungeonDifficulty
    WHERE id = ?
  """, dungeonDifficultyId)

  result = MdDungeonDifficulty(
    id: dungeonDifficultyId,
    bonusRatedRewardSetIds: protoJsonTo(parseJson(row[0]), seq[int]),
    bossRatedRewardSetIds: protoJsonTo(parseJson(row[1]), seq[int]),
    enemyLevel: parseInt(row[2]),
    enemyTrainingScoreId: parseInt(row[3]),
    goalEnemyRateSetId: parseInt(row[4]),
  )


proc getMdDungeonEnemyRate*(db: DbConn, dungeonEnemyRateId: int): MdDungeonEnemyRate =
  let row = db.getRow(
    sql"SELECT areaEnemyId, battleEntryId, dungeonEnemyRateSetId FROM mdDungeonEnemyRate WHERE id = ?",
    dungeonEnemyRateId
  )

  result = MdDungeonEnemyRate(
    id: dungeonEnemyRateId,
    areaEnemyId: parseInt(row[0]),
    battleEntryId: parseInt(row[1]),
    dungeonEnemyRateSetId: parseInt(row[2]),
  )


proc getMdDungeonEnemyRates*(db: DbConn, dungeonEnemyRateSetId: int): seq[MdDungeonEnemyRate] =
  let rows = db.getAllRows(sql"""
    SELECT id, areaEnemyId, battleEntryId FROM mdDungeonEnemyRate WHERE dungeonEnemyRateSetId = ?
  """, dungeonEnemyRateSetId)

  for row in rows:
    result.add(MdDungeonEnemyRate(
      id: parseInt(row[0]),
      areaEnemyId: parseInt(row[1]),
      battleEntryId: parseInt(row[2]),
      dungeonEnemyRateSetId: dungeonEnemyRateSetId,
    ))


proc getNotGoalEnemyRateSetId*(cityId: int, dungeonId: int): int =
  if cityId == cityIdShinagawa.int or cityId == cityIdMinato.int:
    # in shinagawa and minato every dungeon has a enemyRateSetId
    result = dungeonId*100 + 1
  else:
    # in chiyoda there is only one enemyRateSetId
    result = (dungeonId div 100) * 10000 + 1


proc getDungeons*(db: DbConn): seq[Dungeon] =
  db.getAllRows(sql"SELECT dungeonId, isFinished FROM dungeons").mapIt(Dungeon(
    dungeonId: parseInt(it[0]),
    isFinished: parseInt(it[1]) == 1,
  ))


proc getDungeon*(db: DbConn, dungeonId: int): JsonNode =
  let row = db.getRow(sql"SELECT dungeonId, isFinished FROM dungeons WHERE dungeonId = ?", dungeonId)

  if row[0] != "":
    let isFinished = if parseInt(row[1]) == 1: true else: false
    result = %*{
      "dungeonId": dungeonId,
      "isFinished": isFinished,
    }


proc addDungeon*(db: DbConn, dungeon: JsonNode) =
  let dungeonId = dungeon["dungeonId"].getInt()
  let isFinished = if dungeon.getOrDefault("isFinished").getBool(): 1 else: 0
  db.exec(sql"""
    INSERT INTO dungeons (dungeonId, isFinished) VALUES (?, ?)
    ON CONFLICT (dungeonId) DO
    UPDATE SET isFinished = excluded.isFinished
  """, dungeonId, isFinished)


proc addDungeonTypeSafe*(db: DbConn, dungeon: Dungeon) =
  db.exec(sql"""
    INSERT INTO dungeons (dungeonId, isFinished) VALUES (?, ?)
    ON CONFLICT (dungeonId) DO
    UPDATE SET isFinished = excluded.isFinished
  """, dungeon.dungeonId, if dungeon.isFinished: 1 else: 0)


proc parseBlocks(blocksJson: JsonNode): seq[Block] =
  for blockJson in blocksJson:
    result.add(Block(
      x: blockJson["x"].getInt(),
      y: blockJson["y"].getInt(),
      top: blockJson["top"].getInt(),
      right: blockJson["right"].getInt(),
      bottom: blockJson["bottom"].getInt(),
      left: blockJson["left"].getInt(),
    ))


proc getDungeonData*(db: DbConn): DungeonData =
  db.getAllRows(sql"SELECT id, name, blocks, angle, maxEnemies, maxAreaItems FROM dungeonData").mapIt(DungeonPart(
    id: parseInt(it[0]),
    name: it[1],
    blocks: parseBlocks(parseJson(it[2])),
    angle: parseInt(it[3]),
    maxEnemies: parseInt(it[4]),
    maxAreaItems: parseInt(it[5]),
  ))


proc getDungeonEnemy*(db: DbConn, dungeonId: int, entityId: int): DungeonEnemy =
  let row = db.getRow(sql"""
    SELECT dungeonEnemyRateId, dungeonPieceId, dungeonPieceX, dungeonPieceY,
           dungeonPieceIndex, defeatedAt, isBoss
    FROM dungeonEnemies
    WHERE dungeonId = ? AND entityId = ?
  """, dungeonId, entityId)

  result = DungeonEnemy(
    entityId: entityId,
    dungeonEnemyRateId: parseInt(row[0]),
    dungeonPieceId: parseInt(row[1]),
    dungeonPieceX: parseInt(row[2]),
    dungeonPieceY: parseInt(row[3]),
    dungeonPieceIndex: parseInt(row[4]),
    defeatedAt: if row[5] != "": some(row[5]) else: none(string),
    isBoss: row[6] == "true",
  )

proc dungeonDifficultyIdToDungeonId*(dungeonDifficultyId: int): int = dungeonDifficultyId div 100
proc dungeonDifficultyIdToCityId*(dungeonDifficultyId: int): int = dungeonDifficultyId div 1_000_000
proc dungeonPieceIdToDungeonPartId(dungeonPieceId: int): int = dungeonPieceId mod 10_000


proc findDungeonPart(dungeonData: openArray[DungeonPart], dungeonPieceId: int): DungeonPart =
  let dungeonPartIndex = dungeonData.findIt(it.id == dungeonPieceIdToDungeonPartId(dungeonPieceId))

  if dungeonPartIndex == -1:
    raise newException(SembaError, "Couldn't find dungeonPart for dungeonPieceId " & $dungeonPieceId)

  dungeonData[dungeonPartIndex]


proc genDungeonAreaItems*(
  db: DbConn, cityId: int, dungeonPieces: openArray[DungeonPiece], dungeonData: openArray[DungeonPart]
): seq[DungeonAreaItem] =
  let areaItemPool = getMdDungeonAreaItemsForCity(db, cityId)

  var entityId = 1

  for i in 1 ..< dungeonPieces.len - 1:
    let dungeonPiece = dungeonPieces[i]
    let dungeonPart = findDungeonPart(dungeonData, dungeonPiece.dungeonPieceId)

    for j in 0 ..< dungeonPart.maxAreaItems:
      result.add(DungeonAreaItem(
        entityId: entityId,
        dungeonAreaItemId: areaItemPool.sample().dungeonAreaItemId,
        dungeonPieceId: dungeonPiece.dungeonPieceId,
        dungeonPieceX: dungeonPiece.x,
        dungeonPieceY: dungeonPiece.y,
        dungeonPieceIndex: j,
      ))

      entityId += 1


proc genDungeonEnemies*(
  db: DbConn, notGoalEnemyRateSetId: int, dungeonDifficultyId: int,
  dungeonPieces: seq[DungeonPiece], dungeonData: seq[DungeonPart]
): seq[DungeonEnemy] =
  let dungeonDifficulty = getDungeonDifficulty(db, dungeonDifficultyId)
  let notGoalEnemyRates = getMdDungeonEnemyRates(db, notGoalEnemyRateSetId)
  let goalEnemyRates = getMdDungeonEnemyRates(db, dungeonDifficulty.goalEnemyRateSetId)

  var entityId = 1

  for i in 1 ..< dungeonPieces.len - 1:
    let dungeonPiece = dungeonPieces[i]

    let dungeonPart = findDungeonPart(dungeonData, dungeonPiece.dungeonPieceId)

    for j in 0 ..< dungeonPart.maxEnemies:
      result.add(DungeonEnemy(
        entityId: entityId,
        dungeonEnemyRateId: notGoalEnemyRates[rand(0 ..< notGoalEnemyRates.len)].id,
        dungeonPieceId: dungeonPiece.dungeonPieceId,
        dungeonPieceX: dungeonPiece.x,
        dungeonPieceY: dungeonPiece.y,
        dungeonPieceIndex: j,
      ))

      entityId += 1

  let lastDungeonPiece = dungeonPieces[dungeonPieces.len - 1]

  result.add(DungeonEnemy(
    entityId: entityId,
    isBoss: true,
    dungeonEnemyRateId: goalEnemyRates[0].id,
    dungeonPieceId: lastDungeonPiece.dungeonPieceId,
    dungeonPieceX: lastDungeonPiece.x,
    dungeonPieceY: lastDungeonPiece.y
  ))