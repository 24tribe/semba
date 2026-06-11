import std/json
import std/options
import std/sequtils

import ../db_connector/db_sqlite

import ../model_stable/area_object_lock
import ../model_stable/city
import ../model_stable/character
import ../model_stable/battle
import ../model_stable/tension_card
import ../model_stable/dungeon
import ../model_stable/area_object
import ../model_stable/reward
import ../model_stable/enemy
import ../model_stable/item
import ../model_stable/challenge_task
import ../model_stable/challenge_progress
import ../model_stable/resources
import ../model_stable/status
import ../model_stable/warp_point
import ../model_stable/mission
import ../semba_error
import ../protojson


type BattleFinishRequest = object
  battleResult: Option[string]
  characterUpdates: seq[CharacterUpdate]
  encounteredEnemyIds: seq[int]

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
  tensionCards: seq[JsonNode] # FIXME: use TensionCard
  battleParameters: seq[BattleParameter]
  battleTriggers: seq[BattleTrigger]
  advantageType: Option[string]
  characterDishes: seq[JsonNode] # FIXME: use CharacterDish
  wonResultType: Option[string]
  abilityEnigmaId: Option[int]
  changedResources: Resources
  guestCharacters: seq[JsonNode] # FIXME: use Character
  difficultyDecreaseCount: Option[int]

type BattleStartResponse* = object
  characters: seq[Character]
  tensionCards: seq[JsonNode] # FIXME: use TensionCard
  battleParameters: seq[BattleParameter]
  battleTriggers: seq[BattleTrigger]
  advantageType: string
  changedResources: Resources
  characterDishes: seq[JsonNode] # FIXME: use CharacterDish
  wonResultType: string
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
  result.advantageType = jsonReq.getOrDefault("advantageType").getStr()

  lastBattleInfo = some(BattleInfo(
    battleEntryIds: battleEntryIds,
    lineCharacterIds: lineCharacterIds,
    battleTriggers: protoJsonTo(jsonReq["battleTriggers"], seq[BattleTrigger]),
    advantageType: some(result.advantageType),
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


proc battle_Finish*(db: DbConn, lastBattleInfo: var Option[BattleInfo], jsonReq: JsonNode): BattleFinishResponse =
  if lastBattleInfo.isNone():
    raise newException(SembaError, "lastBattleInfo.isNone()")

  let characterIds = lastBattleInfo.get().lineCharacterIds
  let battleTriggers = lastBattleInfo.get().battleTriggers
  let battleEntryIds = lastBattleInfo.get().battleEntryIds
  let dungeonId = lastBattleInfo.get().dungeonId

  lastBattleInfo = none(BattleInfo)

  let req = protoJsonTo(jsonReq, BattleFinishRequest)

  let status = getUserStatusTypeSafe(db)

  if req.battleResult.get("") == "lost":
    return BattleFinishResponse(changedResources: Resources(
      status: some(status)
    ))

  for characterUpdate in req.characterUpdates:
    setCharacterHp(db, characterUpdate.characterId, characterUpdate.hp.get(0))

  let characters = getCharactersWithId(db, characterIds)

  if req.battleResult.get("") == "retire":
    return BattleFinishResponse(
      changedResources: Resources(status: some(status), characters: characters),
      moveToAreaLocatorId: some(getLastWarpPoint(db).areaLocatorId),
    )

  var areaObjectLocks = newSeq[AreaObjectLock]()

  let characterExps = getCharacterExps(db, characterIds, battleEntryIds)
  updateCharacterExps(db, characterExps, characters)
  let newCharacters = getCharactersWithId(db, characterIds)

  for battleTrigger in battleTriggers:
    var isAreaObject = battleTrigger.triggerType.get("") == "area_object"
    var isActionSequence = battleTrigger.triggerType.get("") == "action_sequence"
    var isDungeon = battleTrigger.triggerType.get("") == "dungeon"

    if not isActionSequence:
      for triggerId in battleTrigger.triggerIds.get(@[]):
        if isDungeon:
          removeDungeonEnemy(db, dungeonId.get(), triggerId)
        else:
          let areaKeyId = status.currentAreaKeyId.get(0)
          if isAreaObject:
            let areaObjectLockId = getAreaObjectLockIdForBattle(db, triggerId)

            if areaObjectLockId.isSome():
              areaObjectLocks.add(AreaObjectLock(areaObjectLockId: areaObjectLockId.get(), count: some(1)))

            removeAreaObject(db, areaKeyId, triggerId)
          else:
            removeAreaEnemy(db, areaKeyId, triggerId)

  upsertAreaObjectLocks(db, areaObjectLocks)

  var allRewards = newSeq[Reward]()

  for enemyId in req.encounteredEnemyIds:
    let rewardItemIds = getEnemyRewardItemIds(db, enemyId)

    if rewardItemIds.len == 0:
      echo("Warning: rewardItemIds for enemyId=" & $enemyId & " is empty!!")

    let rewards = getRandomRewards(db, rewardItemIds)
    for reward in rewards:
      allRewards.add(reward)

  let (items, totalItems) = rewardsToChangedItems(db, allRewards)
  updateItems(db, items)

  let cityId = areaIdToCityId(status.currentAreaKeyId.get(0))

  var missions: seq[Mission] = getChangedAttackTestMissions(db, newCharacters, cityId)
  missions.insert(getChangedVictorsRightsMissions(db, totalItems, cityId), missions.len)
  missions.insert(getChangedBeAForeverWinnerMissions(db, cityId), missions.len)
  updateMissions(db, missions)

  result = BattleFinishResponse(
    changedResources: Resources(
      areaObjectLocks: some(areaObjectLocks),
      status: some(status),
      characters: newCharacters,
      items: items,
      missions: missions,
    ),
    rewards: @[Rewards(`type`: some(6), contents: allRewards)],
    characterExps: characterExps,
    areaObjects: getBattleFinishAreaObjects(db, battleEntryIds[0]),
  )

  let challengeTask = getMdChallengeTaskForBattleEntryId(db, battleEntryIds[0])

  if challengeTask.isSome():
    let (_, resources) = getChangedResourcesForCompletedChallengeTask(db, challengeTask.get())

    result.changedResources.challengeTasks = resources.challengeTasks
    upsertChallengeTasks(db, resources.challengeTasks)

    result.changedResources.challengeProgresses = resources.challengeProgresses
    upsertChallengeProgresses(db, resources.challengeProgresses)

  updateAreaObjectsEx(db, result.areaObjects)