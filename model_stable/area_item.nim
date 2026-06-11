import std/json
import std/options
import std/random
import std/strutils

import ../db_connector/db_sqlite

import ../semba_error
import ../protojson
import ../model_stable/reward


type AreaItemBaseId* = enum
  areaItemBaseIdRegularChest = 500001
  areaItemBaseIdValuableChest = 500002
  areaItemBaseIdLuxuriousChest = 500003

type AreaItemContentType* = enum
  kaneContentType = 3,
  gearContentType = 6,
  itemContentType = 7,
  charExpContentType = 13

type MdQuantityLottery = object
  quantity: int

type MdQuantityLotteryReward = object
  quantity_lotteries: seq[MdQuantityLottery]
  reward_id: int
  reward_type: int

type MdAreaItemReward = object
  id: int
  quantity_lottery_reward: Option[MdQuantityLotteryReward]

type MdAreaItem* = object
  id*: int
  areaItemRewardIds*: seq[int]
  areaItemBaseId*: int
  cityId*: int

type AreaItem* = object
  areaItemId*: int
  acquired*: bool


proc getMdAreaItem*(db: DbConn, areaItemId: int): MdAreaItem =
  let row = db.getRow(
    sql"SELECT areaItemRewardIds, areaItemBaseId, cityId FROM mdAreaItem WHERE id = ?", areaItemId
  )

  if row[0] == "":
    raise newException(SembaError, "Couldn't find MdAreaItem for areaItemId=" & $areaItemId)

  result = MdAreaItem(
    id: areaItemId,
    areaItemRewardIds: protoJsonTo(parseJson(row[0]), seq[int]),
    areaItemBaseId: parseInt(row[1]),
    cityId: parseInt(row[2]),
  )


proc getMdAreaItemReward(db: DbConn, areaItemRewardId: int): MdAreaItemReward = 
  let row = db.getRow(sql"SELECT id, quantityLotteryReward FROM mdAreaItemReward WHERE id = ?", areaItemRewardId)

  if row[0] == "":
    raise newException(SembaError, "Couldn't find areaItemReward for areaItemRewardId=" & $areaItemRewardId)

  result.id = areaItemRewardId

  if row[1] != "":
    result.quantityLotteryReward = some(protoJsonTo(parseJson(row[1]), MdQuantityLotteryReward))


proc isChestAreaItem*(areaItemBaseId: int): bool =
  case areaItemBaseId:
  of areaItemBaseIdRegularChest.int, areaItemBaseIdValuableChest.int, areaItemBaseIdLuxuriousChest.int:
    true
  else:
    false


proc getAreaItemRewards*(db: DbConn, areaItemRewardIds: seq[int]): seq[Rewards] =
  var rewards = newSeq[Reward]()

  for areaItemRewardId in areaItemRewardIds:
    let reward = getMdAreaItemReward(db, areaItemRewardId)
    # FIXME: follow reward_lottery_group_weight_set_id if quantityLotteryReward isNone
    if reward.quantityLotteryReward.isSome():
      let quantityLotteryReward = reward.quantityLotteryReward.get()
      let quantityLottery = sample(quantityLotteryReward.quantityLotteries)
      if quantityLottery.quantity != 0:
        rewards.add(Reward(
          `type`: quantityLotteryReward.rewardType,
          id: quantityLotteryReward.rewardId,
          quantity: quantityLottery.quantity,
        ))

  result.add(Rewards(`type`: some(5), contents: rewards))