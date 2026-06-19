import std/algorithm
import std/json
import std/options
import std/sequtils
import std/tables

import ./utils
import ../../src/semba/protojson
import ../../src/semba/api_stable/mission
import ../../src/semba/model_stable/area_object
import ../../src/semba/model_stable/area_object_lock
import ../../src/semba/model_stable/challenge_progress
import ../../src/semba/model_stable/city
import ../../src/semba/model_stable/mission
import ../../src/semba/model_stable/timestamp
import ../../src/semba/model_stable/total_task


proc testMissionReceive() =
  var ctx = getInMemorySembaCtx()

  updateMissions(ctx.db, [
    Mission(missionId: 1041041, count: some(155), clearedAt: some(getTimestampNow())),
    Mission(missionId: 1041042, count: some(155), clearedAt: some(getTimestampNow())),
  ])

  let missionIds = [1041041, 1041042]

  let resJson = ctx.sembaCall("/mission/receive", %*{"missionIds": missionIds})

  doAssert(resJson != nil)

  let res = protoJsonTo(resJson, MissionReceiveResponse)

  let changedResources = res.changedResources

  doAssert(changedResources.missions.len > 0)

  let missions = changedResources.missions.mapIt((it.missionId, it)).toTable()

  for missionId in missionIds:
    let mission = missions[missionId]
    doAssert(mission.receivedStepCount == 1)

  doAssert(
    getMissionsWithIds(ctx.db, missionIds).all(proc (mi: Mission): bool = mi.receivedStepCount == 1)
  )

  doAssert(res.rewards.len > 0)
  doAssert(changedResources.status.get().flowerMark == 2)

  let totalTaskIndex = changedResources.totalTasks.findIt(it.conditionId == flowerMarksTotalTaskConditionId)

  doAssert(totalTaskIndex != -1)

  doAssert(changedResources.totalTasks[totalTaskIndex].count == 2.ProtoJsonInt64)


proc testUnlockFullMarkGates() =
  let ctx = getInMemorySembaCtx()

  proc getGate(): AreaObject =
    let areaObjects = protoJsonTo(%*getAreaObjectsInArea(ctx.db, 101103), seq[AreaObject])
    result = areaObjects.filterIt(it.areaPointId == 101103801).toSeq()[0]

  let gateBefore = getGate()

  doAssert(gateBefore.action.get() == AreaObjectAction(
    `type`: 3, id: some(1), label: some("Fence"), sequenceId: some(10836901)
  ))

  unlockFullMarksGates(ctx.db, 17)

  let gateAfter = getGate()

  doAssert(gateAfter.action.get() == AreaObjectAction(`type`: 7, id: some(1)))


proc testSaveFileWithBuggedAreaObjectLocksIsFixed(saves_dir: string) =
  var ctx = getInMemorySembaCtx()

  ctx.loadSaveFile(saves_dir, "after puzzle")

  let locks = getAreaObjectLocks(ctx.db)

  doAssert(locks.findIt(it.areaObjectLockId == 10504002) != -1)

  let shinagawaTroubleshooterMissionIds = [1041065, 1041066]

  let missions = getMissionsWithIds(ctx.db, shinagawaTroubleshooterMissionIds)

  doAssert(missions.len == shinagawaTroubleshooterMissionIds.len)
  doAssert(missions.allIt(it.count == some(1)))


proc testSaveFileWithBuggedGraffitiMissionsIsFixed(saves_dir: string) =
  var ctx = getInMemorySembaCtx()

  ctx.loadSaveFile(saves_dir, "meiou isle after graffiti")

  var mdMissions = getGraffitiMissionsForCity(ctx.db, cityIdShinagawa.int)
  var missions = getMissionsWithIds(ctx.db, mdMissions.mapIt(it.id))

  missions.sort(cmpMissionsById)
  mdMissions.sort(cmpMdMissionsById)

  let expected = mdMissions.mapIt(Mission(missionId: it.id, count: some(1)))

  doAssert(missions == expected)


