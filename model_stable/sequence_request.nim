import std/json
import std/options
import std/strutils
import std/sequtils

import ../db_connector/db_sqlite

import ../util
import timestamp
import challenge_task
import area_object
import challenge_progress

proc parseReadSequenceRow*(row: Row): JsonNode =
  result = %*{
    "changedResources": {},
    "areaObjects": [],
  }

  if row[0] != "":
    result["areaObjects"] = parseJson(row[0])

  if row[1] != "":
    result["changedResources"] = parseJson(row[1])


#[
Swap the changed areaObjects, challengeTasks and challengeProgresses taken from
the online logs with the ones from the master data
]# 
proc changeReadSequenceResponse*(db: DbConn, seqReqId: int, response: JsonNode) =
  response["areaObjects"] = %*[]

  let changedResources = response["changedResources"]
  changedResources["challengeTasks"] = %*[]
  changedResources["challengeProgresses"] = %*[]

  let challengeTask = getMdChallengeTaskForSequenceRequestId(db, seqReqId)
  if challengeTask.isSome():
    changedResources["challengeTasks"] = %*[
      ChallengeTask(challengeTaskId: challengeTask.get().id, count: 1, clearedAt: some(getDateNow()))
    ]

    var areaObjects = getAreaObjectsWithCondition(
      db, areaObjectConditionTypeClearedChallengeTask, challengeTask.get().id
    )

    let otherChallengeTasks = getOtherChallengeTasks(db, challengeTask.get())

    if all(otherChallengeTasks, proc (x: MdChallengeTask): bool = isChallengeTaskComplete(db, x.id)):
      var challengeProgresses = @[
        ChallengeProgress(
          challengeProgressId: challengeTask.get().challengeProgressId,
          state: challengeProgressStateCleared.int,
          clearedAt: some(getTimestampNow()),
        )
      ]

      areaObjects.insert(getAreaObjectsWithCondition(
        db, areaObjectConditionTypeClearedChallengeProgress, challengeTask.get().challengeProgressId
      ), areaObjects.len)

      let nextChallengeProgressId = getNextChallengeProgress(db, challengeTask.get().challengeProgressId)

      if nextChallengeProgressId.isSome():
        challengeProgresses.add(ChallengeProgress(
          challengeProgressId: nextChallengeProgressId.get(),
          state: challengeProgressStateStarted.int,
        ))

        areaObjects.insert(getAreaObjectsWithCondition(
          db, areaObjectConditionTypeStartedChallengeProgress, nextChallengeProgressId.get()
        ), areaObjects.len)

      changedResources["challengeProgresses"] = %*challengeProgresses
    else:
      changedResources["challengeProgresses"] = %*[
        ChallengeProgress(
          challengeProgressId: challengeTask.get().challengeProgressId,
          state: challengeProgressStateStarted.int,
        )
      ]

    response["areaObjects"] = %*areaObjects