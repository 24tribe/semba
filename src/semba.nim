import std/json
import std/strutils
import std/times

import msgpack4nim
import msgpack4nim/msgpack2json

import ../tests/utils
import ../sembasave
import ../db_connector/sqlite3
import ../semba
import ../protojson


proc pack_type*(s: MsgStream, n: JsonNode) =
  let val =
    if n.isNil:
      JsonNode(kind: JNull)
    else:
      n

  s.fromJsonNode(val)


proc unpack_type*(s: MsgStream, n: var JsonNode) =
  n = s.toJsonNode()


proc init_msgstream(data: sink string): MsgStream = MsgStream.init(data, MSGPACK_OBJ_TO_MAP)


proc convert_json_save_to_msgpack(ctx: var SembaExContext, outName: string) =
  ctx.loadSaveFile("test_saves", "meiou isle restricted area puzzle")
  let save = ctx.db.getSaveFile()

  var s = init_msgstream("")
  s.pack(save)
  echo(s.data.len)

  writeFile(outName, s.data)


var ctx = getInMemorySembaCtx()

# echo(libversion()) # FIXME: check version, the default in windows (3.31.1) doesn't implement some joins

let outName = "out.msgpack"

let r = 0..10

let t0 = cpuTime()

for i in r:
  #[ var s = init_msgstream(readFile(outName))
  var save: SembaSave
  s.unpack(save) ]#

  let s = readFile("test_saves/meiou isle restricted area puzzle.save")
  let save = protoJsonTo(parseJson(s), SembaSave)

  # ctx.loadSaveFile("test_saves", "meiou isle restricted area puzzle")


let diff = cpuTime() - t0
echo("one call in secs: ", diff/(r.len.float))