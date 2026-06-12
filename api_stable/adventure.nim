import std/json
import std/options
import std/sequtils

import ../db_connector/db_sqlite

import ../model_stable/adventure_variable
import ../model_stable/area
import ../model_stable/area_item
import ../model_stable/area_object
import ../model_stable/character
import ../model_stable/city
import ../model_stable/graffiti_art
import ../model_stable/happy_worker
import ../model_stable/lux_phantasma
import ../model_stable/mission
import ../model_stable/magic_orb
import ../model_stable/nine_sequence
import ../model_stable/resources
import ../model_stable/reward
import ../model_stable/sequence_request
import ../model_stable/status
import ../model_stable/tutorial_state
import ../model_stable/wallet
import ../model_stable/warp_point


type AdventureAreaObjectResponse* = object
  areaObjects*: seq[AreaObject]
  areaItems*: seq[AreaItem]
  bloodStains*: seq[JsonNode] # FIXME: use BloodStain

type AdventureAcquireAreaItemResponse* = object
  areaItem*: AreaItem
  rewards*: seq[Rewards]
  changedResources*: Resources
  areaObjects*: seq[AreaObject]

type AdventureFindGraffitiRequest* = object
  graffitiArtId: int
  currentLocation: Option[JsonNode] # FIXME: use CurrentLocation

type AdventureFindGraffitiResponse* = object
  rewards*: seq[Reward]
  changedResources*: Resources

type AdventureAccessWarpPointResponse* = object
  changedResources*: Resources
  areaObjects*: seq[AreaObject]

type AdventureMoveToAreaRequest* = object
  areaId*: int
  currentLocation*: Option[CurrentLocation]
  respawnAtHospital*: Option[bool]

type AdventureMoveToAreaResponse* = object
  changedResources*: Resources
  areaChangeLocks*: seq[JsonNode] # FIXME: use AreaChangeLock
  areaBehavior*: Option[AreaBehavior]
  areaBgm*: AreaBgm

type AdventureAcquireAreaItemRequest* = object
  areaItemId*: int
  currentLocation*: CurrentLocation

type AdventureReadSequenceResponse* = object
  areaObjects*: seq[AreaObject]
  rewards*: seq[Rewards]
  changedResources*: Resources
  deletedCharacterIds*: seq[int]

type AdventureReadSequenceRequest* = object
  sequenceRequestIds*: Option[seq[int]]
  nineSequences*: Option[seq[NineSequenceRequest]]
  miniGameId*: Option[int]
  areaType*: int
  areaKeyId*: int
  currentLocation*: CurrentLocation


proc adventure_WarpAreaLocator*(db: DbConn, jsonReq: JsonNode): ChangedResourcesResponse =
  resetAreaEnemies(db)

  result.changedResources = Resources(
    status: some(getUserStatusTypeSafe(db)),
    characters: healCharactersTypeSafe(db),
  )


proc adventure_ReleaseEventLift*(jsonReq: JsonNode): JsonNode =
  return %*{
    "changedResources": {}
  }


proc adventure_AreaObject*(db: DbConn, jsonReq: JsonNode): AdventureAreaObjectResponse =
  let areaId = jsonReq["areaId"].getInt()

  result.areaObjects = getAreaObjectsInArea(db, areaId);

  if areaId == 130801: # Mita's Hideout
    result.areaObjects.insert(getLuxPhantasmaAreaObjects(), result.areaObjects.len)

  result.areaObjects.insert(getAreaEnemiesInArea(db, areaId), result.areaObjects.len)
  result.areaObjects.insert(getDummyAreaObjects(db, areaId), result.areaObjects.len)

  result.areaItems = getAreaItems(db, areaId)


