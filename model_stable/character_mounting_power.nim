import std/options


type CharacterMountingPower* = object
  characterId: int
  value: Option[int]

type CharacterMountingPowerCommon* = object
  value: Option[int]