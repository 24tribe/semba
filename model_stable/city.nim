import std/json
import std/strutils
import std/options

import ../db_connector/db_sqlite

import timestamp


type City* = object
  cityId: int
  isGearShopReleased: Option[bool]
  releasedAt: Option[Timestamp]

type CityId* = enum
  cityIdShinagawa = 10
  cityIdMinato = 13
  cityIdChiyoda = 14
  cityId24City = 30
  cityIdRift = 80
  cityIdFractalVise1 = 81
  cityIdFractalVise2 = 82
  cityIdFractalVise3 = 83


proc addCity*(db: DbConn, city: JsonNode) =
  let cityId = city["cityId"].getInt()
  let isGearShopReleased = city.getOrDefault("isGearShopReleased").getBool()
  let releasedAt = city["releasedAt"].getStr()
  db.exec(sql"""
    INSERT INTO cities (cityId, isGearShopReleased, releasedAt)
    VALUES (?, ?, ?)
    ON CONFLICT (cityId) DO UPDATE SET isGearShopReleased = excluded.isGearShopReleased
  """, cityId, isGearShopReleased, releasedAt)


proc getCities*(db: DbConn): seq[JsonNode] =
  for row in db.getAllRows(sql"SELECT cityId, isGearShopReleased, releasedAt FROM cities"):
    let cityId = parseInt(row[0])
    let isGearShopReleased = row[1] == "true"
    let releasedAt = row[2]
    result.add(%*{
      "cityId": cityId,
      "isGearShopReleased": isGearShopReleased,
      "releasedAt": releasedAt
    })


func areaIdToCityId*(areaId: int): int = areaId div 10000