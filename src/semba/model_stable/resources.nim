import std/json
import std/options
import std/sequtils
import std/strutils
import std/tables

import db_connector/db_sqlite

import ../enum_ex
import ../protojson
import ../extsqlite
import ./adventure_variable
import ./area
import ./area_item
import ./area_change_lock
import ./area_group
import ./area_object
import ./area_object_lock
import ./challenge
import ./challenge_progress
import ./challenge_task
import ./character
import ./character_likability
import ./character_mounting_power
import ./character_piece
import ./city
import ./dungeon
import ./formation
import ./gear
import ./graffiti_art
import ./happy_worker
import ./item
import ./magic_orb
import ./mission
import ./mission_count_reward_state
import ./nine_sequence
import ./notification
import ./reward
import ./status
import ./shop
import ./total_task
import ./tutorial_state
import ./tip
import ./tension_card
import ./lux_phantasma
import ./timestamp
import ./wallet
import ./warp_point
import ./xb_types


type ResourceEntities* = object
  followUserIds*: seq[ProtoJsonInt64]
  gearEntityIds*: seq[int]
  tensionCardEntityIds*: seq[int]

type Resources* = object
  adventureVariables*: seq[AdventureVariable]
  areas*: seq[Area]
  areaChangeLocks*: seq[AreaChangeLock]
  areaGroups*: seq[AreaGroup]
  areaObjectLocks*: seq[AreaObjectLock]
  challenges*: seq[Challenge]
  challengeProgresses*: seq[ChallengeProgress]
  challengeTasks*: seq[ChallengeTask]
  characters*: seq[Character]
  characterCostumes*: seq[CharacterCostume]
  characterLikabilities: Option[seq[CharacterLikability]]
  characterMountingPowers*: Option[seq[CharacterMountingPower]]
  characterMountingPowerCommon*: Option[CharacterMountingPowerCommon]
  characterPieces*: seq[CharacterPiece]
  cities*: seq[City]
  cycleUpdateShopStates: Option[seq[JsonNode]] # FIXME: CycleUpdateShopState
  dailyPassStates: Option[seq[JsonNode]] # FIXME: DailyPassState
  dungeons*: seq[Dungeon]
  eventFloorNodes: Option[seq[EventFloorNode]]
  eventLifts: Option[seq[EventLift]]
  follows: Option[seq[JsonNode]] # FIXME: Follow
  formations*: seq[JsonNode] # FIXME: Formation
  fractalVises: Option[seq[JsonNode]] # FIXME: FractalVise
  gears*: seq[Gear]
  graffitiArts*: seq[GraffitiArt]
  guestCharacters: Option[seq[JsonNode]] # FIXME: GuestCharacter
  items*: seq[Item]
  loginBonuses: Option[seq[JsonNode]] # FIXME: LoginBonus
  magicOrbs*: seq[MagicOrb]
  missions*: seq[Mission]
  missionCountRewardStates*: seq[MissionCountRewardState]
  nineSequences*: seq[NineSequence]
  notifications*: Option[Notifications]
  profile*: Option[JsonNode] # FIXME: Profile
  profileBadges: Option[seq[JsonNode]] # FIXME: ProfileBadge
  profileBanners*: seq[JsonNode] # FIXME: ProfileBanner
  questStates*: seq[JsonNode] # FIXME: QuestState
  seasonPasses: Option[seq[JsonNode]] # FIXME: SeasonPass
  seasonPassTierStates: Option[seq[JsonNode]] # FIXME: SeasonPassTierState
  shopProductStates*: Option[seq[ShopProductState]]
  status*: Option[Status]
  synthesisRecipes: Option[seq[JsonNode]] # FIXME: SynthesisRecipe
  tensionCards*: seq[TensionCard]
  tips*: seq[Tip]
  totalTasks*: seq[TotalTask]
  trialBattleStates: Option[seq[JsonNode]] # FIXME: TrialBattleState
  tutorialStates*: seq[TutorialState]
  wallet*: Option[Wallet]
  warpPoints*: seq[WarpPoint]
  xbStatuses*: seq[XbStatus]

type ChangedResourcesResponse* = object
  changedResources*: Resources


