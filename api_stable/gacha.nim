import std/json
import std/random

import ../db_connector/db_sqlite

import ../model_stable/gacha
import ../model_stable/user


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


proc gacha_Execute*(db: DbConn, jsonReq: JsonNode): JsonNode =
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
  let changedResources = updateDbFromDrawnCards(db, drawnCards, drawnRewards)

  return %*{
    "gacha": gacha,
    "drawnCards": drawnCards,
    "drawnRewards": drawnRewards,
    "changedResources": changedResources,
  }