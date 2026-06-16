import std/json
import std/strutils
import std/math
import std/options
import std/sequtils

import db_connector/db_sqlite

import ../semba_error
import ../extsqlite
import ../enum_ex
import ../protojson
import status
import mission
import timestamp
import gear


const charBaseMovementSpeed = 6.0
const charBaseDamageTakenRate = 1.0
const charBaseCriticalRate = 5.0
const charBaseCriticalDamageRate = 50.0
const charBaseDamageInflictedRate = 100.0
const charBaseTensionIncreaseRate = 100.0
const charBaseCpRecastRate = 100.0
const charBaseSpGaugeIncreaseRate = 100.0
const charBaseAttackSpeed = 100.0
const charBaseActionPointMax = 1000
const charBaseActionPointRate = 3000.0
const charBaseActionPointConsumption = 160.0

const saizoCharId = 102901
const saizoBaseMovementSpeed = 8.0


type CharacterExp* = object
  characterId*: int
  exp*: int
  dropExp*: int

type MdCharacter* = object
  id*: int
  baseAttack*: int
  baseDefense*: int
  baseHp*: int
  favoritePresentItemId*: int
  mountingPower*: int
  rarity*: int
  skillGemId*: int

type MdCharacterLevel* = object
  level*: int
  exp*: int
  statusFactor*: float

type Character* = object
  characterId*: int
  exp*: int
  limitBreak*: int
  hp*: int
  attack*: int
  defense*: int
  maxHp*: int
  gearSlot1*: Option[int]
  gearSlot2*: Option[int]
  gearSlot3*: Option[int]
  receivedAt*: Timestamp
  characterOwnershipType*: int
  dishId*: Option[int]
  dishEffectCount*: int
  dishEffectExpiredAt*: Option[Timestamp]
  rank*: int
  criticalRate*: float
  criticalDamageRate*: float
  supportPowerRate*: int
  movementSpeed*: float
  powerRate*: float
  dodgeSpeed*: float
  damageInflictedRate*: float
  tensionIncreaseRate*: float
  cpRecastRate*: float
  recoveryGivenRate*: float
  spGaugeIncreaseRate*: float
  attackSpeed*: float
  characterCostumeId*: Option[int]
  characterSkillPanel1Level*: int
  characterSkillPanel2Level*: int
  characterSkillPanel3Level*: int
  characterSkillPanel4Level*: int
  characterSkillPanel5Level*: int
  abnormalityParamSet*: JsonNode # FIXME: use AbnormalityParamSet
  trainingScore*: int
  trainingScoreLevelScore*: int
  trainingScoreRankScore*: int
  actionPointMax*: int
  actionPointRate*: float
  actionPointConsumption*: float
  damageTakenRate*: float

type CharacterCostume* = object
  characterCostumeId: int
  receivedAt: Timestamp


type CharacterUpdate* = object
  characterId*: int
  hp*: Option[int]


type CharacterOwnershipType* = enum
  charOwnershipOwned = 1
  charOwnershipGuest = 2


proc costumeIdToCharacterId*(costumeId: int): int =
  return (costumeId div 1000)*100 + 1


proc characterIdToCostumeId*(characterId: int): int = (characterId div 100)*1000 + 1


proc setCharacterHp*(db: DbConn, characterId: int, hp: int) =
  db.exec(sql"UPDATE characters SET hp = ? WHERE characterId = ?", hp, characterId)


proc setCharacterExp*(db: DbConn, characterId: int, exp: int) =
  db.exec(sql"UPDATE characters SET exp = ? WHERE characterId = ?", exp, characterId)


proc addCharacterLimitBreak*(db: DbConn, characterId: int, limitBreak: int) =
  db.exec(sql"""
    INSERT INTO characterLimitBreaks (characterId, limitBreak) VALUES (?, ?)
    ON CONFLICT (characterId) DO
    UPDATE SET limitBreak = excluded.limitBreak
  """, characterId, limitBreak)


