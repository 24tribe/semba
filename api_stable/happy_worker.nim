import std/sequtils
import std/json
import std/options

import ../db_connector/db_sqlite

import ../model_stable/challenge
import ../model_stable/challenge_progress
import ../model_stable/challenge_task
import ../model_stable/city
import ../model_stable/happy_worker
import ../model_stable/resources
import ../model_stable/timestamp


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

  let challengeId = getHappyWorkerItemChallengeId(db, req.happyWorkerItemId)

  let changedChallenges = @[Challenge(
    challengeId: challengeId, state: 5, expiresAt: some(endOfToday())
  )]

  result.changedResources.challenges = some(changedChallenges)
  upsertChallenges(db, changedChallenges)

  let firstProgressId = getChallengeFirstProgressId(db, challengeId)

  let challengeProgressIds = getChallengeProgressIds(db, challengeId)

  let challengeProgresses = challengeProgressIds.mapIt(ChallengeProgress(
    challengeProgressId: it,
    state: if it == firstProgressId: challengeProgressStateStarted.int else: challengeProgressStateNotStarted.int
  ))

  upsertChallengeProgresses(db, challengeProgresses)
  result.changedResources.challengeProgresses = some(challengeProgresses)

  let challengeTasks = getChallengeTaskIdsForChallengeProgressIds(db, challengeProgressIds).mapIt(ChallengeTask(
    challengeTaskId: it
  ))

  upsertChallengeTasks(db, challengeTasks)
  result.changedResources.challengeTasks = some(challengeTasks)

  # FIXME: update area objects with mdAreaBehavior conditions