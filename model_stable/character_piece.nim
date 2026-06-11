import std/options
import std/strutils
import std/sequtils

import ../db_connector/db_sqlite

import ../extsqlite


type CharacterPiece* = object
  characterId*: int
  quantity*: int


proc getCharacterPiece*(db: DbConn, characterId: int): CharacterPiece =
  let row = db.getRow(
    sql"SELECT quantity FROM characterPieces WHERE characterId = ?", characterId
  )

  result = CharacterPiece(
    characterId: characterId,
    quantity: tryParseInt(row[0]).get(0)
  )


proc updateCharacterPiece*(db: DbConn, characterPiece: CharacterPiece) =
  db.exec(sql"""
    INSERT INTO characterPieces (characterId, quantity) VALUES (?, ?)
    ON CONFLICT (characterId) DO
    UPDATE SET quantity = excluded.quantity
  """, characterPiece.characterId, characterPiece.quantity)


proc addCharacterPiece*(db: DbConn, characterId: int): int =
  ## Add one character piece to the db, returns the changed count of character pieces

  let row = db.getRow(sql"SELECT quantity FROM characterPieces")

  if row[0] == "":
    result = 1
  else:
    result = parseInt(row[0]) + 1

  updateCharacterPiece(db, CharacterPiece(characterId: characterId, quantity: result))


proc getCharacterPieces*(db: DbConn): seq[CharacterPiece] =
  let rows = db.getAllRows(sql"SELECT characterId, quantity FROM characterPieces")

  result = rows.mapIt(CharacterPiece(
    characterId: parseInt(it[0]),
    quantity: parseInt(it[1])
  ))