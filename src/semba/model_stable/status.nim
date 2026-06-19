import std/options
import std/json

import db_connector/db_sqlite
import ../protojson

import timestamp


type PositionCoordinates* = object
  x*: Option[float]
  y*: Option[float]
  z*: Option[float]

type CurrentLocation* = object
  areaType*: Option[int]
  areaKeyId*: Option[int]
  positionCoordinates*: Option[PositionCoordinates]
  direction*: Option[int]

type Status* = object
  exp*: Option[int]
  rank*: int
  gold*: int
  staminaWhenUpdated*: Option[Timestamp]
  staminaUpdatedAt*: Timestamp
  formationNumber*: Option[int]
  currentAreaType*: Option[int]
  currentAreaKeyId*: Option[int]
  currentPositionCoordinates*: Option[PositionCoordinates]
  currentDirection*: Option[int]
  staminaPurchasedCount*: Option[int]
  birthYear*: Option[int]
  birthMonth*: Option[int]
  loggedInAt*: Timestamp
  trackingWarpPointId*: Option[int]
  trackingFieldBossId*: Option[int]
  trackingDungeonId*: Option[int]
  enemyForcedRespawnAt*: Option[Timestamp]
  flowerMark*: int
  dishId*: Option[int]
  dishEffectExpiredAt*: Option[Timestamp]
  dishEffectBaseGearEntityId*: Option[int]
  dishEffectCount*: Option[int]
  costumeToken*: Option[int]


proc getUserStatusTypeSafe*(db: DbConn): Status =
  let statusRow = db.getRow(sql"SELECT val FROM userData WHERE keyName = ?", "status")
  return protoJsonTo(parseJson(statusRow[0]), Status)


proc setUserStatusTypeSafe*(db: DbConn, status: Status) =
  db.exec(sql"UPDATE userData SET val = ? WHERE keyName = ?", %*status, "status")


proc updateStatusFromStatusLocation*(status: var Status, otherStatus: Status) =
  status.currentAreaType = otherStatus.currentAreaType
  status.currentDirection = otherStatus.currentDirection
  status.currentPositionCoordinates = otherStatus.currentPositionCoordinates
  status.currentAreaKeyId = otherStatus.currentAreaKeyId