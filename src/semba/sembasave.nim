#[
This module is in charge of the save files.
Each version can save/load more tables from the db.
Old save files should work on new versions of the offline mode,
and if they don't, that's considered a bug.

version 2: formations
version 3: tips, areaObjects, areaEnemies
version 4: userStatus
version 5: (
  debugLogsOffline, areaBgm, characters, tensionCards,
  challengeProgresses, nineSequences, totalTasks, tutorialStates,
  adventureVariables, challengeTasks, areaActionSequenceIds, questStates
  clearedAchievements
)
version 6: has new areaObjects
version 7: challenges
version 8: warpPoints, areas, areaGroups, cities
version 9: characterPieces, userData
version 10: dungeons
version 11: magicOrbs, items, areaChangeLocks
version 12: gears
version 13: graffitis
version 14: areaObjectLocks, happyWorkerItems
version 15: missions
version 16: dungeon states, dungeon area items, dungeon enemies
]#

import std/json
import std/files
import std/paths
import std/options
import std/sets
import std/sequtils
import std/tables
import std/strutils

import db_connector/db_sqlite
import zippy

import ./protojson
import ./semba_error
import ./enum_ex
import ./api_stable/adventure
import ./api_stable/battle
import ./model_semba/offline_log
import ./model_stable/adventure_variable
import ./model_stable/area
import ./model_stable/area_change_lock
import ./model_stable/area_group
import ./model_stable/area_object
import ./model_stable/area_object_lock
import ./model_stable/battle_enum
import ./model_stable/challenge
import ./model_stable/challenge_progress
import ./model_stable/challenge_task
import ./model_stable/character
import ./model_stable/character_piece
import ./model_stable/city
import ./model_stable/dungeon
import ./model_stable/formation
import ./model_stable/gacha
import ./model_stable/gear
import ./model_stable/graffiti_art
import ./model_stable/happy_worker
import ./model_stable/item
import ./model_stable/lux_phantasma
import ./model_stable/magic_orb
import ./model_stable/mission
import ./model_stable/nine_sequence
import ./model_stable/resources
import ./model_stable/status
import ./model_stable/sequence_request
import ./model_stable/tension_card
import ./model_stable/tip
import ./model_stable/total_task
import ./model_stable/tutorial_state
import ./model_stable/user
import ./model_stable/warp_point


const gzipMagic = "\x1F\x8B"


type SembaSave* = object
  version*: int
  adventureVariables: seq[AdventureVariable]
  areaActionSequenceIds: seq[JsonNode]
  areaBgms: seq[JsonNode]
  areaChangeLocks: seq[AreaChangeLock]
  areaEnemies: seq[JsonNode]
  areaGroups: seq[AreaGroup]
  areaObjectLocks: seq[AreaObjectLock]
  areaObjects: seq[JsonNode]
  areas: seq[Area]
  challengeProgresses: seq[ChallengeProgress]
  challengeTasks: seq[ChallengeTask]
  challenges: seq[Challenge]
  characterPieces: seq[CharacterPiece]
  characters: seq[Character]
  cities: seq[City]
  clearedAchievements: seq[JsonNode]
  dungeons: seq[Dungeon]
  dungeonEnemies*: seq[tuple[dungeonId: int, enemy: DungeonEnemy]]
  formations: seq[JsonNode]
  gears: seq[Gear]
  graffitiArts: seq[GraffitiArt]
  happyWorkerItems: seq[HappyWorkerItem]
  items: seq[Item]
  magicOrbs: seq[MagicOrb]
  missions: seq[Mission]
  nineSequences: seq[NineSequence]
  offlineLogs: seq[OfflineLog]
  questStates: seq[JsonNode]
  status: Status
  tensionCards: seq[TensionCard]
  tips: seq[Tip]
  totalTasks: seq[TotalTask]
  tutorialStates: seq[TutorialState]
  userData: seq[JsonNode]
  warpPoints: seq[WarpPoint]


proc resetAreaObjects*(db: DbConn) =
  db.exec(sql"DELETE FROM areaObjects")
  db.exec(sql"INSERT INTO areaObjects SELECT * FROM areaObjectsOriginal")
  db.exec(sql"DELETE FROM areaEnemies")
  db.exec(sql"INSERT INTO areaEnemies SELECT * FROM areaEnemiesOriginal")
  db.exec(sql"DELETE FROM areaBgm")
  db.exec(sql"INSERT INTO areaBgm SELECT * FROM areaBgmOriginal")


