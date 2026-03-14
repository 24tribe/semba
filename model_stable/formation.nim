import std/json
import std/strutils

import ../db_connector/db_sqlite


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