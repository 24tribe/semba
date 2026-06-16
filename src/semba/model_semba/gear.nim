import std/options

import ../model_stable/gear
import ../semba_error


proc sembaGearRarityToProperGearRarity*(rarity: int): GearRarity =
  result =
    case rarity:
    of 0: gearRarityN
    of 1: gearRarityR
    of 2: gearRaritySr
    of 3: gearRaritySsr
    else: gearRarityInvalid

  if result == gearRarityInvalid:
    raise newException(SembaError, "Invalid gear rarity")


proc sembaPieceToMainStatusId*(piece: int): int =
  result = piece + 1

  if result < 1 or 3 < result:
    raise newException(SembaError, "Invalid gear main status")


proc sembaSetToGearType*(setIndex: int): GearType =
  let res =
    case setIndex:
    of 0: some(gearAttacker)
    of 1: some(gearGladiator)
    of 2: some(gearBerserker)
    of 3: some(gearDefender)
    of 4: some(gearPaladin)
    of 5: some(gearFortress)
    of 6: some(gearHealer)
    of 7: some(gearTrickster)
    of 8: some(gearEnchanter)
    else:
      none(GearType)

  if res.isNone():
    raise newException(SembaError, "Invalid gear type")

  result = res.get()


proc sembaTierToGrade*(tierIndex: int): int =
  if tierIndex < 0 or 9 < tierIndex:
    raise newException(SembaError, "Invalid gear grade")

  result =
    if tierIndex == 9:
      11 # tier 10 doesn't exist
    else:
      tierIndex + 1


proc sembaSubstatToGearStatusId*(substatIndex: int): Option[int] =
  if substatIndex == 0:
    return none(int)

  let gearStatusIds = [
    10010001, 10010002, 10011001, 10011002, 10012001, 10012002, 10013001, 10013002, 10013003, 10020001,
    10020002, 10021001, 10021002, 10022001, 10022002, 10023001, 10023002, 10023003, 10030001, 10030002,
    10031001, 10031002, 10032001, 10032002, 10033001, 10033002, 10033003, 10040001, 10040002, 10041001,
    10041002, 10042001, 10042002, 10043001, 10043002, 10043003, 10050001, 10050002, 10051001, 10051002,
    10052001, 10052002, 10053001, 10053002, 10053003, 10060001, 10060002, 10061001, 10061002, 10062001,
    10062002, 10063001, 10063002, 10063003, 10070001, 10071001, 10072001, 10073001, 10080001, 10080002,
    10081001, 10081002, 10082001, 10082002, 10083001, 10083002, 10083003, 10090001, 10091001, 10092001,
    10093001, 10094001, 10095001, 10096001, 10097001, 10098001, 10099001, 10100001, 10101001, 10102001,
    10103001, 10104001, 10105001, 10106001, 10107001, 10108001, 10109001, 10110001, 10111001, 10112001,
    10113031, 10113032, 10114031, 10114032, 10115031, 10115032, 10116031, 10116032, 10117031, 10117032,
    10119031, 11001001, 11001003, 11001004, 11001006, 11002001, 11002003, 11002004, 11002006, 11003001,
    11003003, 11003004, 11003006, 11004001, 11004003, 11004004, 11004006, 11005001, 11005004, 11005006,
    11006001, 11006004, 11006006, 11007001, 11007003, 11007004, 11007006, 11008001, 11008003, 11008004,
    11008006, 11009001, 11009003, 11009006, 11010001, 11010004, 11010006, 11011001, 11011003, 11011004,
    11011006, 11012001, 11012003, 11012004, 11012006, 11013001, 11013003, 11013004, 11013006, 11014001,
    11014003, 11014004, 11014006, 11015001, 11015003, 11015004, 11015006, 11029001, 11029003, 11029004,
    11029006, 11030001, 11030003, 11030006, 11031001, 11031004, 11031006
  ]

  let idx = substatIndex - 1

  if idx > gearStatusIds.high:
    raise newException(SembaError, "Invalid substat")

  result = some(gearStatusIds[idx])