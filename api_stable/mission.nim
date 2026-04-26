import ../db_connector/db_sqlite

import ../model_stable/resources
import ../model_stable/reward


type MissionReceiveRequest* = object
  missionIds*: seq[int]

type MissionReceiveResponse* = object
  changedResources*: Resources
  rewards*: seq[Reward]


proc mission_Receive*(db: DbConn, req: MissionReceiveRequest): MissionReceiveResponse =
  discard