import std/json

import ./utils
import ../../src/semba/model_stable/user


proc testUserUpdateLanguage() =
  var ctx = getInMemorySembaCtx()

  doAssert(getUserLanguage(ctx.db) == userLanguageEnglish)

  const newLanguage = 1

  discard ctx.sembaCall("/user/update_language", %*{
    "language": newLanguage,
  })

  doAssert(getUserLanguage(ctx.db) == newLanguage)


proc testSuiteUser*(savesDir: string) =
  testUserUpdateLanguage()
