import std/json

import ../db_connector/db_sqlite

import ../model_stable/character


proc character_CostumeUpdate*(db: DbConn, jsonReq: JsonNode): JsonNode =
  let costumeId = jsonReq["characterCostumeId"].getInt()
  let characterId = costumeIdToCharacterId(costumeId)
  var characters = newSeq[JsonNode]()

  let character = getCharacter(db, characterId)
  character["characterCostumeId"] = %*costumeId
  characters.add(character)

  db.exec(sql"UPDATE characters SET characterCostumeId = ? WHERE characterId = ?", costumeId, characterId)

  return %*{
    "changedResources": {
      "characters": characters
    }
  }


proc character_LimitBreak*(db: DbConn, jsonReq: JsonNode): JsonNode =
  let characterId = jsonReq["characterId"].getInt()
  let limitBreakCount = jsonReq["limitBreakCount"].getInt()

  let character = getCharacter(db, characterId)
  let limitBreak = character.getOrDefault("limitBreak").getInt() + limitBreakCount
  character["limitBreak"] = %*limitBreak
  addCharacterLimitBreak(db, characterId, limitBreak)

  let characterPiece = getCharacterPiece(db, characterId)
  let quantity = max(0, characterPiece.getOrDefault("quantity").getInt() - 1)
  characterPiece["quantity"] = %*quantity
  updateCharacterPiece(db, characterPiece)

  result = %*{
    "changedResources": {
      "characters": [character],
      "characterPieces": [characterPiece],
    }
  }