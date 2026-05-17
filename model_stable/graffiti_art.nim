import strutils

import ../db_connector/db_sqlite


type GraffitiArt* = object
  graffitiArtId*: int


proc getGraffitiArts*(db: DbConn): seq[GraffitiArt] =
  let rows = db.getAllRows(sql"SELECT graffitiArtId FROM graffitiArts")

  for row in rows:
    result.add(GraffitiArt(graffitiArtId: parseInt(row[0])))


proc addGraffitiArt*(db: DbConn, graffitiArt: GraffitiArt) =
  db.exec(sql"INSERT INTO graffitiArts (graffitiArtId) VALUES (?)", graffitiArt.graffitiArtId)


proc addGraffitiArts*(db: DbConn, graffitiArts: openArray[GraffitiArt]) =
  for graffitiArt in graffitiArts:
    addGraffitiArt(db, graffitiArt)


proc graffitiArtIdToCityId*(graffitiArtId: int): int = graffitiArtId div 1000000