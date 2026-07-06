import std/json
import std/options

import ./utils
import ../../src/semba/protojson
import ../../src/semba/api_stable/auth
import ../../src/semba/model_stable/user


proc genFakeHex(byteCount: int): string =
  for i in 0 ..< byteCount:
    result.add("FF")


proc testSignUp() =
  var ctx = getInMemorySembaCtx()
  let res = ctx.sembaCall("/auth/sign_up", %*{
    "deviceSecret": genFakeHex(234),
    "deviceUniqueId": genFakeHex(20),
    "deviceModel": "PC",
    "language": 2,
    "locale": 2
  }).protoJsonTo(Option[AuthSignUpResponse])

  doAssert(res.isSome)
  doAssert(res.get().userId == fakeUserId)


proc testAuthSignIn() =
  var ctx = getInMemorySembaCtx()
  let res = ctx.sembaCall("/auth/sign_in", %*{}).protoJsonTo(Option[AuthSignInResponse])
  doAssert(res.isSome)
  doAssert(res.get().language == userLanguageEnglish)
  doAssert(res.get().sessionToken == fakeSessionToken)
  doAssert(not res.get().deviceChanged)


proc testSuiteAuth*(savesDir: string) =
  testSignUp()
  testAuthSignIn()
