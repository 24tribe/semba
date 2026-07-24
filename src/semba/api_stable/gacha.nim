import std/json
import std/options
import std/random

import db_connector/db_sqlite

import ../model_stable/gacha
import ../model_stable/resources
import ../model_stable/challenge_progress
import ../model_stable/challenge_task


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

  var changedResources = Resources(
    characterPieces: characterPieces,
    tensionCards: tensionCards,
  )

  if gachaId == gachaIdTutorial.int:
    setAfterTutorialGacha(db)

    ## This should've been set by calling getChangedResourcesForCompletedChallengeTask 
    ## but challengeTaskId=10001531 is the only one with a taskConditionType of 48 (gacha execute)
    ## so it's not worth changing the implementation just for this

    changedResources.challengeProgresses = @[
      ChallengeProgress(
        challengeProgressId: 1000153, clearedAt: some(getTimestampNow()), state: challengeProgressStateCleared.int
      ),
      ChallengeProgress(
        challengeProgressId: 1000161, state: challengeProgressStateStarted.int
      ),
    ]

    db.upsertChallengeProgresses(changedResources.challengeProgresses)

    changedResources.challengeTasks = @[
      ChallengeTask(challengeTaskId: 10001531, clearedAt: some(getTimestampNow()), count: some(1))
    ]

    db.upsertChallengeTasks(changedResources.challengeTasks)

  result = GachaExecuteResponse(
    gacha: gacha,
    drawnCards: drawnCards,
    drawnRewards: drawnRewards,
    changedResources: changedResources,
  )
