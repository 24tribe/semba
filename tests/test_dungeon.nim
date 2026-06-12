import std/options
import std/json
import std/sequtils

import ../protojson
import ../model_stable/resources
import utils


proc testDungeonFinish() =
  var ctx = getInMemorySembaCtx()
  let res = protoJsonTo(ctx.sembaCall("/dungeon/finish", %*{
    "dungeonDifficultyId": 10920201
  }), Option[ChangedResourcesResponse])

  doAssert(res.isSome)

  let changedResources = res.get().changedResources

  let clearDungeonMissionIdx = changedResources.missions.findIt(it.missionId == 1041049)

  doAssert(clearDungeonMissionIdx != -1)

  let clearDungeonMission = changedResources.missions[clearDungeonMissionIdx]

  doAssert(clearDungeonMission.count == some(1))


proc testSuiteDungeon*() =
  testDungeonFinish()