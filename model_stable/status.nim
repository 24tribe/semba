import std/options
import std/json

import ../db_connector/db_sqlite

import timestamp


type PositionCoordinates* = object
  x*: Option[float]
  y*: Option[float]
  z*: Option[float]

type Status* = object
  exp*: Option[int]
  rank*: int
  gold*: Option[int]
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
  flowerMark*: Option[int]
  dishId*: Option[int]
  dishEffectExpiredAt*: Option[Timestamp]
  dishEffectBaseGearEntityId*: Option[int]
  dishEffectCount*: Option[int]
  costumeToken*: Option[int]


proc getUserStatusTypeSafe*(db: DbConn): Status =
  let statusRow = db.getRow(sql"SELECT val FROM userData WHERE keyName = ?", "status")
  return to(parseJson(statusRow[0]), Status)


proc setUserStatusTypeSafe*(db: DbConn, status: Status) =
  db.exec(sql"UPDATE userData SET val = ? WHERE keyName = ?", %*status, "status")


proc getUserStatus*(db: DbConn): JsonNode {.deprecated: "use getUserStatusTypeSafe instead".} =
  return %*getUserStatusTypeSafe(db)


proc setUserStatus*(db: DbConn, status: JsonNode) {.deprecated: "use setUserStatusTypeSafe instead".} =
  setUserStatusTypeSafe(db, to(status, Status))