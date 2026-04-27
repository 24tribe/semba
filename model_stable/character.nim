import std/json
import std/strutils
import std/math
import std/options
import std/sequtils

import ../db_connector/db_sqlite

import ../semba_error
import ../extsqlite
import user
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
  exp*: Option[int]
  limitBreak*: Option[int]
  hp*: Option[int]
  attack*: Option[int]
  defense*: Option[int]
  maxHp*: Option[int]
  gearSlot1*: Option[int]
  gearSlot2*: Option[int]
  gearSlot3*: Option[int]
  receivedAt*: Timestamp
  characterOwnershipType*: Option[int]
  dishId*: Option[int]
  dishEffectCount*: Option[int]
  dishEffectExpiredAt*: Option[Timestamp]
  rank*: Option[int]
  criticalRate*: Option[float]
  criticalDamageRate*: Option[float]
  supportPowerRate*: Option[int]
  movementSpeed*: Option[float]
  powerRate*: Option[float]
  dodgeSpeed*: Option[float]
  damageInflictedRate*: Option[float]
  tensionIncreaseRate*: Option[float]
  cpRecastRate*: Option[float]
  recoveryGivenRate*: Option[float]
  spGaugeIncreaseRate*: Option[float]
  attackSpeed*: Option[float]
  characterCostumeId*: Option[int]
  characterSkillPanel1Level*: Option[int]
  characterSkillPanel2Level*: Option[int]
  characterSkillPanel3Level*: Option[int]
  characterSkillPanel4Level*: Option[int]
  characterSkillPanel5Level*: Option[int]
  abnormalityParamSet*: JsonNode # FIXME: use AbnormalityParamSet
  trainingScore*: Option[int]
  trainingScoreLevelScore*: Option[int]
  trainingScoreRankScore*: Option[int]
  actionPointMax*: Option[int]
  actionPointRate*: Option[float]
  actionPointConsumption*: Option[float]
  damageTakenRate*: Option[float]

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

  let gearSlot1 = to(character.getOrDefault("gearSlot1"), Option[int])
  let gearSlot2 = to(character.getOrDefault("gearSlot2"), Option[int])
  let gearSlot3 = to(character.getOrDefault("gearSlot3"), Option[int])

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
    let damageTakenRate = character.damageTakenRate.get(0)
    character.damageTakenRate = some(damageTakenRate - statusEffect.value)
  of statusEffectMaximumStamina:
    let actionPointMax = character.actionPointMax.get(0)
    character.actionPointMax = some(actionPointMax + statusEffect.value.int)
  of statusEffectMovingSpeed:
    let origMovementSpeed = originalChar.movementSpeed.get(0)
    let movementSpeed = character.movementSpeed.get(0)
    character.movementSpeed = some(movementSpeed + (statusEffect.value - 1.0)*origMovementSpeed)
  of statusEffectDefense:
    let origDef = originalChar.defense.get(0).float
    let def = character.defense.get(0).float
    character.defense = some(ceil(def + (statusEffect.value - 1.0)*origDef).int)
  of statusEffectAttack:
    let origAttack = originalChar.attack.get(0).float
    let attack = character.attack.get(0).float
    let newAttack = ceil(attack + origAttack*(statusEffect.value - 1.0)).int
    character.attack = some(newAttack)
  of statusEffectMaximumHP:
    let origMaxHp = originalChar.maxHp.get(0).float
    let maxHp = character.maxHp.get(0).float
    let newMaxHp = ceil(maxHp + origMaxHp*(statusEffect.value - 1.0)).int
    character.maxHp = some(newMaxHp)
  of statusEffectCriticalRate:
    character.criticalRate = character.criticalRate.map(proc (cr: float): float =
      cr + statusEffect.value
    )
  of statusEffectCriticalDMGMultiplier:
    character.criticalDamageRate = character.criticalDamageRate.map(proc (cdmg: float): float =
      cdmg + statusEffect.value
    )
  of statusEffectFlatAtk:
    character.attack = character.attack.map(proc (atk: int): int = atk + statusEffect.value.int)
  of statusEffectFlatDef:
    character.defense = character.defense.map(proc (def: int): int = def + statusEffect.value.int)
  of statusEffectFlatHp:
    character.maxHp = some(character.maxHp.get(0) + statusEffect.value.int)
  of statusEffectSupport:
    character.supportPowerRate = some(character.supportPowerRate.get(0) + ceil(statusEffect.value).int)
  of statusEffectGrantRecoveryEffect:
    character.recoveryGivenRate = some(character.recoveryGivenRate.get(0) + statusEffect.value)



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
  result = gears.countIt(it.gearTypeId.GearType == gearSet.gearType) >= setRequiredCount


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

  let exp = parseInt(row[1])

  let mdChar = getMdCharacter(db, characterId)
  
  let mdCharacterLevel = getMdCharacterLevelFromExp(db, exp)

  let attack = ceil(mdChar.baseAttack.float*mdCharacterLevel.statusFactor).int
  let defense = ceil(mdChar.baseDefense.float*mdCharacterLevel.statusFactor).int
  let maxHp = ceil(mdChar.baseHp.float*mdCharacterLevel.statusFactor).int

  result = Character(
    characterId: parseInt(row[0]),
    exp: some(exp),
    hp: some(parseInt(row[2])),
    receivedAt: row[3].Timestamp,
    characterOwnershipType: some(parseInt(row[4])),
    characterCostumeId: some(parseInt(row[5])),
    limitBreak: tryParseInt(row[6]),
    gearSlot1: tryParseInt(row[7]),
    gearSlot2: tryParseInt(row[8]),
    gearSlot3: tryParseInt(row[9]),
    trainingScoreLevelScore: tryParseInt(row[10]),
    trainingScoreRankScore: tryParseInt(row[11]),
    damageTakenRate: some(charBaseDamageTakenRate),
    attack: some(attack),
    defense: some(defense),
    maxHp: some(maxHp),
    criticalRate: some(charBaseCriticalRate),
    criticalDamageRate: some(charBaseCriticalDamageRate),
    movementSpeed: some(if characterId == saizoCharId: saizoBaseMovementSpeed else: charBaseMovementSpeed),
    damageInflictedRate: some(charBaseDamageInflictedRate),
    tensionIncreaseRate: some(charBaseTensionIncreaseRate),
    cpRecastRate: some(charBaseCpRecastRate),
    spGaugeIncreaseRate: some(charBaseSpGaugeIncreaseRate),
    attackSpeed: some(charBaseAttackSpeed),
    abnormalityParamSet: getAbnormalityParamSet(),
    actionPointMax: some(charBaseActionPointMax),
    actionPointRate: some(charBaseActionPointRate),
    actionPointConsumption: some(charBaseActionPointConsumption),
  )

  applyGearStats(db, result)


