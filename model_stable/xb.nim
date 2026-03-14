import std/json
import std/strutils
import std/math

import ../db_connector/db_sqlite

import ../semba_error
import ../protojson


type TensionData = object
  topTeamDelta: int
  bottomTeamDelta: int
  topTeamSkitIndex: int
  bottomTeamSkitIndex: int


proc getGameInfo*(db: DbConn, xbId: int): JsonNode =
  let row = db.getRow(sql"SELECT content FROM xbGameInfos WHERE xbId=?", xbId)

  if row[0] == "":
    raise newException(SembaError, "Couldn't find gameInfo for xbId=" & $xbId)

  return parseJson(row[0])


proc updateGameInfo*(db: DbConn, xbId: int, gameInfo: JsonNode) =
  let content = $gameInfo

  db.exec(sql"UPDATE xbGameInfos SET content=? WHERE xbId=?", content, xbId)


proc getStartGameInfo*(db: DbConn, xbId: int): JsonNode =
  let row = db.getRow(sql"SELECT content FROM xbStartGameInfos WHERE xbId=?", xbId)

  if row[0] == "":
    raise newException(SembaError, "Couldn't find start gameInfo for xbId=" & $xbId)

  return parseJson(row[0])


proc getTensionData*(db: DbConn, tensionFluctuationId: int): TensionData =
  let row = db.getRow(sql"""
    SELECT topTeamDelta, bottomTeamDelta, topTeamSkitIndex, bottomTeamSkitIndex FROM tensionData
    WHERE tensionFluctuationId=?
  """, tensionFluctuationId)

  if row[0] == "":
    raise newException(SembaError, "Couldn't find tensionData for tensionFluctuationId=" & $tensionFluctuationId)

  result.topTeamDelta = parseInt(row[0])
  result.bottomTeamDelta = parseInt(row[1])
  result.topTeamSkitIndex = parseInt(row[2])
  result.bottomTeamSkitIndex = parseInt(row[3])


proc updateCurrentXbPlayDataIdx*(db: DbConn, xbId: int, idx: int) =
  db.exec(sql"""
    INSERT INTO currentXbPlayData (xbId, idx) VALUES (?, ?)
    ON CONFLICT (xbId) DO UPDATE SET idx = excluded.idx
  """, xbId, idx)


proc getCurrentXbPlayDataIdx*(db: DbConn, xbId: int): int =
  let row = db.getRow(sql"SELECT idx FROM currentXbPlayData WHERE xbId=?", xbId)

  if row[0] == "":
    raise newException(SembaError, "Couldn't find currentXbPlayData idx for xbId=" & $xbId)

  let idx = parseInt(row[0])

  return idx

proc getXbPlayData(
  db: DbConn, xbId: int, idx: int,
  nextAtBatGameInfo: var JsonNode, changedResources: var JsonNode, currentAtBatGameInfo: var JsonNode
) =
  let row = db.getRow(sql"""
    SELECT idx, nextAtBatGameInfo, changedResources, currentAtBatGameInfo
    FROM xbPlayData WHERE xbId=? AND idx=?
  """, xbId, idx)

  if row[0] == "":
    raise newException(SembaError, "Couldn't find xbPlayData for idx=" & $idx & " and xbId=" & $xbId)

  nextAtBatGameInfo = if row[1] != "": parseJson(row[1]) else: nil
  changedResources = if row[2] != "": parseJson(row[2]) else: nil
  currentAtBatGameInfo = parseJson(row[3])

proc popCurrentXbPlayData*(
  db: DbConn, xbId: int,
  nextAtBatGameInfo: var JsonNode, changedResources: var JsonNode, currentAtBatGameInfo: var JsonNode
) =
  let idx = getCurrentXbPlayDataIdx(db, xbId)

  getXbPlayData(db, xbId, idx, nextAtBatGameInfo, changedResources, currentAtBatGameInfo)

  updateCurrentXbPlayDataIdx(db, xbId, idx + 1)


proc setGlobalSkitIndex*(db: DbConn, skitIndex: int) =
  db.exec(sql"""
    INSERT INTO userData (keyName, val) VALUES ('gSkitIndex', ?)
    ON CONFLICT (keyName) DO UPDATE SET val = excluded.val
  """, skitIndex)


