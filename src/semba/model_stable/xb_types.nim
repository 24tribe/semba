import std/options

type XbStatus* = object
  xbId*: int
  actionSequenceId*: Option[int]
