import std/json
import std/strutils
import std/options
import std/sequtils
import std/tables

import ../db_connector/db_sqlite
import ../extsqlite
import ../protojson
import ../semba_error

import timestamp
import graffiti_art


type FlowerMarkLevel* = object
  requiredFlowerMark*: int
  characterMaxLevel*: int

type Mission* = object
  missionId*: int
  count*: Option[int]
  receivedStepCount*: int
  resetAt*: Option[Timestamp]
  clearedAt*: Option[Timestamp]

type MdMissionStep* = object
  count*: int
  reward_set_id*: int

type MdMission* = object
  id*: int
  cityId*: Option[int]
  steps*: seq[MdMissionStep]


proc getMissionsForCity*(db: DbConn, missionIds: openArray[int], cityId: int): seq[MdMission] =
  let rows = db.getAllRows(sql("""
    SELECT id, steps FROM mdMission WHERE id IN """ & sqlIntTuple(missionIds) & """ AND cityId = ?
  """), cityId)

  for row in rows:
    result.add(MdMission(
      id: parseInt(row[0]),
      cityId: some(cityId),
      steps: protoJsonTo(parseJson(row[1]), seq[MdMissionStep])
    ))


proc getOpenChestMissionsForCity*(db: DbConn, cityId: int): seq[MdMission] =
  const missionIds = [1041062, 1041063, 1041064, 1041362, 1041363, 1041364, 1041462, 1041463, 1041464]
  return getMissionsForCity(db, missionIds, cityId)


proc getTroubleshooterMissionsForCity*(db: DbConn, cityId: int): seq[MdMission] =
  const missionIds = [1041065, 1041066, 1041365, 1041366, 1041465, 1041466]
  return getMissionsForCity(db, missionIds, cityId)


proc getGraffitiMissionsForCity*(db: DbConn, cityId: int): seq[MdMission] =
  const missionIds = [1041005, 1041006, 1041305, 1041306, 1041405, 1041406]
  return getMissionsForCity(db, missionIds, cityId)


proc getHappyWorkaholicMissionsForCity*(db: DbConn, cityId: int): seq[MdMission] =
  const missionIds = [1041002, 1041302, 1041402]
  return getMissionsForCity(db, missionIds, cityId)


proc getMagicOrbMissionsForCity*(db: DbConn, cityId: int): seq[MdMission] =
  const missionIds = [1041007, 1041008, 1041009, 1041307, 1041308, 1041309, 1041409]
  return getMissionsForCity(db, missionIds, cityId)


proc getAttackTestMissionsForCity*(db: DbConn, cityId: int): seq[MdMission] =
  const missionIds = [1041041, 1041042, 1041043, 1041044, 1041335, 1041345, 1041346, 1041438, 1041439, 1041440]
  return getMissionsForCity(db, missionIds, cityId)


proc getVictorsRightsMissionsForCity*(db: DbConn, cityId: int): seq[MdMission] =
  const missionIds = [1041031, 1041032, 1041033]
  return getMissionsForCity(db, missionIds, cityId)


proc getBeAForeverWinnerMissionsForCityId*(db: DbConn, cityId: int): seq[MdMission] =
  const missionIds = [1041034, 1041035, 1041036, 1041331, 1041332, 1041333, 1041349, 1041431, 1041432, 1041433]
  return getMissionsForCity(db, missionIds, cityId)


proc getCompleteCityChallengeMissionsForCityId*(db: DbConn, cityId: int): seq[MdMission] = 
  const missionIds = [1041003, 1041004, 1041303, 1041304, 1041403, 1041404]
  return getMissionsForCity(db, missionIds, cityId)


proc getMdMissionsWithIds*(db: DbConn, ids: openArray[int]): seq[MdMission] = 
  let rows = db.getAllRows(sql("SELECT id, steps, cityId FROM mdMission WHERE id IN " & sqlIntTuple(ids)))

  result = rows.mapIt(MdMission(
    id: parseInt(it[0]),
    steps: protoJsonTo(parseJson(it[1]), seq[MdMissionStep]),
    cityId: tryParseInt(it[2]),
  )).toSeq()


proc getAttackTestMissionMinChars*(missionId: int): int =
  case missionId:
  of 1041041: 1
  of 1041042: 2
  else: 3


proc getMissionsWithIds*(db: DbConn, missionIds: openArray[int]): seq[Mission] =
  let rows = db.getAllRows(sql("""
    SELECT missionId, count, receivedStepCount, resetAt, clearedAt FROM missions
    WHERE missionId IN (""" & missionIds.mapIt($it).join(", ") & """)
  """))

  for row in rows:
    result.add(Mission(
      missionId: parseInt(row[0]),
      count: tryParseInt(row[1]),
      receivedStepCount: parseInt(row[2]),
      resetAt: if row[3] != "": some(row[3].Timestamp) else: none(Timestamp),
      clearedAt: if row[4] != "": some(row[4].Timestamp) else: none(Timestamp),
    ))


