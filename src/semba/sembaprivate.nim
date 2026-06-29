import std/algorithm
import std/strutils
import std/json
import std/os
import std/sequtils
import std/options

import db_connector/db_sqlite

import ./protojson
import ./sembasave
import ./extsqlite
import ./model_stable/tutorial
import ./model_stable/reward
import ./model_stable/mail
import ./model_stable/gear
import ./model_stable/timestamp
import ./model_stable/status
import ./model_semba/gear
import ./model_semba/known_location

const sembaSql = slurp("semba.sql")

type SembaNewGameRequest = object
  skipTutorial: bool

type SembaSetSkipTutorialRequest = object
  skipTutorial: bool

type SembaGetSkipTutorialResponse = object
  skipTutorial: bool

type SembaListSaveFilesRequest = object
  savesDir: string

type SembaListSaveFilesResponse = object
  names: seq[string]

type HairColor* = object
  charId*: int
  r*: float
  g*: float
  b*: float
  enabled*: bool

type GachaRateId = enum
  NormalPullThreeStarCharRateId = 101,
  NormalPullThreeStarTCRateId = 102,
  NormalPullTwoStarCharRateId = 103,
  NormalPullTwoStarTCRateId = 104,
  NormalPullOneStarTCRateId = 105,

  GuaranteedPullThreeStarCharRateId = 106,
  GuaranteedPullThreeStarTCRateId = 107,

  PromisedPullThreeStarCharRateId = 108,
  PromisedPullThreeStarTCRateId = 109,
  PromisedPullTwoStarCharRateId = 110,
  PromisedPullTwoStarTCRateId = 111


type SembaMailGearRequest* = object
  rarity: int
  piece: int
  `set`: int
  tier: int
  substat1: int
  substat2: int
  substat3: int

type SembaMoveToAreaRequest* = object
  areaId: int


proc semba_LoadSaveFile(jsonReq: JsonNode, db: DbConn): JsonNode =
  let saves_dir = jsonReq["saves_dir"].getStr()
  let name = jsonReq["name"].getStr()

  let err = loadSaveFile(db, saves_dir, name)

  return %*{
    "err": err
  }


proc semba_CreateSaveFile(jsonReq: JsonNode, db: DbConn): JsonNode =
  let saves_dir = jsonReq["saves_dir"].getStr()

  discard existsOrCreateDir(saves_dir)

  let name = jsonReq["name"].getStr()

  let err = createSaveFile(db, saves_dir, name)

  return %*{
    "err": err
  }


proc semba_DeleteSaveFile(jsonReq: JsonNode) =
  let saves_dir = jsonReq["saves_dir"].getStr()
  let name = jsonReq["name"].getStr()

  deleteSaveFile(saves_dir, name)


proc semba_ListSaveFiles(req: SembaListSaveFilesRequest): SembaListSaveFilesResponse =
  for k in walkDir(req.savesDir, relative = true):
    if k.kind == pcFile and k.path.endswith(".save"):
      result.names.add(k.path.changeFileExt(""))

  result.names.sort()


proc semba_GetStdGachaRates(db: DbConn): JsonNode =
  let rateIds = [
    NormalPullThreeStarCharRateId,
    NormalPullThreeStarTCRateId,
    NormalPullTwoStarCharRateId,
    NormalPullTwoStarTCRateId,
    NormalPullOneStarTCRateId,
    GuaranteedPullThreeStarCharRateId,
    GuaranteedPullThreeStarTCRateId,
    PromisedPullThreeStarCharRateId,
    PromisedPullThreeStarTCRateId,
    PromisedPullTwoStarCharRateId,
    PromisedPullTwoStarTCRateId
  ]

  result = %*{}

  for rateId in rateIds:
    let row = db.getRow(sql"SELECT percentRate FROM gachaRates WHERE gachaRateId = ?", rateId.int)
    result[$rateId] = %*parseFloat(row[0])


proc semba_SetStdGachaRates(db: DbConn, jsonReq: JsonNode) =
  for key, val in jsonReq.pairs():
    let rateId = parseEnum[GachaRateId](key)
    let percentRate = val.getFloat()
    db.exec(
      sql"UPDATE gachaRates SET percentRate = ? WHERE gachaRateId = ?",
      $percentRate, rateId.int
    )


proc semba_ResetDb(db: DbConn) =
  let lines = sembaSql.split('\n')
  let skipLines = ["BEGIN;", "COMMIT;"]
  let withoutBeginCommit = lines.filterIt(not (it.strip in skipLines)).join("\n")
  loadSql(db, withoutBeginCommit)


proc semba_UpdateHairColor(db: DbConn, jsonReq: JsonNode): JsonNode =
  let req = protoJsonTo(jsonReq, HairColor)
  db.exec(sql"""
    INSERT INTO hairColors (charId, r, g, b, enabled)
    VALUES (?, ?, ?, ?, ?)
    ON CONFLICT (charId) DO
    UPDATE SET r = excluded.r, g = excluded.g, b = excluded.b, enabled = excluded.enabled
  """, req.charId, req.r, req.g, req.b, req.enabled)

  result = %*{
    "status": "ok"
  }


