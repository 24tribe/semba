from argparse  import ArgumentParser
import gzip
import sys

def main():
    parser = ArgumentParser()
    parser.add_argument("savefile")
    args = parser.parse_args()
    with open(args.savefile, "rb") as f:
        sys.stdout.buffer.write(gzip.decompress(f.read()))

if  __name__ == "__main__":
    main()
