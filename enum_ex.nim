import std/sugar
import std/enumutils


proc intToEnum*(i: int, T: typedesc): T =
  let res = collect:
    for e in T.items():
      if e.int == i: e

  if res.len == 0:
    raise newException(ValueError, "Couldn't get enum of type " & $T & "for value: " & $i)

  result = res[0]