proc updateResources*(db: DbConn, changedResources: var Resources) =
  updateMissions(db, changedResources.missions)
  updateItems(db, changedResources.items)

  updateFormations(db, changedResources.formations)

  if changedResources.status.isSome():
    let changedStatus = changedResources.status.get()

    var status = getUserStatusTypeSafe(db)

    if changedResources.formations.len > 0:
      status.formationNumber = changedStatus.formationNumber

    updateStatusFromStatusLocation(status, changedStatus)

    setUserStatusTypeSafe(db, status);
    changedResources.status = some(status)

  updateNineSequences(db, changedResources.nineSequences)
  updateAdventureVariables(db, changedResources.adventureVariables)
  upsertChallengeProgresses(db, changedResources.challengeProgresses)
  upsertChallengeTasks(db, changedResources.challengeTasks)
  upsertChallenges(db, changedResources.challenges)

  for tutorialState in changedResources.tutorialStates:
    updateTutorialState(db, tutorialState.tutorialStatusKey, tutorialState.enabled)

  for areaGroup in changedResources.areaGroups:
    addAreaGroup(db, areaGroup.areaGroupId)

  for city in changedResources.cities:
    addCity(db, city)

  updateMagicOrbs(db, changedResources.magicOrbs)
  updateAreaChangeLocks(db, changedResources.areaChangeLocks)
  updateCharactersTypeSafe(db, changedResources.characters)
  updateCharacterCostumes(db, changedResources.characterCostumes)
  upsertTensionCards(db, changedResources.tensionCards)


proc isChallengeProgressComplete(db: DbConn, challengeProgressId: int): bool =
  db.getAllRows(sql"""
    SELECT clearedAt FROM challengeTasks
      RIGHT JOIN mdChallengeTask ON challengeTasks.challengeTaskId = mdChallengeTask.id
      WHERE mdChallengeTask.challengeProgressId = ?
  """, challengeProgressId).allIt(it[0] != "")


proc getChangedResourcesFromTotalTasks*(
  db: DbConn
): (seq[AreaObject], seq[Challenge], seq[ChallengeProgress], seq[ChallengeTask], seq[NineSequence])


proc getChangedResourcesForChallengeProgress(
  db: DbConn, challengeProgressId: int
): (seq[AreaObject], seq[Challenge], seq[ChallengeProgress], seq[ChallengeTask], seq[NineSequence]) = 

  var areaObjects: seq[AreaObject]
  var challengeTasks: seq[ChallengeTask]
  var challengeProgresses: seq[ChallengeProgress]
  var challenges: seq[Challenge]
  var nineSequences: seq[NineSequence]

  if db.isChallengeProgressComplete(challengeProgressId):
    challengeProgresses.add(ChallengeProgress(
      challengeProgressId: challengeProgressId,
      state: challengeProgressStateCleared.int,
      clearedAt: some(getTimestampNow()),
    ))

    areaObjects.insert(getAreaObjectsWithCondition(
      db, areaObjectConditionTypeClearedChallengeProgress, challengeProgressId
    ), areaObjects.len)

    let nextChallengeProgressId = getNextChallengeProgress(db, challengeProgressId)

    if nextChallengeProgressId.isSome():
      let nineSequenceId = getNineTrigger(db, nextChallengeProgressId.get())

      if nineSequenceId.isSome:
        nineSequences.add(NineSequence(
          nineSequenceId: nineSequenceId.get(),
          lastReceiveAt: some(getTimestampNow()),
        ))

      areaObjects.insert(getAreaObjectsWithCondition(
        db, areaObjectConditionTypeStartedChallengeProgress, nextChallengeProgressId.get()
      ), areaObjects.len)

      db.upsertChallengeProgresses([ChallengeProgress(
        challengeProgressId: nextChallengeProgressId.get(),
        state: challengeProgressStateStarted.int,
      )])

      block:
        let (
          ao, chals, chalProgs, chalTasks, nineSeqs
        ) = db.getChangedResourcesFromTotalTasks()
        areaObjects.insert(ao)
        challenges.insert(chals)
        challengeProgresses.insert(chalProgs)
        challengeTasks.insert(chalTasks)
        nineSequences.insert(nineSeqs)

        db.upsertChallengeTasks(chalTasks)

      block:
        # TODO: add recursion limit?
        let (
          ao, chals, chalProgs, chalTasks, nineSeqs
        ) = db.getChangedResourcesForChallengeProgress(nextChallengeProgressId.get())

        # TODO: area objects conflict strategy?
        areaObjects.insert(ao)
        challenges.insert(chals)
        challengeProgresses.insert(chalProgs)
        challengeTasks.insert(chalTasks)
        nineSequences.insert(nineSeqs)
    else:
      challenges.add(Challenge(
        challengeId: getChallengeId(db, challengeProgressId),
        state: challengeStateCompleted.int,
        clearedAt: some(getTimestampNow()),
        # expiresAt?
      ))
  else:
    challengeProgresses.add(ChallengeProgress(
      challengeProgressId: challengeProgressId,
      state: challengeProgressStateStarted.int,
    ))

  result = (areaObjects, challenges, challengeProgresses, challengeTasks, nineSequences)


