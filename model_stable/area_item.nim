import std/json
import std/options
import std/random

import ../db_connector/db_sqlite

import ../semba_error
import ../model_stable/reward


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


proc getAreaItemRewardIds(db: DbConn, areaItemId: int): seq[int] =
  let row = db.getRow(sql"SELECT areaItemRewardIds FROM mdAreaItem WHERE id = ?", areaItemId)

  if row[0] == "":
    raise newException(SembaError, "Couldn't find reward ids for areaItemId=" & $areaItemId)

  result = to(parseJson(row[0]), seq[int])


proc getMdAreaItemReward(db: DbConn, areaItemRewardId: int): MdAreaItemReward = 
  let row = db.getRow(sql"SELECT id, quantityLotteryReward FROM mdAreaItemReward WHERE id = ?", areaItemRewardId)

  if row[0] == "":
    raise newException(SembaError, "Couldn't find areaItemReward for areaItemRewardId=" & $areaItemRewardId)

  result.id = areaItemRewardId

  if row[1] != "":
    result.quantityLotteryReward = some(to(parseJson(row[1]), MdQuantityLotteryReward))


proc getAreaItemRewards*(db: DbConn, areaItemId: int): seq[Rewards] =
  let areaItemRewardIds = getAreaItemRewardIds(db, areaItemId)

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