proc addCharacterTypeSafe*(db: DbConn, character: Character) =
  db.exec(sql"""
    INSERT INTO characters
    (characterId, exp, hp, receivedAt, characterOwnershipType,
     characterCostumeId, trainingScoreLevelScore, trainingScoreRankScore,
     gearSlot1, gearSlot2, gearSlot3)
    VALUES
    (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    ON CONFLICT (characterId) DO UPDATE SET
      exp = excluded.exp, hp = excluded.hp, receivedAt = excluded.receivedAt,
      characterOwnershipType = excluded.characterOwnershipType,
      characterCostumeId = excluded.characterCostumeId, 
      trainingScoreLevelScore = excluded.trainingScoreLevelScore,
      trainingScoreRankScore = excluded.trainingScoreRankScore,
      gearSlot1 = excluded.gearSlot1, gearSlot2 = excluded.gearSlot2, gearSlot3 = excluded.gearSlot3
  """, character.characterId, character.exp, character.hp, character.receivedAt,
    character.characterOwnershipType, character.characterCostumeId.get(0),
    character.trainingScoreLevelScore, character.trainingScoreRankScore,
    optionToSqlArg(character.gearSlot1), optionToSqlArg(character.gearSlot2), optionToSqlArg(character.gearSlot3)
  )

  addCharacterLimitBreak(db, character.characterId, character.limitBreak)


proc addCharacter*(db: DbConn, character: JsonNode) =
  let characterId = character["characterId"].getInt()
  let exp = character.getOrDefault("exp").getInt()
  let hp = character["hp"].getInt()
  let attack = character["attack"].getInt()
  let defense = character["defense"].getInt()
  let maxHp = character["maxHp"].getInt()
  let receivedAt = character["receivedAt"].getStr()
  let characterOwnershipType = character["characterOwnershipType"].getInt()
  let criticalRate = character["criticalRate"].getInt()
  let criticalDamageRate = character["criticalDamageRate"].getInt()
  let movementSpeed = character["movementSpeed"].getInt()
  let damageInflictedRate = character["damageInflictedRate"].getInt()
  let tensionIncreaseRate = character["tensionIncreaseRate"].getInt()
  let cpRecastRate = character["cpRecastRate"].getInt()
  let spGaugeIncreaseRate = character["spGaugeIncreaseRate"].getInt()
  let attackSpeed = character["attackSpeed"].getInt()
  let characterCostumeId = character["characterCostumeId"].getInt()
  let abnormalityParamSet = $character["abnormalityParamSet"]
  let trainingScoreLevelScore = character["trainingScoreLevelScore"].getInt()
  let trainingScoreRankScore = character["trainingScoreRankScore"].getInt()
  let actionPointMax = character["actionPointMax"].getInt()
  let actionPointRate = character["actionPointRate"].getInt()
  let actionPointConsumption = character["actionPointConsumption"].getInt()
  let damageTakenRate = character["damageTakenRate"].getInt()
  let limitBreak = character.getOrDefault("limitBreak").getInt()

  let gearSlot1 = protoJsonTo(character.getOrDefault("gearSlot1"), Option[int])
  let gearSlot2 = protoJsonTo(character.getOrDefault("gearSlot2"), Option[int])
  let gearSlot3 = protoJsonTo(character.getOrDefault("gearSlot3"), Option[int])

  db.exec(sql"""
    INSERT INTO characters
    (characterId, exp, hp, attack, defense, maxHp, receivedAt, characterOwnershipType,
     criticalRate, criticalDamageRate, movementSpeed, damageInflictedRate, tensionIncreaseRate,
     cpRecastRate, spGaugeIncreaseRate, attackSpeed, characterCostumeId, abnormalityParamSet,
     trainingScoreLevelScore, trainingScoreRankScore, actionPointMax, actionPointRate,
     actionPointConsumption, damageTakenRate, gearSlot1, gearSlot2, gearSlot3)
    VALUES
    (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    ON CONFLICT (characterId) DO UPDATE SET
      exp = excluded.exp, hp = excluded.hp, attack = excluded.attack, defense = excluded.defense,
      maxHp = excluded.maxHp, receivedAt = excluded.receivedAt, characterOwnershipType = excluded.characterOwnershipType,
      criticalRate = excluded.criticalRate, criticalDamageRate = excluded.criticalDamageRate,
      movementSpeed = excluded.movementSpeed, damageInflictedRate = excluded.damageInflictedRate,
      tensionIncreaseRate = excluded.tensionIncreaseRate, cpRecastRate = excluded.cpRecastRate,
      spGaugeIncreaseRate = excluded.spGaugeIncreaseRate, attackSpeed = excluded.attackSpeed,
      characterCostumeId = excluded.characterCostumeId, abnormalityParamSet = excluded.abnormalityParamSet,
      trainingScoreLevelScore = excluded.trainingScoreLevelScore, trainingScoreRankScore = excluded.trainingScoreRankScore,
      actionPointMax = excluded.actionPointMax, actionPointRate = excluded.actionPointRate,
      actionPointConsumption = excluded.actionPointConsumption, damageTakenRate = excluded.damageTakenRate,
      gearSlot1 = excluded.gearSlot1, gearSlot2 = excluded.gearSlot2, gearSlot3 = excluded.gearSlot3
  """, characterId, exp, hp, attack, defense, maxHp, receivedAt, characterOwnershipType,
     criticalRate, criticalDamageRate, movementSpeed, damageInflictedRate, tensionIncreaseRate,
     cpRecastRate, spGaugeIncreaseRate, attackSpeed, characterCostumeId, abnormalityParamSet,
     trainingScoreLevelScore, trainingScoreRankScore, actionPointMax, actionPointRate,
     actionPointConsumption, damageTakenRate,
     optionToSqlArg(gearSlot1), optionToSqlArg(gearSlot2), optionToSqlArg(gearSlot3)
  )

  addCharacterLimitBreak(db, characterId, limitBreak)


