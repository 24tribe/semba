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
  let clientTimestamp = jsonReq["clientTimestamp"].getStr()

  let gacha = getGacha(db, gachaId)
  let gachaCategoryState = gacha["gachaCategoryState"]
  let pulls = gachaButtonToPulls(gachaButtonId)
  let isPromised = gachaButtonId == gachaButtonTen.int

  let gachaRateSets = getGachaRateSets(db)

  var drawnCards = newSeq[JsonNode]()
  var drawnRewards = newSeq[JsonNode]()

  for pullIdx in 0 ..< pulls:
    let gachaRateSet = getGachaRateSetForPull(gachaCategoryState, pullIdx, pulls, isPromised, gachaRateSets)

    let card = pickCard(gachaRateSet)
    drawnCards.add(card)

  let changedResources = updateDbFromDrawnCards(db, drawnCards, drawnRewards)

  return %*{
    "gacha": gacha,
    "drawnCards": drawnCards,
    "drawnRewards": drawnRewards,
    "changedResources": changedResources,
  }