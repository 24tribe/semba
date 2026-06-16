import std/json
import std/strutils
import std/sequtils
import std/sugar
import std/options
import std/tables

import db_connector/db_sqlite

import ../extsqlite
import ../enum_ex
import ../protojson
import adventure_variable
import area_object
import area_object_lock
import city
import mission
import resources
import reward
import status
import wallet


const fullMarksGateTutorialSeqReqId* = 108369011
const fullMarksGateTutorialSeqId* = 10836901


type MdSequenceRequestKind* = enum
  seqReqInvalid = 0
  seqReqCosts = 1
  seqReqRewards = 3
  seqReqAreaObjectState = 4
  seqReqAdventureVariable = 5
  seqReqAreaChangeLock = 6
  seqReqArea = 7
  seqReqCity = 8
  seqReqAreaGroup = 9
  seqReqUnused1 = 10
  seqReqUnused2 = 11
  seqReqUnused3 = 12
  seqReqUnused4 = 13
  seqReqUnused5 = 14
  seqReqEvent = 15


type MdSequenceRequest* = object
  id*: int
  costs*: seq[Resource]
  rewards*: seq[Resource]
  case kind*: MdSequenceRequestKind
  of seqReqAreaObjectState:
    areaObjectId*: int
    areaObjectState*: int
  of seqReqAdventureVariable:
    adventureVariableId*: int
    variableChangeValue*: int
    variableOperator*: VariableOperator
  of seqReqAreaChangeLock:
    areaChangeLockId*: int
  of seqReqArea:
    areaId*: int
  of seqReqCity:
    cityId*: int
  of seqReqAreaGroup:
    areaGroupId*: int
  of seqReqEvent:
    eventLiftId*: int
  else:
    discard


proc getMdSequenceRequests*(db: DbConn, sequenceRequestIds: openArray[int]): seq[MdSequenceRequest] =
  let rows = db.getAllRows(sql("""
    SELECT id, costs, rewards, type,
      areaObjectId, areaObjectState,
      adventureVariableId, variableChangeValue, variableOperator,
      areaChangeLockId, areaId, cityId, areaGroupId, eventLiftId
    FROM mdSequenceRequest
    WHERE id IN """ & sqlIntTuple(sequenceRequestIds) & """
  """))

  for row in rows:
    var seqReq = MdSequenceRequest(
      id: parseInt(row[0]),
      costs: protoJsonTo(parseJson(row[1]), seq[Resource]),
      rewards: protoJsonTo(parseJson(row[2]), seq[Resource]),
      kind: parseInt(row[3]).intToEnum(MdSequenceRequestKind),
    )

    case seqReq.kind:
    of seqReqAreaObjectState:
      seqReq.areaObjectId = parseInt(row[4])
      seqReq.areaObjectState = parseInt(row[5])
    of seqReqAdventureVariable:
      seqReq.adventureVariableId = parseInt(row[6])
      seqReq.variableChangeValue = parseInt(row[7])
      seqReq.variableOperator = parseInt(row[8]).VariableOperator
    of seqReqAreaChangeLock:
      seqReq.areaChangeLockId = parseInt(row[9])
    of seqReqArea:
      seqReq.areaId = parseInt(row[10])
    of seqReqCity:
      seqReq.cityId = parseInt(row[11])
    of seqReqAreaGroup:
      seqReq.areaGroupId = parseInt(row[12])
    of seqReqEvent:
      seqReq.eventLiftId = parseInt(row[13])
    else:
      discard

    result.add(seqReq)


