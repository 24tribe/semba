import std/json
import std/options
import std/sequtils

import ../db_connector/db_sqlite

import ../model_stable/timestamp
import ../model_stable/resources
import ../model_stable/item
import ../model_stable/shop
import ../model_stable/reward
import ../model_stable/wallet


type ShopGemListResponse* = object
  shopProducts*: seq[JsonNode] # FIXME: use ShopProduct
  storeProducts*: seq[JsonNode] # FIXME: use StoreProduct
  monthlyBillingAmount*: int

type ShopRandomCostumeListResponse* = object
  characterCostumeIds*: seq[int]
  expiresAt: Timestamp

type ShopPurchaseRequest* = object
  shopProductId*: int
  quantity*: int


func shop_GemList*(): ShopGemListResponse =
  discard


proc shop_RandomCostumeList*(): ShopRandomCostumeListResponse =
  result.expiresAt = (now() + 1.months).timestamp


proc shop_Purchase*(db: DbConn, req: ShopPurchaseRequest): ChangedResourcesResponse =
  let shopProduct = getShopProduct(db, req.shopProductId)

  # FIXME: purchase steps with two elements?
  let purchaseStep = shopProduct.purchaseSteps[0]

  # FIXME: Don't know how to handle it yet
  if purchaseStep.storeProductId.isSome():
    return result

  let rewardSetId = purchaseStep.rewardSetId.get()

  let rewardSet = getMdRewardSet(db, rewardSetId)
  var rewards = rewardSet.rewards.mapIt(Reward(`type`: it.`type`, `id`: it.`id`, quantity: it.quantity*req.quantity))

  var changedResources = updateResourcesFromRewardsTypeSafe(db, rewards)

  # FIXME: save on db?
  # FIXME: "the exchangeable items have been updated"
  #[ changedResources.shopProductStates = some(@[ShopProductState(
    shopProductId: req.shopProductId, purchasedCount: req.quantity, nextResetAt: (now() + 1.months).timestamp
  )]) ]#

  for cost in purchaseStep.costs.get(@[]):
    case cost.`type`:
    of rewardPaidGem.int:
      var wallet = changedResources.wallet.get(getWallet(db))
      wallet.paid = some(wallet.paid.get(0) - cost.quantity)
      setWallet(db, wallet)
      changedResources.wallet = some(wallet)
    of rewardCostumeToken.int:
      discard
    of rewardItem.int:
      var item = getItem(db, cost.id).get()
      item.quantity = some(item.quantity.get(0) - cost.quantity*req.quantity)
      upsertItem(db, item)
      changedResources.items.add(item)
    else:
      discard

  result.changedResources = changedResources