proc getCharactersWithId*(db: DbConn, ids: openArray[int]): seq[Character] =
  for id in ids:
    let character = getCharacter(db, id)
    result.add(character)


proc updateCharacterPiece*(db: DbConn, characterPiece: JsonNode) =
  let characterId = characterPiece["characterId"].getInt()
  let quantity = characterPiece.getOrDefault("quantity").getInt()

  db.exec(sql"""
    INSERT INTO characterPieces (characterId, quantity) VALUES (?, ?)
    ON CONFLICT (characterId) DO
    UPDATE SET quantity = excluded.quantity
  """, characterId, quantity)


#[
Add one character piece to the db, returns the changed count of character pieces
]#
proc addCharacterPiece*(db: DbConn, characterId: int): int =
  let row = db.getRow(sql"SELECT quantity FROM characterPieces")

  if row[0] == "":
    result = 1
  else:
    result = parseInt(row[0]) + 1

  updateCharacterPiece(db, %*{"characterId": characterId, "quantity": result})


proc getCharacterPiece*(db: DbConn, characterId: int): JsonNode =
  let row = db.getRow(
    sql"SELECT characterId, quantity FROM characterPieces WHERE characterId = ?", characterId
  )

  let quantity = if row[0] == "": 0 else: parseInt(row[1])

  result = %*{
    "characterId": characterId,
    "quantity": quantity,
  }


proc getCharacterPieces*(db: DbConn): seq[JsonNode] =
  let rows = db.getAllRows(sql"SELECT characterId, quantity FROM characterPieces")
  for row in rows:
    let characterId = parseInt(row[0])
    let quantity = parseInt(row[1])

    result.add(%*{
      "characterId": characterId,
      "quantity": quantity
    })
  

proc getCharacters*(db: DbConn): seq[JsonNode] {.deprecated: "use getCharactersTypeSafe instead".} =
  let charactersRows = db.getAllRows(sql"SELECT characterId FROM characters")

  for characterRow in charactersRows:   
    result.add(%*getCharacter(db, parseInt(characterRow[0])))


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


proc updateCharacterExp*(db: DbConn, addExp: int, character: Character, maxExp: int) =
  let finalExp = min(character.exp.get(0) + addExp, maxExp)
  db.exec(sql"UPDATE characters SET exp = ? WHERE characterId = ?", finalExp, character.characterId)


proc getCharacterMaxExp*(db: DbConn): int =
  let charMaxLevel = getCharacterMaxLevel(db)
  let mdCharLevel = getMdCharacterLevel(db, charMaxLevel)
  return mdCharLevel.exp


proc updateCharacterExps*(db: DbConn, characterExps: seq[JsonNode], characters: seq[Character]) =
  let maxExp = getCharacterMaxExp(db)

  for character in characters:
    for characterExp in characterExps:
      if characterExp.getOrDefault("characterId").getInt(0) == character.characterId:
        updateCharacterExp(db, characterExp["dropExp"].getInt(), character, maxExp)
        break


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


#[
Set the characters hp to max in the database and return the characters with
changed hp.
]#
proc healCharacters*(db: DbConn): seq[JsonNode] {.deprecated: "use healCharactersTypeSafe instead".} =
  let characters = getCharacters(db)

  for character in characters:
    let characterId = character["characterId"].getInt()
    let hp = character["hp"].getInt()
    let maxHp = character["maxHp"].getInt()
    if hp != maxHp:
      setCharacterHp(db, characterId, maxHp)
      character["hp"] = %*maxHp
      result.add(character)


proc healCharactersTypeSafe*(db: DbConn): seq[Character] =
  var characters = getCharactersTypeSafe(db)

  for character in characters.mitems():
    if character.hp.get(0) != character.maxHp.get(0):
      setCharacterHp(db, character.characterId, character.maxHp.get(0))
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