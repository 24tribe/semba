import std/options


type CharacterPiece* = object
  characterId: int
  quantity: Option[int]