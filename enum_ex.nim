import std/enumutils


#[
Converts an int to an enum with holes.
Throws a ValueError if the integer is not in the enum
]#
proc intToEnum*(i: int, T: typedesc): T =
  for e in T.items():
    if e.int == i:
      return e

  raise newException(ValueError, "Couldn't get enum of type " & $T & " for value: " & $i)