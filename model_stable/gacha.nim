import std/json
import std/strutils
import std/random
import std/tables
import std/options

import ../db_connector/db_sqlite

import character
import character_piece
import timestamp
import reward
import entity
import tension_card
import ../semba_error
import ../extsqlite


type GachaNotification* = object
  latestGachaStartAt*: Option[Timestamp]
  executableGachaIds*: Option[seq[int]]

type GachaButton* = enum
  gachaButtonSingle = 1,
  gachaButtonTen = 2

type GachaCardType* = enum 
  gachaCardCharacter = 4,
  gachaCardTensionCard = 9

type GachaRateSetId* = enum
  normalGachaRateSetId = 101,
  promisedGachaRateSetId = 102,
  guaranteedGachaRateSetId = 103

type GachaId* = enum
  gachaIdTutorial = 101


const tutorialGachaSql = slurp("../tutorialGacha.sql")
const tutorialSkipGachaSql = slurp("../tutorialSkipGacha.sql")


proc getGachaNotification*(db: DbConn): JsonNode =
  let rows = db.getAllRows(sql"SELECT gachaId FROM gachas")
  var ids = newSeq[int]()

  for row in rows:
    ids.add(parseInt(row[0]))

  return %*{
    "executableGachaIds": ids
  }


proc getGachaCharacterIds(db: DbConn): seq[int] =
  let rows = db.getAllRows(sql"SELECT characterId FROM gachaCharacterIds")
  for row in rows:
    result.add(parseInt(row[0]))


proc getGachaCharacters*(db: DbConn): seq[JsonNode] =
  let characterIds = getGachaCharacterIds(db)

  for characterId in characterIds:
    let costumeId = characterIdToCostumeId(characterId)
    result.add(%*{
      "characterId": characterId,
      "characterCostumeId": costumeId,
      "exp": 4490000,
      "hp": 1662, # FIXME: correct hp
      "attack": 406, # FIXME: correct attack
      "defense": 282, # FIXME: correct defense
      "maxHp": 1662, # FIXME: corrent maxHp
      "receivedAt": getDateNow(),
      "characterOwnershipType": 1,
      "criticalRate": 5,
      "criticalDamageRate": 50,
      "movementSpeed": 6,
      "damageInflictedRate": 100,
      "tensionIncreaseRate": 100,
      "cpRecastRate": 100,
      "spGaugeIncreaseRate": 100,
      "attackSpeed": 100,
      "abnormalityParamSet": {
        "oily": {
          "burstResistance": 100,
          "burstResistanceLimit": 100
        },
        "pressure": {
          "burstResistance": 100,
          "burstResistanceLimit": 100
        },
        "scared": {
          "burstResistance": 100,
          "burstResistanceLimit": 100
        },
        "electric": {
          "burstResistance": 100,
          "burstResistanceLimit": 100
        },
        "unfortified": {
          "burstResistance": 100,
          "burstResistanceLimit": 100
        }
      },
      "actionPointMax": 1000,
      "actionPointRate": 3000,
      "actionPointConsumption": 160,
      "damageTakenRate": 1
    })


proc getGachaButtonStates(db: DbConn, gachaId: int): seq[JsonNode] =
  let rows = db.getAllRows(sql"""
    SELECT gachaButtonId, executionCount, lastExecutedAt FROM gachaButtonStates
    WHERE gachaId=?
  """, gachaId)

  for row in rows:
    let gachaButtonId = parseInt(row[0])
    let executionCount = parseInt(row[1])
    let lastExecutedAt = row[2]

    let gachaButtonState = %*{
      "gachaId": gachaId,
      "gachaButtonId": gachaButtonId,
      "executionCount": executionCount,
    }

    if lastExecutedAt != "":
      gachaButtonState["lastExecutedAt"] = %*lastExecutedAt

    result.add(gachaButtonState)