proc loadSaveFileVer3(db: DbConn, save: SembaSave, dontDeleteAllAreaObjects: bool) =
  db.exec(sql"DELETE FROM tips")

  addTips(db, save.tips)

  if not dontDeleteAllAreaObjects:
    db.exec(sql"DELETE FROM areaObjects")

  for areaObject in save.areaObjects:
    addAreaObject(db, areaObject)

  if not dontDeleteAllAreaObjects:
    db.exec(sql"DELETE FROM areaEnemies")

  for areaEnemy in save.areaEnemies:
    addAreaEnemy(db, areaEnemy)


proc loadSaveFileVer5(db: DbConn, save: SembaSave, dontDeleteAllAreaObjects: bool) =
  db.exec(sql"DELETE FROM debugLogsOffline")

  for offlineLog in save.offlineLogs:
    addOfflineLog(db, offlineLog)

  if not dontDeleteAllAreaObjects:
    db.exec(sql"DELETE FROM areaBgm")

  for areaBgm in save.areaBgms:
    addAreaBgm(db, areaBgm)

  db.exec(sql"DELETE FROM characters")
  db.exec(sql"DELETE FROM characterLimitBreaks")

  for character in save.characters:
    addCharacterTypeSafe(db, character)

  db.exec(sql"DELETE FROM tensionCards")

  for tensionCard in save.tensionCards:
    upsertTensionCard(db, tensionCard)

  db.exec(sql"DELETE FROM challengeProgresses")

  upsertChallengeProgresses(db, save.challengeProgresses)

  db.exec(sql"DELETE FROM nineSequences")

  updateNineSequences(db, save.nineSequences)

  db.exec(sql"DELETE FROM totalTasks")

  upsertTotalTasks(db, save.totalTasks)

  db.exec(sql"DELETE FROM tutorialStates")

  upsertTutorialStates(db, save.tutorialStates)

  db.exec(sql"DELETE FROM adventureVariables")

  updateAdventureVariables(db, save.adventureVariables)

  db.exec(sql"DELETE FROM challengeTasks")

  upsertChallengeTasks(db, save.challengeTasks)

  db.exec(sql"DELETE FROM areaActionSequenceIds")
  db.exec(sql"INSERT INTO areaActionSequenceIds SELECT * FROM defaultAreaActionSequenceIds")

  for areaActionSequenceId in save.areaActionSequenceIds:
    addAreaActionSequenceId(db, areaActionSequenceId)

  db.exec(sql"DELETE FROM questStates")

  for questState in save.questStates:
    addQuestState(db, questState)

  db.exec(sql"DELETE FROM clearedAchievements")

  for clearedAchievement in save.clearedAchievements:
    addClearedAchievement(db, clearedAchievement)


proc loadSaveFileVer8(db: DbConn, save: SembaSave) =
  db.exec(sql"DELETE FROM warpPoints")

  for warpPoint in save.warpPoints:
    addWarpPoint(db, warpPoint.warpPointId)

  db.exec(sql"DELETE FROM areas")

  for area in save.areas:
    addArea(db, area.areaId)

  db.exec(sql"DELETE FROM areaGroups")

  for areaGroup in save.areaGroups:
    addAreaGroup(db, areaGroup.areaGroupId)

  db.exec(sql"DELETE FROM cities")

  for city in save.cities:
    addCity(db, city)


proc tableToCounts(t: Table[CityId, HashSet[int]]): CountTable[CityId] =
  for cityId, areaObjectLocks in t:
    result[cityId] = areaObjectLocks.len


proc handleReadSequence(db: DbConn, req: AdventureReadSequenceRequest): (CityId, Option[int], seq[AreaChangeLock]) =
  if req.miniGameId.isSome():
    let miniGameId = req.miniGameId.get()
    let areaId = req.currentLocation.areaKeyId.get()
    let areaObjectLockId = getAreaObjectLockIdForMiniGame(db, areaId, miniGameId)
    let cityId = areaIdToCityId(areaId).intToEnum(CityId)

    let seqReqs = getMdSequenceRequests(db, req.sequenceRequestIds.get(@[]))

    var areaChangeLocks = newSeq[AreaChangeLock]()

    for seqReq in seqReqs:
      case seqReq.kind:
      of seqReqAreaChangeLock:
        areaChangeLocks.add(AreaChangeLock(areaChangeLockId: seqReq.areaChangeLockId))
      else:
        discard

    result = (cityId, areaObjectLockId, areaChangeLocks)


