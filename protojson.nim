#[
the functions in this file mimic the behaviour of the protobuf json dumper
(they omit the field if the value is set to the default)
]#

import std/json
import std/jsonutils
import std/strutils
import std/macros

export jsonutils


type ProtoJsonInt64* = distinct int64


proc `$`*(i: ProtoJsonInt64): string {.borrow.}
proc `==`*(a, b: ProtoJsonInt64): bool {.borrow.}


proc protoJsonDeleteKey*(node: JsonNode, key: string) =
  if node.hasKey(key):
    node.delete(key)

proc protoJsonGetBool*(node: JsonNode, key: string): bool = node.getOrDefault(key).getBool()

proc protoJsonSetBool*(node: JsonNode, key: string, val: bool) =
  if val:
    node[key] = %*true
  else:
    if node.hasKey(key):
      node.delete(key)

proc protoJsonGetInt*(node: JsonNode, key: string): int = node.getOrDefault(key).getInt()

proc protoJsonSetInt*(node: JsonNode, key: string, val: int) =
  if val != 0:
    node[key] = %*val
  else:
    if node.hasKey(key):
      node.delete(key)

proc protoJsonGetFloat*(node: JsonNode, key: string): float = node.getOrDefault(key).getFloat()

proc protoJsonSetFloat*(node: JsonNode, key: string, val: float) =
  if val != 0.0:
    node[key] = %*val
  else:
    if node.hasKey(key):
      node.delete(key)


proc fromJsonHook*(a: var ProtoJsonInt64, b: JsonNode) =
  a = jsonTo(b, string).parseBiggestInt().ProtoJsonInt64


proc toJsonHook*(a: ProtoJsonInt64): JsonNode = toJson($(a.int64))


proc protoJsonTo*(b: JsonNode, T: typedesc): T =
  ## jsonTo wrapper that allows extra keys, missing keys and a nil argument

  when T is enum:
    if b.isNil or b.kind == JNull:
      return T.low

  var val =
    if b.isNil():
      JsonNode(kind: JNull)
    else:
      b

  jsonTo(val, T, Joptions(allowExtraKeys: true, allowMissingKeys: true))


proc fromJsonHook*(res: var JsonNode, n: JsonNode) =
  res =
    if n.isNil:
      JsonNode(kind: JNull)
    else:
      n


proc toJsonHook*(n: JsonNode): JsonNode =
  if n.isNil:
    JsonNode(kind: JNull)
  else:
    n


proc fromJsonHook*(res: var int, n: JsonNode) =
  res =
    if n.isNil or n.kind == JNull:
      0
    else:
      n.getInt()


proc toJsonHook*(i: int): JsonNode =
  %i


macro genStringEnumHooks*(e: untyped): untyped =
  ## Macro that receives an enum type and generates a fromJsonHook and a toJsonHook that parses a JString.
  ## The fromJsonHook sets the result to the first value of the enum when receives an empty string.
  ## The toJsonHook does nothing special, but it's needed for consistency.

  quote do:
    proc fromJsonHook*(e: var `e`, n: JsonNode) =
      e =
        if n.kind == JString and n.getStr() == "":
          `e`.low
        else:
          parseEnum[`e`](n.getStr())

    proc toJsonHook*(e: `e`): JsonNode = %($e)


proc toProtoJson*[T](o: T): JsonNode =
  ## toJson wrapper to match protoJsonTo

  var opts = initToJsonOptions()
  opts.enumMode = joptEnumString
  toJson(o, opts)