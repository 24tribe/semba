import std/json
import std/options

import db_connector/db_sqlite

import ../dungeongen
import ../protojson
import ../model_stable/battle_enum
import ../model_stable/character
import ../model_stable/tension_card
import ../model_stable/dungeon
import ../model_stable/dungeon_area_item
import ../model_stable/challenge_progress
import ../model_stable/timestamp
import ../model_stable/battle
import ../model_stable/status
import ../model_stable/resources
import ../model_stable/mission
import ../model_stable/reward


type DungeonAcquireAreaItemRequest* = object
  dungeonDifficultyId*: int
  entityId*: int

type DungeonAcquireAreaItemResponse* = object
  rewards*: seq[Rewards]
  changedResources*: Resources
  dungeonAreaItem*: DungeonAreaItem

type DungeonStartResponse* = object
  dungeonState*: DungeonState
  dungeonEnemies*: seq[DungeonEnemy]
  dungeonAreaItems*: seq[DungeonAreaItem]
  changedResources*: Resources

type DungeonBattleStartRequest = object
  dungeonDifficultyId: int
  entityIds: seq[int]
  lineCharacterIds: seq[int]
  advantageType: BattleAdvantageType
  isAttackHit: bool

type DungeonResumeRequest* = object
  dungeonDifficultyId*: int

type DungeonResumeResponse = object
  dungeonState*: DungeonState
  dungeonEnemies*: seq[DungeonEnemy]
  dungeonAreaItems*: seq[DungeonAreaItem]

type DungeonEntryResponse* = object
  currentDungeonDifficultyId*: Option[int]
  prevAccessDungeonDifficultyId*: Option[int]
  changedResources*: Resources


proc dungeon_Finish*(db: DbConn, jsonReq: JsonNode): ChangedResourcesResponse =
  let dungeonDifficultyId = jsonReq["dungeonDifficultyId"].getInt()
  let dungeonId = dungeonDifficultyIdToDungeonId(dungeonDifficultyId)

  result.changedResources.dungeons = @[Dungeon(dungeonId: dungeonId, isFinished: true)]
  upsertDungeons(db, result.changedResources.dungeons)
  updateCurrentDungeonDifficultyId(db, dungeonId, none(int))

  result.changedResources.missions = getChangedRiftClearMissions(db, dungeonId)
  updateMissions(db, result.changedResources.missions)

  if (
    dungeonId == healthyOutlawsDungeonId and
    not isChallengeProgressComplete(db, clearHealthyOutlawsChallengeProgressId)
  ):
    let (challengeProgresses, challengeTasks) = completeMainStoryRiftTutorialChallenge(db)
    result.changedResources.challengeProgresses = challengeProgresses
    result.changedResources.challengeTasks = challengeTasks


proc dungeon_BattleStart*(db: DbConn, jsonReq: JsonNode, lastBattleInfo: var Option[BattleInfo]): JsonNode =
  let req = protoJsonTo(jsonReq, DungeonBattleStartRequest)
  let dungeonId = dungeonDifficultyIdToDungeonId(req.dungeonDifficultyId)

  let characters = getCharactersWithId(db, req.lineCharacterIds)
  let tensionCards = getEquippedTensionCards(db)
  let battleEntryIds = getBattleEntryIdsFromDungeonEntityIds(db, dungeonId, req.entityIds)
  let battleParameters = getBattleParametersFromBattleEntryIds(db, battleEntryIds)
  let battleTriggers = @[BattleTrigger(triggerType: BattleTriggerType.dungeon, triggerIds: req.entityIds)]

  result = %*{
    "characters": characters,
    "tensionCards": tensionCards,
    "changedResources": {},
    "battleParameters": battleParameters,
    "battleTriggers": battleTriggers,
    "advantageType": req.advantageType,
  }

  lastBattleInfo = some(BattleInfo(
    battleEntryIds: battleEntryIds,
    battleTriggers: battleTriggers,
    lineCharacterIds: req.lineCharacterIds,
    dungeonDifficultyId: some(req.dungeonDifficultyId),
    advantageType: req.advantageType,
    isDungeonBossBattle: isDungeonBossBattle(db, dungeonId, req.entityIds)
  ))


