import std/algorithm
import std/json
import std/options
import std/sequtils
import std/tables

import utils
import ../protojson
import ../api_stable/mission
import ../model_stable/area_object_lock
import ../model_stable/city
import ../model_stable/mission
import ../model_stable/timestamp
import ../model_stable/area_object

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

  doAssert(res.changedResources.missions.isSome())

  let missions = res.changedResources.missions.get().mapIt((it.missionId, it)).toTable()

  for missionId in missionIds:
    let mission = missions[missionId]
    doAssert(mission.receivedStepCount == 1)

  doAssert(
    getMissionsWithIds(ctx.db, missionIds).all(proc (mi: Mission): bool = mi.receivedStepCount == 1)
  )

  doAssert(res.rewards.len > 0)
  doAssert(res.changedResources.status.get().flowerMark.get(0) == 2)


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

  missions.sort(proc (a, b: Mission): int = cmp(a.missionId, b.missionId))
  mdMissions.sort(proc (a, b: MdMission): int = cmp(a.id, b.id))

  let expected = mdMissions.mapIt(Mission(missionId: it.id, count: some(1)))

  doAssert(missions == expected)


proc testSuiteMission*(saves_dir: string) =
  testMissionReceive()
  testUnlockFullMarkGates()
  testSaveFileWithBuggedAreaObjectLocksIsFixed(saves_dir)
  testSaveFileWithBuggedGraffitiMissionsIsFixed(saves_dir)