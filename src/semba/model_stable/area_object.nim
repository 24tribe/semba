import std/json
import std/strutils
import std/options
import std/sets
import std/sequtils
import std/tables

import db_connector/db_sqlite

import ../protojson
import ../extsqlite


type AreaObjectBehaviorConditionType* = enum
  areaObjectConditionTypeStartedChallengeProgress = 1
  areaObjectConditionTypeClearedChallengeProgress = 2
  areaObjectConditionTypeClearedChallengeTask = 3
  areaObjectConditionTypeAreaObjectState = 4
  areaObjectConditionTypeFlowerMark = 11

type AreaObjectActionType* = enum
  areaObjectActionTypeSequence = 3
  areaObjectActionTypeDisabled = 7

type AreaObjectAction* = object
  `type`*: int
  id*: Option[int]
  label*: Option[string]
  areaItemId*: Option[int]
  areaEnemyId*: Option[int]
  battleEntryId*: Option[int]
  sequenceId*: Option[int]
  graffitiArtId*: Option[int]
  warpPointId*: Option[int]
  fieldBossId*: Option[int]
  dungeonId*: Option[int]
  eventLiftId*: Option[int]

type AreaObject* = object
  areaObjectId*: Option[int]
  areaPointId*: int
  areaObjectBehaviorId*: Option[int]
  areaEnemyRateSetId*: Option[int]
  action*: Option[AreaObjectAction]

type MdAreaObjectBehaviorCondition* = object
  areaObjectId*: Option[int]
  areaObjectState*: Option[int]
  id*: Option[int]
  `type`*: int

type MdAreaObjectBehavior* = object
  id*: int
  areaObjectId*: Option[int]
  areaPointId*: int
  condition*: Option[MdAreaObjectBehaviorCondition]
  action*: Option[AreaObjectAction]
  priority*: int


proc getAreaObjects*(db: DbConn): seq[JsonNode] =
  let rows = db.getAllRows(sql"""
    SELECT areaId, areaObjectId, areaPointId, areaObjectBehaviorId, action
    FROM areaObjects
  """)

  for row in rows:
    let areaId = parseInt(row[0])
    let areaObjectId = parseInt(row[1])
    let areaPointId = parseInt(row[2])
    let areaObjectBehaviorId = parseInt(row[3])
    var action: JsonNode = nil

    if row[4] != "":
      action = parseJson(row[4])

    let areaObject = %*{
      "areaId": areaId,
      "areaObjectId": areaObjectId,
      "areaPointId": areaPointId,
      "areaObjectBehaviorId": areaObjectBehaviorId,
    }

    if action != nil:
      areaObject["action"] = action

    result.add(areaObject)


proc addAreaObject*(db: DbConn, areaObject: JsonNode) =
  let areaId = areaObject["areaId"].getInt()
  let areaObjectId = areaObject["areaObjectId"].getInt()
  let areaPointId = areaObject["areaPointId"].getInt()
  let areaObjectBehaviorId = areaObject["areaObjectBehaviorId"].getInt()
  let action = areaObject.getOrDefault("action")
  let actionStr = if action != nil: $action else: ""

  db.exec(sql"""
    INSERT INTO areaObjects (areaId, areaObjectId, areaPointId, areaObjectBehaviorId, action)
    VALUES (?, ?, ?, ?, ?)
  """, areaId, areaObjectId, areaPointId, areaObjectBehaviorId, actionStr)


proc addAreaEnemy*(db: DbConn, areaEnemy: JsonNode) =
  let areaId = areaEnemy["areaId"].getInt()
  let areaPointId = areaEnemy["areaPointId"].getInt()
  let areaEnemyRateSetId = areaEnemy["areaEnemyRateSetId"].getInt()
  let action = $(areaEnemy["action"])

  db.exec(sql"""
    INSERT INTO areaEnemies (areaId, areaPointId, areaEnemyRateSetId, action)
    VALUES (?, ?, ?, ?)
  """, areaId, areaPointId, areaEnemyRateSetId, action)


