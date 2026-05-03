import std/times
import std/json

export times

type Timestamp* = distinct string

proc timestamp*(dt: DateTime): Timestamp = ($(dt.utc)).Timestamp

proc getDateNow*(): string = $(now().utc)
proc getTimestampNow*(): Timestamp = getDateNow().Timestamp
proc getFutureTimestamp*(): Timestamp = "2100-01-11T20:20:25Z".Timestamp

proc endOfToday*(): Timestamp =
  let dtNow = now()
  result = datetime(dtNow.year, dtNow.month, dtNow.monthday, 23, 59, 59).timestamp

proc `%`*(timestamp: Timestamp): JsonNode {.borrow.}
proc `==`*(a, b: Timestamp): bool {.borrow.}
proc `$`*(a: Timestamp): string {.borrow.}