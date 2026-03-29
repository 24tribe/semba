import std/json
import std/assertions

import ../model_stable/reward


proc test_reward_field_name() =
  let reward = Reward()
  let rewardJson = %*reward
  doAssert rewardJson.hasKey("type")


when isMainModule:
  test_reward_field_name()