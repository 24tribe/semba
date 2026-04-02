import std/assertions
import std/json
import std/options
import std/sequtils

import ../model_stable/resources
import ../model_stable/character
import utils


proc testCharacterStatsDependOnLevel() =
  var ctx = getInMemorySembaCtx()

  const yoCharId = 100101
  const yoLevel2MaxHp = 511
  const yoLevel2Attack = 106
  const yoLevel2Defense = 105
  const yoLevel2Exp = 240

  proc checkYo(character: Character): bool =
    result = character.characterId == yoCharId and
      character.exp.get(0) == yoLevel2Exp and
      character.maxHp.get(0) == yoLevel2MaxHp and
      character.attack.get(0) == yoLevel2Attack and
      character.defense.get(0) == yoLevel2Defense

  const irohaCharId = 100201
  const irohaLevel1MaxHp = 452
  const irohaLevel1Attack = 109
  const irohaLevel1Defense = 92
  const irohaLevel1Exp = 0

  proc checkIroha(character: Character): bool =
    result = character.characterId == irohaCharId and
      character.exp.get(0) == irohaLevel1Exp and
      character.maxHp.get(0) == irohaLevel1MaxHp and
      character.attack.get(0) == irohaLevel1Attack and
      character.defense.get(0) == irohaLevel1Defense

  setCharacterExp(ctx.db, irohaCharId, irohaLevel1Exp)
  setCharacterExp(ctx.db, yoCharId, yoLevel2Exp)

  let yoChar = getCharacter(ctx.db, yoCharId)
  doAssert(checkYo(yoChar))

  let irohaChar = getCharacter(ctx.db, irohaCharId)
  doAssert(checkIroha(irohaChar))

  let characters = to(%*getCharacters(ctx.db), seq[Character])
  doAssert(characters.any(checkYo))
  doAssert(characters.any(checkIroha))


proc testCharacterEquip() =
  var ctx = getInMemorySembaCtx()

  let gearId = 10000
  let res = ctx.sembaCall("/character/equip", %*{ "characterId": 101101, "gearSlot3": gearId })

  doAssert(res != nil)

  let crRes = to(res, ChangedResourcesResponse)

  let characters = to(%*(crRes.changedResources.characters.get()), seq[Character])

  doAssert(characters.len == 1)
  doAssert(characters[0].gearSlot1.isNone())
  doAssert(characters[0].gearSlot2.isNone())
  doAssert(characters[0].gearSlot3.get() == gearId)

  let res2 = ctx.sembaCall("/character/equip", %*{ "characterId": 101101 })

  let crRes2 = to(res2, ChangedResourcesResponse)

  let characters2 = to(%*(crRes2.changedResources.characters.get()), seq[Character])

  doAssert(characters2.len == 1)
  doAssert(characters2[0].gearSlot1.isNone())
  doAssert(characters2[0].gearSlot2.isNone())
  doAssert(characters2[0].gearSlot3.isNone())

  # TODO: should check status updates?


proc testSuiteCharacter*() =
  testCharacterEquip()
  testCharacterStatsDependOnLevel()