proc getGlobalSkitIndex*(db: DbConn): int =
  let row = db.getRow(sql"SELECT val FROM userData WHERE keyName='gSkitIndex'")
  if row[0] == "":
    raise newException(SembaError, "gSkitIndex not set")
  return parseInt(row[0])


proc popGlobalSkitIndex*(db: DbConn): int =
  let skitIndex = getGlobalSkitIndex(db)
  setGlobalSkitIndex(db, skitIndex + 1)
  return skitIndex


proc calcNewTensionValue(tensionValue: float, delta: float): float = clamp(tensionValue + delta, 0.0, 3.0)
proc isTensionMax(tensionLv: int): bool = tensionLv == 3


proc calcTensionLv(lastTensionLv: int, tensionValue: float): int =
  let delta = tensionValue - lastTensionLv.float
  if delta > 0:
    if delta >= 1:
      result = lastTensionLv + 1
    else:
      result = lastTensionLv
  elif delta < 0:
    let deltaAbs = -delta
    if deltaAbs >= 1:
      result = lastTensionLv - 1
    else:
      result = lastTensionLv
  else:
    result = lastTensionLv

proc addDeltaToTeamTension(delta: float, team: JsonNode) =
  let previousTensionValue = protoJsonGetFloat(team, "tensionValue")
  let tensionValue = calcNewTensionValue(previousTensionValue, delta)
  protoJsonSetFloat(team, "tensionValue", tensionValue)

  let lastTensionLv = protoJsonGetInt(team, "tensionLv")
  let tensionLv = calcTensionLv(lastTensionLv, tensionValue)
  protoJsonSetInt(team, "tensionLv", tensionLv)

  let isTensionMax = isTensionMax(tensionLv)
  protoJsonSetBool(team, "isTensionMax", isTensionMax)

proc addDeltaToTensionInfo(delta: float, tensionInfo: JsonNode) =
  let previousTensionValue = protoJsonGetFloat(tensionInfo, "tensionValue")
  let tensionValue = calcNewTensionValue(previousTensionValue, delta)
  protoJsonSetFloat(tensionInfo, "tensionValue", tensionValue)

  let previousTensionLv = protoJsonGetInt(tensionInfo, "tensionLv")
  let tensionLv = calcTensionLv(previousTensionLv, tensionValue)
  protoJsonSetInt(tensionInfo, "tensionLv", tensionLv)

  protoJsonSetBool(tensionInfo, "isTensionMax", isTensionMax(tensionLv))

proc findTensionInfo(tensionInfos: seq[JsonNode], isPlayerTeam: bool): JsonNode =
  for tensionInfo in tensionInfos:
    let isPlayer = protoJsonGetBool(tensionInfo, "isPlayer")
    if isPlayer == isPlayerTeam:
      return tensionInfo
  return nil

proc updateTeamTension(delta: float, team: JsonNode, currentAtBatGameInfo: JsonNode, skitIndex: int): JsonNode =
  let isPlayerTeam = protoJsonGetBool(team, "isPlayerTeam")

  let previousTensionLv = protoJsonGetInt(team, "tensionLv")
  let previousTensionValue = protoJsonGetFloat(team, "tensionValue")

  addDeltaToTeamTension(delta, team)

  var predictedTensionInfos: JsonNode = currentAtBatGameInfo["predictedTensionInfos"]

  for tensionInfo in predictedTensionInfos.items():
    let isPlayer = protoJsonGetBool(tensionInfo, "isPlayer")
    if isPlayerTeam == isPlayer:
      addDeltaToTensionInfo(delta.float, tensionInfo)
      if tensionInfo["commandId"].getInt() == 1100044:
        addDeltaToTensionInfo(-0.55, tensionInfo)

  let logicEventInfos = currentAtBatGameInfo["currentAtBatEventInfo"]["logicEventInfos"]
  var tensionInfos = logicEventInfos[3].getOrDefault("tensionInfos").getElems()
  let match = findTensionInfo(tensionInfos, isPlayerTeam)
  let tensionInfo = if match != nil: match else: %*{}

  tensionInfo["skitIndex"] = %*skitIndex
  protoJsonSetFloat(tensionInfo, "previousTensionValue", previousTensionValue)
  protoJsonSetInt(tensionInfo, "previousTensionLv", previousTensionLv)
  protoJsonSetFloat(tensionInfo, "tensionValue", protoJsonGetFloat(team, "tensionValue"))
  protoJsonSetInt(tensionInfo, "tensionLv", protoJsonGetInt(team, "tensionLv"))
  protoJsonSetBool(tensionInfo, "isTensionMax", protoJsonGetBool(team, "isTensionMax"))
  protoJsonSetBool(tensionInfo, "isPlayer", isPlayerTeam)

  if match == nil:
    tensionInfos.add(tensionInfo)
    currentAtBatGameInfo["currentAtBatEventInfo"]["logicEventInfos"][3]["tensionInfos"] = %*tensionInfos

  return %*[tensionInfo]

