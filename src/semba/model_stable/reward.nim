import std/options
import std/strutils
import std/random
import std/json
import std/sequtils

import db_connector/db_sqlite
import ../semba_error
import ../protojson


type RewardType* = enum
  rewardInvalid = 0
  rewardFreeGem = 1
  rewardPaidGem = 2
  rewardGold = 3
  rewardCharacter = 4
  rewardCharacterPiece = 5
  rewardGear = 6
  rewardItem = 7
  rewardStamina = 8
  rewardTensionCard = 9
  rewardUserRankExp = 10
  rewardCharacterCostume = 11
  rewardSeasonPassExp = 12
  rewardCharacterExp = 13
  rewardFlowerMark = 15
  rewardProfileBadge = 16
  rewardProfileBanner = 17
  rewardMountingPower = 19
  rewardSynthesisRecipe = 20
  rewardMysteryBox = 21
  rewardCostumeToken = 22
  rewardGearDrop = 23
  rewardGemCost = 24
  rewardMagicOrb = 25
  rewardCharacterSpecificDrop = 26

type GearRewardStatus* = object
  subStatusIds*: Option[seq[int]]
  gearRarity*: int

type GearSubStatus* = object
  gearStatusRateSetIds*: Option[seq[int]]

type ResourceParams* = object
  oldLimitBreak*: Option[int]
  newLimitBreak*: Option[int]
  gearRewardStatus*: Option[GearRewardStatus]
  gearSubStatusDraw*: Option[GearSubStatus]
  mysteryBoxDrawResults*: Option[JsonNode] # FIXME: use MysteryBoxDrawResults

type Resource* = object
  `type`*: int
  id*: int
  quantity*: int
  resourceParams*: Option[ResourceParams]

type Reward* = object
  `type`*: int
  id*: int
  quantity*: int
  entityId*: Option[int]
  resourceParams*: Option[ResourceParams]
  isNew*: Option[bool]
  isBonus*: Option[bool]
  overflowed*: Option[bool]
  discardedQuantity*: Option[int]
  sentAsMail*: Option[bool]
  oldValue*: Option[int]
  otherRewards*: Option[seq[Reward]]

type Rewards* = object
  `type`*: Option[int]
  contents*: seq[Reward]

type MdReward* = object
  `id`*: int
  quantity*: int
  `type`*: int

type MdRewardSet* = object
  `id`*: int
  rewards*: seq[MdReward]


let enigmaticRemnentId* = 105


proc getMdRewardSet*(db: DbConn, rewardSetId: int): MdRewardSet =
  let row = db.getRow(sql"SELECT rewards FROM mdRewardSet WHERE id = ?", rewardSetId)

  if row[0] == "":
    raise newException(SembaError, "Couldn't get reward set for id=" & $rewardSetId)

  result = MdRewardSet(`id`: rewardSetId, rewards: protoJsonTo(parseJson(row[0]), seq[MdReward]))


proc getMdRatedRewardSet*(db: DbConn, ratedRewardSetId: int): MdRewardSet =
  let rewards = db.getAllRows(sql"""
    SELECT rewardId, rewardQuantity, rewardType FROM mdRatedRewardSet
    WHERE id = ?
  """, ratedRewardSetId).mapIt(MdReward(
    id: parseInt(it[0]),
    quantity: parseInt(it[1]),
    `type`: parseInt(it[2]),
  ))

  MdRewardSet(id: ratedRewardSetId, rewards: rewards)


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


proc shouldHaveEntityId*(rewardType: RewardType): bool =
  case rewardType:
  of rewardGear, rewardTensionCard:
    true
  else:
    false