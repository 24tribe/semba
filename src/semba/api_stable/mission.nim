import std/sequtils
import std/tables

import db_connector/db_sqlite

import ../model_stable/challenge
import ../model_stable/challenge_progress
import ../model_stable/challenge_task
import ../model_stable/mission
import ../model_stable/nine_sequence
import ../model_stable/resources
import ../model_stable/reward


type MissionReceiveRequest* = object
  missionIds*: seq[int]

type MissionReceiveResponse* = object
  changedResources*: Resources
  rewards*: seq[Reward]

type MissionCountRewardReceiveRequest* = object  
  missionCountRewardId*: int

type MissionCountRewardReceiveResponse* = object
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

    let completedSteps = steps.filterIt(mission.count >= it[1].count)

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

  var changedResources = updateResourcesFromRewardsTypeSafe(db, rewards, unused)
  changedResources.missions = changedMissions

  # TODO: do something with the area objects?
  let (
    _,
    challenges, challengeProgresses, challengeTasks,
    nineSequences
  ) = getChangedResourcesFromTotalTasks(
    db, changedResources.totalTasks
  )

  changedResources.challenges = challenges
  upsertChallenges(db, challenges)

  changedResources.challengeProgresses = challengeProgresses
  upsertChallengeProgresses(db, challengeProgresses)

  changedResources.challengeTasks = challengeTasks
  upsertChallengeTasks(db, challengeTasks)

  changedResources.nineSequences = nineSequences
  updateNineSequences(db, nineSequences)

  result.changedResources = changedResources
  result.rewards = rewards
