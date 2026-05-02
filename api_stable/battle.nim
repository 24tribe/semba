import std/json
import std/options
import std/tables

import ../db_connector/db_sqlite

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


type BattleFinishRequest = object
  battleResult: Option[string]
  characterUpdates: seq[CharacterUpdate]
  encounteredEnemyIds: seq[int]

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


proc battle_Start*(db: DbConn, lastBattleInfo: var Option[BattleInfo], jsonReq: JsonNode): JsonNode =
  let lineCharacterIds = to(jsonReq["lineCharacterIds"], seq[int])
  let characters = getCharactersWithId(db, lineCharacterIds)

  var status = getUserStatusTypeSafe(db)

  let currentLocation = to(jsonReq["currentLocation"], CurrentLocation)

  updateStatusFromCurrentLocation(status, currentLocation)

  setUserStatusTypeSafe(db, status)

  let battleEntryIds = to(jsonReq["battleEntryIds"], seq[int])

  let battleParameters = getBattleParametersFromBattleEntryIds(db, battleEntryIds)

  let advantageType = jsonReq.getOrDefault("advantageType")

  result = %*{
    "characters": characters,
    "tensionCards": getEquippedTensionCards(db),
    "changedResources": {
      "status": status
    },
    "battleParameters": battleParameters,
    "battleTriggers": jsonReq["battleTriggers"]
  }

  lastBattleInfo = some(BattleInfo(
    battleEntryIds: battleEntryIds,
    lineCharacterIds: lineCharacterIds,
    battleTriggers: to(jsonReq["battleTriggers"], seq[BattleTrigger]),
    advantageType: to(advantageType, Option[string]),
  ))

  if advantageType != nil:
    result["advantageType"] = advantageType


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


proc battle_Finish*(db: DbConn, lastBattleInfo: var Option[BattleInfo], jsonReq: JsonNode): JsonNode =
  if lastBattleInfo.isNone():
    raise newException(SembaError, "lastBattleInfo.isNone()")

  let characterIds = lastBattleInfo.get().lineCharacterIds
  let battleTriggers = lastBattleInfo.get().battleTriggers
  let battleEntryIds = lastBattleInfo.get().battleEntryIds
  let dungeonId = lastBattleInfo.get().dungeonId

  lastBattleInfo = none(BattleInfo)

  let req = to(jsonReq, BattleFinishRequest)

  let status = getUserStatusTypeSafe(db)

  if req.battleResult.get("") == "lost":
    return %*{"changedResources": {"status": status}}

  for characterUpdate in req.characterUpdates:
    setCharacterHp(db, characterUpdate.characterId, characterUpdate.hp.get(0))

  let characters = getCharactersWithId(db, characterIds)

  if req.battleResult.get("") == "retire":
    let moveToAreaLocatorId = getLastWarpPoint(db).areaLocatorId
    return %*{
      "changedResources": {
        "status": status,
        "characters": characters,
      },
      "moveToAreaLocatorId": moveToAreaLocatorId
    }

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
            removeAreaObject(db, areaKeyId, triggerId)
          else:
            removeAreaEnemy(db, areaKeyId, triggerId)

  let areaObjects = getBattleFinishAreaObjects(db, battleEntryIds[0])

  var allRewards = newSeq[Reward]()

  for enemyId in req.encounteredEnemyIds:
    let rewardItemIds = getEnemyRewardItemIds(db, enemyId)

    if rewardItemIds.len == 0:
      echo("Warning: rewardItemIds for enemyId=" & $enemyId & " is empty!!")

    let rewards = getRandomRewards(db, rewardItemIds)
    for reward in rewards:
      allRewards.add(reward)

  var itemsTable = getItemsTable(db)
  var changedItems: Table[int, JsonNode]

  for reward in allRewards:
    var item: JsonNode
    if reward.id in itemsTable:
      item = itemsTable[reward.id]
    else:
      item = %*{"itemId": reward.id, "quantity": 0}
      itemsTable[reward.id] = item

    var quantity = item.getOrDefault("quantity").getInt()
    quantity += reward.quantity
    item["quantity"] = %*quantity
    if not (reward.id in changedItems):
      changedItems[reward.id] = item

  let items = itemsTableToItemsSeq(changedItems)

  for item in items:
    upsertItem(db, to(item, Item))

  let cityId = areaIdToCityId(status.currentAreaKeyId.get(0))

  let missions = getChangedAttackTestMissions(db, newCharacters, cityId)
  updateMissions(db, missions)

  result = %*{
    "characterExps": characterExps,
    "rewards": [
      {
        "type": 6,
        "contents": allRewards
      }
    ],
    "changedResources": {
      "status": status,
      "characters": newCharacters,
      "items": items,
      "missions": missions,
    }
  }

  let challengeTask = getMdChallengeTaskForBattleEntryId(db, battleEntryIds[0])

  if challengeTask.isSome():
    let (_, resources) = getChangedResourcesForCompletedChallengeTask(db, challengeTask.get())

    result["changedResources"]["challengeTasks"] = %*resources.challengeTasks.get()
    updateChallengeTasks(db, result["changedResources"]["challengeTasks"])

    result["changedResources"]["challengeProgresses"] = %*resources.challengeProgresses.get()
    updateChallengeProgresses(db, result["changedResources"]["challengeProgresses"])

  if areaObjects != nil:
    result["areaObjects"] = areaObjects
    if battleEntryIds == @[1000002]:
      updateAreaObjectsEx(db, to(areaObjects, seq[AreaObject]))
    else:
      updateAreaObjects(db, areaObjects)