proc getChangedResourcesForCompletedChallengeTaskEx*(
  db: DbConn, chalTaskId: int, chalProgId: int
): (seq[AreaObject], seq[Challenge], seq[ChallengeProgress], seq[ChallengeTask], seq[NineSequence]) =
  var challenges = newSeq[Challenge]()

  var challengeProgresses = newSeq[ChallengeProgress]()

  var challengeTasks = @[ChallengeTask(
    challengeTaskId: chalTaskId, count: some(1), clearedAt: some(getTimestampNow())
  )]

  db.upsertChallengeTasks(challengeTasks)

  var nineSequences = newSeq[NineSequence]()

  var areaObjects = getAreaObjectsWithCondition(
    db, areaObjectConditionTypeClearedChallengeTask, chalTaskId
  )

  let (
    ao, chals, chalProgs, chalTasks, nineSeqs
  ) = db.getChangedResourcesForChallengeProgress(chalProgId)

  areaObjects.insert(ao)
  challenges.insert(chals)
  challengeProgresses.insert(chalProgs)
  challengeTasks.insert(chalTasks)
  nineSequences.insert(nineSeqs)

  result = (areaObjects, challenges, challengeProgresses, challengeTasks, nineSequences)


proc getChangedResourcesForCompletedChallengeTask*(
  db: DbConn, challengeTask: MdChallengeTask
): (seq[AreaObject], seq[Challenge], seq[ChallengeProgress], seq[ChallengeTask], seq[NineSequence]) =
  result = db.getChangedResourcesForCompletedChallengeTaskEx(challengeTask.id, challengeTask.challengeProgressId)
  

proc updateResourcesFromRewardsTypeSafe*(
  db: DbConn, rewards: var seq[Reward], itemCounts: var Table[int, int]
): Resources =
  var gears = newSeq[Gear]()

  var status = getUserStatusTypeSafe(db)

  var characters = newSeq[Character]()

  for reward in rewards.mitems():
    case intToEnum(reward.`type`, RewardType):
    of rewardFreeGem:
      var wallet = result.wallet.get(getWallet(db))
      wallet.free += reward.quantity
      setWallet(db, wallet)
      result.wallet = some(wallet)
    of rewardGearDrop:
      # FIXME: only golden chests should have a minRarity of gearRaritySsr
      let mdGears = getBalancedGears(db)
      let (gear, gearReward) = randomGear(db, gearRaritySsr.int, mdGears)

      reward = gearReward
      addGear(db, gear)
      gears.add(gear)
    of rewardGear:
      let gear = gearRewardToGear(reward)
      addGear(db, gear)
      gears.add(gear)
    of rewardItem:
      if not (reward.id in itemCounts):
        itemCounts[reward.id] = 0

      itemCounts[reward.id] += reward.quantity
    of rewardGold:
      status.gold += reward.quantity
    of rewardFlowerMark:
      status.flowerMark += reward.quantity
    of rewardCharacterExp:
      let formationNumber = status.formationNumber.get(0)
      let members = getFormationMembers(db, formationNumber)

      let maxExp = getCharacterMaxExp(db)

      if members.character1Id.isSome():
        updateCharacterExp(db, reward.quantity, members.character1Id.get(), maxExp)
        characters.add(getCharacter(db, members.character1Id.get()))

      if members.character2Id.isSome():
        updateCharacterExp(db, reward.quantity, members.character2Id.get(), maxExp)
        characters.add(getCharacter(db, members.character2Id.get()))

      if members.character3Id.isSome():
        updateCharacterExp(db, reward.quantity, members.character3Id.get(), maxExp)
        characters.add(getCharacter(db, members.character3Id.get()))
    else:
      discard

  let items = addCountsToItems(db, itemCounts)
  updateItems(db, items)

  setUserStatusTypeSafe(db, status)

  result.totalTasks = @[TotalTask(
    conditionId: flowerMarksTotalTaskConditionId, count: status.flowerMark.ProtoJsonInt64
  )]
  upsertTotalTasks(db, result.totalTasks)

  result.gears = gears
  result.items = items
  result.status = some(status)
  result.characters = characters


