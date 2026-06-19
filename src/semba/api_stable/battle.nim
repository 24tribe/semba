import std/json
import std/options
import std/sequtils

import db_connector/db_sqlite

import ../model_stable/area_object_lock
import ../model_stable/city
import ../model_stable/challenge
import ../model_stable/character
import ../model_stable/battle
import ../model_stable/battle_enum
import ../model_stable/tension_card
import ../model_stable/area_object
import ../model_stable/reward
import ../model_stable/item
import ../model_stable/challenge_task
import ../model_stable/challenge_progress
import ../model_stable/resources
import ../model_stable/status
import ../model_stable/warp_point
import ../model_stable/mission
import ../semba_error
import ../protojson


type BattleFinishRequest* = object
  battleResult: BattleResult
  characterUpdates: seq[CharacterUpdate]
  encounteredEnemyIds: seq[int]
  battleTaskTopics: seq[BattleTaskTopic]

type BattleFinishResponse* = object
  rewards*: seq[Rewards]
  ignoredRewards*: seq[Resource]
  changedResources*: Resources
  characterExps*: seq[CharacterExp]
  areaObjects*: seq[AreaObject]
  moveToAreaLocatorId*: Option[int]
  fractalViseUpdate*: Option[JsonNode] # FIXME: use FractalViseUpdate

type BattleRestartRequest* = object
  lineCharacterIds: seq[int]
  encounteredEnemyIds: seq[int]
  isDifficultyDecrease: Option[bool]

type BattleRestartResponse = object
  characters: seq[Character]
  tensionCards: seq[TensionCard]
  battleParameters: seq[BattleParameter]
  battleTriggers: seq[BattleTrigger]
  advantageType: BattleAdvantageType
  characterDishes: seq[JsonNode] # FIXME: use CharacterDish
  wonResultType: BattleWonResultType
  abilityEnigmaId: Option[int]
  changedResources: Resources
  guestCharacters: seq[JsonNode] # FIXME: use Character
  difficultyDecreaseCount: Option[int]

type BattleStartResponse* = object
  characters: seq[Character]
  tensionCards: seq[TensionCard]
  battleParameters: seq[BattleParameter]
  battleTriggers: seq[BattleTrigger]
  advantageType: BattleAdvantageType
  changedResources: Resources
  characterDishes: seq[JsonNode] # FIXME: use CharacterDish
  wonResultType: BattleWonResultType
  abilityEnigmaId: Option[int]
  guestCharacters: seq[JsonNode] # FIXME: use Character
  difficultyDecreaseCount: int


proc battle_Start*(db: DbConn, lastBattleInfo: var Option[BattleInfo], jsonReq: JsonNode): BattleStartResponse =
  let lineCharacterIds = protoJsonTo(jsonReq["lineCharacterIds"], seq[int])
  let characters = getCharactersWithId(db, lineCharacterIds)

  var status = getUserStatusTypeSafe(db)

  let currentLocation = protoJsonTo(jsonReq["currentLocation"], CurrentLocation)

  updateStatusFromCurrentLocation(status, currentLocation)

  setUserStatusTypeSafe(db, status)

  let battleEntryIds = protoJsonTo(jsonReq["battleEntryIds"], seq[int])

  result.characters = characters
  result.tensionCards = getEquippedTensionCards(db)
  result.changedResources.status = some(status)
  result.battleParameters = getBattleParametersFromBattleEntryIds(db, battleEntryIds)
  result.battleTriggers = protoJsonTo(jsonReq["battleTriggers"], seq[BattleTrigger])
  result.advantageType = protoJsonTo(jsonReq{"advantageType"}, BattleAdvantageType)

  lastBattleInfo = some(BattleInfo(
    battleEntryIds: battleEntryIds,
    lineCharacterIds: lineCharacterIds,
    battleTriggers: protoJsonTo(jsonReq["battleTriggers"], seq[BattleTrigger]),
    advantageType: result.advantageType,
  ))