proc ensureAlreadyDoneMiniGameThingsAreUnlocked(db: DbConn, save: var SembaSave): CountTable[CityId]  =
  var areaObjectLocksForCity: Table[CityId, HashSet[int]]
  var areaObjectLockIds = save.areaObjectLocks.mapIt(it.areaObjectLockId).toHashSet()
  var areaChangeLocks = newSeq[AreaChangeLock]()

  var lastBattleStart = none(BattleStartRequest)

  for log in save.offlineLogs:
    case log.uri:
    of "/adventure/read_sequence":
      let req = parseJson(log.req).protoJsonTo(AdventureReadSequenceRequest)
      let (cityId, areaObjectLockId, newAreaChangeLocks) = handleReadSequence(db, req)

      if areaObjectLockId.isSome:
        if not areaObjectLocksForCity.hasKey(cityId):
          areaObjectLocksForCity[cityId] = initHashSet[int]()

        areaObjectLocksForCity[cityId].incl(areaObjectLockId.get())

        areaObjectLockIds.incl(areaObjectLockId.get())

      areaChangeLocks.insert(newAreaChangeLocks)
    of "/battle/start":
      lastBattleStart = some(parseJson(log.req).protoJsonTo(BattleStartRequest))
    of "/battle/finish":
      let req = parseJson(log.req).protoJsonTo(BattleFinishRequest)
      if lastBattleStart.isSome and req.battleResult == BattleResult.won:
        for battleTrigger in lastBattleStart.get().battleTriggers:
          if battleTrigger.triggerType == BattleTriggerType.areaObject:
            for triggerId in battleTrigger.triggerIds:
              let areaObjectLockId = getAreaObjectLockIdForBattle(db, triggerId)

              if areaObjectLockId.isSome:
                areaObjectLockIds.incl(areaObjectLockId.get())

  updateAreaChangeLocks(db, areaChangeLocks)

  result = tableToCounts(areaObjectLocksForCity)

  save.areaObjectLocks = areaObjectLockIds.mapIt(AreaObjectLock(areaObjectLockId: it, count: some(1)))


proc fixMissionCounts(
  missions: var Table[int, Mission],
  db: DbConn, counts: CountTable[CityId],
  getMissionsOfTypeForCity: proc (db: DbConn, cityId: int): seq[MdMission]
) =
  for cityId, count in counts.pairs():
    let mdMissions = getMissionsOfTypeForCity(db, cityId.int)
    for mission in mdMissions:
      if not missions.hasKey(mission.id):
        missions[mission.id] = Mission(missionId: mission.id)

      missions[mission.id].count = some(count)


proc fixTroubleshooterMissions(
  missions: var Table[int, Mission], db: DbConn, areaObjectLockCounts: CountTable[CityId]
) =
  fixMissionCounts(missions, db, areaObjectLockCounts, getTroubleshooterMissionsForCity)


proc fixGraffitiMissions(missions: var Table[int, Mission], db: DbConn, graffitiArtCounts: CountTable[CityId]) =
  fixMissionCounts(missions, db, graffitiArtCounts, getGraffitiMissionsForCity)


proc fixMagicOrbMissions(missions: var Table[int, Mission], db: DbConn, magicOrbCounts: CountTable[CityId]) =
  fixMissionCounts(missions, db, magicOrbCounts, getMagicOrbMissionsForCity)


proc fixClearCityChallengesMissions(
  missions: var Table[int, Mission], db: DbConn, cityChallengesCount: CountTable[CityId]
) =
  fixMissionCounts(missions, db, cityChallengesCount, getCompleteCityChallengeMissionsForCityId)


proc fixMissions(db: DbConn, save: var SembaSave, areaObjectLockCounts: CountTable[CityId]) =
  var missions = save.missions.mapIt((it.missionId, it)).toTable()

  let graffitiArtCounts = save.graffitiArts.mapIt(
    graffitiArtIdToCityId(it.graffitiArtId).intToEnum(CityId)
  ).toCountTable

  let magicOrbCounts = save.magicOrbs.mapIt(magicOrbIdToCityId(it.magicOrbId)).toCountTable

  let cityChallengesCount = getCityChallengesCount(db)

  fixTroubleshooterMissions(missions, db, areaObjectLockCounts)
  fixGraffitiMissions(missions, db, graffitiArtCounts)
  fixMagicOrbMissions(missions, db, magicOrbCounts)
  fixClearCityChallengesMissions(missions, db, cityChallengesCount)
  
  let warpPointCounts = save.warpPoints.mapIt(warpPointIdToCityId(it.warpPointId).intToEnum(CityId)).toCountTable
  fixMissionCounts(missions, db, warpPointCounts, getLinkedSignpostsMissionsForCity)

  save.missions = missions.values().toSeq()


