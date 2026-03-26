import std/options
import std/json
import std/strutils

import ../db_connector/db_sqlite

import ../semba_error
import enemy
import dungeon


type BattleTrigger* = object
  triggerType*: Option[string]
  triggerIds*: Option[seq[int]]

type BattleInfo* = object
  battleEntryIds*: seq[int]
  lineCharacterIds*: seq[int]
  currentLocation*: JsonNode
  battleTriggers*: seq[BattleTrigger]
  dungeonId*: Option[int]
  advantageType*: Option[string]

type MdBattleEntry = object
  id: int
  enemyLevel: int
  battleParameterId: int

type MdBattleParameter = object
  id: int
  dropExpFactor: float
  battleWaveIds: seq[int]

type MdBattleWave = object
  id: int
  battleEnemyIds: seq[int]

type BattleParameter* = object
  id*: int
  enemies*: seq[Enemy]


proc getMdBattleEntry(db: DbConn, battleEntryId: int): MdBattleEntry =
  let row = db.getRow(sql"""
    SELECT enemyLevel, battleParameterId FROM mdBattleEntry
    WHERE id = ?
  """, battleEntryId)

  result = MdBattleEntry(
    id: battleEntryId,
    enemyLevel: parseInt(row[0]),
    battleParameterId: parseInt(row[1])
  )

proc getMdBattleParameter(db: DbConn, battleParameterId: int): MdBattleParameter =
  let battleParameterRow = db.getRow(
    sql"SELECT dropExpFactor FROM mdBattleParameter WHERE id = ?", battleParameterId
  )

  let dropExpFactor = parseFloat(battleParameterRow[0])

  let battleParameterWaveRows = db.getAllRows(sql"""
    SELECT battleWaveId FROM mdBattleParameterWave
    WHERE battleParameterId = ?
  """, battleParameterId)

  var battleWaveIds = newSeq[int]()

  for row in battleParameterWaveRows:
    let battleWaveId = parseInt(row[0])
    battleWaveIds.add(battleWaveId)

  result = MdBattleParameter(
    id: battleParameterId,
    dropExpFactor: dropExpFactor,
    battleWaveIds: battleWaveIds
  )

proc getMdBattleWave(db: DbConn, battleWaveId: int): MdBattleWave =
  var battleEnemyIds = newSeq[int]()

  let rows = db.getAllRows(sql"SELECT battleEnemyId FROM mdBattleWave WHERE id = ?", battleWaveId)

  for row in rows:
    let battleEnemyId = parseInt(row[0])
    battleEnemyIds.add(battleEnemyId)

  result = MdBattleWave(id: battleWaveId, battleEnemyIds: battleEnemyIds)

proc getMdBattleEnemyDropExp(db: DbConn, battleEnemyId: int): int =
  let row = db.getRow(sql"""
    SELECT dropExp
    FROM mdEnemy INNER JOIN mdBattleEnemy ON mdEnemy.id == enemyId
    WHERE mdBattleEnemy.id = ?
  """, battleEnemyId)

  result = parseInt(row[0])

proc getMdEnemyLevelDropExpFactor(db: DbConn, level: int): float =
  let row = db.getRow(sql"SELECT dropExpFactor FROM mdEnemyLevel WHERE level = ?", level)
  result = parseFloat(row[0])

proc getMdEnemyLevel(db: DbConn, level: int): MdEnemyLevel =
  let row = db.getRow(
    sql"SELECT dropExpFactor, atkStatusFactor, defStatusFactor, hpStatusFactor FROM mdEnemyLevel WHERE level = ?",
    level
  )

  result = MdEnemyLevel(
    level: level,
    dropExpFactor: parseFloat(row[0]),
    atkStatusFactor: parseFloat(row[1]),
    defStatusFactor: parseFloat(row[2]),
    hpStatusFactor: parseFloat(row[3]),
  )


proc getBattleParameters*(db: DbConn, battleEntryIds: JsonNode): seq[JsonNode] =
  # FIXME: fix n+1
  for battleEntryId in battleEntryIds:
    let id = battleEntryId.getInt()
    let battleParameterRow = db.getRow(sql"""
      SELECT enemies FROM battleParameters WHERE id = ?
    """, id)

    if battleParameterRow[0] == "":
      raise newException(SembaError, "Couldn't find battleParameters for battleEntryId=" & $battleEntryId)

    let enemies = parseJson(battleParameterRow[0])

    result.add(%*{
      "id": id,
      "enemies": enemies
    })


proc getBattleExp*(db: DbConn, battleEntryIds: seq[int]): float =
  for battleEntryId in battleEntryIds:
    var dropExp = 0.0

    let battleEntry = getMdBattleEntry(db, battleEntryId)
    let enemyLevelDropExpFactor = getMdEnemyLevelDropExpFactor(db, battleEntry.enemyLevel)
    let battleParameter = getMdBattleParameter(db, battleEntry.battleParameterId)

    for battleWaveId in battleParameter.battleWaveIds:
      let battleWave = getMdBattleWave(db, battleWaveId)

      for battleEnemyId in battleWave.battleEnemyIds:
        dropExp += getMdBattleEnemyDropExp(db, battleEnemyId).float

    dropExp *= battleParameter.dropExpFactor*enemyLevelDropExpFactor
    result += dropExp


proc getMdEnemyFromBattleEnemyId(db: DbConn, battleEnemyId: int): MdEnemy =
  let row = db.getRow(sql"""
    SELECT mdEnemy.id, attack, defense, hp, dropExp
    FROM mdEnemy INNER JOIN mdBattleEnemy ON mdEnemy.id = mdBattleEnemy.enemyId
    WHERE mdBattleEnemy.id = ?
  """, battleEnemyId)

  result = MdEnemy(
    id: parseInt(row[0]),
    attack: parseInt(row[1]),
    defense: parseInt(row[2]),
    hp: parseInt(row[3]),
    dropExp: parseInt(row[4])
  )

proc getBattleEntryIdsFromDungeonEntityIds*(db: DbConn, dungeonId: int, entityIds: seq[int]): seq[int] =
  for entityId in entityIds:
    let dungeonEnemy = getDungeonEnemy(db, dungeonId, entityId)
    let dungeonEnemyRate = getMdDungeonEnemyRate(db, dungeonEnemy.dungeonEnemyRateId)
    result.add(dungeonEnemyRate.battleEntryId)

proc getBattleParametersFromBattleEntryIds*(db: DbConn, battleEntryIds: seq[int]): seq[BattleParameter] =
  for battleEntryId in battleEntryIds:
    let battleEntry = getMdBattleEntry(db, battleEntryId)
    let battleParameter = getMdBattleParameter(db, battleEntry.battleParameterId)

    var enemies = newSeq[Enemy]()

    let enemyLevel = getMdEnemyLevel(db, battleEntry.enemyLevel)

    for battleWaveId in battleParameter.battleWaveIds:
      let battleWave = getMdBattleWave(db, battleWaveId)

      for battleEnemyId in battleWave.battleEnemyIds:
        let enemy = getMdEnemyFromBattleEnemyId(db, battleEnemyId)
        enemies.add(Enemy(
          id: enemy.id,
          attack: (enemy.attack.float*enemyLevel.atkStatusFactor).int,
          defense: (enemy.defense.float*enemyLevel.defStatusFactor).int,
          hp: (enemy.hp.float*enemyLevel.hpStatusFactor).int,
        ))

    result.add(BattleParameter(
      id: battleParameter.id,
      enemies: enemies,
    ))