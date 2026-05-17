import std/options
import std/strutils
import std/json
import std/random
import std/sequtils

import ../db_connector/db_sqlite

import ../enum_ex
import ../extsqlite
import ../semba_error
import timestamp
import reward
import entity

type GearRarity* = enum
  gearRarityInvalid = 0
  gearRarityN = 1
  gearRarityR = 2
  gearRaritySr = 3
  gearRaritySsr = 4

type Gear* = object
  entityId*: int
  gearId*: int
  receivedAt*: Timestamp
  rarity*: int
  isLocked*: Option[bool]
  subStatus1Id*: Option[int]
  subStatus2Id*: Option[int]
  subStatus3Id*: Option[int]
  trainingScoreLevelScore*: Option[int]

type MdGear* = object
  id*: int
  grade*: int
  gearTypeId*: int
  descr*: string
  compressItemRewards*: JsonNode # FIXME: proper type
  compressItems*: JsonNode # FIXME: proper type
  mainStatusId*: int

type MdGearStatusAbility = object
  ability_efficacy_id: int
  exec_timing_type: int

type MdGearStatusAdventureAbility = object
  ability_type: int
  value: int

type MdGSCharacterSkillPlus = object
  character_id: int
  character_skill_types: seq[int]
  value: int

type MdStatusEffectType* = enum
  statusEffectMaximumHP = 1
  statusEffectFlatHp = 2
  statusEffectAttack = 3
  statusEffectFlatAtk = 4
  statusEffectDefense = 5
  statusEffectFlatDef = 6
  statusEffectCriticalRate = 7
  statusEffectCriticalDMGMultiplier = 8
  statusEffectSupport = 9
  statusEffectMovingSpeed = 20
  statusEffectGrantRecoveryEffect = 29
  statusEffectMaximumStamina = 30
  statusEffectDamageCutRate = 32

type MdStatusEffect* = object
  `type`*: MdStatusEffectType
  value*: float

type GearType* = enum
  gearAttacker = 101
  gearBerserker = 102
  gearGladiator = 103
  gearDefender = 201
  gearPaladin = 202
  gearFortress = 203
  gearHealer = 301
  gearTrickster = 302
  gearEnchanter = 303

type GearSet* = object
  gearType*: GearType
  statusEffect*: MdStatusEffect

const attackerGearSet* = GearSet(
  gearType: gearAttacker, statusEffect: MdStatusEffect(`type`: statusEffectAttack, value: 1.15)
)

const defenderGearSet* = GearSet(
  gearType: gearDefender, statusEffect: MdStatusEffect(`type`: statusEffectMaximumHP, value: 1.1)
)

const fortressGearSet* = GearSet(
  gearType: gearFortress, statusEffect: MdStatusEffect(`type`: statusEffectDamageCutRate, value: 0.08)
)

const healerGearSet* = GearSet(
  gearType: gearHealer, statusEffect: MdStatusEffect(`type`: statusEffectGrantRecoveryEffect, value: 30.0)
)

const tricksterGearSet* = GearSet(
  gearType: gearTrickster, statusEffect: MdStatusEffect(`type`: statusEffectSupport, value: 30.0)
)

const setRequiredCount* = 2

type MdGearStatus = object
  id: int
  rarity: int
  statusEffectType: Option[int]
  statusEffectValue: Option[float]
  statusGroupId: int
  abilities: seq[MdGearStatusAbility]
  adventureAbilities: seq[MdGearStatusAdventureAbility]
  characterSkillPlus: Option[MdGSCharacterSkillPlus]


type GearMainStatus* = object
  `type`*: MdStatusEffectType
  values*: array[11, int]

const headMainStatus = GearMainStatus(
  `type`: statusEffectFlatDef, values: [21, 32, 43, 56, 69, 82, 106, 130, 154, 202, 250]
)

const bodyMainStatus = GearMainStatus(
  `type`: statusEffectFlatHp, values: [105, 160, 215, 280, 345, 410, 530, 650, 770, 1010, 1250]
)

const weaponMainStatus = GearMainStatus(
  `type`: statusEffectFlatAtk, values: [21, 32, 43, 56, 69, 82, 106, 130, 154, 202, 250]
)

const mainStatusList* = [headMainStatus, bodyMainStatus, weaponMainStatus]