proc parseGachaRow(db: DbConn, row: Row): JsonNode =
  let gachaId = parseInt(row[0])
  let gachaCategoryId = parseInt(row[1])
  let guaranteedCount = parseInt(row[2])
  let isGuaranteedPickup = row[3] == "true"
  let executionCount = parseInt(row[4])
  let isSelectable = row[5] == "true"
  let gachaButtonStates = getGachaButtonStates(db, gachaId)

  return %*{
    "gachaId": gachaId,
    "gachaButtonStates": gachaButtonStates,
    "gachaCategoryState": {
      "gachaCategoryId": gachaCategoryId,
      "guaranteedCount": guaranteedCount,
      "isGuaranteedPickup": isGuaranteedPickup,
      "executionCount": executionCount,
      "isSelectable": isSelectable
    }
  }


proc getGachas*(db: DbConn): seq[JsonNode] =
  let rows = db.getAllRows(sql"""
    SELECT gachaId, gachaCategoryId, guaranteedCount, isGuaranteedPickup, executionCount, isSelectable
    FROM gachas
  """)

  for row in rows:
    result.add(parseGachaRow(db, row))


proc getGachaRateSetIds(db: DbConn): seq[int] =
  let rows = db.getAllRows(sql"SELECT DISTINCT gachaRateSetId FROM gachaRates")
  for row in rows:
    result.add(parseInt(row[0]))


proc getGachaRateCards(db: DbConn, gachaRateId: int): seq[JsonNode] =
  let rows = db.getAllRows(sql"""
    SELECT cardType, cardId, isAttention, isSelectable, gachaCardId FROM gachaCards
    WHERE gachaRateId=?
  """, gachaRateId)

  for row in rows:
    let cardType = parseInt(row[0])
    let cardId = parseInt(row[1])
    let isAttention = row[2] == "true"
    let isSelectable = row[3] == "true"
    let gachaCardId = parseInt(row[4])
    result.add(%*{
      "cardType": cardType,
      "cardId": cardId,
      "isAttention": isAttention,
      "isSelectable": isSelectable,
      "gachaCardId": gachaCardId
    })


proc getGachaRateSetRows(db: DbConn, gachaRateSetId: int): seq[JsonNode] =
  let rows = db.getAllRows(sql"""
    SELECT gachaRateId, percentRate FROM gachaRates
    WHERE gachaRateSetId=?
  """, gachaRateSetId)

  for row in rows:
    let gachaRateId = parseInt(row[0])
    let percentRate = row[1]
    let cards = getGachaRateCards(db, gachaRateId)
    let percentRatePerCard = $(parseFloat(percentRate)/cards.len.float)
    result.add(%*{
      "gachaRateId": gachaRateId,
      "percentRate": percentRate,
      "percentRatePerCard": percentRatePerCard,
      "cards": cards
    })


proc getGachaRateSets*(db: DbConn): seq[JsonNode] =
  for gachaRateSetId in getGachaRateSetIds(db):
    let rows = getGachaRateSetRows(db, gachaRateSetId)
    result.add(%*{
      "gachaRateSetId": gachaRateSetId,
      "rows": rows
    })


proc getGacha*(db: DbConn, gachaId: int): JsonNode =
  let row = db.getRow(sql"""
    SELECT gachaId, gachaCategoryId, guaranteedCount, isGuaranteedPickup, executionCount, isSelectable
    FROM gachas
    WHERE gachaId=?
  """, gachaId)

  if row[0] == "":
    raise newException(SembaError, "Couldn't find gacha for gachaId=" & $gachaId)

  return parseGachaRow(db, row)


proc gachaButtonToPulls*(gachaButtonId: int): int =
  case gachaButtonId.GachaButton:
    of gachaButtonSingle:
      result = 1
    of gachaButtonTen:
      result = 10


proc getRewardFromCard(db: DbConn, card: JsonNode): JsonNode =
  let cardType = card["cardType"].getInt()
  let cardId = card["cardId"].getInt()

  if cardType == gachaCardCharacter.int:
    result = %*{
      "type": rewardCharacter.int,
      "id": cardId,
      "quantity": 1,
      "otherRewards": [
        # FIXME: check if character exists in db and don't give more pieces at max dupes
        {"type": rewardCharacterPiece.int, "id": cardId, "quantity": 1},
        # FIXME: check character rarity and give the other type of remnent
        {"type": rewardItem.int, "id": enigmaticRemnentId, "quantity": 20}
      ]
    }
  elif cardType == gachaCardTensionCard.int:
    let entityId = popEntityId(db)
    result = %*{
      "type": rewardTensionCard.int,
      "id": cardId,
      "quantity": 1,
      "entityId": entityId,
      # FIXME: check if tension card exists and set a correct value
      "isNew": true
    }
  else:
    raise newException(SembaError, "Invalid cardType=" & $cardType)


