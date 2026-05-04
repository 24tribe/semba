import std/options


type AreaObjectLock* = object
  areaObjectLockId*: int
  count*: Option[int]