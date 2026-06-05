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


#[
Swaps the nineSequences taken from online logs to the ones generated
by a proper implementation.
]#
proc changeNineSequences*(
  db: DbConn, nineSequenceRequests: seq[NineSequenceRequest], response: JsonNode
) =
  var nineSequences = newSeq[NineSequence]()

  for nineSequenceReq in nineSequenceRequests:
    var nineSequence = getNineSequence(db, nineSequenceReq.id).get(NineSequence(
      nineSequenceId: nineSequenceReq.id,
      choices: "{\"Selections\":[]}",
    ))

    nineSequence.lastReadAt = some(getTimestampNow())

    nineSequences.add(nineSequence)
    updateNineSequence(db, nineSequence)

  #[
  FIXME: `nineSequences` is missing some nine sequences (taken from master data nine_trigger.json)
  that are returned from an unrelated nine sequence request. I still don't know how to pick
  which one to return.
  ]#

  response["changedResources"]["nineSequences"] = %*nineSequences


proc updateNineSequences*(db: DbConn, nineSequences: JsonNode) =
  for nineSequence in nineSequences:
    let nineSequenceId = nineSequence["nineSequenceId"].getInt()
    let seqCopy = nineSequence.copy()
    seqCopy.delete("nineSequenceId")
    let seqCopyStr = $seqCopy

    db.exec(sql"""
      INSERT INTO nineSequences (nineSequenceId, content) VALUES (?, ?)
      ON CONFLICT (nineSequenceId) DO UPDATE SET content = ?
    """, nineSequenceId, seqCopyStr, seqCopyStr)


proc addNineSequence*(db: DbConn, nineSequence: JsonNode) =
  let nineSequenceId = nineSequence["nineSequenceId"].getInt()
  let tmp = nineSequence.copy()
  tmp.delete("nineSequenceId")
  let content = $tmp
  db.exec(
    sql"INSERT INTO nineSequences (nineSequenceId, content) VALUES (?, ?)",
    nineSequenceId, content
  )