proc updateTension*(
  db: DbConn, tensionFluctuationId: int, currentAtBatGameInfo: JsonNode,
  playerTensionInfos: var JsonNode, enemyTensionInfos: var JsonNode
) =
  let tensionData = getTensionData(db, tensionFluctuationId)

  var topTeam = currentAtBatGameInfo["topTeam"]
  var bottomTeam = currentAtBatGameInfo["bottomTeam"]

  if tensionData.topTeamDelta != 0:
    let tensionInfos = updateTeamTension(
      tensionData.topTeamDelta.float, topTeam, currentAtBatGameInfo, tensionData.topTeamSkitIndex
    )
    let isPlayerTeam = topTeam.getOrDefault("isPlayerTeam").getBool()
    if isPlayerTeam:
      playerTensionInfos = tensionInfos
    else:
      enemyTensionInfos = tensionInfos

  if tensionData.bottomTeamDelta != 0:
    let tensionInfos = updateTeamTension(
      tensionData.bottomTeamDelta.float, bottomTeam, currentAtBatGameInfo, tensionData.bottomTeamSkitIndex
    )
    let isPlayerTeam = bottomTeam.getOrDefault("isPlayerTeam").getBool()
    if isPlayerTeam:
      playerTensionInfos = tensionInfos
    else:
      enemyTensionInfos = tensionInfos



proc battedBallPredictionIdToPosition(battedBallPredictionId: int): int =
  case battedBallPredictionId:
    of 1:
      return 7
    of 2:
      return 8
    of 3:
      return 9
    else:
      raise newException(SembaError, "Unknown battedBallPredictionId: " & $battedBallPredictionId)

proc isPlayerOffense(currentAtBatEventInfo: JsonNode): bool =
  return protoJsonGetBool(currentAtBatEventInfo["afterGameSituation"], "isPlayerOffense")

proc isIncorrectCommand(selectedCommand: JsonNode): bool =
  return selectedCommand.getOrDefault("correctType").getStr() == "incorrect_command"