proc updateCharacters*(db: DbConn, characters: seq[JsonNode]) =
  for character in characters:
    addCharacter(db, character)


proc updateCharactersTypeSafe*(db: DbConn, characters: seq[Character]) =
  for character in characters:
    addCharacterTypeSafe(db, character)


proc getMdCharacter*(db: DbConn, characterId: int): MdCharacter =
  let row = db.getRow(sql"""
    SELECT baseAttack, baseDefense, baseHp, favoritePresentItemId, mountingPower, rarity, skillGemId
    FROM mdCharacter
    WHERE id = ?
  """, characterId)

  if row[0] == "":
    raise newException(SembaError, "Couldn't find MdCharacter for id=" & $characterId)

  result = MdCharacter(
    id: characterId,
    baseAttack: parseInt(row[0]),
    baseDefense: parseInt(row[1]),
    baseHp: parseInt(row[2]),
    favoritePresentItemId: parseInt(row[3]),
    mountingPower: parseInt(row[4]),
    rarity: parseInt(row[5]),
    skillGemId: parseInt(row[6]),
  )


proc getAbnormalityParamSet*(): JsonNode =
  result = %*{
    "electric": {
      "attack_rate": 0,
      "burst_resistance": 100,
      "burst_resistance_increase_value": 0,
      "burst_resistance_limit": 100,
      "defense_rate": 0
    },
    "oily": {
      "attack_rate": 0,
      "burst_resistance": 100,
      "burst_resistance_increase_value": 0,
      "burst_resistance_limit": 100,
      "defense_rate": 0
    },
    "pressure": {
      "attack_rate": 0,
      "burst_resistance": 100,
      "burst_resistance_increase_value": 0,
      "burst_resistance_limit": 100,
      "defense_rate": 0
    },
    "scared": {
      "attack_rate": 0,
      "burst_resistance": 100,
      "burst_resistance_increase_value": 0,
      "burst_resistance_limit": 100,
      "defense_rate": 0
    },
    "unfortified": {
      "attack_rate": 0,
      "burst_resistance": 100,
      "burst_resistance_increase_value": 0,
      "burst_resistance_limit": 100,
      "defense_rate": 0
    }
  }


proc getMdCharacterLevelFromExp(db: DbConn, exp: int): MdCharacterLevel =
  let row = db.getRow(sql"""
    SELECT level, exp, statusFactor FROM mdCharacterLevel
    WHERE ? >= exp 
    ORDER BY level DESC
  """, exp)

  if row[0] == "":
    raise newException(SembaError, "Couldn't get MdCharacterLevel for exp < " & $exp)

  result = MdCharacterLevel(
    level: parseInt(row[0]),
    exp: parseInt(row[1]),
    statusFactor: parseFloat(row[2]),
  )


