import std/json


type PurchaseHistoryResponse* = object
  histories: seq[JsonNode] # FIXME: use PurchaseHistory


func purchase_History*(): PurchaseHistoryResponse =
  discard