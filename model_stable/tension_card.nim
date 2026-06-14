import std/json
import std/strutils
import std/options
import std/sequtils

import ../db_connector/db_sqlite

import ../extsqlite
import ../semba_error
import ../protojson
import timestamp
import status


type AbilityEfficacy* = object
  id*: int
  abilityEfficacyGroupId*: Option[int]
  coolTimeMillisecond*: int
  effectCoolTimeMillisecond*: int
  activeTimeMillisecond*: int
  efficacyType*: int
  probability*: int
  activateConditions*: string
  deactivateConditions*: string
  sustainConditions*: string
  targetConditions*: string
  fValues*: seq[float]
  values*: seq[int]
  uiViewPriority*: int
  effectValueSteps*: seq[float]
  targetType*: int
  maximumActiveTimeMillisecond*: Option[int]


type TensionCard* = object
  tensionCardId*: int
  entityId*: int
  exp*: int
  limitBreak*: int
  receivedAt*: Timestamp
  maxLevel*: int
  abilityEfficacies*: seq[AbilityEfficacy]
  trainingScoreLevelScore*: int
  isLocked*: bool


proc getTensionCards*(db: DbConn, filterIds: openArray[int] = @[]): seq[TensionCard] =
  let whereSql =
    if filterIds.len > 0:
      "WHERE tensionCardId IN " & sqlIntTuple(filterIds)
    else:
      ""

  db.getAllRows(sql("""
    SELECT
      tensionCardId, receivedAt, maxLevel, abilityEfficacies,
      trainingScoreLevelScore, entityId, isLocked, limitBreak, exp
    FROM tensionCards """ & whereSql
  )).mapIt(TensionCard(
    tensionCardId: parseInt(it[0]),
    receivedAt: it[1].Timestamp,
    maxLevel: parseInt(it[2]),
    abilityEfficacies: protoJsonTo(parseJson(it[3]), seq[AbilityEfficacy]),
    trainingScoreLevelScore: parseInt(it[4]),
    entityId: parseInt(it[5]),
    isLocked: parseInt(it[6]) == 1,
    limitBreak: tryParseInt(it[7]).get(0),
    exp: tryParseInt(it[8]).get(0),
  ))


proc upsertTensionCard*(db: DbConn, tc: TensionCard) =
  db.exec(
    sql"""
      INSERT INTO tensionCards
        (tensionCardId, receivedAt, maxLevel, abilityEfficacies,
        trainingScoreLevelScore, entityId, isLocked, limitBreak, exp)
      VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
      ON CONFLICT (entityId)
      DO UPDATE SET
        tensionCardId = excluded.tensionCardId, receivedAt = excluded.receivedAt,
        maxLevel = excluded.maxLevel, abilityEfficacies = excluded.abilityEfficacies,
        trainingScoreLevelScore = excluded.trainingScoreLevelScore, isLocked = excluded.isLocked,
        limitBreak = excluded.limitBreak, exp = excluded.exp
    """,
    tc.tensionCardId, tc.receivedAt, tc.maxLevel, toProtoJson(tc.abilityEfficacies),
    tc.trainingScoreLevelScore, tc.entityId, if tc.isLocked: 1 else: 0, tc.limitBreak, tc.exp
  )


proc upsertTensionCards*(db: DbConn, tensionCards: openArray[TensionCard]) =
  for tensionCard in tensionCards:
    upsertTensionCard(db, tensionCard)


proc getFormationCards(db: DbConn, formationNumber: int): JsonNode =
  let row = db.getRow(sql"SELECT cards FROM formations WHERE number = ?", formationNumber)

  if row[0] == "":
    raise newException(SembaError, "Couldn't find formation cards for formationNumber=" & $formationNumber)

  result = parseJson(row[0])


proc getEquippedTensionCards*(db: DbConn): seq[TensionCard] =
  let status = getUserStatusTypeSafe(db)
  let formationNumber = status.formationNumber.get(0)
  let cards = getFormationCards(db, formationNumber)

  var tensionCardIds = newSeq[int]()

  let tensionCard1Id = cards.getOrDefault("tensionCard1Id")
  if tensionCard1Id != nil:
    tensionCardIds.add(tensionCard1Id.getInt())

  let tensionCard2Id = cards.getOrDefault("tensionCard2Id")
  if tensionCard2Id != nil:
    tensionCardIds.add(tensionCard2Id.getInt())

  let tensionCard3Id = cards.getOrDefault("tensionCard3Id")
  if tensionCard3Id != nil:
    tensionCardIds.add(tensionCard3Id.getInt())

  let tensionCard4Id = cards.getOrDefault("tensionCard4Id")
  if tensionCard4Id != nil:
    tensionCardIds.add(tensionCard4Id.getInt())

  let tensionCard5Id = cards.getOrDefault("tensionCard5Id")
  if tensionCard5Id != nil:
    tensionCardIds.add(tensionCard5Id.getInt())

  result = getTensionCards(db, tensionCardIds)


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


proc getAbilityEfficacies(db: DbConn, tensionCardId: int): seq[AbilityEfficacy] =
  db.getAllRows(sql("""
    SELECT abilityEfficacyId, abilityEfficacyGroupId, coolTimeMillisecond,
          effectCoolTimeMillisecond, activeTimeMillisecond, efficacyType, probability,
          activateConditions, deactivateConditions, sustainConditions, targetConditions,
          fValues, values_, uiViewPriority, effectValueSteps, targetType
    FROM mdAbilityEfficacy WHERE abilityEfficacyId IN """ & sqlIntTuple(getAbilityEfficacyIds(db, tensionCardId))
  )).mapIt(AbilityEfficacy(
    id: parseInt(it[0]),
    abilityEfficacyGroupId: if parseInt(it[1]) != 0: some(parseInt(it[1])) else: none(int),
    coolTimeMillisecond: parseInt(it[2]),
    effectCoolTimeMillisecond: parseInt(it[3]),
    activeTimeMillisecond: parseInt(it[4]),
    efficacyType: parseInt(it[5]),
    probability: parseInt(it[6]),
    activateConditions: it[7],
    deactivateConditions: it[8],
    sustainConditions: it[9],
    targetConditions: it[10],
    fValues: protoJsonTo(parseJson(it[11]), seq[float]),
    values: protoJsonTo(parseJson(it[12]), seq[int]),
    uiViewPriority: parseInt(it[13]),
    effectValueSteps: protoJsonTo(parseJson(it[14]), seq[float]),
    targetType: parseInt(it[15]),
  ))


proc getNewTensionCard*(db: DbConn, entityId: int, tensionCardId: int): TensionCard =
  TensionCard(
    abilityEfficacies: getAbilityEfficacies(db, tensionCardId),
    entityId: entityId,
    isLocked: false,
    maxLevel: 10,
    receivedAt: getTimestampNow(),
    tensionCardId: tensionCardId,
    trainingScoreLevelScore: 2,
  )


proc deleteTensionCards*(db: DbConn, entityIds: openArray[int]) =
  db.exec(sql("DELETE FROM tensionCards WHERE entityId IN " & sqlIntTuple(entityIds)))