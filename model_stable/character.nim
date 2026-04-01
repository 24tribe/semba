import std/json
import std/strutils
import std/math
import std/options

import ../db_connector/db_sqlite

import ../semba_error
import ../extsqlite
import user
import mission
import battle
import timestamp


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
  abnormalityParamSet*: Option[JsonNode] # FIXME: use AbnormalityParamSet
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


const dbCharacterFields* = """
  characters.characterId, exp, hp, attack, defense, maxHp, receivedAt, characterOwnershipType,
  criticalRate, criticalDamageRate, movementSpeed, damageInflictedRate, tensionIncreaseRate,
  cpRecastRate, spGaugeIncreaseRate, attackSpeed, characterCostumeId, abnormalityParamSet,
  trainingScoreLevelScore, trainingScoreRankScore, actionPointMax,
  actionPointRate, actionPointConsumption, damageTakenRate, limitBreak, gearSlot1, gearSlot2, gearSlot3
"""

const selectCharacterSql = """
  SELECT """ & dbCharacterFields & """
  FROM characters LEFT JOIN characterLimitBreaks
  ON characters.characterId = characterLimitBreaks.characterId
"""


proc costumeIdToCharacterId*(costumeId: int): int =
  return (costumeId div 1000)*100 + 1


proc characterIdToCostumeId*(characterId: int): int = (characterId div 100)*1000 + 1


proc setCharacterHp*(db: DbConn, characterId: int, hp: int) =
  db.exec(sql"UPDATE characters SET hp = ? WHERE characterId = ?", hp, characterId)


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


proc parseCharacterRow*(characterRow: Row): JsonNode =
  let characterId = parseInt(characterRow[0])
  let exp = parseInt(characterRow[1])
  let hp = parseInt(characterRow[2])
  let attack = parseInt(characterRow[3])
  let defense = parseInt(characterRow[4])
  let maxHp = parseInt(characterRow[5])
  let receivedAt = characterRow[6]
  let characterOwnershipType = parseInt(characterRow[7])
  let criticalRate = parseInt(characterRow[8])
  let criticalDamageRate = parseInt(characterRow[9])
  let movementSpeed = parseInt(characterRow[10])
  let damageInflictedRate = parseInt(characterRow[11])
  let tensionIncreaseRate = parseInt(characterRow[12])
  let cpRecastRate = parseInt(characterRow[13])
  let spGaugeIncreaseRate = parseInt(characterRow[14])
  let attackSpeed = parseInt(characterRow[15])
  let characterCostumeId = parseInt(characterRow[16])
  let abnormalityParamSet = parseJson(characterRow[17])
  let trainingScoreLevelScore = parseInt(characterRow[18])
  let trainingScoreRankScore = parseInt(characterRow[19])
  let actionPointMax = parseInt(characterRow[20])
  let actionPointRate = parseInt(characterRow[21])
  let actionPointConsumption = parseInt(characterRow[22])
  let damageTakenRate = parseInt(characterRow[23])
  let limitBreak = if characterRow[24] == "": 0 else: parseInt(characterRow[24])
  let gearSlot1 = if characterRow[25] == "": none(int) else: some(parseInt(characterRow[25]))
  let gearSlot2 = if characterRow[26] == "": none(int) else: some(parseInt(characterRow[26]))
  let gearSlot3 = if characterRow[27] == "": none(int) else: some(parseInt(characterRow[27]))

  return %*{
    "characterId": characterId,
    "exp": exp,
    "hp": hp,
    "attack": attack,
    "defense": defense,
    "maxHp": maxHp,
    "receivedAt": receivedAt,
    "characterOwnershipType": characterOwnershipType,
    "criticalRate": criticalRate,
    "criticalDamageRate": criticalDamageRate,
    "movementSpeed": movementSpeed,
    "damageInflictedRate": damageInflictedRate,
    "tensionIncreaseRate": tensionIncreaseRate,
    "cpRecastRate": cpRecastRate,
    "spGaugeIncreaseRate": spGaugeIncreaseRate,
    "attackSpeed": attackSpeed,
    "characterCostumeId": characterCostumeId,
    "abnormalityParamSet": abnormalityParamSet,
    "trainingScoreLevelScore": trainingScoreLevelScore,
    "trainingScoreRankScore": trainingScoreRankScore,
    "actionPointMax": actionPointMax,
    "actionPointRate": actionPointRate,
    "actionPointConsumption": actionPointConsumption,
    "damageTakenRate": damageTakenRate,
    "limitBreak": limitBreak,
    "gearSlot1": gearSlot1,
    "gearSlot2": gearSlot2,
    "gearSlot3": gearSlot3,
  }


proc getCharacter*(db: DbConn, characterId: int): JsonNode =
  let row = db.getRow(sql(selectCharacterSql & " WHERE characters.characterId = ?"), characterId)

  if row[0] == "":
    raise newException(SembaError, "Couldn't find character for characterId=" & $characterId)

  result = parseCharacterRow(row)


proc getCharactersWithId*(db: DbConn, ids: seq[int]): seq[JsonNode] =
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
  

proc getCharacters*(db: DbConn): seq[JsonNode] =
  let charactersRows = db.getAllRows(sql(selectCharacterSql))

  for characterRow in charactersRows:   
    result.add(parseCharacterRow(characterRow))


proc getCharacterMaxLevel*(db: DbConn): int =
  let status = getUserStatus(db)
  let flowerMarks = status.getOrDefault("flowerMark").getInt()

  let flowerMarkLevels = getFlowerMarkLevels(db)

  for flowerMarkLevel in flowerMarkLevels:
    if flowerMarks >= flowerMarkLevel.requiredFlowerMark:
      return flowerMarkLevel.characterMaxLevel

  raise newException(SembaError, "Got to unreachable part in getCharacterMaxLevel")


proc getLevelExp(db: DbConn, level: int): int =
  let row = db.getRow(sql"SELECT exp FROM mdCharacterLevel WHERE level = ?", level)
  result = parseInt(row[0])


proc updateCharacterExps*(db: DbConn, characterExps: seq[JsonNode], characters: seq[JsonNode]) =
  let charMaxLevel = getCharacterMaxLevel(db)
  let maxExp = getLevelExp(db, charMaxLevel)

  for character in characters:
    let characterId = character["characterId"].getInt()
    let exp = character.getOrDefault("exp").getInt()
    for characterExp in characterExps:
      if characterExp["characterId"] == character["characterId"]:
        let sum = exp + characterExp["dropExp"].getInt()
        let finalExp = if sum <= maxExp: sum else: maxExp
        character["exp"] = %*finalExp
        db.exec(sql"UPDATE characters SET exp = ? WHERE characterId = ?", finalExp, characterId)
        break


proc getCharacterExps*(db: DbConn, characterIds: seq[int], battleEntryIds: seq[int]): seq[JsonNode] =
  let dropExp = round(getBattleExp(db, battleEntryIds)).int

  for characterId in characterIds:
    result.add(%*{
      "characterId": characterId,
      "exp": dropExp,
      "dropExp": dropExp
    })


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
proc healCharacters*(db: DbConn): seq[JsonNode] =
  let characters = getCharacters(db)

  for character in characters:
    let characterId = character["characterId"].getInt()
    let hp = character["hp"].getInt()
    let maxHp = character["maxHp"].getInt()
    if hp != maxHp:
      setCharacterHp(db, characterId, maxHp)
      character["hp"] = %*maxHp
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