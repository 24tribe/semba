import std/json
import std/sets

import ../db_connector/db_sqlite

import area_object
import user
import nine_sequence
import adventure_variable
import challenge_progress
import challenge_task
import challenge
import tutorial_state
import area_group
import city
import magic_orb
import item
import area_change_lock
import formation
import character


proc updateResources*(db: DbConn, changedResources: var JsonNode) =
  var handledKeys = initHashSet[string]()

  if changedResources.getOrDefault("status") != nil:
    handledKeys.incl("status")
    var status = getUserStatus(db)
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

  let items = changedResources.getOrDefault("items").getElems()
  
  if items.len > 0:
    handledKeys.incl("items")
  
  updateItems(db, items)

  let areaChangeLocks = changedResources.getOrDefault("areaChangeLocks").getElems()

  if areaChangeLocks.len > 0:
    handledKeys.incl("areaChangeLocks")

  updateAreaChangeLocks(db, areaChangeLocks)

  let missions = changedResources.getOrDefault("missions")

  if missions != nil:
    # Don't return (zero sensei) missions from online logs
    changedResources.delete("missions")
    handledKeys.incl("missions")

  let formations = changedResources.getOrDefault("formations").getElems()

  if formations.len > 0:
    updateFormations(db, formations)
    handledKeys.incl("formations")

  let characters = changedResources.getOrDefault("characters").getElems()

  if characters.len > 0:
    updateCharacters(db, characters)
    handledKeys.incl("characters")

  for key, _ in changedResources.pairs():
    if not (key in handledKeys):
      echo("WARNING: " & key & " not handled in updateResources")


proc updateFromReadSequenceResponse*(db: DbConn, response: JsonNode) =
  updateAreaObjects(db, response["areaObjects"])
  var changedResources = response["changedResources"]
  updateResources(db, changedResources) 