proc getAreaEnemies*(db: DbConn): seq[JsonNode] =
  let rows = db.getAllRows(sql"""
    SELECT areaId, areaPointId, areaEnemyRateSetId, action
    FROM areaEnemies
  """)

  for row in rows:
    let areaId = parseInt(row[0])
    let areaPointId = parseInt(row[1])
    let areaEnemyRateSetId = parseInt(row[2])
    let action = parseJson(row[3])

    let areaEnemy = %*{
      "areaId": areaId,
      "areaPointId": areaPointId,
      "areaEnemyRateSetId": areaEnemyRateSetId,
      "action": action 
    }

    result.add(areaEnemy)


proc getAreaEnemiesInArea*(db: DbConn, areaId: int): seq[AreaObject] =
  let rows = db.getAllRows(sql"""
    SELECT areaPointId, areaEnemyRateSetId, action
    FROM areaEnemies WHERE areaId = ?
  """, areaId)

  for row in rows:
    result.add(AreaObject(
      areaPointId: parseInt(row[0]),
      areaEnemyRateSetId: some(parseInt(row[1])),
      action: some(protoJsonTo(parseJson(row[2]), AreaObjectAction)),
    ))


proc getOriginalAreaEnemies*(db: DbConn, areaId: int): seq[AreaObject] =
  let rows = db.getAllRows(sql"""
    SELECT areaPointId, areaEnemyRateSetId, action
    FROM areaEnemiesOriginal WHERE areaId = ?
  """, areaId)

  for row in rows:
    result.add(AreaObject(
      areaPointId: parseInt(row[0]),
      areaEnemyRateSetId: some(parseInt(row[1])),
      action: some(protoJsonTo(parseJson(row[2]), AreaObjectAction)),
    ))


proc getRespawnAreaEnemies*(db: DbConn, areaId: int): seq[AreaObject] =
  let areaEnemies = getAreaEnemiesInArea(db, areaId).toHashSet()
  let origAreaEnemies = getOriginalAreaEnemies(db, areaId).toHashSet()
  result = (origAreaEnemies - areaEnemies).toSeq()


# FIXME: this should not be called directly by adventure_AreaObject
proc parseAreaEnemyRow*(row: Row): JsonNode =
  let areaPointId = parseInt(row[0])
  let areaEnemyRateSetId = parseInt(row[1])
  let action = parseJson(row[2])

  result = %*{
    "areaPointId": areaPointId,
    "areaEnemyRateSetId": areaEnemyRateSetId,
    "action": action 
  }


proc getAreaObjectAction*(db: DbConn, areaObjectBehaviorId: int): Option[AreaObjectAction] =
  let row = db.getRow(sql"""
    SELECT areaObjectBehaviorId, areaEnemyId, areaItemId, battleEntryId,
           dungeonId, eventLiftId, fieldBossId, graffitiArtId, id, label_en,
           sequenceId, type, warpPointId
    FROM mdAreaObjectBehaviorAction
    WHERE areaObjectBehaviorId = ?
  """, areaObjectBehaviorId)

  if row[0] != "":
    result = some(AreaObjectAction(
      areaEnemyId: tryParseInt(row[1]),
      areaItemId: tryParseInt(row[2]),
      battleEntryId: tryParseInt(row[3]),
      dungeonId: tryParseInt(row[4]),
      eventLiftId: tryParseInt(row[5]),
      fieldBossId: tryParseInt(row[6]),
      graffitiArtId: tryParseInt(row[7]),
      id: tryParseInt(row[8]),
      label: if row[9] != "": some(row[9]) else: none(string),
      sequenceId: tryParseInt(row[10]),
      `type`: parseInt(row[11]),
      warpPointId: tryParseInt(row[12]),
    ))


