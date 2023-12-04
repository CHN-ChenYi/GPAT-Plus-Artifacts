#!/usr/bin/env python3
# Remove body of kernel from a polybench .c file and transform it into a function declaration

import argparse
from pathlib import Path
import sys

if __name__ == "__main__":

    parser = argparse.ArgumentParser()
    parser.add_argument("filename")
    args = parser.parse_args()

    filename = Path(args.filename)
    if not filename.exists() or not filename.is_file():
        print("Filename is not a file of does not exist", file=sys.stderr)
        sys.exit(1)
    else:
        filename = filename.absolute()

    kernel_found = False
    first_bracket_line = -1
    first_bracket_found = False
    last_bracket_line = -1
    last_bracket_found = False
    bracket_count = 0

    with open(filename, 'r') as f:
        lines = f.readlines()

    # find kernel and first bracket
    for line_number, line in enumerate(lines):
        if "void kernel_" in line:
            kernel_found = True

        if kernel_found and "{" in line:
            first_bracket_line = line_number
            first_bracket_found = True
            bracket_count = 1
            break

    # enclosing bracket
    for line_number, line in enumerate(lines[first_bracket_line+1:], start=first_bracket_line+1):
        if first_bracket_found and line_number > first_bracket_line:
            bracket_count += line.count('{')
            bracket_count -= line.count('}')
            if bracket_count == 0:
                last_bracket_line = line_number
                break

    # rewrite file without kernel body
    with open(filename, 'w') as f:
        for line_number, line in enumerate(lines):

            # if first bracket is in a new line
            if line_number == first_bracket_line-1:
                if ')' not in lines[first_bracket_line]:
                    f.write(line[:-1]+';'+line[-1])
                    continue

            # if brack is at the end of the line, e.g. 'arg4, arg5) {'
            if line_number == first_bracket_line:
                if ')' in lines[first_bracket_line]:
                    f.write(line.replace('{', ';'))
                    continue
            
            if not first_bracket_line <= line_number <= last_bracket_line:
                f.write(line)