import std/options
import std/strutils
import std/json

import ../db_connector/db_sqlite

import ../extsqlite
import ../semba_error
import timestamp
import reward
import entity


type GearRarity* = enum
  gearRarityInvalid = 0
  gearRarityN = 1
  gearRarityR = 2
  gearRaritySr = 3
  gearRaritySsr = 4

type Gear* = object
  entityId*: int
  gearId*: int
  receivedAt*: Timestamp
  rarity*: int
  isLocked*: Option[bool]
  subStatus1Id*: Option[int]
  subStatus2Id*: Option[int]
  subStatus3Id*: Option[int]
  trainingScoreLevelScore*: Option[int]


proc addGear*(db: DbConn, gear: Gear) =
  db.exec(
    sql"""
      INSERT INTO gears (
        entityId, gearId, receivedAt, rarity, isLocked,
        subStatus1Id, subStatus2Id, subStatus3Id, trainingScoreLevelScore
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
    """,
    gear.entityId, gear.gearId, gear.receivedAt, gear.rarity, optionToSqlArg(gear.isLocked),
    optionToSqlArg(gear.subStatus1Id), optionToSqlArg(gear.subStatus2Id), optionToSqlArg(gear.subStatus3Id),
    optionToSqlArg(gear.trainingScoreLevelScore)
  )


proc getGear*(db: DbConn, entityId: int): Gear =
  let row = db.getRow(sql"""
    SELECT gearId, receivedAt, rarity, isLocked, subStatus1Id, subStatus2Id, subStatus3Id, trainingScoreLevelScore
    FROM gears WHERE entityId = ?
  """, entityId)

  if row[0] == "":
    raise newException(SembaError, "Couldn't get gear with entityId=" & $entityId)

  result = Gear(
    entityId: entityId,
    gearId: parseInt(row[0]),
    receivedAt: row[1].Timestamp,
    rarity: parseInt(row[2]),
    isLocked: tryParseBool(row[3]),
    subStatus1Id: tryParseInt(row[4]),
    subStatus2Id: tryParseInt(row[5]),
    subStatus3Id: tryParseInt(row[6]),
    trainingScoreLevelScore: tryParseInt(row[7]),
  )


proc getGears*(db: DbConn): seq[Gear] =
  let rows = db.getAllRows(sql"SELECT entityId FROM gears")

  for row in rows:
    result.add(getGear(db, parseInt(row[0])))


proc getGearReward(db: DbConn): Reward = 
  result = Reward(
    `type`: rewardGear.int,
    id: 30001201,
    quantity: 1,
    entityId: some(popEntityId(db)),
    resourceParams: some(to(%*{
      "gearRewardStatus": {
        "subStatusIds": [
          11011006,
          10099001,
          10021002
        ],
        "gearRarity": 4
      }
    }, ResourceParams)),
    isNew: some(true),
  )


proc randomGear*(db: DbConn): (Gear, Reward) =
  let reward = getGearReward(db)

  let gear = Gear(
    entityId: reward.entityId.get(),
    gearId: reward.id,
    receivedAt: getTimestampNow(),
    subStatus1Id: some(reward.resourceParams.get().gearRewardStatus.get().subStatusIds.get()[0]),
    subStatus2Id: some(reward.resourceParams.get().gearRewardStatus.get().subStatusIds.get()[1]),
    subStatus3Id: some(reward.resourceParams.get().gearRewardStatus.get().subStatusIds.get()[2]),
    trainingScoreLevelScore: some(1),
    rarity: reward.resourceParams.get().gearRewardStatus.get().gearRarity
  )

  result = (gear, reward)