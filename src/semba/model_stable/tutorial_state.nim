import std/json
import std/strutils
import std/sequtils

import db_connector/db_sqlite


const respiteUnitTutorialStatusKey* = 43


type TutorialState* = object
  tutorialStatusKey*: int
  enabled*: bool


proc updateTutorialState*(db: DbConn, tutorialStatusKey: int, enabled: bool) =
  db.exec(sql"""
    INSERT INTO tutorialStates (tutorialStatusKey, enabled) VALUES
    (?, ?)
    ON CONFLICT (tutorialStatusKey) DO UPDATE SET enabled = excluded.enabled
  """, tutorialStatusKey, $enabled)


proc upsertTutorialStates*(db: DbConn, tutorialStates: openArray[TutorialState]) =
  for ts in tutorialStates:
    updateTutorialState(db, ts.tutorialStatusKey, ts.enabled)


proc getTutorialStates*(db: DbConn): seq[TutorialState] =
  db.getAllRows(sql"SELECT tutorialStatusKey, enabled FROM tutorialStates").mapIt(TutorialState(
    tutorialStatusKey: parseInt(it[0]),
    enabled: it[1] == "true",
  ))


proc getTutorialState*(db: DbConn, tutorialStatusKey: int): bool =
  let row = db.getRow(sql"SELECT enabled FROM tutorialStates WHERE tutorialStatusKey=?", tutorialStatusKey)

  if row[0] == "":
    return false

  return row[0] == "true"