proc battle_Restart*(
  db: DbConn, lastBattleInfo: var Option[BattleInfo], req: BattleRestartRequest
): BattleRestartResponse =
  if lastBattleInfo.isNone():
    raise newException(SembaError, "lastBattleInfo.isNone()")

  lastBattleInfo.get().lineCharacterIds = req.lineCharacterIds

  result.characters = getCharactersWithId(db, req.lineCharacterIds)
  result.tensionCards = getEquippedTensionCards(db)
  result.changedResources.status = some(getUserStatusTypeSafe(db))
  result.battleParameters = getBattleParametersFromBattleEntryIds(db, lastBattleInfo.get().battleEntryIds)
  result.battleTriggers = lastBattleInfo.get().battleTriggers
  result.advantageType = lastBattleInfo.get().advantageType


proc battle_Finish*(
  db: DbConn, lastBattleInfo: var Option[BattleInfo], req: BattleFinishRequest
): BattleFinishResponse =
  if lastBattleInfo.isNone():
    raise newException(SembaError, "lastBattleInfo.isNone()")

  let characterIds = lastBattleInfo.get().lineCharacterIds
  let battleTriggers = lastBattleInfo.get().battleTriggers
  let battleEntryIds = lastBattleInfo.get().battleEntryIds
  let dungeonId = lastBattleInfo.get().dungeonId

  lastBattleInfo = none(BattleInfo)

  let status = getUserStatusTypeSafe(db)

  case req.battleResult:
  of BattleResult.lost:
    result.changedResources.status = some(status)

  of BattleResult.retire:
    result.changedResources.status = some(status)
    result.changedResources.characters = applyCharacterUpdates(db, req.characterUpdates)
    result.moveToAreaLocatorId = some(getLastWarpPoint(db).areaLocatorId)

  of BattleResult.won:
    result.changedResources.status = some(status)

    discard applyCharacterUpdates(db, req.characterUpdates)

    result.characterExps = getCharacterExps(db, characterIds, battleEntryIds)
    updateCharacterExps(db, result.characterExps)

    let characters = getCharactersWithId(db, characterIds)
    result.changedResources.characters = characters

    let areaObjectLocks = handleWonBattleTriggers(db, battleTriggers, dungeonId, status.currentAreaKeyId.get(0))
    upsertAreaObjectLocks(db, areaObjectLocks)
    result.changedResources.areaObjectLocks = areaObjectLocks

    var allRewards = collectEnemyRewards(db, req.encounteredEnemyIds)
    result.rewards = @[Rewards(`type`: some(6), contents: allRewards)]

    let (items, totalItems) = rewardsToChangedItems(db, allRewards)
    updateItems(db, items)
    result.changedResources.items = items

    let cityId = areaIdToCityId(status.currentAreaKeyId.get(0))

    var missions = getChangedAttackTestMissions(db, characters, cityId)
    missions.insert(getChangedDefenseTestMissions(db, characters, cityId), missions.len)

    let challengeTask = getMdChallengeTaskForBattleEntryId(db, battleEntryIds[0])

    if challengeTask.isSome():
      let (_, resources) = getChangedResourcesForCompletedChallengeTask(db, challengeTask.get())

      result.changedResources.challengeTasks = resources.challengeTasks
      upsertChallengeTasks(db, resources.challengeTasks)

      result.changedResources.challengeProgresses = resources.challengeProgresses
      upsertChallengeProgresses(db, resources.challengeProgresses)

      result.changedResources.challenges = resources.challenges
      upsertChallenges(db, resources.challenges)

      missions.insert(getChallengesChangedMissions(db, resources.challenges, cityId), missions.len)

    missions.insert(getChangedVictorsRightsMissions(db, totalItems, cityId), missions.len)
    missions.insert(getChangedBeAForeverWinnerMissions(db, cityId), missions.len)
    missions.insert(getBattleTaskTopicsMissions(db, req.battleTaskTopics, cityId), missions.len)

    result.changedResources.missions = missions
    updateMissions(db, missions)

    result.areaObjects = getBattleFinishAreaObjects(db, battleEntryIds[0])
    updateAreaObjectsEx(db, result.areaObjects)