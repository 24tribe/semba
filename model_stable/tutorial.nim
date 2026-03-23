import std/json
import std/strutils

import ../db_connector/db_sqlite

import ../semba_error
import timestamp
import challenge_progress
import challenge
import user
import gacha


proc isFirstLogin*(db: DbConn): bool =
  let row = db.getRow(sql"SELECT val FROM userData WHERE keyName = 'firstLogin'")

  if row[0] == "":
    raise newException(SembaError, "couldn't get firstLogin from user data")

  return row[0] == "true"


proc setFirstLogin*(db: DbConn, val: bool) =
  db.exec(sql"UPDATE userData SET val = ? WHERE keyName = 'firstLogin'", val)


proc getSkipTutorial*(db: DbConn): bool =
  let row = db.getRow(sql"SELECT val FROM userData WHERE keyName = 'skipTutorial'")

  if row[0] == "":
    raise newException(SembaError, "Couldn't find skipTutorial value on db")

  return row[0] == "true"


proc resetToTutorial*(db: DbConn) =
  db.exec(sql"DELETE FROM areas")
  
  db.exec(sql"DELETE FROM challengeProgresses")
  let challengeProgresses = %*[{"challengeProgressId": 1000011, "state": 2}]
  updateChallengeProgresses(db, challengeProgresses)

  db.exec(sql"DELETE FROM challenges")
  let challenges = %*[{"challengeId": 100, "state": 8}]
  updateChallenges(db, challenges.getElems())

  # FIXME: reset characterMountingPowerCommon

  db.exec(sql"DELETE FROM missions")
  db.exec(sql"DELETE FROM nineSequences")
  db.exec(sql"DELETE FROM tensionCards")
  db.exec(sql"DELETE FROM tips")
  db.exec(sql"DELETE FROM tutorialStates")

  db.exec(sql"UPDATE formations SET cards = '{}'")

  setTutorialGacha(db)

  setUserStatus(db, %*{
    "rank": 1,
    "staminaUpdatedAt": "2025-10-27T16:22:38Z",
    "formationNumber": 1,
    "loggedInAt": "2025-10-26T16:22:38Z"
  })