proc applyStatus(db: DbConn, character: var Character, originalChar: Character, statusEffect: MdStatusEffect) =
  case statusEffect.`type`:
  of statusEffectDamageCutRate:
    character.damageTakenRate -= statusEffect.value
  of statusEffectMaximumStamina:
    character.actionPointMax += statusEffect.value.int
  of statusEffectMovingSpeed:
    character.movementSpeed += (statusEffect.value - 1.0)*originalChar.movementSpeed
  of statusEffectDefense:
    character.defense = ceil(character.defense.float + (statusEffect.value - 1.0)*originalChar.defense.float).int
  of statusEffectAttack:
    character.attack = ceil(character.attack.float + (statusEffect.value - 1.0)*originalChar.attack.float).int
  of statusEffectMaximumHP:
    character.maxHp = ceil(character.maxHp.float + (statusEffect.value - 1.0)*originalChar.maxHp.float).int
  of statusEffectCriticalRate:
    character.criticalRate += statusEffect.value
  of statusEffectCriticalDMGMultiplier:
    character.criticalDamageRate += statusEffect.value
  of statusEffectFlatAtk:
    character.attack += statusEffect.value.int
  of statusEffectFlatDef:
    character.defense += statusEffect.value.int
  of statusEffectFlatHp:
    character.maxHp += statusEffect.value.int
  of statusEffectSupport:
    character.supportPowerRate += ceil(statusEffect.value).int
  of statusEffectGrantRecoveryEffect:
    character.recoveryGivenRate += statusEffect.value


proc applyGearSubstat(db: DbConn, character: var Character, originalChar: Character, substatId: int) =
  let statusEffect = getStatusEffect(db, substatId)

  if statusEffect.isSome():
    applyStatus(db, character, originalChar, statusEffect.get())


proc applyMainStatus(db: DbConn, character: var Character, originalChar: Character, mdGear: MdGear) =
  let mainStatus = mainStatusList[mdGear.mainStatusId - 1]
  let value = mainStatus.values[mdGear.grade - 1]

  let statusEffect = MdStatusEffect(`type`: mainStatus.`type`, value: value.float)
  applyStatus(db, character, originalChar, statusEffect)


proc applyGearStats(db: DbConn, character: var Character, originalChar: Character, gear: Gear, mdGear: MdGear) =
  applyMainStatus(db, character, originalChar, mdGear)

  if gear.subStatus1Id.isSome():
    applyGearSubstat(db, character, originalChar, gear.subStatus1Id.get())

  if gear.subStatus2Id.isSome():
    applyGearSubstat(db, character, originalChar, gear.subStatus2Id.get())

  if gear.subStatus3Id.isSome():
    applyGearSubstat(db, character, originalChar, gear.subStatus3Id.get())


proc gearsPassesSetRequirements(gears: openArray[MdGear], gearSet: GearSet): bool =
  result = gears.countIt(intToEnum(it.gearTypeId, GearType) == gearSet.gearType) >= setRequiredCount


proc applySetEffect(db: DbConn, character: var Character, originalChar: Character, gears: openArray[MdGear]) =
  let gearSets = [attackerGearSet, defenderGearSet, fortressGearSet, healerGearSet, tricksterGearSet]

  for gearSet in gearSets:
    if gearsPassesSetRequirements(gears, gearSet):
      applyStatus(db, character, originalChar, gearSet.statusEffect)
      break


proc applyGearStats(db: DbConn, character: var Character) =
  let originalChar = character

  let gear1 = character.gearSlot1.map(proc (gearSlot: int): Gear = getGear(db, gearSlot))
  let gear2 = character.gearSlot2.map(proc (gearSlot: int): Gear = getGear(db, gearSlot))
  let gear3 = character.gearSlot3.map(proc (gearSlot: int): Gear = getGear(db, gearSlot))

  var gears = newSeq[MdGear]()

  if gear1.isSome():
    let mdGear1 = getMdGear(db, gear1.get().gearId)
    gears.add(mdGear1)
    applyGearStats(db, character, originalChar, gear1.get(), mdGear1)

  if gear2.isSome():
    let mdGear2 = getMdGear(db, gear2.get().gearId)
    gears.add(mdGear2)
    applyGearStats(db, character, originalChar, gear2.get(), mdGear2)

  if gear3.isSome():
    let mdGear3 = getMdGear(db, gear3.get().gearId)
    gears.add(mdGear3)
    applyGearStats(db, character, originalChar, gear3.get(), mdGear3)

  applySetEffect(db, character, originalChar, gears)


