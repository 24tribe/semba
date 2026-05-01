import std/json

import ../model_stable/timestamp


type ShopGemListResponse* = object
  shopProducts*: seq[JsonNode] # FIXME: use ShopProduct
  storeProducts*: seq[JsonNode] # FIXME: use StoreProduct
  monthlyBillingAmount*: int

type ShopRandomCostumeListResponse* = object
  characterCostumeIds*: seq[int]
  expiresAt: Timestamp


func shop_GemList*(): ShopGemListResponse =
  discard


proc shop_RandomCostumeList*(): ShopRandomCostumeListResponse =
  result.expiresAt = (now() + 1.months).timestamp