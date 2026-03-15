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
    block_id_map = {}
    block_id_counter = 0

    for line in lines:
        if line.strip() == '```mermaid':
            in_mermaid = True
            block_id_map = {}
            block_id_counter = 0
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

            # Fix connectors first (before edge label fix)
            line = re.sub(r'==>', '-->', line)
            line = re.sub(r'--\*', '-->', line)
            line = re.sub(r'--o\b', '-->', line)

            # Fix edge label quotes: -->|"text"| becomes -->|text|
            line = re.sub(r'-->\|"([^"]*?)"\|', r'-->|\1|', line)

            # Fix \n in labels (literal backslash-n)
            line = re.sub(r'\\n', ' ', line)

            # Fix > shape syntax: id>"label"] or id>["label"] becomes id["label"]
            line = re.sub(r'(\w+)>"', r'\1["', line)
            line = re.sub(r'(\w+)>\["', r'\1["', line)

            # Fix stadium shape: id(["label"]) becomes id["label"]
            line = re.sub(r'(\w+)\(\["', r'\1["', line)
            line = re.sub(r'"\]\)', '"]', line)

            # Replace long block IDs with unique short IDs
            def _replace_block_id(m):
                nonlocal block_id_counter
                bid = m.group()
                if bid not in block_id_map:
                    block_id_map[bid] = f'N{block_id_counter}'
                    block_id_counter += 1
                return block_id_map[bid]
            line = re.sub(r'block-\d{10,}', _replace_block_id, line)

            # Remove «component» «subsystem» «external» «system» prefixes in labels
            line = re.sub(r'[«»](?:component|subsystem|external|system|actor)[«»]\s*', '', line)

            # Remove style lines (reference stale IDs, break rendering)
            if line.strip().startswith('style '):
                changed = True
                continue

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


def fix_mermaid_source(src):
    """Sanitize raw mermaid source (not a markdown file).
    Applies all line-level fixes without the unclosed-fence detection
    (which is only relevant for journal markdown files).
    """
    id_map = {}
    id_counter = 0
    result = []

    for line in src.split('\n'):
        # Skip style lines and empty markers
        if line.strip().startswith('style ') or line.strip().startswith('Empty diagram'):
            continue

        # Fix connectors
        line = re.sub(r'==>', '-->', line)
        line = re.sub(r'--\*', '-->', line)
        line = re.sub(r'--o\b', '-->', line)

        # Fix edge label quotes
        line = re.sub(r'-->\|"([^"]*?)"\|', r'-->|\1|', line)

        # Fix \n in labels
        line = re.sub(r'\\n', ' ', line)

        # Fix > shape syntax
        line = re.sub(r'(\w+)>"', r'\1["', line)
        line = re.sub(r'(\w+)>\["', r'\1["', line)

        # Fix stadium shape
        line = re.sub(r'(\w+)\(\["', r'\1["', line)
        line = re.sub(r'"\]\)', '"]', line)

        # Replace long block IDs with unique short IDs
        def _replace_id(m):
            nonlocal id_counter
            bid = m.group()
            if bid not in id_map:
                id_map[bid] = f'N{id_counter}'
                id_counter += 1
            return id_map[bid]
        line = re.sub(r'block-\d{10,}', _replace_id, line)

        # Remove stereotype labels
        line = re.sub(r'[«»](?:component|subsystem|external|system|actor)[«»]\s*', '', line)

        result.append(line)

    return '\n'.join(result)


if __name__ == '__main__':
    if len(sys.argv) < 2:
        print("Usage: fix-mermaid.py <file.md> OR fix-mermaid.py --source <mermaid-source>", file=sys.stderr)
        sys.exit(1)

    if sys.argv[1] == '--source':
        src = sys.stdin.read()
        print(fix_mermaid_source(src))
        sys.exit(0)

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
