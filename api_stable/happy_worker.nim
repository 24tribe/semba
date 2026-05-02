import ../model_stable/resources
import ../model_stable/happy_worker


type HappyWorkerListResponse* = object
  happyWorkerItems: seq[HappyWorkerItem]
  changedResources: Resources


proc happy_worker_List*(): HappyWorkerListResponse =
  discard