import std/json
import std/options
import std/tables

import ../db_connector/db_sqlite

import ../model_stable/character
import ../model_stable/battle
import ../model_stable/user
import ../model_stable/tension_card
import ../model_stable/dungeon
import ../model_stable/area_object
import ../model_stable/reward
import ../model_stable/enemy
import ../model_stable/item
import ../model_stable/challenge_task
import ../model_stable/challenge_progress
import ../model_stable/resources
import ../semba_error


type BattleFinishRequest = object
  battleResult: Option[string]
  characterUpdates: seq[CharacterUpdate]
  encounteredEnemyIds: seq[int]


proc battle_Start*(db: DbConn, lastBattleInfo: var Option[BattleInfo], jsonReq: JsonNode): JsonNode =
  let lineCharacterIds = to(jsonReq["lineCharacterIds"], seq[int])
  let characters = getCharactersWithId(db, lineCharacterIds)

  let status = getUserStatus(db)

  let currentLocation = jsonReq["currentLocation"]
  
  status["currentAreaKeyId"] = currentLocation["areaKeyId"]
  status["currentAreaType"] = currentLocation["areaType"]
  status["currentDirection"] = currentLocation["direction"]
  status["currentPositionCoordinates"] = currentLocation["positionCoordinates"]

  setUserStatus(db, status)

  let battleParameters = getBattleParameters(db, jsonReq["battleEntryIds"])

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
    battleEntryIds: to(jsonReq["battleEntryIds"], seq[int]),
    lineCharacterIds: lineCharacterIds,
    currentLocation: currentLocation,
    battleTriggers: to(jsonReq["battleTriggers"], seq[BattleTrigger])
  ))

  if advantageType != nil:
    result["advantageType"] = advantageType


proc battle_Finish*(db: DbConn, lastBattleInfo: var Option[BattleInfo], jsonReq: JsonNode): JsonNode =
  if lastBattleInfo.isNone():
    raise newException(SembaError, "lastBattleInfo.isNone()")

  let characterIds = lastBattleInfo.get().lineCharacterIds
  let battleTriggers = lastBattleInfo.get().battleTriggers
  let currentLocation = lastBattleInfo.get().currentLocation
  let battleEntryIds = lastBattleInfo.get().battleEntryIds
  let dungeonId = lastBattleInfo.get().dungeonId

  lastBattleInfo = none(BattleInfo)

  let req = to(jsonReq, BattleFinishRequest)

  let status = getUserStatus(db)

  if req.battleResult.get("") == "lost":
    return %*{"changedResources": {"status": status}}

  for characterUpdate in req.characterUpdates:
    setCharacterHp(db, characterUpdate.characterId, characterUpdate.hp.get(0))

  for battleTrigger in battleTriggers:
    var isAreaObject = battleTrigger.triggerType.get("") == "area_object"
    var isActionSequence = battleTrigger.triggerType.get("") == "action_sequence"
    var isDungeon = battleTrigger.triggerType.get("") == "dungeon"

    if not isActionSequence:
      for triggerId in battleTrigger.triggerIds.get(@[]):
        if isDungeon:
          removeDungeonEnemy(db, dungeonId.get(), triggerId)
        else:
          let areaKeyId = currentLocation["areaKeyId"].getInt()
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
    addItem(db, item)

  let characterExps = getCharacterExps(db, characterIds, battleEntryIds)

  let characters = getCharactersWithId(db, characterIds)
  updateCharacterExps(db, characterExps, characters)

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
      "characters": characters,
      "items": items,
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