import std/options


type HappyWorkerItem* = object
  happyWorkerItemId*: int
  isCleared*: Option[bool]
  state*: Option[int]