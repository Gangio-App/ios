import sys
import os

proj_path = '/Users/admin/Desktop/gangio-ios/Gangio.xcodeproj/project.pbxproj'
with open(proj_path, 'r') as f:
    lines = f.readlines()

new_lines = []
for line in lines:
    # 1. Add to PBXBuildFile
    if '/* UserSheet.swift in Sources */ = {isa = PBXBuildFile;' in line and '17DEADBEEF0002' not in line:
        new_lines.append('\t\t17DEADBEEF0002 /* ReportSheet.swift in Sources */ = {isa = PBXBuildFile; fileRef = 17DEADBEEF0001 /* ReportSheet.swift */; };\n')
    
    # 2. Add to PBXFileReference
    if '/* UserSheet.swift */ = {isa = PBXFileReference;' in line and '17DEADBEEF0001' not in line:
        new_lines.append('\t\t17DEADBEEF0001 /* ReportSheet.swift */ = {isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = ReportSheet.swift; sourceTree = "<group>"; };\n')
    
    # 3. Add to Sheets Group children
    if '17CE2E132AE709CE0059FB3A /* UserSheet.swift */,' in line:
        new_lines.append(line)
        new_lines.append('\t\t\t\t17DEADBEEF0001 /* ReportSheet.swift */,\n')
        continue

    # 4. Add to Sources Build Phase
    if '17CE2E142AE709CE0059FB3A /* UserSheet.swift in Sources */,' in line:
        new_lines.append(line)
        new_lines.append('\t\t\t\t17DEADBEEF0002 /* ReportSheet.swift in Sources */,\n')
        continue
    
    new_lines.append(line)

with open(proj_path, 'w') as f:
    f.writelines(new_lines)
print("Added ReportSheet.swift to project file.")
