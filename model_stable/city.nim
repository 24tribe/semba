import std/strutils
import std/sequtils

import ../db_connector/db_sqlite

import ../semba_error
import timestamp
import magic_orb


type City* = object
  cityId*: int
  isGearShopReleased*: bool
  releasedAt*: Timestamp

type CityId* = enum
  cityIdShinagawa = 10
  cityIdMinato = 13
  cityIdChiyoda = 14
  cityId24City = 30
  cityIdRift = 80
  cityIdFractalVise1 = 81
  cityIdFractalVise2 = 82
  cityIdFractalVise3 = 83


proc addCity*(db: DbConn, city: City) =
  db.exec(sql"""
    INSERT INTO cities (cityId, isGearShopReleased, releasedAt)
    VALUES (?, ?, ?)
    ON CONFLICT (cityId) DO UPDATE SET isGearShopReleased = excluded.isGearShopReleased
  """, city.cityId, city.isGearShopReleased, city.releasedAt)


proc getCities*(db: DbConn): seq[City] =
  let rows = db.getAllRows(sql"SELECT cityId, isGearShopReleased, releasedAt FROM cities")
  result = rows.mapIt(City(
    cityId: parseInt(it[0]),
    isGearShopReleased: it[1] == "true",
    releasedAt: it[2].Timestamp,
  ))


func areaIdToCityId*(areaId: int): int = areaId div 10000


proc magicOrbIdToCityId*(magicOrbId: int): CityId =
  if magicOrbId in shinagawaMagicOrbIds:
    cityIdShinagawa
  elif magicOrbId in minatoMagicOrbIds:
    cityIdMinato
  elif magicOrbId in chiyodaMagicOrbIds:
    cityIdChiyoda
  else:
    raise newException(SembaError, "Magic orb doesn't belong to any city?")