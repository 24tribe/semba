import std/json
import std/options

import ./utils
import ../../src/semba/enum_ex
import ../../src/semba/protojson
import ../../src/semba/api_stable/adventure
import ../../src/semba/model_stable/reward
import ../../src/semba/model_stable/graffiti_art


proc testFindGraffiti() =
  var ctx = getInMemorySembaCtx()

  let graffitiArtId = 10100201

  let res = protoJsonTo(sembaCall(ctx, "/adventure/find_graffiti", %*{
    "graffitiArtId": graffitiArtId,
    "currentLocation": {
      "areaType": 1, "direction": 1, "positionCoordinates": {"x": -9.4, "y": 0.5, "z": 0.2}, "areaKeyId": 101002
    }
  }), Option[AdventureFindGraffitiResponse])

  doAssert(res.isSome())

  let response = res.get()

  doAssert(response.rewards.len == 1)
  doAssert(response.rewards[0].`type`.intToEnum(RewardType) == rewardFreeGem)
  doAssert(response.rewards[0].quantity == 5)
  doAssert(response.rewards[0].id == 1)

  doAssert(response.changedResources.wallet.isSome())
  doAssert(response.changedResources.graffitiArts == @[GraffitiArt(graffitiArtId: graffitiArtId)])
  doAssert(response.changedResources.status.isSome())


proc testSuiteGraffitiArt*(savesDir: string) =
  testFindGraffiti()