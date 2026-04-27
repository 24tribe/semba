import std/json
import std/options
import std/sequtils
import std/tables

import utils
import ../api_stable/mission
import ../model_stable/mission
import ../model_stable/timestamp

proc testMissionReceive() =
    var ctx = getInMemorySembaCtx()

    updateMissions(ctx.db, [
        Mission(
            missionId: 1041041, count: some(155),
            receivedStepCount: some(0), clearedAt: some(getTimestampNow())
        ),
        Mission(
            missionId: 1041042, count: some(155),
            receivedStepCount: some(0), clearedAt: some(getTimestampNow())
        ),
    ])

    let missionIds = [1041041, 1041042]

    let resJson = ctx.sembaCall("/mission/receive", %*{"missionIds": missionIds})

    doAssert(resJson != nil)

    let res = to(resJson, MissionReceiveResponse)

    doAssert(res.changedResources.missions.isSome())

    let missions = res.changedResources.missions.get().mapIt((it.missionId, it)).toTable()

    for missionId in missionIds:
        let mission = missions[missionId]
        doAssert(mission.receivedStepCount.get(0) == 1)

    doAssert(
        getMissionsWithIds(ctx.db, missionIds).all(proc (mi: Mission): bool = mi.receivedStepCount.get(0) == 1)
    )

    doAssert(res.rewards.len > 0)


proc testSuiteMission*() =
    testMissionReceive()