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
]#

import std/json
import std/files
import std/paths
import std/options
import std/sets
import std/sequtils
import std/tables

import db_connector/db_sqlite

import protojson
import semba_error
import enum_ex
import api_stable/adventure
import model_semba/offline_log
import model_stable/adventure_variable
import model_stable/area
import model_stable/area_change_lock
import model_stable/area_group
import model_stable/area_object
import model_stable/area_object_lock
import model_stable/challenge
import model_stable/challenge_progress
import model_stable/challenge_task
import model_stable/character
import model_stable/character_piece
import model_stable/city
import model_stable/dungeon
import model_stable/formation
import model_stable/gacha
import model_stable/gear
import model_stable/graffiti_art
import model_stable/happy_worker
import model_stable/item
import model_stable/lux_phantasma
import model_stable/magic_orb
import model_stable/mission
import model_stable/nine_sequence
import model_stable/resources
import model_stable/status
import model_stable/tension_card
import model_stable/tip
import model_stable/total_task
import model_stable/tutorial_state
import model_stable/user
import model_stable/warp_point


type SembaSave* = object
  version*: int
  formations: seq[JsonNode]
  tips: seq[JsonNode]
  areaObjects: seq[JsonNode]
  areaEnemies: seq[JsonNode]
  status: Status
  offlineLogs: seq[OfflineLog]
  areaBgms: seq[JsonNode]
  characters: seq[Character]
  tensionCards: seq[JsonNode]
  challengeProgresses: seq[JsonNode]
  nineSequences: seq[JsonNode]
  totalTasks: seq[JsonNode]
  tutorialStates: seq[JsonNode]
  adventureVariables: seq[JsonNode]
  challengeTasks: seq[ChallengeTask]
  areaActionSequenceIds: seq[JsonNode]
  questStates: seq[JsonNode]
  clearedAchievements: seq[JsonNode]
  challenges: seq[JsonNode]
  warpPoints: seq[WarpPoint]
  areas: seq[JsonNode]
  areaGroups: seq[JsonNode]
  cities: seq[City]
  characterPieces: seq[CharacterPiece]
  userData: seq[JsonNode]
  dungeons: seq[JsonNode]
  magicOrbs: seq[MagicOrb]
  areaChangeLocks: seq[AreaChangeLock]
  items: seq[Item]
  gears: seq[Gear]
  graffitiArts: seq[GraffitiArt]
  areaObjectLocks: seq[AreaObjectLock]
  happyWorkerItems: seq[HappyWorkerItem]
  missions: seq[Mission]


proc resetAreaObjects*(db: DbConn) =
  db.exec(sql"DELETE FROM areaObjects")
  db.exec(sql"INSERT INTO areaObjects SELECT * FROM areaObjectsOriginal")
  db.exec(sql"DELETE FROM areaEnemies")
  db.exec(sql"INSERT INTO areaEnemies SELECT * FROM areaEnemiesOriginal")
  db.exec(sql"DELETE FROM areaBgm")
  db.exec(sql"INSERT INTO areaBgm SELECT * FROM areaBgmOriginal")


proc loadSaveFileVer3(db: DbConn, save: SembaSave, dontDeleteAllAreaObjects: bool) =
  db.exec(sql"DELETE FROM tips")

  for tip in save.tips:
    addTip(db, tip)

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
    addCharacterTypeSafe(db, character) # FIXME: use type safe version of addCharacter

  db.exec(sql"DELETE FROM tensionCards")
  db.exec(sql"DELETE FROM tensionCardLimitBreaks")

  for tensionCard in save.tensionCards:
    addTensionCard(db, tensionCard)

  db.exec(sql"DELETE FROM challengeProgresses")

  for challengeProgress in save.challengeProgresses:
    addChallengeProgress(db, challengeProgress)

  db.exec(sql"DELETE FROM nineSequences")

  for nineSequence in save.nineSequences:
    addNineSequence(db, nineSequence)

  db.exec(sql"DELETE FROM totalTasks")

  for totalTask in save.totalTasks:
    addTotalTask(db, totalTask)

  db.exec(sql"DELETE FROM tutorialStates")

  for tutorialState in save.tutorialStates:
    addTutorialState(db, tutorialState)

  db.exec(sql"DELETE FROM adventureVariables")

  for adventureVariable in save.adventureVariables:
    addAdventureVariable(db, adventureVariable)

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
    addArea(db, area["areaId"].getInt())

  db.exec(sql"DELETE FROM areaGroups")

  for areaGroup in save.areaGroups:
    addAreaGroup(db, areaGroup["areaGroupId"].getInt())

  db.exec(sql"DELETE FROM cities")

  for city in save.cities:
    addCity(db, city)


proc ensureAlreadyDoneMiniGameChestsAreUnlocked(db: DbConn, save: var SembaSave): Table[CityId, HashSet[int]] =
  var areaObjectLockIds = save.areaObjectLocks.mapIt(it.areaObjectLockId).toHashSet()

  for log in save.offlineLogs:
    if log.uri == "/adventure/read_sequence":
      let req = protoJsonTo(parseJson(log.req), AdventureReadSequenceRequest)
      if req.miniGameId.isSome():
        let miniGameId = req.miniGameId.get()
        let areaId = req.currentLocation.areaKeyId.get()
        let areaObjectLockId = getAreaObjectLockIdForMiniGame(db, areaId, miniGameId)
        if areaObjectLockId.isSome():
          let cityId = areaIdToCityId(areaId).intToEnum(CityId)

          if not result.hasKey(cityId):
            result[cityId] = initHashSet[int]()

          result[cityId].incl(areaObjectLockId.get())

          areaObjectLockIds.incl(areaObjectLockId.get())

  save.areaObjectLocks = areaObjectLockIds.mapIt(AreaObjectLock(areaObjectLockId: it, count: some(1)))


