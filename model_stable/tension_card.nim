import std/json
import std/strutils

import ../db_connector/db_sqlite

import ../semba_error
import user
import timestamp


const dbTensionCardsFields = """
  tensionCardId, receivedAt, maxLevel, abilityEfficacies,
  trainingScoreLevelScore, entityId, isLocked
"""

const dbTensionCardsFieldsJoin = """
  tensionCardId, receivedAt, maxLevel, abilityEfficacies,
  trainingScoreLevelScore, tensionCards.entityId, isLocked, limitBreak
"""

const selectTensionCardSql = """
  SELECT """ & dbTensionCardsFieldsJoin & """
  FROM tensionCards FULL JOIN tensionCardLimitBreaks
  ON tensionCards.entityId = tensionCardLimitBreaks.entityId
"""


proc updateTensionCardLimitBreak*(db: DbConn, entityId: int, limitBreak: int) =
  db.exec(sql"""
    INSERT INTO tensionCardLimitBreaks (entityId, limitBreak) VALUES (?, ?)
    ON CONFLICT (entityId) DO
    UPDATE SET limitBreak = excluded.limitBreak
  """, entityId, limitBreak)


proc parseTensionCardRow(tensionCardRow: Row): JsonNode =
  let tensionCardId = parseInt(tensionCardRow[0])
  let receivedAt = tensionCardRow[1]
  let maxLevel = parseInt(tensionCardRow[2])
  let abilityEfficacies = parseJson(tensionCardRow[3])
  let trainingScoreLevelScore = parseInt(tensionCardRow[4])
  let entityId = parseInt(tensionCardRow[5])
  let isLocked = if parseInt(tensionCardRow[6]) == 1: true else: false
  let limitBreak = if tensionCardRow[7] == "": 0 else: parseInt(tensionCardRow[7])

  return %*{
    "tensionCardId": tensionCardId,
    "receivedAt": receivedAt,
    "maxLevel": maxLevel,
    "abilityEfficacies": abilityEfficacies,
    "trainingScoreLevelScore": trainingScoreLevelScore,
    "entityId": entityId,
    "isLocked": isLocked,
    "limitBreak": limitBreak
  }

proc getTensionCards*(db: DbConn): seq[JsonNode] =
  let tensionCardsRows = db.getAllRows(sql(selectTensionCardSql))

  for tensionCardRow in tensionCardsRows:
    result.add(parseTensionCardRow(tensionCardRow))

proc getTensionCard*(db: DbConn, entityId: int): JsonNode =
  let row = db.getRow(sql(selectTensionCardSql & " WHERE tensionCards.entityId = ?"), entityId)

  if row[0] == "":
    raise newException(SembaError, "Couldn't find tensionCard for entityId=" & $entityId)

  result = parseTensionCardRow(row)

proc addTensionCard*(db: DbConn, tensionCard: JsonNode) =
  let tensionCardId = tensionCard["tensionCardId"].getInt()
  let receivedAt = tensionCard["receivedAt"].getStr()
  let maxLevel = tensionCard["maxLevel"].getInt()
  let abilityEfficacies = $tensionCard["abilityEfficacies"]
  let trainingScoreLevelScore = tensionCard["trainingScoreLevelScore"].getInt()
  let entityId = tensionCard["entityId"].getInt()
  let isLocked = if tensionCard["isLocked"].getBool(): 1 else: 0
  let limitBreak = tensionCard.getOrDefault("limitBreak").getInt()

  db.exec(
    sql("INSERT INTO tensionCards (" & dbTensionCardsFields & """)
    VALUES (?, ?, ?, ?, ?, ?, ?)
    ON CONFLICT (entityId) DO
    UPDATE SET
      tensionCardId = excluded.tensionCardId,
      receivedAt = excluded.receivedAt,
      maxLevel = excluded.maxLevel,
      abilityEfficacies = excluded.abilityEfficacies,
      trainingScoreLevelScore = excluded.trainingScoreLevelScore,
      isLocked = excluded.isLocked
    """),
    tensionCardId, receivedAt, maxLevel, abilityEfficacies,
    trainingScoreLevelScore, entityId, isLocked
  )

  updateTensionCardLimitBreak(db, entityId, limitBreak)


proc updateTensionCards*(db: DbConn, tensionCards: seq[JsonNode]) =
  for tc in tensionCards:
    addTensionCard(db, tc)


proc getFormationCards(db: DbConn, formationNumber: int): JsonNode =
  let row = db.getRow(sql"SELECT cards FROM formations WHERE number = ?", formationNumber)

  if row[0] == "":
    raise newException(SembaError, "Couldn't find formation cards for formationNumber=" & $formationNumber)

  result = parseJson(row[0])

