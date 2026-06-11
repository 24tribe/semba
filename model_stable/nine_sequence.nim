import std/options
import std/json
import std/strutils

import ../db_connector/db_sqlite

import ../protojson
import timestamp

type NineSequence* = object
  nineSequenceId*: int
  choices*: string
  expiresAt*: Option[Timestamp]
  lastReceiveAt*: Option[Timestamp]
  lastReadAt*: Option[Timestamp]

type NineSequenceRequest* = object
  id*: int
  choices*: string


proc getNineSequences*(db: DbConn): seq[JsonNode] =
  let nineSequencesRows = db.getAllRows(sql"SELECT nineSequenceId, content FROM nineSequences")

  for nineSequenceRow in nineSequencesRows:
    let nineSequenceId = parseInt(nineSequenceRow[0])
    let content = parseJson(nineSequenceRow[1])

    content["nineSequenceId"] = %*nineSequenceId
    
    result.add(content)


proc getNineSequence(db: DbConn, nineSequenceId: int): Option[NineSequence] =
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


proc addNineSequence*(db: DbConn, nineSequence: JsonNode) =
  let nineSequenceId = nineSequence["nineSequenceId"].getInt()
  let tmp = nineSequence.copy()
  tmp.delete("nineSequenceId")
  let content = $tmp
  db.exec(
    sql"INSERT INTO nineSequences (nineSequenceId, content) VALUES (?, ?)",
    nineSequenceId, content
  )