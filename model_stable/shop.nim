import std/options
import std/json
import std/sequtils

import ../db_connector/db_sqlite

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


proc getShopProducts*(db: DbConn): seq[ShopProduct] =
  db.getAllRows(sql"SELECT val FROM shopProducts").mapIt(to(parseJson(it[0]), ShopProduct))