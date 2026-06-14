import std/json
import std/random

import ../db_connector/db_sqlite

import ../model_stable/area
import ../model_stable/gacha
import ../model_stable/resources


type GachaExecuteResponse* = object
  drawnCards*: seq[JsonNode] # FIXME: use GachaCard
  drawnRewards*: seq[JsonNode] # FIXME: use Reward
  changedResources*: Resources
  gacha*: JsonNode # FIXME: use Gacha
  rewards*: seq[JsonNode] # FIXME: use Rewards


proc gacha_List*(db: DbConn): JsonNode =
  let gachas = getGachas(db)
  let gachaCharacters = getGachaCharacters(db)
  let gachaNotification = getGachaNotification(db)
  let gachaRateSets = getGachaRateSets(db)

  return %*{
    "gachas": gachas,
    "gachaCharacters": gachaCharacters,
    "gachaRateSets": gachaRateSets,
    "changedResources": {
      "notifications": {
        "gacha": gachaNotification
      }
    }
  }


proc gacha_Execute*(db: DbConn, jsonReq: JsonNode): GachaExecuteResponse =
  randomize()

  let gachaId = jsonReq["gachaId"].getInt()
  let gachaButtonId = jsonReq["gachaButtonId"].getInt()

  let gacha = getGacha(db, gachaId)

  let drawnCards =
    if gachaId == gachaIdTutorial.int:
      @[%*{"cardType": 4, "cardId": 100501, "gachaCardId": 101001}]
    else:
      getDrawnCards(db, gacha, gachaButtonId)

  var drawnRewards = newSeq[JsonNode]()
  let (characterPieces, tensionCards) = updateDbFromDrawnCards(db, drawnCards, drawnRewards)

  result = GachaExecuteResponse(
    gacha: gacha,
    drawnCards: drawnCards,
    drawnRewards: drawnRewards,
    changedResources: Resources(
      characterPieces: characterPieces,
      tensionCards: tensionCards,
    )
  )

  if gachaId == gachaIdTutorial.int:
    setAfterTutorialGacha(db)
    addAreaActionSequenceId(db, %*{"areaId": 300202, "actionSequenceId": 8000161})