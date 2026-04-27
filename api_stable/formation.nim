import std/json
import std/options

import ../db_connector/db_sqlite

import ../model_stable/formation
import ../model_stable/user
import ../model_stable/status


proc formation_Update*(db: DbConn, jsonReq: JsonNode): JsonNode =
  updateFormation(db, jsonReq)

  return %*{
    "changedResources": {
      "formations": [
        jsonReq
      ]
    }
  }


proc formation_Switch*(db: DbConn, jsonReq: JsonNode): JsonNode =
  let formationNumber = jsonReq["formationNumber"].getInt()
  var status = getUserStatusTypeSafe(db)
  status.formationNumber = some(formationNumber)
  setUserStatusTypeSafe(db, status)
  result = %*{
    "changedResources": {
      "status": status,
    }
  }