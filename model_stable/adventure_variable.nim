import std/json
import std/options
import std/strutils

import ../db_connector/db_sqlite


type VariableOperator* = enum
  variableOperatorAdd = 1
  variableOperatorUnknown = 2

type AdventureVariableChange = object
  adventureVariableId: int
  variableOperator: VariableOperator
  variableChangeValue: int

type AdventureVariable* = object
  adventureVariableId*: int
  value*: Option[int]


proc getVariableChanges(db: DbConn, sequenceRequestIds: seq[int]): seq[AdventureVariableChange] =
  for seqReqId in sequenceRequestIds:
    let row = db.getRow(sql"""
      SELECT adventureVariableId, variableChangeValue, variableOperator FROM mdSequenceRequest
      WHERE id = ? AND type = 5
    """, seqReqId)

    if row[0] != "":
      result.add(AdventureVariableChange(
        adventureVariableId: parseInt(row[0]),
        variableChangeValue: parseInt(row[1]),
        variableOperator: VariableOperator(parseInt(row[2]))
      ))


proc getAdventureVariable(db: DbConn, adventureVariableId: int): Option[AdventureVariable] =
  let row = db.getRow(
    sql"SELECT value FROM adventureVariables WHERE adventureVariableId = ?", adventureVariableId
  )

  if row[0] != "":
    result = some(AdventureVariable(
      adventureVariableId: adventureVariableId,
      value: some(parseInt(row[0]))
    ))


proc getSequenceAdventureVariables*(db: DbConn, sequenceRequestIds: seq[int]): seq[AdventureVariable] =
  ## Calculates the new adventure variables based on the sequence request ids.
  ## Doesn't update the db with the new adventure variables.

  for varChange in getVariableChanges(db, sequenceRequestIds):
    var adventureVar = getAdventureVariable(db, varChange.adventureVariableId).get(AdventureVariable(
      adventureVariableId: varChange.adventureVariableId,
      value: some(0)
    ))

    case varChange.variableOperator:
      of variableOperatorAdd:
        adventureVar.value = some(adventureVar.value.get(0) + varChange.variableChangeValue)
      of variableOperatorUnknown: # Assume it's the opposite
        adventureVar.value = some(adventureVar.value.get(0) - varChange.variableChangeValue)

    result.add(adventureVar)


proc updateAdventureVariables*(db: DbConn, adventureVariables: seq[AdventureVariable]) =
  for adventureVariable in adventureVariables:
    db.exec(sql"""
      INSERT INTO adventureVariables (adventureVariableId, value) VALUES (?, ?)
      ON CONFLICT (adventureVariableId) DO UPDATE SET value = excluded.value
    """, adventureVariable.adventureVariableId, adventureVariable.value.get(0))


proc addAdventureVariable*(db: DbConn, adventureVariable: JsonNode) =
  let adventureVariableId = adventureVariable["adventureVariableId"].getInt()
  let value = adventureVariable["value"].getInt()

  db.exec(
    sql"INSERT INTO adventureVariables (adventureVariableId, value) VALUES (?, ?)",
    adventureVariableId, value
  )


proc getAdventureVariables*(db: DbConn): seq[JsonNode] =
  let adventureVariablesRows = db.getAllRows(sql"SELECT adventureVariableId, value FROM adventureVariables")

  for row in adventureVariablesRows:
    let adventureVariableId = parseInt(row[0])
    let value = parseInt(row[1])

    result.add(%*{
      "adventureVariableId": adventureVariableId,
      "value": value
    })