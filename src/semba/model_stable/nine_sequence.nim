import std/options
import std/json
import std/strutils
import std/sugar

import db_connector/db_sqlite

import ../protojson
import ../extsqlite
import ./timestamp


const heroJammedCompleteNineSequenceId* = 10018111


type NineSequence* = object
  nineSequenceId*: int
  choices*: string
  expiresAt*: Option[Timestamp]
  lastReceiveAt*: Option[Timestamp]
  lastReadAt*: Option[Timestamp]

type NineSequenceRequest* = object
  id*: int
  choices*: string


proc getNineSequences*(db: DbConn): seq[NineSequence] =
  collect:
    for it in db.getAllRows(sql"SELECT nineSequenceId, content FROM nineSequences"):
      var nineSeq = parseJson(it[1]).protoJsonTo(NineSequence)
      nineSeq.nineSequenceId = parseInt(it[0])
      nineSeq


proc getNineSequence*(db: DbConn, nineSequenceId: int): Option[NineSequence] =
  let row = db.getRow(
    sql"SELECT content FROM nineSequences WHERE nineSequenceId = ?", nineSequenceId
  )

  if row[0] != "":
    let jsonData = parseJson(row[0])
    jsonData["nineSequenceId"] = %*nineSequenceId
    result = some(protoJsonTo(jsonData, NineSequence))


proc updateNineSequence(db: DbConn, nineSequence: NineSequence) =
  let jsonData = %*nineSequence
  jsonData.delete("nineSequenceId")

  db.exec(sql"""
    INSERT INTO nineSequences (nineSequenceId, content)
    VALUES (?, ?)
    ON CONFLICT (nineSequenceId) DO
    UPDATE SET content = excluded.content
  """, nineSequence.nineSequenceId, $jsonData)


proc processNineSequenceRequests*(db: DbConn, nineSequenceRequests: seq[NineSequenceRequest]): seq[NineSequence] =
  ## Get a seq[NineSequence] based on nine sequence requests.
  ## Updates the db.

  for nineSequenceReq in nineSequenceRequests:
    var nineSequence = getNineSequence(db, nineSequenceReq.id).get(NineSequence(
      nineSequenceId: nineSequenceReq.id,
      choices: "{\"Selections\":[]}",
    ))

    nineSequence.lastReadAt = some(getTimestampNow())

    result.add(nineSequence)
    updateNineSequence(db, nineSequence)

  #[
  FIXME: `nineSequences` is missing some nine sequences (taken from master data nine_trigger.json)
  that are returned from an unrelated nine sequence request. I still don't know how to pick
  which one to return.
  ]#


proc updateNineSequences*(db: DbConn, nineSequences: seq[NineSequence]) =
  for nineSequence in nineSequences:
    db.exec(sql"""
      INSERT INTO nineSequences (nineSequenceId, content) VALUES (?, ?)
      ON CONFLICT (nineSequenceId) DO UPDATE SET content = excluded.content
    """, nineSequence.nineSequenceId, toProtoJson(nineSequence))


proc getNineTrigger*(db: DbConn, chalProgId: int): Option[int] =
  db.getRow(sql"SELECT id FROM mdNineTrigger WHERE challengeProgressId = ?", chalProgId)[0].tryParseInt