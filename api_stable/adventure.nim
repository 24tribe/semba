import std/json
import std/strutils
import std/options
import std/sequtils
import std/tables

import ../db_connector/db_sqlite

import ../model_stable/timestamp
import ../model_stable/user
import ../model_stable/lux_phantasma
import ../model_stable/area_object
import ../model_stable/area
import ../model_stable/character
import ../model_stable/nine_sequence
import ../model_stable/sequence_request
import ../model_stable/adventure_variable
import ../model_stable/resources
import ../model_stable/area_item
import ../model_stable/tutorial_state
import ../model_stable/warp_point
import ../model_stable/reward
import ../model_stable/gear
import ../model_stable/item
import ../model_stable/graffiti_art
import ../model_stable/wallet
import ../model_stable/formation


type AdventureFindGraffitiRequest* = object
  graffitiArtId: int
  currentLocation: Option[JsonNode] # FIXME: use CurrentLocation

type AdventureFindGraffitiResponse* = object
  rewards*: seq[Reward]
  changedResources*: Resources


proc adventure_WarpAreaLocator*(db: DbConn, jsonReq: JsonNode): JsonNode =
  let status = getUserStatus(db)

  return %*{
    "changedResources": {
      "status": status
    }
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


proc adventure_MoveToArea*(db: DbConn, jsonReq: JsonNode): JsonNode =
  let areaId = jsonReq["areaId"].getInt()

  var status = getUserStatus(db)

  if areaId == 800010:
    return %*{
      "changedResources": {"status": status},
      "areaBgm": {
        "id": 1002,
        "eventName": "bgm_adv_00_basic_01"
      }
    }

  var changedAreas = newSeq[JsonNode]()

  if not hasArea(db, areaId):
    addArea(db, areaId)
    changedAreas.add(%*{"areaId": areaId})

  let currentLocation = jsonReq["currentLocation"]

  let fromAreaId = currentLocation["areaKeyId"].getInt()

  if fromAreaId == areaId:
    updateStatusFromCurrentLocation(status, currentLocation)
  else:
    # FIXME: should update status["currentAreaType"] here
    updatePos(db, status, fromAreaId, areaId)
    status["currentAreaKeyId"] = %*areaId

  setUserStatus(db, status)

  let areaBgm = getAreaBgm(db, areaId)

  let areaChangeLocks = getAreaChangeLocksForAreaId(db, areaId)

  result = %*{
    "areaBgm": areaBgm,
    "areaChangeLocks": areaChangeLocks,
    "changedResources": {
      "status": status,
      "areas": changedAreas
    }
  }

  let actionSequenceId = getActionSequenceId(db, areaId)

  if actionSequenceId != 0:
    result["areaBehavior"] = %*{"actionSequenceId": actionSequenceId}


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

  var gears = newSeq[Gear]()
  var itemsTable: Table[int, Item]

  var status = getUserStatus(db)

  var characters = newSeq[Character]()

  for reward in rewards[0].contents.mitems():
    case reward.`type`.RewardType:
    of rewardGearDrop:
      # FIXME: only golden chests should have a minRarity of gearRaritySsr
      let mdGears = getBalancedGears(db)
      let (gear, gearReward) = randomGear(db, gearRaritySsr.int, mdGears)

      reward = gearReward
      addGear(db, gear)
      gears.add(gear)
    of rewardItem:
      if not (reward.id in itemsTable):
        let item = getItem(db, reward.id)
        itemsTable[reward.id] = item.get(Item(itemId: reward.id, quantity: some(0)))

      itemsTable[reward.id].quantity = some(itemsTable[reward.id].quantity.get(0) + reward.quantity)
    of rewardGold:
      status["gold"] = %*(status.getOrDefault("gold").getInt() + reward.quantity)
    of rewardCharacterExp:
      let formationNumber = status.getOrDefault("formationNumber").getInt()
      let members = getFormationMembers(db, formationNumber)

      let maxExp = getCharacterMaxExp(db)

      if members.character1Id.isSome():
        updateCharacterExp(db, reward.quantity, getCharacter(db, members.character1Id.get()), maxExp)
        characters.add(getCharacter(db, members.character1Id.get()))

      if members.character2Id.isSome():
        updateCharacterExp(db, reward.quantity, getCharacter(db, members.character2Id.get()), maxExp)
        characters.add(getCharacter(db, members.character2Id.get()))

      if members.character3Id.isSome():
        updateCharacterExp(db, reward.quantity, getCharacter(db, members.character3Id.get()), maxExp)
        characters.add(getCharacter(db, members.character3Id.get()))
    else:
      discard

  let items = itemsTable.values().toSeq()
  updateItems(db, items)

  setUserStatus(db, status)

  let changedResources = %*{"gears": gears, "items": items, "status": status, "characters": characters}

  return %*{
    "areaItem": {
      "areaItemId": areaItemId,
      "acquired": true
    },
    "rewards": rewards,
    "changedResources": changedResources
  }


proc adventure_Hospital*(db: DbConn): JsonNode =
  let status = getUserStatus(db)
  let changedCharacters = healCharacters(db)

  return %*{
    "changedResources": {
      "characters": changedCharacters,
      "status": status
    }
  }


proc adventure_AccessWarpPoint*(db: DbConn, jsonReq: JsonNode): JsonNode =
  let warpPointId = jsonReq["warpPointId"].getInt()

  var changedTutorialStates = newSeq[JsonNode]()
  var changedWarpPoints = newSeq[JsonNode]()
  let status = getUserStatus(db)

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

  # TODO: update also missions (zero sensei?), areaObjects and guestCharacters

  return %*{
    "changedResources": {
      "warpPoints": changedWarpPoints,
      "tutorialStates": changedTutorialStates,
      "status": status
    }
  }


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

  result.changedResources.status = some(getUserStatus(db))