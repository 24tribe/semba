import std/options


type CharacterLikability* = object
  characterId*: int
  likability*: Option[int]