proc adventure_MoveToArea*(db: DbConn, req: AdventureMoveToAreaRequest): AdventureMoveToAreaResponse =
  var status = getUserStatusTypeSafe(db)

  if req.currentLocation.isNone(): # dungeon? areaId=80XXXX or areaId=81XXXX
    result.changedResources.status = some(status)
    result.areaBgm.id = 1002
    result.areaBgm.eventName = some("bgm_adv_00_basic_01")
    return result

  var changedAreas = newSeq[Area]()

  if not hasArea(db, req.areaId):
    addArea(db, req.areaId)
    changedAreas.add(Area(areaId: req.areaId))

  updateStatusFromCurrentLocation(status, req.currentLocation.get())

  setUserStatusTypeSafe(db, status)

  result.areaBgm = getAreaBgm(db, req.areaId)
  result.areaChangeLocks = getAreaChangeLocksForAreaId(db, req.areaId)
  result.changedResources.status = some(status)
  result.changedResources.areas = some(changedAreas)

  let actionSequenceId = getActionSequenceId(db, req.areaId)

  if actionSequenceId != 0:
    result.areaBehavior = some(AreaBehavior(actionSequenceId: actionSequenceId))


proc adventure_UpdateCharacterStatus*(db: DbConn, jsonReq: JsonNode): ChangedResourcesResponse =
  for characterUpdate in jsonReq["characterUpdates"]:
    let characterId = characterUpdate["characterId"].getInt()
    let hp = characterUpdate["hp"].getInt()

    setCharacterHp(db, characterId, hp)

    let character = getCharacter(db, characterId)
    result.changedResources.characters.add(character)


proc adventure_ReadSequence*(db: DbConn, req: AdventureReadSequenceRequest): AdventureReadSequenceResponse =
  let sequenceRequestIds = req.sequenceRequestIds.get(@[])
  let nineSequenceRequests = req.nineSequences.get(@[])
  let cityId = areaIdToCityId(req.areaKeyId)

  if req.miniGameId.isSome():
    let miniGameId = req.miniGameId.get()
    let areaId = req.currentLocation.areaKeyId.get()
    (result.changedResources, result.areaObjects) = readSequenceMiniGame(db, miniGameId, sequenceRequestIds, areaId)
    return

  if sequenceRequestIds.len > 0:
    let seqReqId = sequenceRequestIds[0]

    let (changedResources, areaObjects) = getReplaySequenceFromSequenceRequestId(db, seqReqId)

    result.changedResources = changedResources.get(Resources())
    result.areaObjects = areaObjects.get(newSeq[AreaObject]())

    let challenges = result.changedResources.challenges

    if challenges.len == 1 and deleteAreaObjectsOfCompletedHappyWorkerChallenge(db, challenges[0]):
      discard

    if seqReqId == 80001521:
      result.deletedCharacterIds = @[100201, 101701]
      deleteGuestCharacters(db, result.deletedCharacterIds)

    const talkWithEnokiSeqReqId = 80100431
    const talkWithMiuSeqReqId = 80100432

    if seqReqId in [80100421, 80100422, talkWithEnokiSeqReqId, talkWithMiuSeqReqId]:
      changeReadSequenceResponse(db, seqReqId, result.changedResources, result.areaObjects)
      result.changedResources.nineSequences = processNineSequenceRequests(db, nineSequenceRequests)
      result.changedResources.adventureVariables = getSequenceAdventureVariables(db, sequenceRequestIds)

    result.changedResources.missions = getChangedMagicOrbMissions(db, result.changedResources.magicOrbs.len, cityId)

    updateAreaObjectsEx(db, result.areaObjects)
    updateResources(db, result.changedResources) 

    let readSequenceAreaAction = getReadSequenceAreaAction(db, seqReqId)

    if readSequenceAreaAction.areaId != 0:
      updateActionSequenceId(db, readSequenceAreaAction.areaId, readSequenceAreaAction.actionSequenceId)

    let readSequenceAreaBgm = getReadSequenceAreaBgm(db, seqReqId)

    if readSequenceAreaBgm.areaId != 0:
      updateAreaBgm(db, readSequenceAreaBgm.areaId, readSequenceAreaBgm.id, readSequenceAreaBgm.eventName)
  else:
    let nineSeqReqId = nineSequenceRequests[0].id
    let (changedResources, areaObjects) = getReplaySequenceFromNineSequenceId(db, nineSeqReqId)

    result.changedResources = changedResources.get(Resources())
    result.areaObjects = areaObjects.get(newSeq[AreaObject]())

    result.changedResources.missions = getChangedMagicOrbMissions(db, result.changedResources.magicOrbs.len, cityId)

    updateAreaObjectsEx(db, result.areaObjects)
    updateResources(db, result.changedResources) 

    # TODO: does a nineSequence change an area action like in the other branch of the if?


