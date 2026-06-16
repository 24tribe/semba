import std/sequtils
import std/tables
import std/options

import db_connector/db_sqlite

import ../model_stable/mission
import ../model_stable/resources
import ../model_stable/reward


type MissionReceiveRequest* = object
  missionIds*: seq[int]

type MissionReceiveResponse* = object
  changedResources*: Resources
  rewards*: seq[Reward]


proc mission_Receive*(db: DbConn, req: MissionReceiveRequest): MissionReceiveResponse =
  let missions = getMissionsWithIds(db, req.missionIds).mapIt((it.missionId, it)).toTable()
  let mdMissions = getMdMissionsWithIds(db, req.missionIds)

  var changedMissions = newSeq[Mission]()
  var rewards = newSeq[Reward]()

  for mdMission in mdMissions:
    var mission = missions[mdMission.id]

    let stepsWithIndex = zip((0 .. mdMission.steps.high).toSeq(), mdMission.steps)

    let steps = stepsWithIndex[mission.receivedStepCount .. stepsWithIndex.high]

    let completedSteps = steps.filterIt(mission.count.get(0) >= it[1].count)

    for completedStep in completedSteps:
      let rewardSet = getMdRewardSet(db, completedStep[1].rewardSetId)
      rewards.insert(rewardSet.rewards.mapIt(Reward(
        `type`: it.`type`, `id`: it.`id`, quantity: it.quantity
      )), rewards.len)

    let receivedStepCount = completedSteps[completedSteps.high][0] + 1

    mission.receivedStepCount = receivedStepCount
    changedMissions.add(mission)

  updateMissions(db, changedMissions)

  var unused: Table[int, int]
  result.changedResources = updateResourcesFromRewardsTypeSafe(db, rewards, unused)
  result.changedResources.missions = changedMissions
  result.rewards = rewards