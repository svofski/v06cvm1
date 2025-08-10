#!/usr/bin/env python3

import json
import sys
from pathlib import Path

def update_labels(json_path, sym_path, output_path):
    # Read vm1.sym and parse label-address pairs
    labels = {}
    with open(sym_path, "r") as sym_file:
        for line in sym_file:
            line = line.strip()
            if not line:
                continue
            parts = line.split()
            if len(parts) != 2:
                continue
            label, addr_hex = parts
            labels[label] = f"0x{addr_hex.lower()}"
    
    # Load vm1.json
    with open(json_path, "r") as json_file:
        data = json.load(json_file)
    
    # Replace "labels"
    data["labels"] = labels
    
    # Save updated JSON
    with open(output_path, "w") as out_file:
        json.dump(data, out_file, indent=4)

if __name__ == "__main__":
    # Change these paths as needed
    #update_labels("vm1.json", "vm1.sym", "vm1_updated.json")
    if len(sys.argv) < 2:
        print("Usage: import_sym.py <program.sym> [<program.json>]", file=sys.stderr)
        sys.exit(1)

    symfile = sys.argv[1]
    print("Input file: ", symfile, file=sys.stderr)

    try:
        jsonfile = sys.argv[2]
    except:
        jsonfile = Path(symfile).with_suffix(".json")

    if not Path(jsonfile).exists():
        print(f"Creating new file {jsonfile}", file=sys.stderr)
        with open(jsonfile, "w") as ryba:
            print("{}", file=ryba)

    print("JSON file: ", jsonfile, file=sys.stderr)

    update_labels(jsonfile, symfile, jsonfile)
