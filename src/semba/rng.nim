import std/random


var isRiggedRng = false


proc setIsRiggedRng*(val: bool) =
  isRiggedRng = val


proc riggedSample*[T](a: openArray[T]): T = a[a.high]


proc mySample*[T](a: openArray[T]): T =
  if isRiggedRng:
    a.riggedSample()
  else:
    a.sample()