proc getCharacter*(db: DbConn, characterId: int): Character =
  let row = db.getRow(sql"""
    SELECT characters.characterId, exp, hp, receivedAt, characterOwnershipType,
           characterCostumeId, limitBreak, gearSlot1, gearSlot2, gearSlot3,
           trainingScoreLevelScore, trainingScoreRankScore
    FROM characters LEFT JOIN characterLimitBreaks
    ON characters.characterId = characterLimitBreaks.characterId
    WHERE characters.characterId = ?
  """, characterId)

  if row[0] == "":
    raise newException(SembaError, "Couldn't find character for characterId=" & $characterId)

  let mdChar = getMdCharacter(db, characterId)

  let exp = parseInt(row[1])
  
  let mdCharacterLevel = getMdCharacterLevelFromExp(db, exp)

  result = Character(
    characterId: parseInt(row[0]),
    exp: exp,
    hp: parseInt(row[2]),
    receivedAt: row[3].Timestamp,
    characterOwnershipType: parseInt(row[4]),
    characterCostumeId: some(parseInt(row[5])),
    limitBreak: tryParseInt(row[6]).get(0),
    gearSlot1: tryParseInt(row[7]),
    gearSlot2: tryParseInt(row[8]),
    gearSlot3: tryParseInt(row[9]),
    trainingScoreLevelScore: parseInt(row[10]),
    trainingScoreRankScore: parseInt(row[11]),
    damageTakenRate: charBaseDamageTakenRate,
    attack: ceil(mdChar.baseAttack.float*mdCharacterLevel.statusFactor).int,
    defense: ceil(mdChar.baseDefense.float*mdCharacterLevel.statusFactor).int,
    maxHp: ceil(mdChar.baseHp.float*mdCharacterLevel.statusFactor).int,
    criticalRate: charBaseCriticalRate,
    criticalDamageRate: charBaseCriticalDamageRate,
    movementSpeed: if characterId == saizoCharId: saizoBaseMovementSpeed else: charBaseMovementSpeed,
    damageInflictedRate: charBaseDamageInflictedRate,
    tensionIncreaseRate: charBaseTensionIncreaseRate,
    cpRecastRate: charBaseCpRecastRate,
    spGaugeIncreaseRate: charBaseSpGaugeIncreaseRate,
    attackSpeed: charBaseAttackSpeed,
    abnormalityParamSet: getAbnormalityParamSet(),
    actionPointMax: charBaseActionPointMax,
    actionPointRate: charBaseActionPointRate,
    actionPointConsumption: charBaseActionPointConsumption,
  )

  applyGearStats(db, result)


proc getCharactersWithId*(db: DbConn, ids: openArray[int]): seq[Character] =
  for id in ids:
    let character = getCharacter(db, id)
    result.add(character)


proc getCharactersTypeSafe*(db: DbConn): seq[Character] =
  let charactersRows = db.getAllRows(sql"SELECT characterId FROM characters")

  for characterRow in charactersRows:
    result.add(getCharacter(db, parseInt(characterRow[0])))


proc getCharacterMaxLevel*(db: DbConn): int =
  let status = getUserStatusTypeSafe(db)
  let flowerMarks = status.flowerMark.get(0)

  let flowerMarkLevels = getFlowerMarkLevels(db)

  for flowerMarkLevel in flowerMarkLevels:
    if flowerMarks >= flowerMarkLevel.requiredFlowerMark:
      return flowerMarkLevel.characterMaxLevel

  raise newException(SembaError, "Got to unreachable part in getCharacterMaxLevel")


