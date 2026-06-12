import std/json
import std/options

import ../db_connector/db_sqlite

import ../dungeongen
import ../protojson
import ../model_stable/battle_enum
import ../model_stable/character
import ../model_stable/tension_card
import ../model_stable/dungeon
import ../model_stable/challenge_progress
import ../model_stable/timestamp
import ../model_stable/challenge_task
import ../model_stable/area_object
import ../model_stable/battle
import ../model_stable/status
import ../model_stable/resources


type DungeonBattleStartRequest = object
  dungeonDifficultyId: int
  entityIds: seq[int]
  lineCharacterIds: seq[int]
  advantageType: BattleAdvantageType
  isAttackHit: bool

type DungeonResumeRequest = object
  dungeonDifficultyId: int

type DungeonResumeResponse = object
  dungeonState: DungeonState
  dungeonEnemies: seq[DungeonEnemy]
  dungeonAreaItems: seq[JsonNode]


proc dungeon_Finish*(db: DbConn, jsonReq: JsonNode): ChangedResourcesResponse =
  let dungeonDifficultyId = jsonReq["dungeonDifficultyId"].getInt()
  let dungeonId = dungeonDifficultyIdToDungeonId(dungeonDifficultyId)

  let healthyOutlawsChallengeProgress = getChallengeProgress(db, clearHealthyOutlawsChallengeProgressId)

  # FIXME: save dungeons to db?
  result.changedResources.dungeons = @[Dungeon(dungeonId: dungeonId, isFinished: true)]

  if (
    dungeonId == healthyOutlawsDungeonId and
    not isChallengeProgressComplete(healthyOutlawsChallengeProgress)
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
  let battleTriggers = @[BattleTrigger(triggerType: some("dungeon"), triggerIds: some(req.entityIds))]

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
    dungeonId: some(dungeonId),
    advantageType: req.advantageType,
  ))


proc dungeon_Resume*(db: DbConn, jsonReq: JsonNode): JsonNode =
  let req = protoJsonTo(jsonReq, DungeonResumeRequest)
  let dungeonId = dungeonDifficultyIdToDungeonId(req.dungeonDifficultyId)

  let res = DungeonResumeResponse(
    dungeonEnemies: getDungeonEnemies(db, dungeonId),
    dungeonState: getDungeonState(db, dungeonId),
  )

  result = %*res


proc dungeon_Entry*(db: DbConn, jsonReq: JsonNode): JsonNode =
  let dungeonId = jsonReq["dungeonId"].getInt()

  let status = getUserStatusTypeSafe(db)
  var dungeons = newSeq[JsonNode]()

  if getDungeon(db, dungeonId) == nil:
    let dungeon = %*{"dungeonId": dungeonId, "isFinished": true}
    addDungeon(db, dungeon)
    dungeons.add(dungeon)

  result = %*{
    "changedResources": {
      "status": status,
      "dungeons": dungeons,
    }
  }


proc dungeon_Start*(db: DbConn, jsonReq: JsonNode): JsonNode = 
  let dungeonDifficultyId = jsonReq["dungeonDifficultyId"].getInt()
  let bulkConsumeCount = jsonReq["bulkConsumeCount"].getInt()

  let cityId = dungeonDifficultyIdToCityId(dungeonDifficultyId)
  let dungeonData = getDungeonData(db)
  let dungeonPieces = genDungeon(dungeonData, cityId)
  let dungeonId = dungeonDifficultyIdToDungeonId(dungeonDifficultyId)

  let notGoalEnemyRateSetId = getNotGoalEnemyRateSetId(cityId, dungeonId)
  let dungeonEnemies = genDungeonEnemies(
    db, notGoalEnemyRateSetId, dungeonDifficultyId, dungeonPieces, dungeonData
  )

  let dungeonState = DungeonState(
    dungeonDifficultyId: dungeonDifficultyId,
    dungeonPieces: dungeonPieces,
  )

  updateDungeonEnemies(db, dungeonId, dungeonEnemies)
  updateDungeonState(db, dungeonId, dungeonState)

  return %*{
    "dungeonState": dungeonState,
    "dungeonEnemies": dungeonEnemies,
    "changedResources": {
      "dungeons": [
        {
          "dungeonId": dungeonId
        }
      ]
    },
    "dungeonAreaItems": [],
  }