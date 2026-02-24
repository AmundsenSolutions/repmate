import sys
import re

project_path = "Vext.xcodeproj/project.pbxproj"

with open(project_path, 'r') as f:
    lines = f.readlines()

new_lines = []
in_build_phase = False
seen_files = set()
removed = 0

for line in lines:
    if "/* PBXSourcesBuildPhase */" in line and "ISA = PBXSourcesBuildPhase" not in line and "= {" in line:
        in_build_phase = True
        new_lines.append(line)
        continue
        
    if in_build_phase:
        if "};" in line:
            in_build_phase = False
            new_lines.append(line)
            continue
            
        # We are inside the PBXSourcesBuildPhase files array
        # Look for: 1A2B3C4D /* Filename.swift in Sources */,
        match = re.search(r'/\* (.+?) in Sources \*/', line)
        if match:
            filename = match.group(1)
            if filename in seen_files:
                removed += 1
                continue # Skip this line
            else:
                seen_files.add(filename)
                
    new_lines.append(line)

if removed > 0:
    with open(project_path, 'w') as f:
        f.writelines(new_lines)
    print(f"Removed {removed} duplicates!")
else:
    print("No duplicates found.")
