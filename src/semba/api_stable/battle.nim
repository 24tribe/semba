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
import ../model_stable/nine_sequence
import ../semba_error
import ../protojson


type BattleFinishRequest* = object
  battleResult*: BattleResult
  characterUpdates*: seq[CharacterUpdate]
  encounteredEnemyIds*: seq[int]
  battleTaskTopics*: seq[BattleTaskTopic]

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

type BattleStartRequest* = object
  battleEntryIds*: seq[int]
  lineCharacterIds*: seq[int]
  battleTriggers*: seq[BattleTrigger]
  advantageType*: BattleAdvantageType
  isAttackHit*: bool
  currentLocation*: CurrentLocation
  bloodStainLocation*: Option[JsonNode] # FIXME: use BloodStainLocation

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

type BattleSkipRequest* = object
  battleEntryId*: int
  battleTrigger*: BattleTrigger
  currentLocation*: CurrentLocation
  lineCharacterIds*: seq[int]

type BattleSkipResponse* = object
  rewards*: seq[Rewards]
  ignoredRewards*: seq[Resource]
  changedResources*: Resources
  characterExps*: seq[CharacterExp]
  areaObjects*: seq[AreaObject]


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
    (
      result.changedResources, result.areaObjects, result.characterExps, result.rewards
    ) = getWonBattleFinishChangedResources(
      db, status, req.characterUpdates, characterIds, battleEntryIds,
      battleTriggers, dungeonId, req.encounteredEnemyIds, req.battleTaskTopics
    )


proc battle_Skip*(db: DbConn, req: BattleSkipRequest): BattleSkipResponse =
  discard