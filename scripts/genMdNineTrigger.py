from argparse import ArgumentParser
import json

from genMasterData import write_rows

def main():
    parser = ArgumentParser()
    parser.add_argument("nine_trigger_json")
    parser.add_argument("out_sql")
    args = parser.parse_args()

    with open(args.nine_trigger_json, "r", encoding="utf-8") as f:
        nine_trigger_json = json.load(f)

    with open(args.out_sql, "w", encoding="utf-8") as f:
        gen_md_nine_trigger(nine_trigger_json, f)

    print("OK")


def gen_md_nine_trigger(nine_trigger_json, f):
    nine_trigger_json = list(filter(lambda x: x["challenge_progress_id"] is not None, nine_trigger_json))

    xprint = lambda *args: print(*args, file=f)

    xprint("INSERT INTO mdNineTrigger (id, challengeProgressId) VALUES")

    write_rows(xprint, f, [
        (nine_trigger["id"], nine_trigger["challenge_progress_id"]) for nine_trigger in nine_trigger_json
    ])

    xprint(";")


if __name__ == "__main__":
    main()