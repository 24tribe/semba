import std/options

import db_connector/db_sqlite

import ../model_stable/status
import ../model_stable/resources


type FieldBossEntryRequest* = object
  fieldBossId*: int
  currentLocation*: CurrentLocation

type FieldBossEntryResponse* = object
  changedResources*: Resources
  prevAccessFieldBossDifficultyId*: Option[int]


proc fieldBoss_Entry*(db: DbConn, req: FieldBossEntryRequest): FieldBossEntryResponse =
  var status = db.getUserStatusTypeSafe()
  status.updateStatusFromCurrentLocation(req.currentLocation)
  db.setUserStatusTypeSafe(status)

  result.changedResources.status = some(status)