proc getMdCharacterLevel(db: DbConn, level: int): MdCharacterLevel =
  let row = db.getRow(sql"SELECT exp, statusFactor FROM mdCharacterLevel WHERE level = ?", level)

  if row[0] == "":
    raise newException(SembaError, "Couldn't get MdCharacterLevel for level=" & $level)

  result = MdCharacterLevel(
    level: level,
    exp: parseInt(row[0]),
    statusFactor: parseFloat(row[1]),
  )


proc updateCharacterExp*(db: DbConn, addExp: int, characterId: int, maxExp: int) =
  db.exec(
    sql"UPDATE characters SET exp = min(CAST(? as INTEGER), exp + ?) WHERE characterId = ?",
    maxExp, addExp, characterId
  )


proc getCharacterMaxExp*(db: DbConn): int =
  let charMaxLevel = getCharacterMaxLevel(db)
  let mdCharLevel = getMdCharacterLevel(db, charMaxLevel)
  return mdCharLevel.exp


proc updateCharacterExps*(db: DbConn, characterExps: openArray[CharacterExp]) =
  let maxExp = getCharacterMaxExp(db)

  for characterExp in characterExps:
    updateCharacterExp(db, characterExp.dropExp, characterExp.characterId, maxExp)


proc getCharacterCostumes*(db: DbConn): seq[JsonNode] =
  let characterCostumesRows = db.getAllRows(sql"""
    SELECT characterCostumeId, receivedAt
    FROM characterCostumes
  """)

  for characterCostumeRow in characterCostumesRows:
    let characterCostumeId = parseInt(characterCostumeRow[0])
    let receivedAt = characterCostumeRow[1]

    result.add(%*{
      "characterCostumeId": characterCostumeId,
      "receivedAt": receivedAt
    })


# Set the characters hp to max in the database and return the characters that changed hp.
proc healCharactersTypeSafe*(db: DbConn): seq[Character] =
  var characters = getCharactersTypeSafe(db)

  for character in characters.mitems():
    if character.hp != character.maxHp:
      setCharacterHp(db, character.characterId, character.maxHp)
      character.hp = character.maxHp
      result.add(character)


proc addCharacterCostume*(db: DbConn, characterCostume: CharacterCostume) =
  db.exec(sql"""
    INSERT INTO characterCostumes (characterCostumeId, receivedAt) VALUES (?, ?)
    ON CONFLICT (characterCostumeId) DO
    UPDATE SET receivedAt = excluded.receivedAt
  """, characterCostume.characterCostumeId, characterCostume.receivedAt)


proc updateCharacterCostumes*(db: DbConn, characterCostumes: seq[CharacterCostume]) =
  for characterCostume in characterCostumes:
    addCharacterCostume(db, characterCostume)


proc deleteGuestCharacters*(db: DbConn, characterIds: openArray[int]) =
  for characterId in characterIds:
    db.exec(sql"""
      DELETE FROM characters WHERE characterId = ? AND characterOwnershipType = ?
    """, characterId, charOwnershipGuest.int)


proc updateCharacterGear*(
  db: DbConn, charId: int, gearSlot1: Option[int], gearSlot2: Option[int], gearSlot3: Option[int]
) =
  db.exec(sql"UPDATE characters SET gearSlot1 = ? WHERE characterId = ?", optionToSqlArg(gearSlot1), charId)
  db.exec(sql"UPDATE characters SET gearSlot2 = ? WHERE characterId = ?", optionToSqlArg(gearSlot2), charId)
  db.exec(sql"UPDATE characters SET gearSlot3 = ? WHERE characterId = ?", optionToSqlArg(gearSlot3), charId)


proc getBalancedGears*(db: DbConn): seq[MdGear] =
  let maxLevel = getCharacterMaxLevel(db)

  case maxLevel:
  of 10:
    result = getMdGears(db, "grade 1 - Shinagawa")
  of 15:
    result = getMdGears(db, "grade 2 - Shinagawa")
  else:
    result = getMdGears(db, "grade 3 - Shinagawa") # FIXME: minato, chiyoda, fv???


proc knockOutCharacters*(db: DbConn, charIds: openArray[int]) =
  db.exec(sql("UPDATE characters SET hp=0 WHERE characterId IN " & sqlIntTuple(charIds)))