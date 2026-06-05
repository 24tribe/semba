import std/json
import std/options

import utils
import ../protojson
import ../api_stable/adventure
import ../model_stable/reward
import ../model_stable/graffiti_art


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
  doAssert(response.rewards[0].`type`.RewardType == rewardFreeGem)
  doAssert(response.rewards[0].quantity == 5)
  doAssert(response.rewards[0].id == 1)

  doAssert(response.changedResources.wallet.isSome())
  doAssert(response.changedResources.graffitiArts.get(@[]) == @[GraffitiArt(graffitiArtId: graffitiArtId)])
  doAssert(response.changedResources.status.isSome())


proc testSuiteGraffitiArt*() =
  testFindGraffiti()