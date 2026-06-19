import std/json
import std/options
import std/sequtils
import std/strutils
import std/tables

import db_connector/db_sqlite

import ../enum_ex
import ../protojson
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
  missionCountRewardStates: Option[seq[JsonNode]] # FIXME: MissionCountRewardState
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
  xbStatuses: Option[seq[JsonNode]] # FIXME: XbStatus

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
  updateChallengeProgresses(db, changedResources.challengeProgresses)
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


proc getChangedResourcesForCompletedChallengeTask*(
  db: DbConn, challengeTask: MdChallengeTask
): (seq[AreaObject], Resources) =
  var areaObjects = newSeq[AreaObject]()
  var challengeTasks = newSeq[ChallengeTask]()
  var challengeProgresses = newSeq[ChallengeProgress]()
  var challenges = newSeq[Challenge]()

  challengeTasks.add(ChallengeTask(
    challengeTaskId: challengeTask.id, count: some(1), clearedAt: some(getTimestampNow())
  ))

  areaObjects = getAreaObjectsWithCondition(
    db, areaObjectConditionTypeClearedChallengeTask, challengeTask.id
  )

  let otherChallengeTasks = getOtherChallengeTasks(db, challengeTask)

  if all(otherChallengeTasks, proc (x: MdChallengeTask): bool = isChallengeTaskComplete(db, x.id)):
    challengeProgresses.add(ChallengeProgress(
      challengeProgressId: challengeTask.challengeProgressId,
      state: challengeProgressStateCleared.int,
      clearedAt: some(getTimestampNow()),
    ))

    areaObjects.insert(getAreaObjectsWithCondition(
      db, areaObjectConditionTypeClearedChallengeProgress, challengeTask.challengeProgressId
    ), areaObjects.len)

    let nextChallengeProgressId = getNextChallengeProgress(db, challengeTask.challengeProgressId)

    if nextChallengeProgressId.isSome():
      challengeProgresses.add(ChallengeProgress(
        challengeProgressId: nextChallengeProgressId.get(),
        state: challengeProgressStateStarted.int,
      ))

      areaObjects.insert(getAreaObjectsWithCondition(
        db, areaObjectConditionTypeStartedChallengeProgress, nextChallengeProgressId.get()
      ), areaObjects.len)
    else:
      challenges.add(Challenge(
        challengeId: getChallengeId(db, challengeTask.challengeProgressId),
        state: challengeStateCompleted.int,
        clearedAt: some(getTimestampNow()),
        # expiresAt?
      ))
  else:
    challengeProgresses.add(ChallengeProgress(
      challengeProgressId: challengeTask.challengeProgressId,
      state: challengeProgressStateStarted.int,
    ))

  let resources = Resources(
    challengeTasks: challengeTasks,
    challengeProgresses: challengeProgresses,
    challenges: challenges,
  )

  result = (areaObjects, resources)


#[
Swap the changed areaObjects, challengeTasks and challengeProgresses taken from
the online logs with the ones from the master data
]# 
proc changeReadSequenceResponse*(
  db: DbConn, seqReqId: int, changedResources: var Resources, areaObjects: var seq[AreaObject]
) =
  areaObjects = @[]

  changedResources.challengeTasks = @[]
  changedResources.challengeProgresses = @[]

  let challengeTask = getMdChallengeTaskForSequenceRequestId(db, seqReqId)

  if challengeTask.isSome():
    let (newAreaObjects, resources) = getChangedResourcesForCompletedChallengeTask(db, challengeTask.get())

    changedResources.challengeTasks = resources.challengeTasks
    changedResources.challengeProgresses = resources.challengeProgresses
    areaObjects = newAreaObjects


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
      wallet.free = some(wallet.free.get(0) + reward.quantity)
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

  result.gears = gears
  result.items = items
  result.status = some(status)
  result.characters = characters


proc updateStatusFromCurrentLocation*(status: var Status, currentLocation: CurrentLocation) =
  status.currentAreaType = currentLocation.areaType
  status.currentDirection = currentLocation.direction
  status.currentPositionCoordinates = currentLocation.positionCoordinates
  status.currentAreaKeyId = currentLocation.areaKeyId


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

  updateChallengeProgresses(db, challengeProgresses)

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
    some(mi.count.get(0) + itemCounts[missionItemIds[mi.missionId]])
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