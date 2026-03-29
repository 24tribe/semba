import std/options
import std/strutils
import std/random
import std/json

import ../db_connector/db_sqlite


type RewardType* = enum
  rewardCharacter = 4,
  rewardCharacterPiece = 5,
  rewardItem = 7,
  rewardTensionCard = 9

type Reward* = object
  `type`*: int
  id*: int
  quantity*: int
  entityId*: Option[int]
  resourceParams*: Option[JsonNode] # FIXME: ResourceParams
  isNew*: Option[bool]
  isBonus*: Option[bool]
  overflowed*: Option[bool]
  discardedQuantity*: Option[int]
  sentAsMail*: Option[bool]
  oldValue*: Option[int]
  otherRewards*: Option[seq[Reward]]

type Rewards* = object
  `type`*: Option[int]
  contents: seq[Reward]


let enigmaticRemnentId* = 105


proc getRewardGroupIdFromEnemyGroupId*(db: DbConn, enemyGroupId: int): Option[int] =
  let row = db.getRow(
    sql"SELECT rewardGroupId FROM enemyGroupRewards WHERE enemyGroupId = ?", enemyGroupId
  )

  if row[0] != "":
    result = some(parseInt(row[0]))
  else:
    result = none(int)


proc getRandomRewards*(db: DbConn, itemsIds: seq[int]): seq[Reward] =
  var min = 1
  var max = 6

  for itemId in itemsIds:
    let quantity = rand(min .. max)

    if quantity > 0:
      result.add(Reward(`type`: rewardItem.int, id: itemId, quantity: quantity))

    if min > 0:
      min -= 1

    if max > 2:
      max -= 2