proc addGear*(db: DbConn, gear: Gear) =
  db.exec(
    sql"""
      INSERT INTO gears (
        entityId, gearId, receivedAt, rarity, isLocked,
        subStatus1Id, subStatus2Id, subStatus3Id, trainingScoreLevelScore
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
      ON CONFLICT (entityId) DO
      UPDATE SET gearId = excluded.gearId, receivedAt = excluded.receivedAt, rarity = excluded.rarity,
        isLocked = excluded.isLocked, subStatus1Id = excluded.subStatus1Id, subStatus2Id = excluded.subStatus2Id,
        subStatus3Id = excluded.subStatus3Id, trainingScoreLevelScore = excluded.trainingScoreLevelScore
    """,
    gear.entityId, gear.gearId, gear.receivedAt, gear.rarity, optionToSqlArg(gear.isLocked),
    optionToSqlArg(gear.subStatus1Id), optionToSqlArg(gear.subStatus2Id), optionToSqlArg(gear.subStatus3Id),
    optionToSqlArg(gear.trainingScoreLevelScore)
  )


proc getGear*(db: DbConn, entityId: int): Gear =
  let row = db.getRow(sql"""
    SELECT gearId, receivedAt, rarity, isLocked, subStatus1Id, subStatus2Id, subStatus3Id, trainingScoreLevelScore
    FROM gears WHERE entityId = ?
  """, entityId)

  if row[0] == "":
    raise newException(SembaError, "Couldn't get gear with entityId=" & $entityId)

  result = Gear(
    entityId: entityId,
    gearId: parseInt(row[0]),
    receivedAt: row[1].Timestamp,
    rarity: parseInt(row[2]),
    isLocked: tryParseBool(row[3]),
    subStatus1Id: tryParseInt(row[4]),
    subStatus2Id: tryParseInt(row[5]),
    subStatus3Id: tryParseInt(row[6]),
    trainingScoreLevelScore: tryParseInt(row[7]),
  )


proc getGears*(db: DbConn): seq[Gear] =
  let rows = db.getAllRows(sql"SELECT entityId FROM gears")

  for row in rows:
    result.add(getGear(db, parseInt(row[0])))


proc getMdGear*(db: DbConn, gearId: int): MdGear =
  let row = db.getRow(sql"""
    SELECT grade, gearTypeId, compressItemRewards, compressItems, mainStatusId, descr FROM mdGear
    WHERE id = ?
  """, gearId)

  if row[0] == "":
    raise newException(SembaError, "Couldn't get MdGear for gearId=" & $gearId)

  result = MdGear(
    id: gearId,
    grade: parseInt(row[0]),
    gearTypeId: parseInt(row[1]),
    compressItemRewards: parseJson(row[2]),
    compressItems: parseJson(row[3]),
    mainStatusId: parseInt(row[4]),
    descr: row[5],
  )


proc getMdGears*(db: DbConn, descr: string): seq[MdGear] =
  let rows = db.getAllRows(sql"""
    SELECT id, grade, gearTypeId, compressItemRewards, compressItems, mainStatusId FROM mdGear
    WHERE descr = ?
  """, descr)

  for row in rows:
    result.add(MdGear(
      id: parseInt(row[0]),
      grade: parseInt(row[1]),
      gearTypeId: parseInt(row[2]),
      descr: descr,
      compressItemRewards: parseJson(row[3]),
      compressItems: parseJson(row[4]),
      mainStatusId: parseInt(row[5]),
    ))


proc getMdGearStatsWithRarity(db: DbConn, rarity: int): seq[MdGearStatus] =
  let rows = db.getAllRows(sql"""
    SELECT id, statusEffectType, statusEffectValue, statusGroupId FROM mdGearStatus
    WHERE rarity = ? AND characterSkillPlus IS null
  """, rarity)

  for row in rows:
    result.add(MdGearStatus(
      id: parseInt(row[0]),
      rarity: rarity,
      statusEffectType: tryParseInt(row[1]),
      statusEffectValue: tryParseFloat(row[2]),
      statusGroupId: parseInt(row[3]),
    ))


proc getMdGearStatsWithMaxRarity(db: DbConn, maxRarity: int): seq[MdGearStatus] =
  let rows = db.getAllRows(sql"""
    SELECT id, rarity, statusEffectType, statusEffectValue, statusGroupId FROM mdGearStatus
    WHERE rarity <= ? AND characterSkillPlus IS null
  """, maxRarity)

  for row in rows:
    result.add(MdGearStatus(
      id: parseInt(row[0]),
      rarity: parseInt(row[1]),
      statusEffectType: tryParseInt(row[2]),
      statusEffectValue: tryParseFloat(row[3]),
      statusGroupId: parseInt(row[4]),
    ))


