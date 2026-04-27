import std/json
import std/options
import std/sequtils
import std/strutils

import ../db_connector/db_sqlite

import ../model_stable/adventure_variable
import ../model_stable/area
import ../model_stable/area_item
import ../model_stable/area_object
import ../model_stable/character
import ../model_stable/graffiti_art
import ../model_stable/lux_phantasma
import ../model_stable/nine_sequence
import ../model_stable/resources
import ../model_stable/reward
import ../model_stable/sequence_request
import ../model_stable/status
import ../model_stable/tutorial_state
import ../model_stable/wallet
import ../model_stable/warp_point


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


proc adventure_WarpAreaLocator*(db: DbConn, jsonReq: JsonNode): JsonNode =
  resetAreaEnemies(db)

  let changedResources = Resources(
    status: some(getUserStatusTypeSafe(db)),
    characters: some(healCharactersTypeSafe(db)),
  )

  return %*{
    "changedResources": changedResources
  }


proc adventure_ReleaseEventLift*(jsonReq: JsonNode): JsonNode =
  return %*{
    "changedResources": {}
  }


proc adventure_AreaObject*(db: DbConn, jsonReq: JsonNode): JsonNode =
  let areaId = jsonReq["areaId"].getInt()
  let rows = db.getAllRows(sql"""
    SELECT areaObjectId, areaPointId, areaObjectBehaviorId, action
    FROM areaObjects
    WHERE areaId = ?
  """, areaId)

  var areaObjects = newSeq[JsonNode]();

  if areaId == 130801: # Mita's Hideout
    areaObjects = getLuxPhantasmaAreaObjects()

  # FIXME: put this in another function

  for row in rows:
    let areaObject = parseAreaObjectRow(row)
    areaObjects.add(areaObject)

  let enemyRows = db.getAllRows(sql"""
    SELECT areaPointId, areaEnemyRateSetId, action
    FROM areaEnemies
    WHERE areaId = ?
  """, areaId)

  for row in enemyRows:
    let areaEnemy = parseAreaEnemyRow(row)
    areaObjects.add(areaEnemy)

  var areaItemsRes = newSeq[JsonNode]()

  let areaItems = db.getAllRows(sql"SELECT areaItemId FROM areaItems WHERE areaId = ?", areaId)

  for areaItem in areaItems:
    areaItemsRes.add(%*{"areaItemId": parseInt(areaItem[0])})

  let dummyAreaObjects = getDummyAreaObjects(db, areaId)

  areaObjects.insert((%*dummyAreaObjects).getElems(), areaObjects.len)

  return %*{"areaObjects": areaObjects, "areaItems": areaItemsRes}


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


proc adventure_UpdateCharacterStatus*(db: DbConn, jsonReq: JsonNode): JsonNode =
  var changedCharacters = newSeq[Character]()

  for characterUpdate in jsonReq["characterUpdates"]:
    let characterId = characterUpdate["characterId"].getInt()
    let hp = characterUpdate["hp"].getInt()

    setCharacterHp(db, characterId, hp)

    let character = getCharacter(db, characterId)
    changedCharacters.add(character)

  return %*{
    "changedResources": {
      "characters": changedCharacters
    }
  }


proc adventure_ReadSequence*(db: DbConn, jsonReq: JsonNode): JsonNode =
  let sequenceRequestIds = to(
    jsonReq.getOrDefault("sequenceRequestIds"), Option[seq[int]]
  ).get(@[])

  let nineSequences = to(
    jsonReq.getOrDefault("nineSequences"), Option[seq[NineSequenceRequest]]
  ).get(@[])

  let areaKeyId = jsonReq["areaKeyId"].getInt()

  if sequenceRequestIds.len > 0:
    let seqReqId = sequenceRequestIds[0]
    let row = db.getRow(sql"""
      SELECT areaObjects, changedResources FROM readSequence WHERE sequenceRequestId=?
    """, seqReqId);

    # FIXME: this should be in a separate function
    result = parseReadSequenceRow(row)

    if seqReqId == 80001521:
      let deletedCharacterIds = [100201, 101701]
      result["deletedCharacterIds"] = %*deletedCharacterIds
      deleteGuestCharacters(db, deletedCharacterIds)

    const talkWithEnokiSeqReqId = 80100431
    const talkWithMiuSeqReqId = 80100432

    if seqReqId in [80100421, 80100422, talkWithEnokiSeqReqId, talkWithMiuSeqReqId]:
      changeReadSequenceResponse(db, seqReqId, result)
      changeNineSequences(db, nineSequences, result)
      changeAdventureVariables(db, sequenceRequestIds, result)

    updateFromReadSequenceResponse(db, result)

    let readSequenceAreaAction = getReadSequenceAreaAction(db, seqReqId)

    if readSequenceAreaAction.areaId != 0:
      updateActionSequenceId(db, readSequenceAreaAction.areaId, readSequenceAreaAction.actionSequenceId)

    let readSequenceAreaBgm = getReadSequenceAreaBgm(db, seqReqId)

    if readSequenceAreaBgm.areaId != 0:
      updateAreaBgm(db, readSequenceAreaBgm.areaId, readSequenceAreaBgm.id, readSequenceAreaBgm.eventName)
  else:
    let nineSequenceId = nineSequences[0].id
    let row = db.getRow(sql"""
      SELECT areaObjects, changedResources FROM readSequence WHERE nineSequenceId=?
    """, nineSequenceId);
    result = parseReadSequenceRow(row)
    updateFromReadSequenceResponse(db, result)

    # TODO: does a nineSequence change an area action like in the other branch of the if?


proc adventure_AcquireAreaItem*(db: DbConn, jsonReq: JsonNode): JsonNode =
  let areaItemId = jsonReq["areaItemId"].getInt()

  var rewards = getAreaItemRewards(db, areaItemId)

  let changedResources = updateResourcesFromRewards(db, rewards[0].contents)

  return %*{
    "areaItem": {
      "areaItemId": areaItemId,
      "acquired": true
    },
    "rewards": rewards,
    "changedResources": changedResources
  }


proc adventure_Hospital*(db: DbConn): JsonNode =
  let status = getUserStatusTypeSafe(db)
  let changedCharacters = healCharacters(db)

  return %*{
    "changedResources": {
      "characters": changedCharacters,
      "status": status
    }
  }


proc adventure_AccessWarpPoint*(db: DbConn, jsonReq: JsonNode): AdventureAccessWarpPointResponse =
  let warpPointId = jsonReq["warpPointId"].getInt()

  var changedTutorialStates = newSeq[JsonNode]()
  var changedWarpPoints = newSeq[JsonNode]()
  let status = getUserStatusTypeSafe(db)

  if not getTutorialState(db, respiteUnitTutorialStatusKey):
    updateTutorialState(db, respiteUnitTutorialStatusKey, true)
    changedTutorialStates.add(%*{
      "tutorialStatusKey": respiteUnitTutorialStatusKey,
      "enabled": true
    })

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
      tutorialStates: some(changedTutorialStates),
      status: some(status),
      characters: some(healCharactersTypeSafe(db)),
    ),
    areaObjects: areaObjects,
  )


proc adventure_FindGraffiti*(db: DbConn, req: AdventureFindGraffitiRequest): AdventureFindGraffitiResponse =
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