proc handleCorrectCommand(
  currentAtBatEventInfo: JsonNode, afterGameSituation: JsonNode,
  fakeCurrentAtBatEventInfo: JsonNode, selectedCommand: JsonNode
) =
  let batterMemberId = afterGameSituation["batterMemberId"].getInt()

  var newCurrentBaseSituation = afterGameSituation["currentBaseSituation"].getElems()

  let newCurrentBaseSituation3 = newCurrentBaseSituation[2]
  newCurrentBaseSituation[2] = newCurrentBaseSituation[1]
  newCurrentBaseSituation[1] = newCurrentBaseSituation[0]
  newCurrentBaseSituation[0] = %*batterMemberId

  let runningInfoMemberIds = @[
    newCurrentBaseSituation[0],
    newCurrentBaseSituation[1],
    newCurrentBaseSituation[2],
    newCurrentBaseSituation3
  ]

  let time = 1.76481688

  var lastRunningInfoMemberId = 0

  var runningInfos = newSeq[JsonNode]()

  for i in 0 ..< runningInfoMemberIds.len:
    let memberId = runningInfoMemberIds[i].getInt()

    if memberId != 0:
      let endPosition = i.float + 0.123843156

      lastRunningInfoMemberId = memberId

      runningInfos.add(%*{
        "memberId": memberId,
        "startPosition": i,
        "endPosition": endPosition,
        "velocity": 0.340174,
        "time": time
      })
    else:
      runningInfos.add(%*{})

  let direction = battedBallPredictionIdToPosition(selectedCommand["battedBallPredictionId"].getInt())

  let battedBallInfo = %*{
    "afterGameSituation": afterGameSituation.copy(),
    "direction": direction,
    "fielderMemberId": 17, # always?
    "runningInfos": runningInfos,
    "time": time
  }

  currentAtBatEventInfo["battedBallInfo"] = battedBallInfo

  afterGameSituation["currentBaseSituation"] = %*newCurrentBaseSituation

  currentAtBatEventInfo["buffInfos"] = %*[{"timing": 80, "playerBuffMemberIds": [51]}]
  currentAtBatEventInfo["logicEventInfos"] = fakeCurrentAtBatEventInfo["logicEventInfos"]

  var defenseRunningInfos = newSeq[JsonNode]()

  var lastDefenseRunningPosition = 0

  for runningInfo in runningInfos:
    let memberId = runningInfo.getOrDefault("memberId").getInt()
    if memberId != 0:
      let startPosition = runningInfo["endPosition"].getFloat()
      let endPosition = ceil(startPosition)
      lastDefenseRunningPosition = endPosition.int
      defenseRunningInfos.add(%*{
        "memberId": memberId,
        "startPosition": startPosition,
        "endPosition": endPosition,
        "velocity": 0.340174,
        "time": 10.9274044
      })
    else:
      defenseRunningInfos.add(%*{})

  let fielderMemberIdTo = 14 # FIXME: get it from topTeam members

  var baseAdvanceInfos = newSeq[JsonNode]()

  for i in 0 ..< newCurrentBaseSituation.len:
    let memberId = newCurrentBaseSituation[i].getInt()
    if memberId != 0:
      baseAdvanceInfos.add(%*{
        "isPlayer": true,
        "memberId": memberId,
        "baseNum": i + 1,
      })

  let defenseBeforeGameSituation = battedBallInfo["afterGameSituation"].copy()
  let defenseAfterGameSituation = afterGameSituation.copy()

  defenseBeforeGameSituation["eventOrder"] = %*1
  defenseAfterGameSituation["eventOrder"] = %*1

  currentAtBatEventInfo["defenseInfos"] = %*[
    {
      "targetRunnerMemberId": lastRunningInfoMemberId,
      "defenseOwnBaseInfo": {},
      "throwingInfo": {
        "isThrown": true,
        "positionFrom": direction,
        "ballLevel": 1,
        "baseNumOfReceive": lastDefenseRunningPosition,
        "time": 0.0136560118,
        "fielderMemberIdFrom": 17, # FIXME: get it from topTeam members
        "fielderMemberIdTo": fielderMemberIdTo
      },
      "runningInfos": defenseRunningInfos,
      "boutInfo": {
        "boutOccurred": true,
        "baseNumOfBout": lastDefenseRunningPosition,
        "runnerMemberId": batterMemberId,
        "fielderMemberId": fielderMemberIdTo,
        "baseAdvanceInfos": baseAdvanceInfos,
      },
      "beforeGameSituation": defenseBeforeGameSituation,
      "afterGameSituation": defenseAfterGameSituation,
      "eventOrder": 1,
    }
  ]

proc getCommand(zoneAreaIndex: int, currentAtBatGameInfo: JsonNode): JsonNode =
  for zoneArea in currentAtBatGameInfo["bottomTeam"]["zoneAreas"]:
    if protoJsonGetInt(zoneArea, "index") == zoneAreaIndex:
      result = zoneArea["commands"][0]
      break

  if result == nil:
    raise newException(SembaError, "Couldn't get command for zoneArea: " & $zoneAreaIndex)