proc readSequenceMiniGame*(
  db: DbConn, miniGameId: int, sequenceRequestIds: openArray[int], areaId: int
): (Resources, seq[AreaObject]) =
  ## Handles /adventure/read_sequence for a minigame.
  ## Returns the changed resources and area objects in the db.

  let sequenceRequests = getMdSequenceRequests(db, sequenceRequestIds)

  for seqReq in sequenceRequests:
    case seqReq.kind:
    of seqReqAreaObjectState:
      result[1].insert(
        getAreaObjectsForState(db, seqReq.areaObjectId, seqReq.areaObjectState), result[1].len
      )
    else:
      discard

  updateAreaObjectsEx(db, result[1])

  let areaObjectLockId = getAreaObjectLockIdForMiniGame(db, areaId, miniGameId)

  result[0].areaObjectLocks = areaObjectLockId.map(proc (areaObjectLockId: int): seq[AreaObjectLock] =
    @[AreaObjectLock(areaObjectLockId: areaObjectLockId, count: some(1))]
  )

  result[0].areaObjectLocks.map(proc (areaObjectLocks: seq[AreaObjectLock]) =
    upsertAreaObjectLocks(db, areaObjectLocks)
  )

  result[0].status = some(getUserStatusTypeSafe(db))

  let missions = getTroubleshooterMissionsForCity(db, areaIdToCityId(areaId))

  let changedMissions = getMissionsWithNewCount(
    db, missions, (mission, mdMission) => some(mission.count.get(0) + 1)
  )

  result[0].missions = changedMissions

  updateMissions(db, changedMissions)


proc removeProblematicResources(changedResources: var Resources) =
  # Don't return (zero sensei) missions from online logs
  changedResources.missions = @[]

  # Remove wallet changes to avoid gems changing to random amounts in the client.
  # The correct fix here would be to get the rewards from completing a challenge from
  # the master data instead of the online logs, but for now it's okay
  changedResources.wallet = none(Wallet)

  # Don't change the currency items to avoid them changing to random amounts in the client.
  # The correct fix here would be to get the rewards from completing a challenge from
  # the master data instead of the online logs, but for now it's okay
  const tPointItemId = 2
  const stampsItemId = 14
  const boostersItemId = 15
  const problematicItemIds = [tPointItemId, stampsItemId, boostersItemId]

  changedResources.items = changedResources.items.filterIt(not (it.itemId in problematicItemIds))


proc getReplaySequenceFromSequenceRequestId*(db: DbConn, seqReqId: int): (Option[Resources], Option[seq[AreaObject]]) =
  let row = db.getRow(sql"""
    SELECT changedResources, areaObjects FROM readSequence WHERE sequenceRequestId=?
  """, seqReqId)

  var changedResources = tryParseJson(row[0]).map(proc (n: JsonNode): Resources = protoJsonTo(n, Resources))
  let areaObjects = tryParseJson(row[1]).map(proc (n: JsonNode): seq[AreaObject] = protoJsonTo(n, seq[AreaObject]))

  if changedResources.isSome():
    removeProblematicResources(changedResources.get())

  result = (changedResources, areaObjects)


proc getReplaySequenceFromNineSequenceId*(db: DbConn, nineSequenceId: int): (Option[Resources], Option[seq[AreaObject]]) =
  let row = db.getRow(sql"""
    SELECT changedResources, areaObjects FROM readSequence WHERE nineSequenceId=?
  """, nineSequenceId)

  var changedResources = tryParseJson(row[0]).map(proc (n: JsonNode): Resources = protoJsonTo(n, Resources))
  let areaObjects = tryParseJson(row[1]).map(proc (n: JsonNode): seq[AreaObject] = protoJsonTo(n, seq[AreaObject]))

  if changedResources.isSome():
    removeProblematicResources(changedResources.get())

  result = (changedResources, areaObjects)


proc handleSequenceRequestsAreaObjectsExperimental*(db: DbConn, seqReqIds: openArray[int]): seq[AreaObject] =
  let flowerMarks = getUserStatusTypeSafe(db).flowerMark.get(0)
  let mdSequenceRequest = getMdSequenceRequests(db, seqReqIds)

  result = collect:
    for seqReq in mdSequenceRequest:
      if seqReq.kind == seqReqAreaObjectState:
        let areaObjects = getAreaObjectsForState(db, seqReq.areaObjectId, seqReq.areaObjectState)
        let aobTable = getAreaObjectsRelatedTo(db, areaObjects)

        for areaPointId, areaObjectBehaviors in aobTable.pairs:
          let validAreaObjectBehaviors = areaObjectBehaviors.filterIt(
            checkAreaObjectBehaviorCondition(it.condition, seqReq.areaObjectId, seqReq.areaObjectState, flowerMarks)
          )

          if validAreaObjectBehaviors.len > 0:
            validAreaObjectBehaviors.getTheHighestPriority.toAreaObject