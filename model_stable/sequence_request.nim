import std/json
import std/strutils

import ../db_connector/db_sqlite

import ../extsqlite
import ../enum_ex
import ../protojson
import adventure_variable
import reward


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


proc getMdSequenceRequests*(db: DbConn, sequenceRequestIds: seq[int]): seq[MdSequenceRequest] =
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


proc parseReadSequenceRow*(row: Row): JsonNode =
  result = %*{
    "changedResources": {},
    "areaObjects": [],
  }

  if row[0] != "":
    result["areaObjects"] = parseJson(row[0])

  if row[1] != "":
    result["changedResources"] = parseJson(row[1])