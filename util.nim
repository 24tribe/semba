import std/options
import std/strutils

proc tryParseInt*(s: string): Option[int] = (if s != "": some(parseInt(s)) else: none(int))