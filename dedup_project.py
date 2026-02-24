from pbxproj import XcodeProject

project_path = "Vext.xcodeproj/project.pbxproj"
project = XcodeProject.load(project_path)

# Vext target properties - Use get_target_by_name
target = project.get_target_by_name("Vext")
if not target:
    print("Vext target not found.")
    exit(1)

# Find PBXSourcesBuildPhase
build_phases = project.get_build_phases_by_name("PBXSourcesBuildPhase")
if not build_phases:
    print("No PBXSourcesBuildPhase found.")
    exit(1)

vext_build_phase = None
for phase in build_phases:
    if phase.get_id() in target.buildPhases:
        vext_build_phase = phase
        break

if not vext_build_phase:
    print("No sources build phase attached to Vext target")
    exit(1)

# De-duplicate files in build phase
seen_paths = set()
files_to_remove = []

# List all objects to find PBXBuildFile
for build_file_id in list(vext_build_phase.files):
    if build_file_id not in project.objects:
        continue
        
    build_file = project.objects[build_file_id]
    
    if not hasattr(build_file, 'fileRef'):
        continue
        
    file_ref_id = build_file.fileRef
    
    if file_ref_id not in project.objects:
        continue
        
    file_ref = project.objects[file_ref_id]
    
    if not hasattr(file_ref, 'path'):
        continue
        
    path = file_ref.path
    
    if path in seen_paths:
        files_to_remove.append(build_file_id)
    else:
        seen_paths.add(path)

removed = 0
for duplicate_id in files_to_remove:
    # Use the pbxproj API to remove from build phase
    project.remove_build_file(duplicate_id)
    removed += 1

if removed > 0:
    project.save()
    print(f"Removed {removed} duplicate build files.")
else:
    print("No duplicates found.")