proc getAreaObjectsForState*(db: DbConn, areaObjectId: int, areaObjectState: int): seq[AreaObject] =
  let rows = db.getAllRows(sql"""
    SELECT mdAreaObjectBehavior.id, mdAreaObjectBehavior.areaObjectId, mdAreaObjectBehavior.areaPointId
    FROM mdAreaObjectBehavior
    INNER JOIN mdAreaObjectBehaviorCondition
    ON mdAreaObjectBehavior.id = mdAreaObjectBehaviorCondition.areaObjectBehaviorId
    WHERE mdAreaObjectBehaviorCondition.type = 4
      AND mdAreaObjectBehaviorCondition.areaObjectId = ?
      AND mdAreaObjectBehaviorCondition.areaObjectState = ?
  """, areaObjectId, areaObjectState)

  for row in rows:
    let areaObjectBehaviorId = parseInt(row[0])
    result.add(AreaObject(
      areaObjectId: tryParseInt(row[1]),
      areaPointId: parseInt(row[2]),
      areaObjectBehaviorId: some(areaObjectBehaviorId),
      action: getAreaObjectAction(db, areaObjectBehaviorId)
    ))


proc getAreaObjectsRelatedTo*(
  db: DbConn, areaObjects: seq[AreaObject]
): Table[int, seq[MdAreaObjectBehavior]] =
  for areaObject in areaObjects:
    result[areaObject.areaPointId] = db.getAllRows(sql"""
      SELECT mdAreaObjectBehavior.id, mdAreaObjectBehavior.areaObjectId,
        mdAreaObjectBehaviorCondition.type, mdAreaObjectBehaviorCondition.id,
        mdAreaObjectBehaviorCondition.areaObjectId, mdAreaObjectBehaviorCondition.areaObjectState,
        mdAreaObjectBehavior.priority
      FROM mdAreaObjectBehavior
      INNER JOIN mdAreaObjectBehaviorCondition
      ON mdAreaObjectBehavior.id = mdAreaObjectBehaviorCondition.areaObjectBehaviorId
      WHERE mdAreaObjectBehavior.areaPointId = ?
    """, areaObject.areaPointId).mapIt(MdAreaObjectBehavior(
      areaPointId: areaObject.areaPointId,
      `id`: parseInt(it[0]),
      areaObjectId: tryParseInt(it[1]),
      condition: (
        if it[2] != "":
          some(MdAreaObjectBehaviorCondition(
            `type`: parseInt(it[2]),
            id: tryParseInt(it[3]),
            areaObjectId: tryParseInt(it[4]),
            areaObjectState: tryParseInt(it[5]),
          ))
        else:
          none(MdAreaObjectBehaviorCondition)
      ),
      action: getAreaObjectAction(db, parseInt(it[0])),
      priority: tryParseInt(it[6]).get(1),
    ))


proc getAreaObjectsWithCondition*(
  db: DbConn, conditionType: AreaObjectBehaviorConditionType, id: int
): seq[AreaObject] =
  let rows = db.getAllRows(sql"""
    SELECT mdAreaObjectBehavior.id, mdAreaObjectBehavior.areaObjectId, mdAreaObjectBehavior.areaPointId
    FROM mdAreaObjectBehavior
    INNER JOIN mdAreaObjectBehaviorCondition
    ON mdAreaObjectBehavior.id = mdAreaObjectBehaviorCondition.areaObjectBehaviorId
    WHERE mdAreaObjectBehaviorCondition.type = ? AND mdAreaObjectBehaviorCondition.id = ?
  """, conditionType.int, id)

  for row in rows:
    let areaObjectBehaviorId = parseInt(row[0])
    result.add(AreaObject(
      areaObjectId: tryParseInt(row[1]),
      areaPointId: parseInt(row[2]),
      areaObjectBehaviorId: some(areaObjectBehaviorId),
      action: getAreaObjectAction(db, areaObjectBehaviorId)
    ))


