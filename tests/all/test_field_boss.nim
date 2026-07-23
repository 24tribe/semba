import std/json
import std/options

import ../../src/semba/api_stable/field_boss
import ../../src/semba/model_stable/status
import ../../src/semba/protojson
import ./utils


proc testFieldBossEntry() =
  var ctx = getInMemorySembaCtx()

  let currentLocation = %*{
    "areaType": 1, "direction": 1,
    "positionCoordinates": { "x": 0.5775823, "y": 3.0416667, "z": 3.815215 }, "areaKeyId": 100211
  }

  let res = ctx.sembaCall("/field_boss/entry", %*{
    "fieldBossId": 109201,
    "currentLocation": currentLocation
  }).protoJsonTo(Option[FieldBossEntryResponse])

  doAssert(res.isSome)

  let changedResources = res.get().changedResources

  doAssert(changedResources.status.isSome)

  let status = changedResources.status.get()

  doAssert(status.getCurrentLocation == currentLocation.protoJsonTo(CurrentLocation))


proc testSuiteFieldBoss*(savesDir: string) =
  testFieldBossEntry()
