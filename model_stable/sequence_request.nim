import std/json
import std/options
import std/strutils

import ../db_connector/db_sqlite

import ../util
import timestamp
import challenge_task
import area_object
import challenge_progress

proc parseReadSequenceRow*(row: Row): JsonNode =
  result = %*{
    "changedResources": {},
    "areaObjects": [],
  }

  if row[0] != "":
    result["areaObjects"] = parseJson(row[0])

  if row[1] != "":
    result["changedResources"] = parseJson(row[1])