proc updateMissions*(db: DbConn, missions: openArray[Mission]) =
  for mission in missions:
    db.exec(
      sql"""
        INSERT INTO missions (missionId, count, receivedStepCount, resetAt, clearedAt)
        VALUES (?, ?, ?, ?, ?)
        ON CONFLICT (missionId) DO
        UPDATE SET
          count = excluded.count, receivedStepCount = excluded.receivedStepCount,
          resetAt = excluded.resetAt, clearedAt = excluded.clearedAt
      """,
      mission.missionId, mission.count.get(0), mission.receivedStepCount,
      mission.resetAt.get("".Timestamp), mission.clearedAt.get("".Timestamp)
    )


proc getMissions*(db: DbConn): seq[Mission] =
  let rows = db.getAllRows(sql"""
    SELECT missionId, count, receivedStepCount, resetAt, clearedAt FROM missions
  """)

  result = rows.mapIt(Mission(
    missionId: parseInt(it[0]),
    count: some(parseInt(it[1])),
    receivedStepCount: parseInt(it[2]),
    resetAt: tryParseTimestamp(it[3]),
    clearedAt: tryParseTimestamp(it[4]),
  ))


proc getFlowerMarkLevels*(db: DbConn): seq[FlowerMarkLevel] =
  let rows = db.getAllRows(sql"""
  SELECT requiredFlowerMark, characterMaxLevel FROM mdFlowerMarkLevel
  ORDER BY requiredFlowerMark DESC
  """)

  for row in rows:
    let requiredFlowerMark = parseInt(row[0])
    let characterMaxLevel = parseInt(row[1])
    result.add(FlowerMarkLevel(
      requiredFlowerMark: requiredFlowerMark,
      characterMaxLevel: characterMaxLevel
    ))


proc getMissionsWithNewCount*(
  db: DbConn, mdMissions: openArray[MdMission], getNewCount: proc (mission: Mission, mdMission: MdMission): Option[int]
): seq[Mission] =
  ## Get the current missions in `mdMissions` from db and uses the return value of `getNewCount`
  ## to create a seq[Mission] with changed counts. Doesn't update the db.

  var missions = getMissionsWithIds(db, mdMissions.mapIt(it.id)).mapIt((it.missionId, it)).toTable()

  for mdMission in mdMissions:
    var mission = missions.getOrDefault(mdMission.id, Mission(missionId: mdMission.id))

    if mission.clearedAt.isSome():
      continue

    let newCount = getNewCount(mission, mdMission)

    if newCount.isSome():
      mission.count = newCount

      if newCount.get() >= mdMission.steps[mdMission.steps.high].count:
        mission.clearedAt = some(getTimestampNow())

      result.add(mission)


proc getChangedOpenChestMissions*(db: DbConn, cityId: int): seq[Mission] = 
  let openChestMissions = getOpenChestMissionsForCity(db, cityId)
  return getMissionsWithNewCount(db, openChestMissions, proc (mission: Mission, mdMission: MdMission): Option[int] =
    result = some(mission.count.get(0) + 1)
  )


proc getChangedGraffitiMissions*(db: DbConn, cityId: int): seq[Mission] =
  let graffitiMissions = getGraffitiMissionsForCity(db, cityId)

  let graffitiCount = getGraffitiArts(db).filterIt(graffitiArtIdToCityId(it.graffitiArtId) == cityId).toSeq().len

  return getMissionsWithNewCount(db, graffitiMissions, proc (mission: Mission, mdMission: MdMission): Option[int] =
    result = some(graffitiCount + 1)
  )


proc getChangedHappyWorkaholicMissions*(db: DbConn, cityId: int): seq[Mission] =
  let missions = getHappyWorkaholicMissionsForCity(db, cityId)

  return getMissionsWithNewCount(db, missions, proc (mi: Mission, mdMi: MdMission): Option[int] =
    some(mi.count.get(0) + 1)
  )


proc getChangedBattleBetweenTheRevivedMissions*(db: DbConn, cityId: int): seq[Mission] =
  let mdMissions = getMissionsForCity(db, [1041037], cityId)
  return getMissionsWithNewCount(db, mdMissions, proc (mi: Mission, mdMi: MdMission): Option[int] = some(1))


proc getRiftClearMission*(db: DbConn, dungeonId: int): seq[MdMission] =
  let row = db.getRow(sql"SELECT missionId FROM clearDungeonMissionIds WHERE dungeonId = ?", dungeonId)

  if row[0] == "":
    raise newException(SembaError, "Couldn't get 'Clear Dungeon' missionId from dungeonId " & $dungeonId)

  let missionId = parseInt(row[0])
  getMdMissionsWithIds(db, [missionId])


proc getChangedRiftClearMissions*(db: DbConn, dungeonId: int): seq[Mission] =
  let mdMissions = getRiftClearMission(db, dungeonId)
  getMissionsWithNewCount(db, mdMissions, proc (mi: Mission, mdMi: MdMission): Option[int] =
    some(mi.count.get(0) + 1)
  )


proc getChangedCompleteCityChallengeMissions*(db: DbConn, cityId: int): seq[Mission] =
  let mdMissions = getCompleteCityChallengeMissionsForCityId(db, cityId)

  getMissionsWithNewCount(db, mdMissions, proc (mi: Mission, _: MdMission): Option[int] =
    some(mi.count.get(0) + 1)
  )


proc cmpMissionsById*(a, b: Mission): int = cmp(a.missionId, b.missionId)

proc cmpMdMissionsById*(a, b: MdMission): int = cmp(a.id, b.id)