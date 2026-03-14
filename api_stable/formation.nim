import std/json

import ../db_connector/db_sqlite

import ../model_stable/formation
import ../model_stable/user


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
  let status = getUserStatus(db)
  status["formationNumber"] = %*formationNumber
  setUserStatus(db, status)
  result = %*{
    "changedResources": {
      "status": status,
    }
  }