proc adventure_AcquireAreaItem*(db: DbConn, req: AdventureAcquireAreaItemRequest): AdventureAcquireAreaItemResponse =
  let areaItem = getMdAreaItem(db, req.areaItemId)

  result.rewards = getAreaItemRewards(db, areaItem.areaItemRewardIds)

  result.changedResources = updateResourcesFromRewardsTypeSafe(db, result.rewards[0].contents)

  if isChestAreaItem(areaItem.areaItemBaseId):
    let cityId = areaIdToCityId(req.currentLocation.areaKeyId.get())
    let missions = getChangedOpenChestMissions(db, cityId)

    result.changedResources.missions = missions
    updateMissions(db, missions)

  result.areaItem = AreaItem(areaItemId: req.areaItemId, acquired: true)


proc adventure_Hospital*(db: DbConn): ChangedResourcesResponse =
  result.changedResources.status = some(getUserStatusTypeSafe(db))
  result.changedResources.characters = healCharactersTypeSafe(db)


proc adventure_AccessWarpPoint*(db: DbConn, jsonReq: JsonNode): AdventureAccessWarpPointResponse =
  let warpPointId = jsonReq["warpPointId"].getInt()

  var changedTutorialStates = newSeq[TutorialState]()
  var changedWarpPoints = newSeq[JsonNode]()
  let status = getUserStatusTypeSafe(db)

  if not getTutorialState(db, respiteUnitTutorialStatusKey):
    updateTutorialState(db, respiteUnitTutorialStatusKey, true)
    changedTutorialStates.add(TutorialState(
      tutorialStatusKey: respiteUnitTutorialStatusKey,
      enabled: true
    ))

  if not hasWarpPoint(db, warpPointId):
    addWarpPoint(db, warpPointId)
    changedWarpPoints.add(%*{
      "warpPointId": warpPointId
    })

  let areaId = getWarpPointAreaId(db, warpPointId)
  let areaObjects = getRespawnAreaEnemies(db, areaId)
  resetAreaEnemies(db)

  # TODO: update also missions (zero sensei?) and guestCharacters

  return AdventureAccessWarpPointResponse(
    changedResources: Resources(
      warpPoints: some(changedWarpPoints),
      tutorialStates: changedTutorialStates,
      status: some(status),
      characters: healCharactersTypeSafe(db),
    ),
    areaObjects: areaObjects,
  )


proc adventure_FindGraffiti*(db: DbConn, req: AdventureFindGraffitiRequest): AdventureFindGraffitiResponse =
  let cityId = graffitiArtIdToCityId(req.graffitiArtId)
  let missions = getChangedGraffitiMissions(db, cityId)
  result.changedResources.missions = missions
  updateMissions(db, missions)

  let graffitiArt = GraffitiArt(graffitiArtId: req.graffitiArtId)
  addGraffitiArt(db, graffitiArt)
  result.changedResources.graffitiArts = some(@[graffitiArt])

  const graffitiFreeGems = 5

  result.rewards = @[Reward(`type`: rewardFreeGem.int, id: 1, quantity: graffitiFreeGems)]

  var wallet = getWallet(db)
  wallet.free = some(wallet.free.get(0) + graffitiFreeGems)
  setWallet(db, wallet)
  result.changedResources.wallet = some(wallet)

  result.changedResources.status = some(getUserStatusTypeSafe(db))