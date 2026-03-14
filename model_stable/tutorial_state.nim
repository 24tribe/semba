import std/json
import std/strutils

import ../db_connector/db_sqlite


const respiteUnitTutorialStatusKey* = 43


proc updateTutorialState*(db: DbConn, tutorialStatusKey: int, enabled: bool) =
  db.exec(sql"""
    INSERT INTO tutorialStates (tutorialStatusKey, enabled) VALUES
    (?, ?)
    ON CONFLICT (tutorialStatusKey) DO UPDATE SET enabled = excluded.enabled
  """, tutorialStatusKey, $enabled)


proc addTutorialState*(db: DbConn, tutorialState: JsonNode) =
  let tutorialStatusKey = tutorialState["tutorialStatusKey"].getInt()
  let enabledTmp = tutorialState.getOrDefault("enabled")
  let enabled = if enabledTmp != nil: (if enabledTmp.getBool(): "true" else: "false") else: ""

  db.exec(
    sql"INSERT INTO tutorialStates (tutorialStatusKey, enabled) VALUES (?, ?)",
    tutorialStatusKey, enabled
  )


proc getTutorialStates*(db: DbConn): seq[JsonNode] =
  let tutorialStatesRows = db.getAllRows(sql"SELECT tutorialStatusKey, enabled FROM tutorialStates")

  for tutorialStateRow in tutorialStatesRows:
    let tutorialStatusKey = parseInt(tutorialStateRow[0])
    let enabled = tutorialStateRow[1]

    let tutorialState = %*{"tutorialStatusKey": tutorialStatusKey}

    if enabled == "true" or enabled == "false":
      tutorialState["enabled"] = %*(if enabled == "true": true else: false)

    result.add(tutorialState)


proc getTutorialState*(db: DbConn, tutorialStatusKey: int): bool =
  let row = db.getRow(sql"SELECT enabled FROM tutorialStates WHERE tutorialStatusKey=?", tutorialStatusKey)

  if row[0] == "":
    return false

  return row[0] == "true"