proc getEquippedTensionCards*(db: DbConn): seq[JsonNode] =
  let status = getUserStatus(db)
  let formationNumber = status.getOrDefault("formationNumber").getInt()
  let cards = getFormationCards(db, formationNumber)

  let tensionCard1Id = cards.getOrDefault("tensionCard1Id")
  if tensionCard1Id != nil:
    result.add(getTensionCard(db, tensionCard1Id.getInt()))

  let tensionCard2Id = cards.getOrDefault("tensionCard2Id")
  if tensionCard2Id != nil:
    result.add(getTensionCard(db, tensionCard2Id.getInt()))

  let tensionCard3Id = cards.getOrDefault("tensionCard3Id")
  if tensionCard3Id != nil:
    result.add(getTensionCard(db, tensionCard3Id.getInt()))

  let tensionCard4Id = cards.getOrDefault("tensionCard4Id")
  if tensionCard4Id != nil:
    result.add(getTensionCard(db, tensionCard4Id.getInt()))

  let tensionCard5Id = cards.getOrDefault("tensionCard5Id")
  if tensionCard5Id != nil:
    result.add(getTensionCard(db, tensionCard5Id.getInt()))


proc getAbilityEfficacyIds(db: DbConn, tensionCardId: int): seq[int] =
  let row = db.getRow(sql"""
    SELECT mdTensionCard.tensionCardId, mdAbilityTensionCard.abilities
    FROM mdAbilityTensionCard
    INNER JOIN mdTensionCard
    ON mdAbilityTensionCard.abilityTensionCardId = mdTensionCard.abilityTensionCardId
    WHERE mdTensionCard.tensionCardId = ?
  """, tensionCardId)

  if row[0] == "":
    raise newException(SembaError, "Couldn't find abilities for tensionCardId=" & $tensionCardId)

  for abilityEfficacy in parseJson(row[1]):
    let abilityEfficacyId = abilityEfficacy["ability_efficacy_id"].getInt()
    result.add(abilityEfficacyId)


proc parseAbilityEfficacyRow(row: Row): JsonNode =
  let abilityEfficacyId = parseInt(row[0])
  let abilityEfficacyGroupId = parseInt(row[1])
  let coolTimeMillisecond = parseInt(row[2])
  let effectCoolTimeMillisecond = parseInt(row[3])
  let activeTimeMillisecond = parseInt(row[4])
  let efficacyType = parseInt(row[5])
  let probability = parseInt(row[6])
  let activateConditions = row[7]
  let deactivateConditions = row[8]
  let sustainConditions = row[9]
  let targetConditions = row[10]
  let fValues = parseJson(row[11])
  let values = parseJson(row[12])
  let uiViewPriority = parseInt(row[13])
  let effectValueSteps = parseJson(row[14])
  let targetType = parseInt(row[15])

  result = %*{
    "id": abilityEfficacyId,
    "coolTimeMillisecond": coolTimeMillisecond,
    "effectCoolTimeMillisecond": effectCoolTimeMillisecond,
    "activeTimeMillisecond": activeTimeMillisecond,
    "efficacyType": efficacyType,
    "probability": probability,
    "activateConditions": activateConditions,
    "deactivateConditions": deactivateConditions,
    "sustainConditions": sustainConditions,
    "targetConditions": targetConditions,
    "fValues": fValues,
    "values": values,
    "uiViewPriority": uiViewPriority,
    "effectValueSteps": effectValueSteps,
    "targetType": targetType,
  }

  if abilityEfficacyGroupId != 0:
    result["abilityEfficacyGroupId"] = %*abilityEfficacyGroupId


proc getAbilityEfficacies(db: DbConn, tensionCardId: int): seq[JsonNode] =
  var whereBody = ""

  for abilityEfficacyId in getAbilityEfficacyIds(db, tensionCardId):
    if whereBody == "":
      whereBody = "abilityEfficacyId=" & $abilityEfficacyId
    else:
      whereBody &= " OR abilityEfficacyId=" & $abilityEfficacyId

  if whereBody != "":
    let rows = db.getAllRows(sql("""
      SELECT abilityEfficacyId, abilityEfficacyGroupId, coolTimeMillisecond,
            effectCoolTimeMillisecond, activeTimeMillisecond, efficacyType, probability,
            activateConditions, deactivateConditions, sustainConditions, targetConditions,
            fValues, values_, uiViewPriority, effectValueSteps, targetType
      FROM mdAbilityEfficacy WHERE """ & whereBody)
    )

    for row in rows:
      let abilityEfficacy = parseAbilityEfficacyRow(row)
      result.add(abilityEfficacy)


proc getNewTensionCard*(db: DbConn, entityId: int, tensionCardId: int): JsonNode =
  let receivedAt = getDateNow()
  let abilityEfficacies = getAbilityEfficacies(db, tensionCardId)

  result = %*{
    "abilityEfficacies": abilityEfficacies,
    "entityId": entityId,
    "isLocked": false,
    "maxLevel": 10,
    "receivedAt": receivedAt,
    "tensionCardId": tensionCardId,
    "trainingScoreLevelScore": 2,
  }