import std/json
import std/options

import db_connector/db_sqlite

import ../model_stable/adventure_variable
import ../model_stable/area
import ../model_stable/area_object_lock
import ../model_stable/area_change_lock
import ../model_stable/area_group
import ../model_stable/challenge
import ../model_stable/challenge_progress
import ../model_stable/challenge_task
import ../model_stable/character
import ../model_stable/character_piece
import ../model_stable/city
import ../model_stable/dungeon
import ../model_stable/formation
import ../model_stable/graffiti_art
import ../model_stable/gear
import ../model_stable/item
import ../model_stable/lux_phantasma
import ../model_stable/magic_orb
import ../model_stable/mission
import ../model_stable/nine_sequence
import ../model_stable/notification
import ../model_stable/resources
import ../model_stable/status
import ../model_stable/shop
import ../model_stable/tension_card
import ../model_stable/timestamp
import ../model_stable/tip
import ../model_stable/total_task
import ../model_stable/tutorial_state
import ../model_stable/tutorial
import ../model_stable/wallet
import ../model_stable/warp_point


type UserLogInResponse* = object
  resources*: Resources
  masterData*: MasterData
  moveToAreaLocatorId*: Option[int]


proc user_CrossDate*(db: DbConn, jsonReq: JsonNode): JsonNode =
  # FIXME: move status loggedInAt update to user_LogIn
  var status = getUserStatusTypeSafe(db)
  status.loggedInAt = getTimestampNow()
  setUserStatusTypeSafe(db, status)
  return %*{
    "changedResources": {
      "status": status,
      "notifications": getNotifications(db)
    }
  }


proc user_Notification*(db: DbConn): JsonNode =
  let notifications = getNotifications(db)
  return %*{
    "changedResources": {
      "notifications": notifications
    }
  }


proc user_LogIn*(db: DbConn): UserLogInResponse =
  if isFirstLogin(db):
    setFirstLogin(db, false)
    if not getSkipTutorial(db):
      resetToTutorial(db)

  result.masterData.shopProducts = getShopProducts(db)

  result.resources = Resources(
    adventureVariables: getAdventureVariables(db),
    areaChangeLocks: getAreaChangeLocks(db),
    areaGroups: getAreaGroups(db),
    areaObjectLocks: getAreaObjectLocks(db),
    areas: getAreas(db),
    challengeProgresses: getChallengeProgresses(db),
    challengeTasks: getChallengeTasks(db),
    challenges: getChallenges(db),
    characterCostumes: getCharacterCostumes(db),
    characterPieces: getCharacterPieces(db),
    characters: getCharactersTypeSafe(db),
    cities: getCities(db),
    dungeons: getDungeons(db),
    formations: getFormations(db),
    gears: getGears(db),
    graffitiArts: getGraffitiArts(db),
    items: getItems(db),
    magicOrbs: getMagicOrbs(db),
    missions: getMissions(db),
    nineSequences: getNineSequences(db),
    notifications: some(getNotifications(db)),
    profile: some(%*{"name": "Yo Kuronaka3", "profileBannerId": 2010011, "characterLikabilityScale": 500}),
    profileBanners: @[%*{"profileBannerId": 2010011, "receivedAt": "2025-09-10T02:22:51Z"}],
    questStates: getQuestStates(db),
    status: some(getUserStatusTypeSafe(db)),
    tensionCards: getTensionCards(db),
    tips: getTips(db),
    totalTasks: getTotalTasks(db),
    tutorialStates: getTutorialStates(db),
    wallet: some(getWallet(db)),
    warpPoints: getWarpPoints(db),
  )