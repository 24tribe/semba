import std/options
import std/strutils

import db_connector/db_sqlite

import reward


type MdEnemy* = object
  id*: int
  dropExp*: int
  attack*: int
  defense*: int
  hp*: int
  hpStackCount*: int

type Enemy* = object
  id*: int
  attack*: int
  defense*: int
  hp*: int
  isSkipEncounterAnimation*: Option[bool]
  hpStackCount*: Option[int]

type MdEnemyLevel* = object
  level*: int
  dropExpFactor*: float
  atkStatusFactor*: float
  defStatusFactor*: float
  hpStatusFactor*: float


proc enemyIdToEnemyGroupId(enemyId: int): int = enemyId div 100


proc getEnemyRewardItemIds*(db: DbConn, enemyId: int): seq[int] =
  let rewardGroupId = getRewardGroupIdFromEnemyGroupId(db, enemyIdToEnemyGroupId(enemyId))

  if rewardGroupId.isSome():
    let pat = $rewardGroupId.get() & "_"
    let rows = db.getAllRows(sql"SELECT id FROM mdItem WHERE id LIKE ?", pat)

    for row in rows:
      let itemId = parseInt(row[0])
      result.add(itemId)