proc fixTroubleshooterMissions(
  missions: var Table[int, Mission], db: DbConn, cityAreaObjectLockIds: Table[CityId, HashSet[int]]
) =
  for cityId, areaObjectLockIds in cityAreaObjectLockIds.pairs():
    let mdMissions = getTroubleshooterMissionsForCity(db, cityId.int)
    for mission in mdMissions:
      if not missions.hasKey(mission.id):
        missions[mission.id] = Mission(missionId: mission.id)

      missions[mission.id].count = some(areaObjectLockIds.len)


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


proc fixGraffitiMissions(missions: var Table[int, Mission], db: DbConn, graffitiArtCounts: CountTable[CityId]) =
  fixMissionCounts(missions, db, graffitiArtCounts, getGraffitiMissionsForCity)


proc fixMagicOrbMissions(missions: var Table[int, Mission], db: DbConn, magicOrbCounts: CountTable[CityId]) =
  fixMissionCounts(missions, db, magicOrbCounts, getMagicOrbMissionsForCity)


proc fixClearCityChallengesMissions(
  missions: var Table[int, Mission], db: DbConn, cityChallengesCount: CountTable[CityId]
) =
  fixMissionCounts(missions, db, cityChallengesCount, getCompleteCityChallengeMissionsForCityId)


proc fixMissions(db: DbConn, save: var SembaSave, cityAreaObjectLockIds: Table[CityId, HashSet[int]]) =
  var missions = save.missions.mapIt((it.missionId, it)).toTable()

  let graffitiArtCounts = save.graffitiArts.mapIt(
    graffitiArtIdToCityId(it.graffitiArtId).intToEnum(CityId)
  ).toCountTable

  let magicOrbCounts = save.magicOrbs.mapIt(magicOrbIdToCityId(it.magicOrbId)).toCountTable

  let cityChallengesCount = getCityChallengesCount(db)

  fixTroubleshooterMissions(missions, db, cityAreaObjectLockIds)
  fixGraffitiMissions(missions, db, graffitiArtCounts)
  fixMagicOrbMissions(missions, db, magicOrbCounts)
  fixClearCityChallengesMissions(missions, db, cityChallengesCount)
  
  let warpPointCounts = save.warpPoints.mapIt(warpPointIdToCityId(it.warpPointId).intToEnum(CityId)).toCountTable
  fixMissionCounts(missions, db, warpPointCounts, getLinkedSignpostsMissionsForCity)

  save.missions = missions.values().toSeq()


proc sanityChecks(db: DbConn, save: var SembaSave) =
  # https://github.com/24tribe/zero/issues/24
  if (
    isChallengeProgressComplete(getChallengeProgress(db, 1010071)) and
    not isChallengeProgressComplete(getChallengeProgress(db, 1010081))
  ):
    updateActionSequenceId(db, 101311, 8010081)

  # https://github.com/24tribe/zero/issues/26
  if isChallengeProgressComplete(getChallengeProgress(db, 1010042)):
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
  if isChallengeProgressComplete(getChallengeProgress(db, clearHealthyOutlawsChallengeProgressId)):
    updateAreaObjects(db, %*[
      {
        "areaObjectId": 700110, "areaPointId": 101001101, "areaObjectBehaviorId": 7010709,
        "action": {"type": 7, "id": 1}
      }
    ])

  let cityAreaObjectLockIds = ensureAlreadyDoneMiniGameChestsAreUnlocked(db, save)

  fixMissions(db, save, cityAreaObjectLockIds)


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
    updateChallenges(db, save.challenges)

  if save.version >= 8:
    loadSaveFileVer8(db, save)

  db.exec(sql"DELETE FROM dungeons")

  if save.version >= 10:
    for dungeon in save.dungeons:
      addDungeon(db, dungeon)

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

  if isChallengeProgressComplete(getChallengeProgress(db, lastTutorialChallengeProgressId)):
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


proc loadSaveFile*(db: DbConn, saves_dir: string, name: string): string =
  const baseError = "Couldn't load save file"

  if db == nil:
    return baseError & ", db is not initialized"

  let content = readFile(saves_dir & "/" & name & ".save")
  var save = protoJsonTo(parseJson(content), SembaSave)

  loadSembaSave(db, save)


proc getSaveFile*(db: DbConn): SembaSave =
  result = SembaSave(
    version: 15,
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
  )


proc createSaveFile*(db: DbConn, saves_dir: string, name: string): string =
  const baseError = "Couldn't create save file"

  if db == nil:
      return baseError & ", db is not initialized"

  let jsonData = toProtoJson(getSaveFile(db))

  writeFile(saves_dir & "/" & name & ".save", $jsonData)


proc deleteSaveFile*(saves_dir: string, name: string) =
  removeFile((saves_dir & "/" & name & ".save").Path)