import std/json
import std/sets
import std/options
import std/sequtils
import std/tables

import ../db_connector/db_sqlite

import adventure_variable
import area
import area_change_lock
import area_group
import area_object
import area_object_lock
import challenge
import challenge_progress
import challenge_task
import character
import character_likability
import character_mounting_power
import character_piece
import city
import dungeon
import formation
import gear
import graffiti_art
import gacha
import item
import magic_orb
import mission
import nine_sequence
import reward
import tutorial_state
import tip
import tension_card
import user
import lux_phantasma
import timestamp
import wallet


type Notifications* = object
  gacha*: Option[GachaNotification]
  mail*: Option[bool]
  itemRequest*: Option[bool]

type Resources* = object
  adventureVariables: Option[seq[AdventureVariable]]
  areas: Option[seq[Area]]
  areaChangeLocks: Option[seq[AreaChangeLock]]
  areaGroups: Option[seq[AreaGroup]]
  areaObjectLocks: Option[seq[AreaObjectLock]]
  challenges: Option[seq[Challenge]]
  challengeProgresses*: Option[seq[ChallengeProgress]]
  challengeTasks*: Option[seq[ChallengeTask]]
  characters*: Option[seq[Character]]
  characterCostumes: Option[seq[CharacterCostume]]
  characterLikabilities: Option[seq[CharacterLikability]]
  characterMountingPowers: Option[seq[CharacterMountingPower]]
  characterMountingPowerCommon: Option[CharacterMountingPowerCommon]
  characterPieces: Option[seq[CharacterPiece]]
  cities: Option[seq[City]]
  cycleUpdateShopStates: Option[seq[JsonNode]] # FIXME: CycleUpdateShopState
  dailyPassStates: Option[seq[JsonNode]] # FIXME: DailyPassState
  dungeons: Option[seq[Dungeon]]
  eventFloorNodes: Option[seq[EventFloorNode]]
  eventLifts: Option[seq[EventLift]]
  follows: Option[seq[JsonNode]] # FIXME: Follow
  formations: Option[seq[JsonNode]] # FIXME: Formation
  fractalVises: Option[seq[JsonNode]] # FIXME: FractalVise
  gears*: Option[seq[Gear]]
  graffitiArts*: Option[seq[GraffitiArt]]
  guestCharacters: Option[seq[JsonNode]] # FIXME: GuestCharacter
  items*: Option[seq[Item]] # FIXME: Item
  loginBonuses: Option[seq[JsonNode]] # FIXME: LoginBonus
  magicOrbs: Option[seq[JsonNode]] # FIXME: MagicOrb
  missions*: Option[seq[Mission]]
  missionCountRewardStates: Option[seq[JsonNode]] # FIXME: MissionCountRewardState
  nineSequences: Option[seq[NineSequence]]
  notifications*: Option[Notifications]
  profile: Option[JsonNode] # FIXME: Profile
  profileBadges: Option[seq[JsonNode]] # FIXME: ProfileBadge
  profileBanners: Option[seq[JsonNode]] # FIXME: ProfileBanner
  questStates: Option[seq[JsonNode]] # FIXME: QuestState
  seasonPasses: Option[seq[JsonNode]] # FIXME: SeasonPass
  seasonPassTierStates: Option[seq[JsonNode]] # FIXME: SeasonPassTierState
  shopProductStates: Option[seq[JsonNode]] # FIXME: ShopProductState
  status*: Option[JsonNode] # FIXME: Status
  synthesisRecipes: Option[seq[JsonNode]] # FIXME: SynthesisRecipe
  tensionCards: Option[seq[JsonNode]] # FIXME: TensionCard
  tips*: Option[seq[Tip]]
  totalTasks: Option[seq[JsonNode]] # FIXME: TotalTask
  trialBattleStates: Option[seq[JsonNode]] # FIXME: TrialBattleState
  tutorialStates*: Option[seq[JsonNode]] # FIXME: TutorialState
  wallet*: Option[Wallet]
  warpPoints*: Option[seq[JsonNode]] # FIXME: WarpPoint
  xbStatuses: Option[seq[JsonNode]] # FIXME: XbStatus