proc getRandomSubstatWithMaxRarity(db: DbConn, maxRarity: int): MdGearStatus =
  result = getMdGearStatsWithMaxRarity(db, maxRarity).sample()


proc getRandomSubstatWithRarity(db: DbConn, rarity: int): MdGearStatus =
  result = getMdGearStatsWithRarity(db, rarity).sample()


proc getSubstats(db: DbConn, rarity: int): (Option[MdGearStatus], Option[MdGearStatus], Option[MdGearStatus]) =
  var subStatus1: Option[MdGearStatus]
  var subStatus2: Option[MdGearStatus]
  var subStatus3: Option[MdGearStatus]

  if rarity != gearRarityN.int:
    subStatus1 = some(getRandomSubstatWithRarity(db, rarity))

  if rarity == gearRaritySr.int or rarity == gearRaritySsr.int:
    subStatus2 = some(getRandomSubstatWithMaxRarity(db, rarity))

  if rarity == gearRaritySsr.int:
    subStatus3 = some(getRandomSubstatWithMaxRarity(db, gearRaritySsr.int))

  result = (subStatus1, subStatus2, subStatus3)


proc gearRewardToGear*(reward: Reward): Gear =
  let gearRewardStatus = reward.resourceParams.get().gearRewardStatus.get()
  let subStatusIds = gearRewardStatus.subStatusIds.get(@[])

  result = Gear(
    entityId: reward.entityId.get(),
    gearId: reward.id,
    receivedAt: getTimestampNow(),
    subStatus1Id: if subStatusIds.len >= 1: some(subStatusIds[0]) else: none(int),
    subStatus2Id: if subStatusIds.len >= 2: some(subStatusIds[1]) else: none(int),
    subStatus3Id: if subStatusIds.len == 3: some(subStatusIds[2]) else: none(int),
    trainingScoreLevelScore: some(1),
    rarity: gearRewardStatus.gearRarity,
  )


proc randomGear*(db: DbConn, minRarity: int, mdGears: seq[MdGear]): (Gear, Reward) =
  let mdGear = mdGears.sample()

  let rarity = toSeq(minRarity .. gearRaritySsr.int).sample()

  let (subStatus1, subStatus2, subStatus3) = getSubstats(db, rarity)

  let entityId = popEntityId(db)

  let subStatusIds = (
    [subStatus1, subStatus2, subStatus3]
    .filter(proc (x: Option[MdGearStatus]): bool = x.isSome())
    .map(proc (x: Option[MdGearStatus]): int = x.get().id)
  ) 

  let gearRewardStatus = GearRewardStatus(
    subStatusIds: some(subStatusIds),
    gearRarity: rarity
  )
  
  let reward = Reward(
    `type`: rewardGear.int,
    id: mdGear.id,
    quantity: 1,
    entityId: some(entityId),
    resourceParams: some(ResourceParams(gearRewardStatus: some(gearRewardStatus))),
    isNew: some(true),
  ) 

  let gear = Gear(
    entityId: entityId,
    gearId: mdGear.id,
    receivedAt: getTimestampNow(),
    subStatus1Id: subStatus1.map(proc (x: MdGearStatus): int = x.id),
    subStatus2Id: subStatus2.map(proc (x: MdGearStatus): int = x.id),
    subStatus3Id: subStatus3.map(proc (x: MdGearStatus): int = x.id),
    trainingScoreLevelScore: some(1),
    rarity: rarity
  )

  result = (gear, reward)


proc getStatusEffect*(db: DbConn, gearStatusId: int): Option[MdStatusEffect] =
  let row = db.getRow(sql"""
    SELECT id, statusEffectType, statusEffectValue FROM mdGearStatus WHERE id = ?
  """, gearStatusId)

  if row[0] == "":
    raise newException(SembaError, "Failed to get status effect with gearStatusId=" & $gearStatusId)

  if row[1] != "":
    result = some(MdStatusEffect(`type`: parseInt(row[1]).intToEnum(MdStatusEffectType), value: parseFloat(row[2])))


proc getMdGearId*(db: DbConn, mainStatusId: int, gearType: GearType, grade: int): int =
  let row = db.getRow(sql"""
    SELECT id FROM mdGear WHERE grade = ? AND gearTypeId = ? AND mainStatusId = ?
  """, grade, gearType.int, mainStatusId)

  if row[0] == "":
    raise newException(
      SembaError,
      "Failed to get gear id for grade=" & $grade & ", mainStatusId=" & $mainStatusId & "and gearType " & $gearType
    )

  result = parseInt(row[0])