proc rewardsToChangedItems*(db: DbConn, rewards: seq[Reward]): (seq[Item], int) =
  var itemsTable = getItemsTable(db)

  var changedItems: Table[int, Item]

  var totalItems = 0

  for reward in rewards:
    var item: Item =
      if reward.id in itemsTable:
        itemsTable[reward.id]
      else:
        Item(itemId: reward.id)

    item.quantity += reward.quantity
    totalItems += reward.quantity

    changedItems[reward.id] = item
    itemsTable[reward.id] = item

  let items = changedItems.values().toSeq()

  return (items, totalItems)


proc completeMainStoryRiftTutorialChallenge*(db: DbConn): (seq[ChallengeProgress], seq[ChallengeTask]) =
  let rightNow = some(getTimestampNow())

  let challengeProgresses = @[
    ChallengeProgress(challengeProgressId: clearHealthyOutlawsChallengeProgressId.int, clearedAt: rightNow, state: 3),
    ChallengeProgress(challengeProgressId: 1010181, state: 2)
  ]

  upsertChallengeProgresses(db, challengeProgresses)

  let challengeTasks = @[ChallengeTask(challengeTaskId: 10101731, clearedAt: rightNow, count: some(1))]

  upsertChallengeTasks(db, challengeTasks)

  updateAreaObjects(db, %*[
    {
      "areaObjectId": 700110, "areaPointId": 101001101, "areaObjectBehaviorId": 7010709,
      "action": {"type": 7, "id": 1}
    }
  ])

  result = (challengeProgresses, challengeTasks)


proc getChallengesChangedMissions*(db: DbConn, challenges: openArray[Challenge], cityId: int): seq[Mission] =
  ## Iterates throught `challenges` and collects changed missions.
  ## If it finds a completed Happy Worker challenge, it deletes the challenge area objects from the db.
  ## Doesn't update the missions in the db.
  ## Returns the changed missions.

  for challenge in challenges:
    if challenge.state == challengeStateCompleted.int:
      if isHappyWorkerChallenge(db, challenge.challengeId):
        let areaObjectIds = getChallengeAreaObjectIds(db, challenge.challengeId)
        deleteAreaObjectsWithIds(db, areaObjectIds)
        result.insert(getChangedHappyWorkaholicMissions(db, cityId), result.len)
      elif isCityChallenge(db, challenge.challengeId):
        result.insert(getChangedCompleteCityChallengeMissions(db, cityId), result.len)


proc getCityChallengesCount*(db: DbConn): CountTable[CityId] =
  db.getAllRows(sql"""
    SELECT challengeId FROM mdChallenge JOIN challenges ON mdChallenge.id = challenges.challengeId
    WHERE state = ?
  """, challengeStateCompleted.int).mapIt(parseInt(it[0]).challengeIdToCityId()).toCountTable


proc getChangedFieldResearchMissions*(db: DbConn, itemCounts: Table[int, int]): seq[Mission] =
  let missionItemIds = getFieldResearchMissionIdsWithItemIds(db, itemCounts.keys.toSeq)
  let mdMissions = getMdMissionsWithIds(db, missionItemIds.keys.toSeq)

  getMissionsWithNewCount(db, mdMissions, proc (mi: Mission, mdMi: MdMission): Option[int] =
    some(mi.count + itemCounts[missionItemIds[mi.missionId]])
  )