proc testSaveFileWithBuggedMagicOrbsMissionsIsFixed(saves_dir: string) =
  var ctx = getInMemorySembaCtx()

  ctx.loadSaveFile(saves_dir, "skybridge marine biology research center door")

  var mdMissions = getMagicOrbMissionsForCity(ctx.db, cityIdShinagawa.int)
  var missions = getMissionsWithIds(ctx.db, mdMissions.mapIt(it.id))

  missions.sort(cmpMissionsById)
  mdMissions.sort(cmpMdMissionsById)

  doAssert(missions == mdMissions.mapIt(Mission(missionId: it.id, count: some(1))))


proc testSaveFileWithBuggedHelpfulDemeanorMissions(saves_dir: string) =
  var ctx = getInMemorySembaCtx()

  ctx.loadSaveFile(saves_dir, "bugged Helpful Demeanor")

  var mdMissions = getCompleteCityChallengeMissionsForCityId(ctx.db, cityIdShinagawa.int)
  var missions = getMissionsWithIds(ctx.db, mdMissions.mapIt(it.id))

  missions.sort(cmpMissionsById)
  mdMissions.sort(cmpMdMissionsById)

  doAssert(missions == mdMissions.mapIt(Mission(missionId: it.id, count: some(4))))


proc testMissionReceiveReturnsChallenges(saves_dir: string) =
  var ctx = getInMemorySembaCtx()

  ctx.loadSaveFile(saves_dir, "16 fm can get one more")

  let res = ctx.sembaCall("/mission/receive", %*{
    "missionIds": [1041033, 1041034, 1041045, 1041046, 1041049]
  }).protoJsonTo(Option[MissionReceiveResponse])

  doAssert(res.isSome)
  let changedResources = res.get().changedResources

  let completeChaProgIndex = changedResources.challengeProgresses.findIt(it.challengeProgressId == 1010192)
  doAssert(completeChaProgIndex != -1)
  doAssert(changedResources.challengeProgresses[completeChaProgIndex].state == challengeProgressStateCleared.int)
  doAssert(changedResources.challengeProgresses[completeChaProgIndex].clearedAt.isSome)

  let nextChaProgIndex = changedResources.challengeProgresses.findIt(it.challengeProgressId == 1010201)
  doAssert(nextChaProgIndex != -1)
  doAssert(changedResources.challengeProgresses[nextChaProgIndex].state == challengeProgressStateStarted.int)

  let ctIndex = changedResources.challengeTasks.findIt(it.challengeTaskId == 10101921)
  doAssert(ctIndex != -1)
  doAssert(changedResources.challengeTasks[ctIndex].clearedAt.isSome)


proc testMissionReceiveDoesntReturnFinishedChallenges(saves_dir: string) =
  var ctx = getInMemorySembaCtx()

  ctx.loadSaveFile(saves_dir, "after fixed mission receive_can receive again")

  let res = ctx.sembaCall("/mission/receive", %*{
    "missionIds": [1041033, 1041050, 1041062, 1041067, 1041070]
  }).protoJsonTo(Option[MissionReceiveResponse])

  doAssert(res.isSome)
  let changedResources = res.get().changedResources

  let alreadyCompletedChaProgIndex = changedResources.challengeProgresses.findIt(it.challengeProgressId == 1010192)
  doAssert(alreadyCompletedChaProgIndex == -1)


proc testSuiteMission*(savesDir: string) =
  testMissionReceive()
  testUnlockFullMarkGates()
  testSaveFileWithBuggedAreaObjectLocksIsFixed(savesDir)
  testSaveFileWithBuggedGraffitiMissionsIsFixed(savesDir)
  testSaveFileWithBuggedMagicOrbsMissionsIsFixed(savesDir)
  testSaveFileWithBuggedHelpfulDemeanorMissions(savesDir)
  testMissionReceiveReturnsChallenges(savesDir)
  testMissionReceiveDoesntReturnFinishedChallenges(savesDir)