proc fixTotalTaskChallenges(db: DbConn, save: SembaSave) =
  let (_, challenges, challengeProgresses, challengeTasks, nineSequences) = getChangedResourcesFromTotalTasks(
    db, [TotalTask(conditionId: flowerMarksTotalTaskConditionId, count: save.status.flowerMark.ProtoJsonInt64)]
  )

  upsertChallengesIfNotComplete(db, challenges)
  upsertChallengeProgressesIfNotComplete(db, challengeProgresses)
  upsertChallengeTasksIfNotComplete(db, challengeTasks)
  updateNineSequences(db, nineSequences)


proc fixHeroJammedDrones(db: DbConn, save: SembaSave) =
  let challs = save.challenges.mapIt((it.challengeId, it)).toTable

  const heroJammedChallengeId = 100181

  if not challs.hasKey(heroJammedChallengeId) or challs[heroJammedChallengeId].state == challengeStateNotStarted.int:
    removeAreaObjects(db, heroJammedDroneAreaObjectBehaviorIds)


proc fixHeroJammedNineSequence(db: DbConn, save: SembaSave) =
  let challProgs = save.challengeProgresses.mapIt((it.challengeProgressId, it)).toTable

  const nineTriggerChallProgId = 10018103

  if challProgs.hasKey(nineTriggerChallProgId) and challProgs[nineTriggerChallProgId].state != challengeProgressStateCleared.int:
    updateNineSequences(db, @[NineSequence(nineSequenceId: heroJammedCompleteNineSequenceId, lastReceiveAt: some(getTimestampNow()))])


proc sanityChecks(db: DbConn, save: var SembaSave) =
  # https://github.com/24tribe/zero/issues/24
  if (
    isChallengeProgressComplete(db, 1010071) and
    not isChallengeProgressComplete(db, 1010081)
  ):
    updateActionSequenceId(db, 101311, 8010081)

  # https://github.com/24tribe/zero/issues/26
  if isChallengeProgressComplete(db, 1010042):
    updateAreaObjects(db, %*[
      {
        "areaObjectId": 700058, "areaPointId": 101312102, "areaObjectBehaviorId": 7010712,
        "action": {"type": 7, "id": 1}
      },
      {
        "areaObjectId": 700053, "areaPointId": 101311120, "areaObjectBehaviorId": 7010714,
        "action": {"type": 7, "id": 1}
      }
    ])

  # https://github.com/24tribe/zero/issues/28
  if isChallengeProgressComplete(db, clearHealthyOutlawsChallengeProgressId):
    updateAreaObjects(db, %*[
      {
        "areaObjectId": 700110, "areaPointId": 101001101, "areaObjectBehaviorId": 7010709,
        "action": {"type": 7, "id": 1}
      }
    ])

  let areaObjectLocksCounts = ensureAlreadyDoneMiniGameThingsAreUnlocked(db, save)

  fixMissions(db, save, areaObjectLocksCounts)
  fixTotalTaskChallenges(db, save)
  fixHeroJammedDrones(db, save)
  fixHeroJammedNineSequence(db, save)


