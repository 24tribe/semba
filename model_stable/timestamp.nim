import std/times
import std/json

type Timestamp* = distinct string

proc getDateNow*(): string = $(now().utc)
proc getTimestampNow*(): Timestamp = getDateNow().Timestamp

proc `%`*(timestamp: Timestamp): JsonNode {.borrow.}
proc `==`*(a, b: Timestamp): bool {.borrow.}