type ChangedResourcesResponse* = object
  changedResources*: Resources


proc updateResources*(db: DbConn, changedResources: var JsonNode) =
  var handledKeys = initHashSet[string]()

  let formations = changedResources.getOrDefault("formations").getElems()

  if formations.len > 0:
    updateFormations(db, formations)
    handledKeys.incl("formations")

  if changedResources.getOrDefault("status") != nil:
    handledKeys.incl("status")
    var status = getUserStatus(db)

    if formations.len > 0:
      let formationNumber = changedResources["status"].getOrDefault("formationNumber").getInt()
      status["formationNumber"] = %*formationNumber

    updateStatusFromStatusLocation(status, changedResources["status"])
    changedResources["status"] = status
    setUserStatus(db, status);

  let nineSequences = changedResources.getOrDefault("nineSequences")

  if nineSequences != nil:
    handledKeys.incl("nineSequences")
    updateNineSequences(db, nineSequences)

  let adventureVariables = changedResources.getOrDefault("adventureVariables")

  if adventureVariables != nil:
    handledKeys.incl("adventureVariables")
    updateAdventureVariables(db, adventureVariables)

  let challengeProgresses = changedResources.getOrDefault("challengeProgresses")

  if challengeProgresses != nil:
    handledKeys.incl("challengeProgresses")
    updateChallengeProgresses(db, challengeProgresses)

  let challengeTasks = changedResources.getOrDefault("challengeTasks")

  if challengeTasks != nil:
    handledKeys.incl("challengeTasks")
    updateChallengeTasks(db, challengeTasks)

  let challenges = changedResources.getOrDefault("challenges").getElems()
  updateChallenges(db, challenges)

  if challenges.len > 0:
    handledKeys.incl("challenges")

  let tutorialStates = changedResources.getOrDefault("tutorialStates").getElems()

  if tutorialStates.len > 0:
    handledKeys.incl("tutorialStates")

  for tutorialState in tutorialStates:
    let tutorialStatusKey = tutorialState["tutorialStatusKey"].getInt()
    let enabled = tutorialState.getOrDefault("enabled").getBool()
    updateTutorialState(db, tutorialStatusKey, enabled)

  let areaGroups = changedResources.getOrDefault("areaGroups").getElems()

  if areaGroups.len > 0:
    handledKeys.incl("areaGroups")

  for areaGroup in areaGroups:
    let areaGroupId = areaGroup["areaGroupId"].getInt()
    addAreaGroup(db, areaGroupId)

  let cities = changedResources.getOrDefault("cities").getElems()

  if cities.len > 0:
    handledKeys.incl("cities")

  for city in cities:
    addCity(db, city)

  let magicOrbs = changedResources.getOrDefault("magicOrbs").getElems()

  if magicOrbs.len > 0:
    handledKeys.incl("magicOrbs")

  updateMagicOrbs(db, magicOrbs)

  let items = to(changedResources.getOrDefault("items"), Option[seq[Item]])
  
  if items.isSome():
    handledKeys.incl("items")
    updateItems(db, items.get())

  let areaChangeLocks = changedResources.getOrDefault("areaChangeLocks").getElems()

  if areaChangeLocks.len > 0:
    handledKeys.incl("areaChangeLocks")

  updateAreaChangeLocks(db, areaChangeLocks)

  let missions = changedResources.getOrDefault("missions")

  if missions != nil:
    # Don't return (zero sensei) missions from online logs
    changedResources.delete("missions")
    handledKeys.incl("missions")

  let characters = changedResources.getOrDefault("characters").getElems()

  if characters.len > 0:
    updateCharacters(db, characters)
    handledKeys.incl("characters")

  let characterCostumes = to(changedResources.getOrDefault("characterCostumes"), Option[seq[CharacterCostume]])

  if characterCostumes.isSome and characterCostumes.get().len > 0:
    updateCharacterCostumes(db, characterCostumes.get())
    handledKeys.incl("characterCostumes")

  let tensionCards = changedResources.getOrDefault("tensionCards").getElems()

  if tensionCards.len > 0:
    updateTensionCards(db, tensionCards)
    handledKeys.incl("tensionCards")

  for key, _ in changedResources.pairs():
    if not (key in handledKeys):
      echo("WARNING: " & key & " not handled in updateResources")


