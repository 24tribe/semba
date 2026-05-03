import std/sequtils
import std/json

import ../db_connector/db_sqlite

import ../model_stable/resources
import ../model_stable/happy_worker
import ../model_stable/city


type HappyWorkerListResponse* = object
  happyWorkerItems: seq[HappyWorkerItem]
  changedResources: Resources

type HappyWorkerStartRequest* = object
  happyWorkerItemId*: int

type HappyWorkerStartResponse* = object
  happyWorkerItem*: HappyWorkerItem
  changedResources*: Resources


proc happy_worker_List*(db: DbConn): HappyWorkerListResponse =
  let cityIds = getCities(db).mapIt(to(it, City).cityId).toSeq()

  result.happyWorkerItems = getHappyWorkerItems(db, cityIds)


proc happy_worker_Start*(db: DbConn, req: HappyWorkerStartRequest): HappyWorkerStartResponse =
  result.happyWorkerItem.happyWorkerItemId = req.happyWorkerItemId
  result.happyWorkerItem.state = 5

  updateHappyWorkerItem(db, result.happyWorkerItem)