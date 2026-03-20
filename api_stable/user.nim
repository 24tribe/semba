import std/json

import ../db_connector/db_sqlite

import ../model_stable/adventure_variable
import ../model_stable/area
import ../model_stable/area_change_lock
import ../model_stable/area_group
import ../model_stable/challenge
import ../model_stable/challenge_progress
import ../model_stable/challenge_task
import ../model_stable/character
import ../model_stable/city
import ../model_stable/dungeon
import ../model_stable/formation
import ../model_stable/item
import ../model_stable/lux_phantasma
import ../model_stable/magic_orb
import ../model_stable/mission
import ../model_stable/nine_sequence
import ../model_stable/notification
import ../model_stable/tension_card
import ../model_stable/timestamp
import ../model_stable/tip
import ../model_stable/total_task
import ../model_stable/tutorial_state
import ../model_stable/tutorial
import ../model_stable/user
import ../model_stable/wallet
import ../model_stable/warp_point


proc user_CrossDate*(db: DbConn, jsonReq: JsonNode): JsonNode =
  # FIXME: move status loggedInAt update to user_LogIn
  let status = getUserStatus(db)
  let loggedInAt = getDateNow()
  status["loggedInAt"] = %*loggedInAt
  setUserStatus(db, status)
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


proc user_LogIn*(db: DbConn): JsonNode =
  if isFirstLogin(db):
    setFirstLogin(db, false)
    if not getSkipTutorial(db):
      resetToTutorial(db)

  let formations = getFormations(db)
  let adventureVariables = getAdventureVariables(db)
  let challengeTasks = getChallengeTasks(db)
  let questStates = getQuestStates(db)
  let challenges = getChallenges(db)
  let warpPoints = getWarpPoints(db)
  let areas = getAreas(db)
  let areaGroups = getAreaGroups(db)
  let cities = getCities(db)
  let wallet = getWallet(db)
  let characterPieces = getCharacterPieces(db)
  let dungeons = getDungeons(db)
  let items = getItems(db)
  let magicOrbs = getMagicOrbs(db)
  let areaChangeLocks = getAreaChangeLocks(db)
  let missions = getMissions(db)

  return %*{
    "resources": {
      "challengeTasks": challengeTasks,
      "adventureVariables": adventureVariables,
      "wallet": wallet,
      "characters": getCharacters(db),
      "status": getUserStatus(db),
      "tensionCards": getTensionCards(db),
      "formations": formations,
      "characterMountingPowerCommon": {},
      "notifications": getNotifications(db),
      "challenges": challenges,
      "challengeProgresses": getChallengeProgresses(db),
      "areas": areas,
      "nineSequences": getNineSequences(db),
      "tips": getTips(db),
      "characterCostumes": getCharacterCostumes(db),
      "missions": missions,
      "totalTasks": getTotalTasks(db),
      "profile": {"name": "Yo Kuronaka3", "profileBannerId": 2010011, "characterLikabilityScale": 500},
      "profileBanners": [{"profileBannerId": 2010011, "receivedAt": "2025-09-10T02:22:51Z"}],
      "tutorialStates": getTutorialStates(db),
      "questStates": questStates,
      "warpPoints": warpPoints,
      "areaGroups": areaGroups,
      "cities": cities,
      "characterPieces": characterPieces,
      "dungeons": dungeons,
      "items": items,
      "magicOrbs": magicOrbs,
      "areaChangeLocks": areaChangeLocks,
    },
    "masterData": {"shopProducts": getShopProducts(db)}
  }