proc dungeon_Resume*(db: DbConn, req: DungeonResumeRequest): DungeonResumeResponse =
  let dungeonId = dungeonDifficultyIdToDungeonId(req.dungeonDifficultyId)

  result.dungeonEnemies = getDungeonEnemies(db, dungeonId)
  result.dungeonState = getDungeonState(db, dungeonId)
  result.dungeonAreaItems = getDungeonAreaItems(db, dungeonId)


proc dungeon_Entry*(db: DbConn, jsonReq: JsonNode): DungeonEntryResponse =
  let dungeonId = jsonReq["dungeonId"].getInt()

  var changedResources: Resources

  changedResources.status = some(getUserStatusTypeSafe(db))

  let (dungeon, currDifficultyId, prevDifficultyId) = getDungeon(db, dungeonId)
  changedResources.dungeons = @[dungeon]
  upsertDungeons(db, changedResources.dungeons)

  DungeonEntryResponse(
    changedResources: changedResources,
    currentDungeonDifficultyId: currDifficultyId,
    prevAccessDungeonDifficultyId: prevDifficultyId,
  )


proc dungeon_Start*(db: DbConn, jsonReq: JsonNode): DungeonStartResponse = 
  let dungeonDifficultyId = jsonReq["dungeonDifficultyId"].getInt()
  let bulkConsumeCount = jsonReq["bulkConsumeCount"].getInt()

  let cityId = dungeonDifficultyIdToCityId(dungeonDifficultyId)
  let dungeonData = getDungeonData(db)
  let dungeonPieces = genDungeon(dungeonData, cityId)
  let dungeonId = dungeonDifficultyIdToDungeonId(dungeonDifficultyId)

  let notGoalEnemyRateSetId = getNotGoalEnemyRateSetId(cityId, dungeonId)

  result.dungeonEnemies = genDungeonEnemies(
    db, notGoalEnemyRateSetId, dungeonDifficultyId, dungeonPieces, dungeonData
  )
  updateDungeonEnemies(db, dungeonId, result.dungeonEnemies)

  result.dungeonState = DungeonState(
    dungeonDifficultyId: dungeonDifficultyId,
    dungeonPieces: dungeonPieces,
  )
  updateDungeonState(db, dungeonId, result.dungeonState)

  result.dungeonAreaItems = genDungeonAreaItems(db, cityId, dungeonPieces, dungeonData)
  setDungeonAreaItems(db, dungeonId, result.dungeonAreaItems)

  result.changedResources.dungeons = @[Dungeon(dungeonId: dungeonId, isFinished: false)]
  upsertDungeons(db, result.changedResources.dungeons)

  updateCurrentDungeonDifficultyId(db, dungeonId, some(dungeonDifficultyId))


proc dungeon_AcquireAreaItem*(db: DbConn, req: DungeonAcquireAreaItemRequest): DungeonAcquireAreaItemResponse =
  let dungeonId = dungeonDifficultyIdToDungeonId(req.dungeonDifficultyId)
  let cityId = dungeonDifficultyIdToCityId(req.dungeonDifficultyId)

  let dungeonAreaItems = getDungeonAreaItems(db, dungeonId, @[req.entityId])
  doAssert(dungeonAreaItems.len > 0)
  var dungeonAreaItem = dungeonAreaItems[0]
  dungeonAreaItem.acquiredAt = some(getTimestampNow())

  result.dungeonAreaItem = dungeonAreaItem
  upsertDungeonAreaItem(db, dungeonId, dungeonAreaItem)

  let mdDungeonAreaItem = getMdDungeonAreaItem(db, dungeonAreaItem.dungeonAreaItemId)

  (result.changedResources, result.rewards) = acquireAreaItemRewards(
    db, mdDungeonAreaItem.areaItemRewardIds, cityId, mdDungeonAreaItem.areaItemBaseId
  )