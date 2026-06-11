import std/json
import std/options

import ../db_connector/db_sqlite

import ../model_stable/character
import ../model_stable/resources
import ../model_stable/item
import ../model_stable/reward
import ../model_stable/character_piece
import ../model_stable/status


type CharacterEquipRequest* = object
  characterId*: int
  gearSlot1*: Option[int]
  gearSlot2*: Option[int]
  gearSlot3*: Option[int]

type CharacterEnhanceRequest* = object
  characterId*: int
  consumedItems*: Option[seq[ConsumedItem]]

type CharacterLimitBreakResponse* = object
  changedResources*: Resources
  rewards*: seq[Rewards]


proc character_CostumeUpdate*(db: DbConn, jsonReq: JsonNode): ChangedResourcesResponse =
  let costumeId = jsonReq["characterCostumeId"].getInt()
  let characterId = costumeIdToCharacterId(costumeId)

  var character = getCharacter(db, characterId)
  character.characterCostumeId = some(costumeId)

  result.changedResources.characters = @[character]

  db.exec(sql"UPDATE characters SET characterCostumeId = ? WHERE characterId = ?", costumeId, characterId)


proc character_LimitBreak*(db: DbConn, jsonReq: JsonNode): CharacterLimitBreakResponse =
  let characterId = jsonReq["characterId"].getInt()
  let limitBreakCount = jsonReq["limitBreakCount"].getInt()

  var character = getCharacter(db, characterId)
  character.limitBreak = character.limitBreak.map(proc (x: int): int = x + limitBreakCount)
  addCharacterLimitBreak(db, characterId, character.limitBreak.get(0))

  var characterPiece = getCharacterPiece(db, characterId)
  characterPiece.quantity = max(0, characterPiece.quantity - 1)
  updateCharacterPiece(db, characterPiece)

  result.changedResources.characters = @[character]
  result.changedResources.characterPieces = some(@[characterPiece])


proc character_Equip*(db: DbConn, req: CharacterEquipRequest): ChangedResourcesResponse =
  updateCharacterGear(db, req.characterId, req.gearSlot1, req.gearSlot2, req.gearSlot3)
  result.changedResources.characters = @[getCharacter(db, req.characterId)]


proc character_Enhance*(db: DbConn, req: CharacterEnhanceRequest): ChangedResourcesResponse =
  let consumedItems = req.consumedItems.get(@[])

  var items = newSeq[Item]()

  for item in consumedItems:
    var dbItem = getItem(db, item.itemId).get()
    dbItem.quantity = some(dbItem.quantity.get(0) - item.quantity.get(0))
    items.add(dbItem)
    upsertItem(db, dbItem)

  result.changedResources.items = items

  let addExp = calcLifeDataExp(consumedItems)

  updateCharacterExp(db, addExp, req.characterId, getCharacterMaxExp(db))
  result.changedResources.characters = @[getCharacter(db, req.characterId)]

  let kane = 2*addExp

  var status = getUserStatusTypeSafe(db)
  status.gold = some(status.gold.get(0) - kane)
  setUserStatusTypeSafe(db, status)
  result.changedResources.status = some(status)