proc semba_GetHairColors(db: DbConn): seq[HairColor] =
  let rows = db.getAllRows(sql"SELECT charId, r, g, b, enabled FROM hairColors")

  for row in rows:
    result.add(HairColor(
      charId: parseInt(row[0]),
      r: parseFloat(row[1]),
      g: parseFloat(row[2]),
      b: parseFloat(row[3]),
      enabled: row[4] == "true"
    ))


proc semba_SetSkipTutorial(db: DbConn, req: SembaSetSkipTutorialRequest) =
  db.exec(sql"UPDATE userData SET val = ? WHERE keyName = 'skipTutorial'", $req.skipTutorial)


proc semba_NewGame(db: DbConn, req: SembaNewGameRequest) =
  semba_ResetDb(db)
  semba_SetSkipTutorial(db, SembaSetSkipTutorialRequest(skipTutorial: req.skipTutorial))


proc semba_GetSkipTutorial(db: DbConn): SembaGetSkipTutorialResponse = 
  result.skipTutorial = getSkipTutorial(db)


proc semba_MailGear(db: DbConn, req: SembaMailGearRequest) =
  let gearRarity = sembaGearRarityToProperGearRarity(req.rarity)
  let mainStatusId = sembaPieceToMainStatusId(req.piece)
  let gearType = sembaSetToGearType(req.`set`)
  let grade = sembaTierToGrade(req.tier)
  let subStatus1Id = sembaSubstatToGearStatusId(req.substat1)
  let subStatus2Id = sembaSubstatToGearStatusId(req.substat2)
  let subStatus3Id = sembaSubstatToGearStatusId(req.substat3)

  let gearId = getMdGearId(db, mainStatusId, gearType, grade)

  let substatusIds = [subStatus1Id, subStatus2Id, subStatus3Id].filterIt(it.isSome()).mapIt(it.get())

  let rewards = [Resource(
    `type`: rewardGear.int,
    id: gearId,
    quantity: 1,
    resourceParams: some(ResourceParams(
      gearRewardStatus: some(GearRewardStatus(
        subStatusIds: some(substatusIds),
        gearRarity: gearRarity.int
      ))
    ))
  )]

  sendMail(db, "New patimon", "Your patimon is here!!!", "TNZ", rewards, getTimestampNow(), getFutureTimestamp())


proc semba_MoveToArea*(db: DbConn, req: SembaMoveToAreaRequest) =
  var status = getUserStatusTypeSafe(db)

  let loc = getKnownLocation(db, req.areaId)

  status.currentAreaKeyId = some(req.areaId)
  status.currentAreaType = some(1)
  status.currentPositionCoordinates = some(PositionCoordinates(x: some(loc.x), y: some(loc.y), z: some(loc.z)))
  status.currentDirection = some(loc.direction)

  setUserStatusTypeSafe(db, status)


proc getJsonResultPrivateApi*(uri: string, jsonReq: JsonNode, db: DbConn): JsonNode =
  if uri == "/semba/echo":
    let dataUpper = jsonReq["data"].getStr().toUpperAscii()
    result = %*{"data": dataUpper}
  elif uri == "/semba/load_save_file":
    result = semba_LoadSaveFile(jsonReq, db)
  elif uri == "/semba/create_save_file":
    result = semba_CreateSaveFile(jsonReq, db)
  elif uri == "/semba/delete_save_file":
    semba_DeleteSaveFile(jsonReq)
  elif uri == "/semba/list_save_files":
    result = %*semba_ListSaveFiles(protoJsonTo(jsonReq, SembaListSaveFilesRequest))
  elif uri == "/semba/get_std_gacha_rates":
    result = semba_GetStdGachaRates(db)
  elif uri == "/semba/set_std_gacha_rates":
    semba_SetStdGachaRates(db, jsonReq)
  elif uri == "/semba/reset_db":
    semba_ResetDb(db)
  elif uri == "/semba/update_hair_color":
    result = semba_UpdateHairColor(db, jsonReq)
  elif uri == "/semba/get_hair_colors":
    result = %*semba_GetHairColors(db)
  elif uri == "/semba/new_game":
    semba_NewGame(db, protoJsonTo(jsonReq, SembaNewGameRequest))
  elif uri == "/semba/set_skip_tutorial":
    semba_SetSkipTutorial(db, protoJsonTo(jsonReq, SembaSetSkipTutorialRequest))
  elif uri == "/semba/get_skip_tutorial":
    result = %*semba_GetSkipTutorial(db)
  elif uri == "/semba/mail_gear":
    semba_MailGear(db, protoJsonTo(jsonReq, SembaMailGearRequest))
  elif uri == "/semba/move_to_area":
    semba_MoveToArea(db, protoJsonTo(jsonReq, SembaMoveToAreaRequest))
