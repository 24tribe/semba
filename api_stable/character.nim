import std/json
import std/options

import ../db_connector/db_sqlite

import ../model_stable/character
import ../model_stable/resources


type CharacterEquipRequest* = object
  characterId*: int
  gearSlot1*: Option[int]
  gearSlot2*: Option[int]
  gearSlot3*: Option[int]


proc character_CostumeUpdate*(db: DbConn, jsonReq: JsonNode): JsonNode =
  let costumeId = jsonReq["characterCostumeId"].getInt()
  let characterId = costumeIdToCharacterId(costumeId)

  var character = getCharacter(db, characterId)
  character.characterCostumeId = some(costumeId)

  let characters = [character]

  db.exec(sql"UPDATE characters SET characterCostumeId = ? WHERE characterId = ?", costumeId, characterId)

  return %*{
    "changedResources": {
      "characters": characters
    }
  }


proc character_LimitBreak*(db: DbConn, jsonReq: JsonNode): JsonNode =
  let characterId = jsonReq["characterId"].getInt()
  let limitBreakCount = jsonReq["limitBreakCount"].getInt()

  var character = getCharacter(db, characterId)
  character.limitBreak = character.limitBreak.map(proc (x: int): int = x + limitBreakCount)
  addCharacterLimitBreak(db, characterId, character.limitBreak.get(0))

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


proc character_Equip*(db: DbConn, req: CharacterEquipRequest): ChangedResourcesResponse =
  updateCharacterGear(db, req.characterId, req.gearSlot1, req.gearSlot2, req.gearSlot3)
  result.changedResources.characters = some(@[getCharacter(db, req.characterId)])