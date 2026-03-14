#!/usr/bin/env python3
"""Fix common Mermaid syntax issues in journal markdown files.

Run on a markdown file to:
1. Close unclosed mermaid code fences (detect headings/prose inside blocks)
2. Remove quotes from edge labels: -->|"text"| becomes -->|text|
3. Remove \n from node labels (literal backslash-n)
4. Replace invalid connectors: --*, --o, ==> become -->
5. Remove > shape syntax for nodes
6. Replace long AIRGen block IDs with short IDs
"""

import re
import sys


def fix_mermaid(text):
    lines = text.split('\n')
    result = []
    in_mermaid = False
    changed = False

    for line in lines:
        if line.strip() == '```mermaid':
            in_mermaid = True
            result.append(line)
            continue

        if in_mermaid:
            # Detect unclosed fence: heading or prose paragraph inside mermaid block
            if re.match(r'^##\s', line) or (
                len(line) > 60 and not line.strip().startswith(('  ', '\t', '#', '%'))
                and '-->' not in line and '==>' not in line
                and not re.match(r'^\s*\w+[\[\(]', line)
                and not re.match(r'^\s*$', line)
                and line.strip() != '```'
            ):
                # Insert closing fence before this line
                result.append('```')
                result.append('')
                in_mermaid = False
                changed = True
                result.append(line)
                continue

            if line.strip() == '```':
                in_mermaid = False
                result.append(line)
                continue

            original = line

            # Fix edge label quotes: -->|"text"| becomes -->|text|
            line = re.sub(r'-->\|"([^"]*?)"\|', r'-->|\1|', line)

            # Fix ==> to -->
            line = re.sub(r'==>', '-->', line)

            # Fix --* and --o to -->
            line = re.sub(r'--\*', '-->', line)
            line = re.sub(r'--o\b', '-->', line)

            # Fix \n in labels (literal backslash-n)
            line = re.sub(r'\\n', ' ', line)

            # Fix > shape syntax: id>"label"] becomes id["label"]
            line = re.sub(r'(\w+)>\["', r'\1["', line)

            # Replace long block IDs (block-1773507844558) with short IDs
            line = re.sub(r'block-\d{13}', lambda m: 'B' + m.group()[6:9], line)

            # Remove «component» «subsystem» «external» «system» prefixes in labels
            line = re.sub(r'[«»](?:component|subsystem|external|system|actor)[«»]\s*', '', line)

            if line != original:
                changed = True

            result.append(line)
        else:
            result.append(line)

    # If still in mermaid at end of file, close it
    if in_mermaid:
        result.append('```')
        changed = True

    return '\n'.join(result), changed


if __name__ == '__main__':
    if len(sys.argv) < 2:
        print("Usage: fix-mermaid.py <file.md>", file=sys.stderr)
        sys.exit(1)

    filepath = sys.argv[1]
    with open(filepath) as f:
        text = f.read()

    fixed, changed = fix_mermaid(text)

    if changed:
        with open(filepath, 'w') as f:
            f.write(fixed)
        print(f"Fixed mermaid in {filepath}", file=sys.stderr)
    else:
        print(f"No mermaid fixes needed in {filepath}", file=sys.stderr)