proc loadSembaSave*(db: DbConn, save: var SembaSave) =
  resetAreaObjects(db)

  if save.version < 2:
    raise newException(SembaError, "invalid save file version: should be >= 2")

  for formation in save.formations:
    updateFormation(db, formation)

  # all saves until version 5 are stuck in the first three areas
  let dontDeleteAllAreaObjects = save.version <= 5

  if save.version >= 3:
    if dontDeleteAllAreaObjects:
      db.exec(sql"DELETE FROM areaObjects WHERE areaId=300402 or areaId=300401 or areaId=101381")
      db.exec(sql"DELETE FROM areaEnemies WHERE areaId=300402 or areaId=300401 or areaId=101381")
      db.exec(sql"DELETE FROM areaBgm WHERE areaId=300402 or areaId=300401 or areaId=300501 or areaId=101381 or areaId=130801")

    loadSaveFileVer3(db, save, dontDeleteAllAreaObjects)

  db.exec(sql"DELETE FROM characterPieces")
  db.exec(sql"DELETE FROM userData")
  db.exec(sql"INSERT INTO userData SELECT * FROM defaultUserData")

  if save.version >= 9:
    for characterPiece in save.characterPieces:
      updateCharacterPiece(db, characterPiece)

    for row in save.userData:
      updateUserData(db, row["keyName"].getStr(), row["val"].getStr())

  if save.version >= 4:
    setUserStatusTypeSafe(db, save.status)

  if save.version >= 5:
    loadSaveFileVer5(db, save, dontDeleteAllAreaObjects)

  if save.version >= 7:
    upsertChallenges(db, save.challenges)

  if save.version >= 8:
    loadSaveFileVer8(db, save)

  db.exec(sql"DELETE FROM dungeons")

  if save.version >= 10:
    upsertDungeons(db, save.dungeons)

  db.exec(sql"DELETE FROM magicOrbs")
  db.exec(sql"DELETE FROM items")
  db.exec(sql"DELETE FROM areaChangeLocks")

  if save.version >= 11:
    updateMagicOrbs(db, save.magicOrbs)

    updateAreaChangeLocks(db, save.areaChangeLocks)

    updateItems(db, save.items)

  db.exec(sql"UPDATE userData SET val = 'false' WHERE keyName = 'firstLogin'")

  sanityChecks(db, save)

  db.exec(sql"DELETE FROM missions")
  updateMissions(db, save.missions)

  if isChallengeProgressComplete(db, lastTutorialChallengeProgressId):
    setAfterTutorialGacha(db)
  else:
    setTutorialGacha(db)

  db.exec(sql"DELETE FROM gears")

  if save.version >= 12:
    for gear in save.gears:
      addGear(db, gear)

  db.exec(sql"DELETE FROM graffitiArts")

  if save.version >= 13:
    addGraffitiArts(db, save.graffitiArts)

  db.exec(sql"DELETE FROM mails")
  db.exec(sql"DELETE FROM areaObjectLocks")

  upsertAreaObjectLocks(db, save.areaObjectLocks)

  db.exec(sql"UPDATE happyWorkerItems SET isCleared = false, state = 1")

  if save.version >= 14:
    updateHappyWorkerItems(db, save.happyWorkerItems)

  loadDungeonEnemies(db, save.dungeonEnemies)


proc toString(a: openArray[uint8]): string =
  result = newStringOfCap(a.len)
  for c in a:
    result.add(c.char)


proc loadSaveFile*(db: DbConn, saves_dir: string, name: string): string =
  const baseError = "Couldn't load save file"

  if db == nil:
    return baseError & ", db is not initialized"

  let content = readFile(saves_dir & "/" & name & ".save")

  let uncompressedContent =
    if content.startswith(gzipMagic):
      uncompress(cast[seq[uint8]](content)).toString
    else:
      content

  var save = parseJson(uncompressedContent).protoJsonTo(SembaSave)

  loadSembaSave(db, save)


proc getSaveFile*(db: DbConn): SembaSave =
  result = SembaSave(
    version: 16,
    formations: getFormations(db),
    tips: getTips(db),
    areaObjects: getAreaObjects(db),
    areaEnemies: getAreaEnemies(db),
    status: getUserStatusTypeSafe(db),
    offlineLogs: getOfflineLogs(db),
    areaBgms: getAreaBgms(db),
    characters: getCharactersTypeSafe(db),
    tensionCards: getTensionCards(db),
    challengeProgresses: getChallengeProgresses(db),
    nineSequences: getNineSequences(db),
    totalTasks: getTotalTasks(db),
    tutorialStates: getTutorialStates(db),
    adventureVariables: getAdventureVariables(db),
    challengeTasks: getChallengeTasks(db),
    areaActionSequenceIds: getAreaActionSequenceIds(db),
    questStates: getQuestStates(db),
    clearedAchievements: getClearedAchievements(db),
    challenges: getChallenges(db),
    warpPoints: getWarpPoints(db),
    areas: getAreas(db),
    areaGroups: getAreaGroups(db),
    cities: getCities(db),
    characterPieces: getCharacterPieces(db),
    userData: getUserData(db),
    dungeons: getDungeons(db),
    magicOrbs: getMagicOrbs(db),
    areaChangeLocks: getAreaChangeLocks(db),
    items: getItems(db),
    gears: getGears(db),
    graffitiArts: getGraffitiArts(db),
    areaObjectLocks: getAreaObjectLocks(db),
    happyWorkerItems: getHappyWorkerItems(db, [10, 13, 14]),
    missions: getMissions(db),
    dungeonEnemies: dumpDungeonEnemies(db),
  )


proc createSaveFile*(db: DbConn, saves_dir: string, name: string): string =
  const baseError = "Couldn't create save file"

  if db == nil:
      return baseError & ", db is not initialized"

  let jsonData = toProtoJson(getSaveFile(db))

  let data = compress(cast[seq[uint8]]($jsonData)).toString

  writeFile(saves_dir & "/" & name & ".save", data)


proc deleteSaveFile*(saves_dir: string, name: string) =
  removeFile((saves_dir & "/" & name & ".save").Path)