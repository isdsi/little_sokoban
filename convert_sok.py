#!/usr/bin/env python3
# convert_sok.py
import sys
import os
import json

def parse_sok(file_path):
    """
    Parses a .sok file containing Sokoban levels.
    Detects levels by lines starting with double quotes ("), collects map grids,
    and extracts solution string steps under 'Solution/' headers.
    """
    if not os.path.exists(file_path):
        print(f"Error: File not found: {file_path}", file=sys.stderr)
        return []

    with open(file_path, 'r', encoding='utf-8') as f:
        lines = f.readlines()
        
    levels = []
    current_level = None
    state = "SCANNING" # SCANNING, MAP_WAIT, MAP, AFTER_MAP, SOLUTION
    
    for line_num, line in enumerate(lines, 1):
        stripped = line.strip()
        
        # Check for new level start (title in quotes)
        if stripped.startswith('"'):
            if current_level:
                levels.append(current_level)
            current_level = {
                "title": stripped,
                "map": [],
                "solution": ""
            }
            state = "MAP_WAIT"
            continue
            
        if not current_level:
            continue
            
        is_map_chars = set(stripped).issubset(set('#$.@*+ ')) if stripped else False
        is_map_line = is_map_chars and '#' in stripped
        
        if state == "MAP_WAIT":
            if is_map_line:
                state = "MAP"
                current_level["map"].append(line.rstrip('\r\n'))
        elif state == "MAP":
            if is_map_line:
                current_level["map"].append(line.rstrip('\r\n'))
            else:
                state = "AFTER_MAP"
        elif state == "AFTER_MAP":
            if stripped.startswith("Solution/"):
                state = "SOLUTION_WAIT"
        elif state == "SOLUTION_WAIT":
            if not stripped:
                continue
            if stripped.startswith("Best Solution") or stripped.startswith("Solution") or stripped.startswith("Solver"):
                continue
            if set(stripped.lower()).issubset(set('lrud ')):
                state = "SOLUTION"
                current_level["solution"] += stripped.replace(" ", "")
            else:
                state = "AFTER_MAP"
        elif state == "SOLUTION":
            if not stripped:
                state = "AFTER_MAP"
            elif set(stripped.lower()).issubset(set('lrud ')):
                current_level["solution"] += stripped.replace(" ", "")
            else:
                state = "AFTER_MAP"
                
    if current_level:
        levels.append(current_level)
        
    return levels

def main():
    if len(sys.argv) < 2:
        print("Usage: python convert_sok.py <path_to_sok_file>", file=sys.stderr)
        sys.exit(1)
        
    sok_file = sys.argv[1]
    levels = parse_sok(sok_file)
    
    if not levels:
        print("Error: No levels parsed.", file=sys.stderr)
        sys.exit(1)
        
    print(f"Parsed {len(levels)} levels from '{sok_file}'.")
    
    # 1. Load existing solutions to merge
    solutions_path = "levels_data_solution.json"
    old_solutions = {}
    if os.path.exists(solutions_path):
        try:
            with open(solutions_path, 'r', encoding='utf-8') as f:
                old_solutions = json.load(f)
            print(f"Loaded {len(old_solutions)} existing solutions from '{solutions_path}' for merging.")
        except Exception as e:
            print(f"Warning: Could not parse existing '{solutions_path}': {e}", file=sys.stderr)
            
    # 2. Merge solutions and construct the new dictionary
    new_solutions = {}
    for idx, lvl in enumerate(levels):
        key = str(idx)
        # Use new solution if present, otherwise fallback to old solution
        sol = lvl["solution"]
        if not sol and key in old_solutions:
            sol = old_solutions[key]
        new_solutions[key] = sol
        
    # Copy any extra keys from old solutions (e.g. debugging/test levels like "100")
    for key, val in old_solutions.items():
        if key not in new_solutions:
            new_solutions[key] = val
            
    # 3. Write solutions.json
    try:
        with open(solutions_path, 'w', encoding='utf-8') as f:
            json.dump(new_solutions, f, indent=2, sort_keys=True)
        print(f"Updated '{solutions_path}' successfully.")
    except Exception as e:
        print(f"Error writing '{solutions_path}': {e}", file=sys.stderr)
        sys.exit(1)
        
    # 4. Write levels_data.gd
    gd_path = "levels_data.gd"
    try:
        gd_lines = [
            "# levels_data.gd",
            "# Generated automatically from levels_data.sok. Do not edit manually.",
            "class_name LevelsData",
            "",
            "const LEVELS = ["
        ]
        
        for idx, lvl in enumerate(levels):
            gd_lines.append(f"\t# Level {idx + 1}")
            gd_lines.append("\t[")
            for row in lvl["map"]:
                escaped_row = row.replace('"', '\\"')
                gd_lines.append(f'\t\t"{escaped_row}",')
            gd_lines.append("\t],")
            
        gd_lines.append("]")
        gd_lines.append("")
        
        with open(gd_path, 'w', encoding='utf-8') as f:
            f.write('\n'.join(gd_lines))
        print(f"Updated '{gd_path}' successfully.")
    except Exception as e:
        print(f"Error writing '{gd_path}': {e}", file=sys.stderr)
        sys.exit(1)

if __name__ == '__main__':
    main()