proc updateFromReadSequenceResponse*(db: DbConn, response: JsonNode) =
  updateAreaObjects(db, response["areaObjects"])
  var changedResources = response["changedResources"]
  updateResources(db, changedResources) 


proc getChangedResourcesForCompletedChallengeTask*(
  db: DbConn, challengeTask: MdChallengeTask
): (seq[AreaObject], Resources) =
  var areaObjects = newSeq[AreaObject]()
  var challengeTasks = newSeq[ChallengeTask]()
  var challengeProgresses = newSeq[ChallengeProgress]()

  challengeTasks.add(ChallengeTask(
    challengeTaskId: challengeTask.id, count: 1, clearedAt: some(getDateNow())
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
    challengeProgresses.add(ChallengeProgress(
      challengeProgressId: challengeTask.challengeProgressId,
      state: challengeProgressStateStarted.int,
    ))

  let resources = Resources(
    challengeTasks: some(challengeTasks),
    challengeProgresses: some(challengeProgresses)
  )

  result = (areaObjects, resources)


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
    let (areaObjects, resources) = getChangedResourcesForCompletedChallengeTask(db, challengeTask.get())

    changedResources["challengeTasks"] = %*resources.challengeTasks.get()
    changedResources["challengeProgresses"] = %*resources.challengeProgresses.get()
    response["areaObjects"] = %*areaObjects


proc updateResourcesFromRewardsTypeSafe*(db: DbConn, rewards: var seq[Reward]): Resources =
  var gears = newSeq[Gear]()
  var itemsTable: Table[int, Item]

  var status = getUserStatus(db)

  var characters = newSeq[Character]()

  for reward in rewards.mitems():
    case reward.`type`.RewardType:
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
      if not (reward.id in itemsTable):
        let item = getItem(db, reward.id)
        itemsTable[reward.id] = item.get(Item(itemId: reward.id, quantity: some(0)))

      itemsTable[reward.id].quantity = some(itemsTable[reward.id].quantity.get(0) + reward.quantity)
    of rewardGold:
      status["gold"] = %*(status.getOrDefault("gold").getInt() + reward.quantity)
    of rewardCharacterExp:
      let formationNumber = status.getOrDefault("formationNumber").getInt()
      let members = getFormationMembers(db, formationNumber)

      let maxExp = getCharacterMaxExp(db)

      if members.character1Id.isSome():
        updateCharacterExp(db, reward.quantity, getCharacter(db, members.character1Id.get()), maxExp)
        characters.add(getCharacter(db, members.character1Id.get()))

      if members.character2Id.isSome():
        updateCharacterExp(db, reward.quantity, getCharacter(db, members.character2Id.get()), maxExp)
        characters.add(getCharacter(db, members.character2Id.get()))

      if members.character3Id.isSome():
        updateCharacterExp(db, reward.quantity, getCharacter(db, members.character3Id.get()), maxExp)
        characters.add(getCharacter(db, members.character3Id.get()))
    else:
      discard

  let items = itemsTable.values().toSeq()
  updateItems(db, items)

  setUserStatus(db, status)

  result.gears = some(gears)
  result.items = some(items)
  result.status = some(status)
  result.characters = some(characters)


proc updateResourcesFromRewards*(
  db: DbConn, rewards: var seq[Reward]
): JsonNode {.deprecated: "use updateResourcesFromRewardsTypeSafe instead".} =
  result = %*updateResourcesFromRewardsTypeSafe(db, rewards)