proc areaPointIdToAreaId(areaPointId: int): int = areaPointId div 1000


proc updateAreaObjectsEx*(db: DbConn, areaObjects: seq[AreaObject]) =
  for areaObject in areaObjects:
    let areaId = areaPointIdToAreaId(areaObject.areaPointId)

    if areaObject.areaObjectId.isSome():
      let areaObjectId = areaObject.areaObjectId.get()
      let areaObjectBehaviorId = areaObject.areaObjectBehaviorId.get()
      let action = $(%*areaObject.action.get())

      db.exec(sql"DELETE FROM areaObjects WHERE areaObjectId = ?", areaObjectId)
      db.exec(sql"""
        INSERT INTO areaObjects (areaId, areaObjectId, areaPointId, areaObjectBehaviorId, action)
        VALUES (?, ?, ?, ?, ?)
      """, areaId, areaObjectId, areaObject.areaPointId, areaObjectBehaviorId, action)
    elif areaObject.areaEnemyRateSetId.isSome():
      let areaEnemyRateSetId = areaObject.areaEnemyRateSetId.get()
      let action = $(%*areaObject.action.get())

      db.exec(sql"""
        INSERT INTO areaEnemies (areaId, areaPointId, areaEnemyRateSetId, action)
        VALUES (?, ?, ?, ?)
        ON CONFLICT (areaPointId) DO
        UPDATE SET areaEnemyRateSetId = excluded.areaEnemyRateSetId,
                   action = excluded.action
      """, areaId, areaObject.areaPointId, areaEnemyRateSetId, action)


proc updateAreaObjects*(db: DbConn, areaObjects: JsonNode) =
  for areaObject in areaObjects:
    let areaPointId = areaObject["areaPointId"].getInt()
    let areaId = areaPointIdToAreaId(areaPointId)
    let areaEnemyRateSetId = areaObject.getOrDefault("areaEnemyRateSetId")
    let action = $(areaObject["action"])

    if areaEnemyRateSetId == nil or areaEnemyRateSetId.kind == JNull:
      let areaObjectId = areaObject["areaObjectId"].getInt()
      let areaObjectBehaviorId = areaObject["areaObjectBehaviorId"].getInt()

      db.exec(sql"""
        INSERT INTO areaObjects (areaId, areaObjectId, areaPointId, areaObjectBehaviorId, action)
        VALUES (?, ?, ?, ?, ?)
        ON CONFLICT (areaId, areaObjectId) DO
        UPDATE SET areaPointId = excluded.areaPointId,
                  areaObjectBehaviorId = excluded.areaObjectBehaviorId,
                  action = excluded.action
      """, areaId, areaObjectId, areaPointId, areaObjectBehaviorId, action)
    else:
      db.exec(sql"""
        INSERT INTO areaEnemies (areaId, areaPointId, areaEnemyRateSetId, action)
        VALUES (?, ?, ?, ?)
        ON CONFLICT (areaPointId) DO
        UPDATE SET areaEnemyRateSetId = excluded.areaEnemyRateSetId,
                   action = excluded.action
      """, areaId, areaPointId, areaEnemyRateSetId, action)


proc removeAreaObject*(db: DbConn, areaKeyId: int, triggerId: int) =
  db.exec(sql"DELETE FROM areaObjects WHERE areaId=? AND areaObjectBehaviorId=?", areaKeyId, triggerId);

proc removeAreaEnemy*(db: DbConn, areaKeyId: int, triggerId: int) =
  db.exec(sql"DELETE FROM areaEnemies WHERE areaId=? AND areaPointId=?", areaKeyId, triggerId);


proc getBattleFinishAreaObjects*(db: DbConn, battleEntryId: int): seq[AreaObject] =
  let row = db.getRow(
    sql"SELECT areaObjects FROM battleFinishAreaObjects WHERE battleEntryId = ?", battleEntryId
  )

  if row[0] != "":
    protoJsonTo(parseJson(row[0]), seq[AreaObject])
  else:
    newSeq[AreaObject]()


