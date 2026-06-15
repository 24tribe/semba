from argparse import ArgumentParser
from pathlib import Path
import json
import sqlite3
from collections import defaultdict
from dataclasses import dataclass

from genMasterData import write_rows


@dataclass
class DungeonPartObjectCount:
    dungeonPartId: int
    enemiesMax: int
    areaItemsMax: int


def main():
    parser = ArgumentParser()
    parser.add_argument("semba_db", type=Path)
    parser.add_argument("online_logs_json")
    parser.add_argument("out_sql")
    args = parser.parse_args()

    assert args.semba_db.exists()

    with open(args.online_logs_json, "r", encoding="utf-8") as f:
        online_logs = json.load(f)

    dungeonPartObjectCounts = gen_dungeon_part_object_counts_from_online_logs(online_logs)

    con = sqlite3.connect(args.semba_db)
    cur = con.cursor()

    res = cur.execute("SELECT id, name, blocks, angle FROM dungeonData")
    rows = res.fetchall()

    with open(args.out_sql, "w", encoding="utf-8") as f:
        rewrite_dungeon_data_sql(f, dungeonPartObjectCounts, rows)


def get_enemies_max_or_zero(dungeonPartObjectCounts, dungeonPieceId):
    res = dungeonPartObjectCounts.get(dungeonPieceId)
    if res is None:
        return 0
    else:
        return res.enemiesMax
    
def get_area_items_max_or_zero(dungeonPartObjectCounts, dungeonPieceId):
    res = dungeonPartObjectCounts.get(dungeonPieceId)
    if res is None:
        return 0
    else:
        return res.areaItemsMax


def rewrite_dungeon_data_sql(f, dungeonPartObjectCounts: dict[int, DungeonPartObjectCount], rows):
    xprint = lambda *args: print(*args, file=f)

    xprint("INSERT INTO dungeonData (id, name, blocks, angle, maxEnemies, maxAreaItems) VALUES ")

    write_rows(xprint, f, [
        (
            int(row[0]), row[1], row[2], int(row[3]),
            get_enemies_max_or_zero(dungeonPartObjectCounts, piece_id_to_idx(int(row[0]))),
            get_area_items_max_or_zero(dungeonPartObjectCounts, piece_id_to_idx(int(row[0]))),
        )
        for row in rows
    ])

    xprint(";")


def piece_id_to_idx(piece_id):
    return (piece_id%10000)//100


def gen_dungeon_part_object_counts_from_online_logs(online_logs: list[dict]) -> dict[int, DungeonPartObjectCount]:
    piece_id_enemy_counts = defaultdict(set)
    piece_id_area_item_counts = defaultdict(set)

    for log in filter(lambda log: log["uri"] == "/dungeon/start", online_logs):
        pos_to_dungeon_piece_id = {
            (piece.get("x", 0), piece.get("y", 0)): piece["dungeonPieceId"]
            for piece in log["res"]["dungeonState"]["dungeonPieces"]
        }

        dungeon_enemies = defaultdict(int)

        for dungeon_enemy in log["res"]["dungeonEnemies"]:
            dungeon_enemies[(dungeon_enemy.get("dungeonPieceX", 0), dungeon_enemy.get("dungeonPieceY", 0))] += 1

        dungeon_area_items = defaultdict(int)

        for dungeon_area_item in log["res"]["dungeonAreaItems"]:
            dungeon_area_items[(dungeon_area_item.get("dungeonPieceX", 0), dungeon_area_item.get("dungeonPieceY", 0))] += 1

        for pos, piece_id in pos_to_dungeon_piece_id.items():
            enemy_count = dungeon_enemies.get(pos, 0)
            area_item_count = dungeon_area_items.get(pos, 0)
            piece_id_enemy_counts[piece_id_to_idx(piece_id)].add(enemy_count)
            piece_id_area_item_counts[piece_id_to_idx(piece_id)].add(area_item_count)

    result = dict()

    for piece_id in sorted(piece_id_enemy_counts.keys()):
        result[piece_id] = DungeonPartObjectCount(
            piece_id, max(piece_id_enemy_counts[piece_id]), max(piece_id_area_item_counts[piece_id])
        )

    return result


if __name__ == "__main__":
    main()