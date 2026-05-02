import std/json

import ../db_connector/db_sqlite

import ../model_stable/timestamp
import ../model_stable/resources


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
  discard