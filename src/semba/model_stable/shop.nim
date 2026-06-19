import std/options
import std/json
import std/sequtils

import db_connector/db_sqlite

import ../semba_error
import ../protojson
import timestamp
import reward


type PurchaseStep* = object
  storeProductId*: Option[int]
  rewardSetId*: Option[int]
  costs*: Option[seq[Resource]]
  name*: Option[string]
  description*: Option[string]

type ShopProduct* = object
  id*: int
  shopId*: int
  purchaseSteps*: seq[PurchaseStep]
  dailyPassId*: Option[int]
  limitCount*: Option[int]
  resetCycle*: Option[int]
  resetPeriod*: Option[int]
  priority*: int
  startAt*: Option[Timestamp]
  endAt*: Option[Timestamp]
  imagePath*: Option[string]

type ShopProductState* = object
  shopProductId*: int
  purchasedCount*: int
  nextResetAt*: Timestamp

type MasterData* = object
  shopProducts*: seq[ShopProduct]


proc getShopProducts*(db: DbConn): seq[ShopProduct] =
  db.getAllRows(sql"SELECT val FROM shopProducts").mapIt(protoJsonTo(parseJson(it[0]), ShopProduct))


proc getShopProduct*(db: DbConn, id: int): ShopProduct =
  let row = db.getRow(sql"SELECT val FROM shopProducts WHERE id = ?", id)

  if row[0] == "":
    raise newException(SembaError, "Couldn't get shopProduct with id=" & $id)

  result = protoJsonTo(parseJson(row[0]), ShopProduct)