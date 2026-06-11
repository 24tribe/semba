import std/json
import std/options
import std/sequtils
import std/tables

import ../db_connector/db_sqlite

import ../enum_ex
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
import status
import shop
import tutorial_state
import tip
import tension_card
import lux_phantasma
import timestamp
import wallet


type Notifications* = object
  gacha*: Option[GachaNotification]
  mail*: Option[bool]
  itemRequest*: Option[bool]

type Resources* = object
  adventureVariables*: seq[AdventureVariable]
  areas*: Option[seq[Area]]
  areaChangeLocks: seq[AreaChangeLock]
  areaGroups: seq[AreaGroup]
  areaObjectLocks*: Option[seq[AreaObjectLock]]
  challenges*: seq[Challenge]
  challengeProgresses*: seq[ChallengeProgress]
  challengeTasks*: seq[ChallengeTask]
  characters*: seq[Character]
  characterCostumes: seq[CharacterCostume]
  characterLikabilities: Option[seq[CharacterLikability]]
  characterMountingPowers: Option[seq[CharacterMountingPower]]
  characterMountingPowerCommon: Option[CharacterMountingPowerCommon]
  characterPieces: Option[seq[CharacterPiece]]
  cities: seq[City]
  cycleUpdateShopStates: Option[seq[JsonNode]] # FIXME: CycleUpdateShopState
  dailyPassStates: Option[seq[JsonNode]] # FIXME: DailyPassState
  dungeons: Option[seq[Dungeon]]
  eventFloorNodes: Option[seq[EventFloorNode]]
  eventLifts: Option[seq[EventLift]]
  follows: Option[seq[JsonNode]] # FIXME: Follow
  formations*: seq[JsonNode] # FIXME: Formation
  fractalVises: Option[seq[JsonNode]] # FIXME: FractalVise
  gears*: Option[seq[Gear]]
  graffitiArts*: Option[seq[GraffitiArt]]
  guestCharacters: Option[seq[JsonNode]] # FIXME: GuestCharacter
  items*: seq[Item]
  loginBonuses: Option[seq[JsonNode]] # FIXME: LoginBonus
  magicOrbs*: seq[MagicOrb]
  missions*: seq[Mission]
  missionCountRewardStates: Option[seq[JsonNode]] # FIXME: MissionCountRewardState
  nineSequences*: seq[NineSequence]
  notifications*: Option[Notifications]
  profile: Option[JsonNode] # FIXME: Profile
  profileBadges: Option[seq[JsonNode]] # FIXME: ProfileBadge
  profileBanners: Option[seq[JsonNode]] # FIXME: ProfileBanner
  questStates: Option[seq[JsonNode]] # FIXME: QuestState
  seasonPasses: Option[seq[JsonNode]] # FIXME: SeasonPass
  seasonPassTierStates: Option[seq[JsonNode]] # FIXME: SeasonPassTierState
  shopProductStates*: Option[seq[ShopProductState]]
  status*: Option[Status]
  synthesisRecipes: Option[seq[JsonNode]] # FIXME: SynthesisRecipe
  tensionCards: seq[JsonNode] # FIXME: TensionCard
  tips*: Option[seq[Tip]]
  totalTasks: Option[seq[JsonNode]] # FIXME: TotalTask
  trialBattleStates: Option[seq[JsonNode]] # FIXME: TrialBattleState
  tutorialStates*: seq[TutorialState]
  wallet*: Option[Wallet]
  warpPoints*: Option[seq[JsonNode]] # FIXME: WarpPoint
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
  updateTensionCards(db, changedResources.tensionCards)


proc getChangedResourcesForCompletedChallengeTask*(
  db: DbConn, challengeTask: MdChallengeTask
): (seq[AreaObject], Resources) =
  var areaObjects = newSeq[AreaObject]()
  var challengeTasks = newSeq[ChallengeTask]()
  var challengeProgresses = newSeq[ChallengeProgress]()

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
    challengeProgresses.add(ChallengeProgress(
      challengeProgressId: challengeTask.challengeProgressId,
      state: challengeProgressStateStarted.int,
    ))

  let resources = Resources(
    challengeTasks: challengeTasks,
    challengeProgresses: challengeProgresses,
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


proc updateResourcesFromRewardsTypeSafe*(db: DbConn, rewards: var seq[Reward]): Resources =
  var gears = newSeq[Gear]()
  var itemsTable: Table[int, Item]

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
      if not (reward.id in itemsTable):
        let item = getItem(db, reward.id)
        itemsTable[reward.id] = item.get(Item(itemId: reward.id, quantity: some(0)))

      itemsTable[reward.id].quantity = some(itemsTable[reward.id].quantity.get(0) + reward.quantity)
    of rewardGold:
      status.gold = some(status.gold.get(0) + reward.quantity)
    of rewardFlowerMark:
      status.flowerMark = some(status.flowerMark.get(0) + reward.quantity)
    of rewardCharacterExp:
      let formationNumber = status.formationNumber.get(0)
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

  setUserStatusTypeSafe(db, status)

  result.gears = some(gears)
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
        Item(itemId: reward.id, quantity: some(0))

    item.quantity = some(reward.quantity + item.quantity.get(0))
    totalItems += reward.quantity

    changedItems[reward.id] = item
    itemsTable[reward.id] = item

  let items = changedItems.values().toSeq()

  return (items, totalItems)