proc handleIncorrectCommand(
  currentAtBatEventInfo: JsonNode, afterGameSituation: JsonNode, fakeCurrentAtBatEventInfo: JsonNode
) =
  let battingInfo = currentAtBatEventInfo["battingInfo"]

  let currentOutCount = protoJsonGetInt(afterGameSituation, "currentOutCount") + 1
  protoJsonSetInt(afterGameSituation, "currentOutCount", currentOutCount)

  if currentOutCount == 3:
    protoJsonSetBool(afterGameSituation, "isChange", true)

  protoJsonSetBool(battingInfo, "isStrikeOut", true)

  currentAtBatEventInfo["logicEventInfos"] = fakeCurrentAtBatEventInfo["logicEventInfos"].copy()

  for eventInfo in currentAtBatEventInfo["logicEventInfos"]:
    protoJsonDeleteKey(eventInfo, "tensionInfos")

  currentAtBatEventInfo["battedBallInfo"] = %*{}


proc createCurrentAtBatGameInfo*(
  zoneAreaIndex: int, lastCurrentAtBatGameInfo: JsonNode, fakeCurrentAtBatGameInfo: JsonNode
): JsonNode =
  let selectedCommand = getCommand(zoneAreaIndex, lastCurrentAtBatGameInfo)

  let lastCurrentAtBatEventInfo = lastCurrentAtBatGameInfo["currentAtBatEventInfo"]

  # zero is batting...
  if not isPlayerOffense(lastCurrentAtBatEventInfo):
    result = fakeCurrentAtBatGameInfo.copy()
    result["bottomTeam"]["selectedCommand"] = selectedCommand
    return result

  result = lastCurrentAtBatGameInfo.copy()
  result["bottomTeam"]["selectedCommand"] = selectedCommand
  result["bottomTeam"]["inningScores"] = fakeCurrentAtBatGameInfo["bottomTeam"]["inningScores"]

  let fakeCurrentAtBatEventInfo = fakeCurrentAtBatGameInfo["currentAtBatEventInfo"]
  let fakeAfterGameSituation = fakeCurrentAtBatEventInfo["afterGameSituation"]
  let isGameSet = protoJsonGetBool(fakeAfterGameSituation, "isGameSet")

  let currentAtBatEventInfo = result["currentAtBatEventInfo"]
  let afterGameSituation = currentAtBatEventInfo["afterGameSituation"]
  protoJsonSetBool(afterGameSituation, "isGameSet", isGameSet)

  let battingInfo = currentAtBatEventInfo["battingInfo"]
  protoJsonSetBool(battingInfo, "isStrikeOut", false)

  protoJsonDeleteKey(result, "predictedTensionInfos")

  if isIncorrectCommand(selectedCommand):
    handleIncorrectCommand(currentAtBatEventInfo, afterGameSituation, fakeCurrentAtBatEventInfo)
  else:
    handleCorrectCommand(currentAtBatEventInfo, afterGameSituation,
                         fakeCurrentAtBatEventInfo, selectedCommand)


