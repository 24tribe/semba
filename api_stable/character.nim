import std/json
import std/options

import ../db_connector/db_sqlite

import ../model_stable/character
import ../model_stable/resources
import ../model_stable/item
import ../model_stable/status


type CharacterEquipRequest* = object
  characterId*: int
  gearSlot1*: Option[int]
  gearSlot2*: Option[int]
  gearSlot3*: Option[int]

type CharacterEnhanceRequest* = object
  characterId*: int
  consumedItems*: Option[seq[ConsumedItem]]


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


proc character_Enhance*(db: DbConn, req: CharacterEnhanceRequest): ChangedResourcesResponse =
  let consumedItems = req.consumedItems.get(@[])

  var items = newSeq[Item]()

  for item in consumedItems:
    var dbItem = getItem(db, item.itemId).get()
    dbItem.quantity = some(dbItem.quantity.get(0) - item.quantity.get(0))
    items.add(dbItem)
    upsertItem(db, dbItem)

  result.changedResources.items = some(items)

  let addExp = calcLifeDataExp(consumedItems)

  var character = getCharacter(db, req.characterId)
  updateCharacterExp(db, addExp, character, getCharacterMaxExp(db))
  result.changedResources.characters = some(@[getCharacter(db, req.characterId)])

  let kane = 2*addExp

  var status = getUserStatusTypeSafe(db)
  status.gold = some(status.gold.get(0) - kane)
  setUserStatusTypeSafe(db, status)
  result.changedResources.status = some(status)