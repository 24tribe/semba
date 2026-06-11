import std/options
import std/json
import std/strutils
import std/math
import std/sequtils
import std/sugar

import ../db_connector/db_sqlite

import ../semba_error
import area_object
import area_object_lock
import character
import dungeon
import enemy
import reward
import mission


type BattleTrigger* = object
  triggerType*: Option[string]
  triggerIds*: Option[seq[int]]

type BattleInfo* = object
  battleEntryIds*: seq[int]
  lineCharacterIds*: seq[int]
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

type MdBattleEnemy = object
  id: int
  enemyId: int
  hpStackCountOverride: Option[int]
  hpStatusFactor: float
  atkStatusFactor: float


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


proc getBattleExp*(db: DbConn, battleEntryIds: openArray[int]): float =
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


proc getCharacterExps*(db: DbConn, characterIds: openArray[int], battleEntryIds: openArray[int]): seq[CharacterExp] =
  let dropExp = round(getBattleExp(db, battleEntryIds)).int

  characterIds.mapIt(CharacterExp(
    characterId: it,
    exp: dropExp,
    dropExp: dropExp,
  ))


proc getMdBattleEnemy(db: DbConn, battleEnemyId: int): MdBattleEnemy =
  let row = db.getRow(sql"""
    SELECT enemyId, hpStackCountOverride, hpStatusFactor, atkStatusFactor FROM mdBattleEnemy
    WHERE id = ?
  """, battleEnemyId)

  if row[0] != "":
    result = MdBattleEnemy(
      id: battleEnemyId,
      enemyId: parseInt(row[0]),
      hpStackCountOverride: if row[1] != "": some(parseInt(row[1])) else: none(int),
      hpStatusFactor: parseFloat(row[2]),
      atkStatusFactor: parseFloat(row[3]),
    )


proc getMdEnemy(db: DbConn, enemyId: int): MdEnemy =
  let row = db.getRow(sql"SELECT attack, defense, hp, dropExp, hpStackCount FROM mdEnemy WHERE id = ?", enemyId)

  if row[0] == "":
    raise newException(SembaError, "enemyId=" & $enemyId & " not found in db")

  result = MdEnemy(
    id: enemyId,
    attack: parseInt(row[0]),
    defense: parseInt(row[1]),
    hp: parseInt(row[2]),
    dropExp: parseInt(row[3]),
    hpStackCount: parseInt(row[4]),
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
        let battleEnemy = getMdBattleEnemy(db, battleEnemyId)
        let enemy = getMdEnemy(db, battleEnemy.enemyId)
        let hpStackCount = battleEnemy.hpStackCountOverride.get(enemy.hpStackCount)
        enemies.add(Enemy(
          id: enemy.id,
          attack: round(enemy.attack.float*enemyLevel.atkStatusFactor*battleEnemy.atkStatusFactor).int,
          defense: (enemy.defense.float*enemyLevel.defStatusFactor).int,
          hp: round(enemy.hp.float*enemyLevel.hpStatusFactor*battleEnemy.hpStatusFactor).int,
          hpStackCount: some(hpStackCount),
          # FIXME: isSkipEncounterAnimation?
        ))

    result.add(BattleParameter(
      id: battleParameter.id,
      enemies: enemies,
    ))


proc getChangedAttackTestMissions*(db: DbConn, characters: seq[Character], cityId: int): seq[Mission] =
  let attackTestMissions = getAttackTestMissionsForCity(db, cityId)

  return getMissionsWithNewCount(db, attackTestMissions, proc (mission: Mission, mdMission: MdMission): Option[int] =
    let minChars = getAttackTestMissionMinChars(mdMission.id)

    let targetAttack = mdMission.steps[0].count
    let charactersWithMoreAttack = characters.filterIt(it.attack.get(0) >= targetAttack).toSeq()

    if charactersWithMoreAttack.len >= minChars:
      result = some(charactersWithMoreAttack.mapIt(it.attack.get(0)).min())
  )


proc getChangedVictorsRightsMissions*(db: DbConn, totalItems: int, cityId: int): seq[Mission] =
  let victorsRightsMissions = getVictorsRightsMissionsForCity(db, cityId)

  return getMissionsWithNewCount(db, victorsRightsMissions, proc (mission: Mission, mdMission: MdMission): Option[int] =
    result = some(mission.count.get(0) + totalItems)
  )


proc getChangedBeAForeverWinnerMissions*(db: DbConn, cityId: int): seq[Mission] =
  let beAForeverWinnerMissions = getBeAForeverWinnerMissionsForCityId(db, cityId)

  return getMissionsWithNewCount(db, beAForeverWinnerMissions, (mission, mdMission) => some(mission.count.get(0) + 1))


proc handleWonBattleTriggers*(
  db: DbConn, battleTriggers: openArray[BattleTrigger], dungeonId: Option[int], areaId: int
): seq[AreaObjectLock] =
  ## Dungeon: Remove defeated enemies
  ## Adventure: Remove defeated area objects/enemies and unlocks reward
  ## Return the changed area object locks

  for battleTrigger in battleTriggers:
    var isAreaObject = battleTrigger.triggerType.get("") == "area_object"
    var isActionSequence = battleTrigger.triggerType.get("") == "action_sequence"
    var isDungeon = battleTrigger.triggerType.get("") == "dungeon"

    if not isActionSequence:
      for triggerId in battleTrigger.triggerIds.get(@[]):
        if isDungeon:
          removeDungeonEnemy(db, dungeonId.get(), triggerId)
        else:
          if isAreaObject:
            let areaObjectLockId = getAreaObjectLockIdForBattle(db, triggerId)

            if areaObjectLockId.isSome():
              result.add(AreaObjectLock(areaObjectLockId: areaObjectLockId.get(), count: some(1)))

            removeAreaObject(db, areaId, triggerId)
          else:
            removeAreaEnemy(db, areaId, triggerId)


proc applyCharacterUpdates*(db: DbConn, characterUpdates: openArray[CharacterUpdate]): seq[Character] =
  ## Changes characters hp based on characterUpdates. Returns the changed characters.

  for characterUpdate in characterUpdates:
      setCharacterHp(db, characterUpdate.characterId, characterUpdate.hp.get(0))

  getCharactersWithId(db, characterUpdates.mapIt(it.characterId))


proc collectEnemyRewards*(db: DbConn, encounteredEnemyIds: openArray[int]): seq[Reward] =
  for enemyId in encounteredEnemyIds:
    let rewardItemIds = getEnemyRewardItemIds(db, enemyId)

    if rewardItemIds.len == 0:
      echo("Warning: rewardItemIds for enemyId=" & $enemyId & " is empty!!")

    let rewards = getRandomRewards(db, rewardItemIds)

    for reward in rewards:
      result.add(reward)