proc getDummyAreaObjects*(db: DbConn, areaId: int): seq[AreaObject] =
  let rows = db.getAllRows(sql"""
    SELECT areaPointId, areaObjectBehaviorId, action FROM dummyAreaObjects
    WHERE areaId = ?
  """, areaId)

  for row in rows:
    result.add(AreaObject(
      areaPointId: parseInt(row[0]),
      areaObjectBehaviorId: some(parseInt(row[1])),
      action: some(protoJsonTo(parseJson(row[2]), AreaObjectAction))
    ))


proc resetAreaEnemies*(db: DbConn) =
  db.exec(sql"DELETE FROM areaEnemies")
  db.exec(sql"INSERT INTO areaEnemies SELECT * FROM areaEnemiesOriginal")


proc getAreaObjectsInArea*(db: DbConn, areaId: int): seq[AreaObject] =
  let rows = db.getAllRows(sql"""
    SELECT areaObjectId, areaPointId, areaObjectBehaviorId, action
    FROM areaObjects
    WHERE areaId = ?
  """, areaId)

  rows.mapIt(AreaObject(
    areaObjectId: some(parseInt(it[0])),
    areaPointId: parseInt(it[1]),
    areaObjectBehaviorId: some(parseInt(it[2])),
    action: if it[3] != "": some(protoJsonTo(parseJson(it[3]), AreaObjectAction)) else: none(AreaObjectAction),
  ))


proc unlockFullMarksGates*(db: DbConn, flowerMark: int) =
  db.exec(sql"""
    UPDATE areaObjects
      SET action='{"type": 7, "id": 1}'
      FROM (
        SELECT mdAreaObjectBehavior.areaObjectId
          FROM mdAreaObjectBehavior
          JOIN mdAreaObjectBehaviorCondition
          ON mdAreaObjectBehavior.id = mdAreaObjectBehaviorCondition.areaObjectBehaviorId
          WHERE mdAreaObjectBehaviorCondition.type = 11 AND ? >= mdAreaObjectBehaviorCondition.id
      ) AS unlockedGateAreaBehavior
      WHERE areaObjects.areaObjectId = unlockedGateAreaBehavior.areaObjectId
  """, flowerMark)


proc deleteAreaObjectsWithIds*(db: DbConn, areaObjectIds: openArray[int]) =
  db.exec(sql("""
    DELETE FROM areaObjects WHERE areaObjectId IN """ & sqlIntTuple(areaObjectIds)
  ))


proc checkAreaObjectBehaviorCondition*(
  maybeAobc: Option[MdAreaObjectBehaviorCondition], areaObjectId: int, areaObjectState: int, flowerMarks: int
): bool =
  if maybeAobc.isSome:
    let aobc = maybeAobc.get()
    case aobc.`type`:
    of areaObjectConditionTypeAreaObjectState.int:
      # TODO: we should also check in the db but we don't save the area object states (yet?)
      return aobc.areaObjectId.get() == areaObjectId and aobc.areaObjectState.get() == areaObjectState
    of areaObjectConditionTypeFlowerMark.int:
      return flowerMarks >= aobc.id.get()
    else:
      # Assume it doesn't pass the check
      return false
  else:
    # no condition means OK
    return true


proc getTheHighestPriority*(aobs: openArray[MdAreaObjectBehavior]): MdAreaObjectBehavior =
  aobs.max(proc (a, b: MdAreaObjectBehavior): int = a.priority - b.priority)


proc toAreaObject*(aob: MdAreaObjectBehavior): AreaObject =
  AreaObject(
    areaObjectBehaviorId: some(aob.id),
    areaObjectId: aob.areaObjectId,
    areaPointId: aob.areaPointId,
    action: aob.action,
  )
