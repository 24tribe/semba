import std/times
import std/json

export times

type Timestamp* = distinct string

proc timestamp*(dt: DateTime): Timestamp = ($(dt.utc)).Timestamp

proc getDateNow*(): string = $(now().utc)
proc getTimestampNow*(): Timestamp = getDateNow().Timestamp
proc getFutureTimestamp*(): Timestamp = "2100-01-11T20:20:25Z".Timestamp

proc `%`*(timestamp: Timestamp): JsonNode {.borrow.}
proc `==`*(a, b: Timestamp): bool {.borrow.}
proc `$`*(a: Timestamp): string {.borrow.}