proc getGachaRateSetForPull*(
  gachaCategoryState: JsonNode, pullIdx: int, pulls: int, isPromised: bool, gachaRateSets: seq[JsonNode]
): JsonNode =
  var gachaRateSetId: GachaRateSetId
  if gachaCategoryState.getOrDefault("isGuaranteedPickup").getBool():
    gachaRateSetId = guaranteedGachaRateSetId
  elif pullIdx == pulls - 1 and isPromised:
    gachaRateSetId = promisedGachaRateSetId
  else:
    gachaRateSetId = normalGachaRateSetId

  for gachaRateSet in gachaRateSets:
    if gachaRateSet["gachaRateSetId"].getInt() == gachaRateSetId.int:
      result = gachaRateSet

  if result == nil:
    raise newException(SembaError, "Couldn't find gachaRateSet for gachaRateSetId=" & $gachaRateSetId)


proc pickCard*(gachaRateSet: JsonNode): JsonNode =
  let choice = rand(100.0)

  var base: float = 0.0

  for gachaRate in gachaRateSet["rows"]:
    let percentRatePerCard = parseFloat(gachaRate["percentRatePerCard"].getStr())
    for card in gachaRate["cards"]:
      result = card

      if (base <= choice) and (choice <= base + percentRatePerCard):
        return card

      base += percentRatePerCard

  echo("Warning: logic error in random card picking, returning last card")


#[
Update the db from drawnCards, returns the changedResources
]#
proc updateDbFromDrawnCards*(
  db: DbConn, drawnCards: seq[JsonNode], drawnRewards: var seq[JsonNode]
): JsonNode =
  var characterCount = initCountTable[int]()

  var tensionCards = newSeq[JsonNode]()

  for card in drawnCards:
    let reward = getRewardFromCard(db, card)
    drawnRewards.add(reward)

    let cardType = card["cardType"].getInt()
    let cardId = card["cardId"].getInt()

    if cardType == gachaCardCharacter.int:
      characterCount.inc(cardId)
    elif cardType == gachaCardTensionCard.int:
      let entityId = reward["entityId"].getInt()
      let tensionCard = getNewTensionCard(db, entityId, cardId)
      addTensionCard(db, tensionCard)
      tensionCards.add(tensionCard)
    else:
      raise newException(SembaError, "Invalid cardType=" & $cardType)

  # FIXME: should check if the character exists and add it to changedResources.characters if not
  var characterPieces = newSeq[JsonNode]()

  for characterId, count in characterCount.pairs():
    var quantity: int
    for i in 0 ..< count:
      quantity = addCharacterPiece(db, characterId)

    characterPieces.add(%*{
      "characterId": characterId,
      "quantity": quantity
    })

  result = %*{
    "characterPieces": characterPieces,
    "tensionCards": tensionCards,
  }


proc getDrawnCards*(db: DbConn, gacha: JsonNode, gachaButtonId: int): seq[JsonNode] =
  let gachaCategoryState = gacha["gachaCategoryState"]
  let pulls = gachaButtonToPulls(gachaButtonId)
  let isPromised = gachaButtonId == gachaButtonTen.int

  let gachaRateSets = getGachaRateSets(db)

  for pullIdx in 0 ..< pulls:
    let gachaRateSet = getGachaRateSetForPull(gachaCategoryState, pullIdx, pulls, isPromised, gachaRateSets)

    let card = pickCard(gachaRateSet)
    result.add(card)


proc setTutorialGacha*(db: DbConn) =
  loadSql(db, tutorialGachaSql)


proc setAfterTutorialGacha*(db: DbConn) =
  loadSql(db, tutorialSkipGachaSql)