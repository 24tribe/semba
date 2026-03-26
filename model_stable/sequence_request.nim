import std/json
import std/options

import ../db_connector/db_sqlite


proc parseReadSequenceRow*(row: Row): JsonNode =
  result = %*{
    "changedResources": {},
    "areaObjects": [],
  }

  if row[0] != "":
    result["areaObjects"] = parseJson(row[0])

  if row[1] != "":
    result["changedResources"] = parseJson(row[1])