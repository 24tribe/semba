import std/json
import std/strutils
import std/options

import ../db_connector/db_sqlite

import ../semba_error


type FormationMembers* = object
  character1Id*: Option[int]
  character2Id*: Option[int]
  character3Id*: Option[int]
  character1OwnershipType*: Option[int]
  character2OwnershipType*: Option[int]
  character3OwnershipType*: Option[int]

type Formation* = object
  number*: Option[int]
  members*: FormationMembers
  cards*: Option[JsonNode] # FIXME: use FormationCards


proc getFormationMembers*(db: DbConn, number: int): FormationMembers =
  let row = db.getRow(sql"SELECT members FROM formations WHERE number = ?", number)

  if row[0] == "":
    raise newException(SembaError, "Failed to get members of formation " & $number)

  result = to(parseJson(row[0]), FormationMembers)


proc getFormations*(db: DbConn): seq[JsonNode] =
  let formationsRows = db.getAllRows(sql"""
    SELECT number, members, cards FROM formations
  """)

  for formationRow in formationsRows:
    let members = parseJson(formationRow[1])
    let cards = parseJson(formationRow[2])

    var formation = %*{
      "members": members,
      "cards": cards
    }

    let number = parseInt(formationRow[0])

    if number != 0:
      formation["number"] = %*number

    result.add(formation)


proc updateFormation*(db: DbConn, formation: JsonNode) =
  let number = formation.getOrDefault("number").getInt()
  let members = $(formation["members"])
  let cards = $(formation["cards"])

  db.exec(sql"""
    UPDATE formations SET members = ?, cards = ? WHERE number = ?
  """, members, cards, number)


proc updateFormations*(db: DbConn, formations: seq[JsonNode]) =
  for formation in formations:
    updateFormation(db, formation)