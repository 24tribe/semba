import std/json
import std/options
import std/strutils
import std/random

import ../db_connector/db_sqlite


type RewardType* = enum
  rewardCharacter = 4,
  rewardCharacterPiece = 5,
  rewardItem = 7,
  rewardTensionCard = 9

type Reward* = object
  rewardType*: int
  id*: int
  quantity*: int


let enigmaticRemnentId* = 105


# FIXME: not needed?
proc `%`(reward: Reward): JsonNode =
  result = %*{"type": reward.rewardType, "id": reward.id, "quantity": reward.quantity}


# FIXME: not needed?
proc `%`(rewards: seq[Reward]): JsonNode =
  var res = newSeq[JsonNode]()

  for reward in rewards:
    res.add(%reward)

  result = %*res


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
      result.add(Reward(rewardType: rewardItem.int, id: itemId, quantity: quantity))

    if min > 0:
      min -= 1

    if max > 2:
      max -= 2