proc acquireAreaItemRewards*(
  db: DbConn, areaItemRewardIds: openArray[int], cityId: int, areaItemBaseId: int
): (Resources, seq[Rewards]) =
  var rewards = getAreaItemRewards(db, areaItemRewardIds)

  var itemCounts: Table[int, int]

  var changedResources = updateResourcesFromRewardsTypeSafe(db, rewards[0].contents, itemCounts)

  var missions = getChangedFieldResearchMissions(db, itemCounts)

  if isChestAreaItem(areaItemBaseId):
    missions.insert(getChangedOpenChestMissions(db, cityId), missions.len)

  updateMissions(db, missions)
  changedResources.missions = missions

  (changedResources, rewards)


proc getMdChallengeTasksWithTotalTask*(db: DbConn): seq[MdChallengeTask] =
  db.getAllRows(sql"""
    SELECT mdChallengeTask.challengeProgressId, taskConditionKeyId, id, summaryChallengeId, targetAreaObjectBehaviorId,
           targetAreaPointId, targetNineSequenceId, targetRadius, taskConditionType, mdChallengeTask.count,
           mdChallengeTask.totalTaskConditionId
    FROM mdChallengeTask
      JOIN challengeProgresses ON mdChallengeTask.challengeProgressId = challengeProgresses.challengeProgressId
      JOIN totalTasks ON mdChallengeTask.totalTaskConditionId = totalTasks.conditionId
      LEFT JOIN challengeTasks ON mdChallengeTask.id = challengeTasks.challengeTaskId
    WHERE
      totalTasks.count >= mdChallengeTask.count
      AND challengeTasks.clearedAt IS NULL
      AND challengeProgresses.state = ? 
  """, challengeProgressStateStarted.int).mapIt(MdChallengeTask(
    challengeProgressId: parseInt(it[0]),
    taskConditionKeyId: tryParseInt(it[1]),
    id: parseInt(it[2]),
    summaryChallengeId: tryParseInt(it[3]),
    targetAreaObjectBehaviorId: tryParseInt(it[4]),
    targetAreaPointId: tryParseInt(it[5]),
    targetNineSequenceId: tryParseInt(it[6]),
    targetRadius: tryParseInt(it[7]),
    taskConditionType: tryParseInt(it[8]),
    count: tryParseInt(it[9]),
    totalTaskConditionId: tryParseInt(it[10]),
  ))


proc getChangedResourcesFromTotalTasks*(
  db: DbConn
): (seq[AreaObject], seq[Challenge], seq[ChallengeProgress], seq[ChallengeTask], seq[NineSequence]) =
  let mdChallengeTasks = getMdChallengeTasksWithTotalTask(db)

  for mdChallengeTask in mdChallengeTasks:
    let (
      areaObjects,
      challenges, challengeProgresses, challengeTasks,
      nineSequences
    ) = getChangedResourcesForCompletedChallengeTask(
      db, mdChallengeTask
    )

    result[0].insert(areaObjects)
    result[1].insert(challenges)
    result[2].insert(challengeProgresses)
    result[3].insert(challengeTasks)
    result[4].insert(nineSequences)


#[
Swap the changed areaObjects, challengeTasks and challengeProgresses taken from
the online logs with the ones from the master data
]# 
proc changeReadSequenceResponse*(
  db: DbConn, seqReqId: int, changedResources: var Resources, areaObjects: var seq[AreaObject]
) =
  areaObjects = @[]

  changedResources.challenges = @[]
  changedResources.challengeTasks = @[]
  changedResources.challengeProgresses = @[]

  upsertTotalTasks(db, changedResources.totalTasks)

  let challengeTask = getMdChallengeTaskForSequenceRequestId(db, seqReqId)

  if challengeTask.isSome():
    (
      areaObjects,
      changedResources.challenges,
      changedResources.challengeProgresses,
      changedResources.challengeTasks,
      changedResources.nineSequences
    ) = getChangedResourcesForCompletedChallengeTask(
      db, challengeTask.get()
    )

  let (ao, chals, chalProgs, chalTasks, nineSeqs) = db.getChangedResourcesFromTotalTasks()
  areaObjects.insert(ao)
  changedResources.challenges.insert(chals)
  changedResources.challengeProgresses.insert(chalProgs)
  changedResources.challengeTasks.insert(chalTasks)
  changedResources.nineSequences.insert(nineSeqs)

  # FIXME: is there a way to not need to do this?
  changedResources.challengeProgresses = deduplicateChallengeProgresses(changedResources.challengeProgresses)
  areaObjects = deduplicateAreaObjects(areaObjects)