proc createNextAtBatGameInfo*(currentAtBatGameInfo: JsonNode, fakeNextAtBatGameInfo: JsonNode): JsonNode =
  # zero is batting...
  if not isPlayerOffense(currentAtBatGameInfo["currentAtBatEventInfo"]):
    return fakeNextAtBatGameInfo.copy()

  result = currentAtBatGameInfo.copy()

  let fakeBottomTeam = fakeNextAtBatGameInfo["bottomTeam"]
  let bottomTeam = result["bottomTeam"]
  protoJsonDeleteKey(bottomTeam, "selectedCommand")

  bottomTeam["zoneAreas"] = fakeBottomTeam["zoneAreas"].copy()
  bottomTeam["currentBattingOrder"] = fakeBottomTeam["currentBattingOrder"]

  let currentAtBatEventInfo = result["currentAtBatEventInfo"]
  let afterGameSituation = currentAtBatEventInfo["afterGameSituation"]

  let fakeCurrentAtBatEventInfo = fakeNextAtBatGameInfo["currentAtBatEventInfo"]
  let fakeAfterGameSituation = fakeCurrentAtBatEventInfo["afterGameSituation"]

  afterGameSituation["batterMemberId"] = fakeAfterGameSituation["batterMemberId"]
  afterGameSituation["pitcherMemberId"] = fakeAfterGameSituation["pitcherMemberId"]

  protoJsonSetInt(
    currentAtBatEventInfo, "inning", protoJsonGetInt(fakeCurrentAtBatEventInfo, "inning")
  )
  protoJsonSetBool(
    currentAtBatEventInfo, "isChange", protoJsonGetBool(fakeCurrentAtBatEventInfo, "isChange")
  )
  protoJsonSetBool(
    currentAtBatEventInfo, "isFirstAtBatInGame",
    protoJsonGetBool(fakeCurrentAtBatEventInfo, "isFirstAtBatInGame")
  )
  protoJsonSetBool(
    currentAtBatEventInfo, "isFirstAtBatInHalfInning",
    protoJsonGetBool(fakeCurrentAtBatEventInfo, "isFirstAtBatInHalfInning")
  )
  protoJsonSetBool(
    currentAtBatEventInfo, "isTop", protoJsonGetBool(fakeCurrentAtBatEventInfo, "isTop")
  )

  let clientStatus = result["clientStatus"]

  currentAtBatEventInfo["battedBallInfo"] = %*{}

  let battingInfo = currentAtBatEventInfo["battingInfo"]

  let beforeGameSituation = currentAtBatEventInfo["beforeGameSituation"]
  let fakeBeforeGameSituation = fakeCurrentAtBatEventInfo["beforeGameSituation"]

  if protoJsonGetBool(battingInfo, "isStrikeOut"):
    protoJsonDeleteKey(battingInfo, "isStrikeOut")
    clientStatus["previousAtBatIsOut"] = %*true
    protoJsonSetInt(
      beforeGameSituation, "currentOutCount",
      protoJsonGetInt(beforeGameSituation, "currentOutCount") + 1
    )
  else:
    var currentBaseSituation = beforeGameSituation["currentBaseSituation"].getElems()
    currentBaseSituation[2] = currentBaseSituation[1]
    currentBaseSituation[1] = currentBaseSituation[0]
    currentBaseSituation[0] = beforeGameSituation["batterMemberId"]
    beforeGameSituation["currentBaseSituation"] = %*currentBaseSituation 

  beforeGameSituation["batterMemberId"] = fakeBeforeGameSituation["batterMemberId"]
  beforeGameSituation["pitcherMemberId"] = fakeBeforeGameSituation["pitcherMemberId"]

  protoJsonSetInt(
    beforeGameSituation, "inning", protoJsonGetInt(fakeBeforeGameSituation, "inning")
  )
  protoJsonSetBool(
    beforeGameSituation, "isChange", protoJsonGetBool(fakeBeforeGameSituation, "isChange")
  )
  protoJsonSetBool(
    beforeGameSituation, "isFirstAtBatInGame",
    protoJsonGetBool(fakeBeforeGameSituation, "isFirstAtBatInGame")
  )
  protoJsonSetBool(
    beforeGameSituation, "isFirstAtBatInHalfInning",
    protoJsonGetBool(fakeBeforeGameSituation, "isFirstAtBatInHalfInning")
  )
  protoJsonSetBool(
    beforeGameSituation, "isTop", protoJsonGetBool(fakeBeforeGameSituation, "isTop")
  )

  protoJsonDeleteKey(currentAtBatEventInfo, "defenseInfos")
  protoJsonDeleteKey(currentAtBatEventInfo, "buffInfos")
  
  currentAtBatEventInfo["logicEventInfos"] = fakeCurrentAtBatEventInfo["logicEventInfos"]
  result["index"] = fakeNextAtBatGameInfo["index"]
  result["predictedTensionInfos"] = fakeNextAtBatGameInfo["predictedTensionInfos"]

  let topTeam = result["topTeam"]
  let fakeTopTeam = fakeNextAtBatGameInfo["topTeam"]

  topTeam["members"] = fakeTopTeam["members"]
  topTeam["selectedCommand"] = fakeTopTeam["selectedCommand"]
  topTeam["skillOrbInfos"] = fakeTopTeam["skillOrbInfos"]

  result["xbStoryInfo"] = fakeNextAtBatGameInfo["xbStoryInfo"]