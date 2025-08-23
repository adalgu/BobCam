#!/usr/bin/env python3
import re
import random

# Files to add
files = [
    'CharacterOverlayView.swift',
    'MiniCameraView.swift', 
    'GameStatsView.swift',
    'ParentControlsView.swift'
]

# Read the project file
with open('BobCamAgent.xcodeproj/project.pbxproj', 'r') as f:
    content = f.read()

# Generate unique IDs
def generate_id():
    return f"A1{random.randint(10000000000000, 99999999999999):014X}1B00000000000001"

file_data = {}
for filename in files:
    file_data[filename] = {
        'build_file_id': generate_id(),
        'file_ref_id': generate_id()
    }

# Add to PBXBuildFile section
build_file_entries = []
for filename in files:
    build_id = file_data[filename]['build_file_id']
    file_ref_id = file_data[filename]['file_ref_id']
    entry = f"\t\t{build_id} /* {filename} in Sources */ = {{isa = PBXBuildFile; fileRef = {file_ref_id} /* {filename} */; }};"
    build_file_entries.append(entry)

# Add entries before "/* End PBXBuildFile section */"
build_file_section_end = content.find('/* End PBXBuildFile section */')
if build_file_section_end != -1:
    content = content[:build_file_section_end] + '\n'.join(build_file_entries) + '\n\t\t' + content[build_file_section_end:]

# Add to PBXFileReference section  
file_ref_entries = []
for filename in files:
    file_ref_id = file_data[filename]['file_ref_id']
    entry = f"\t\t{file_ref_id} /* {filename} */ = {{isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = {filename}; sourceTree = \"<group>\"; }};"
    file_ref_entries.append(entry)

# Add entries before "/* End PBXFileReference section */"
file_ref_section_end = content.find('/* End PBXFileReference section */')
if file_ref_section_end != -1:
    content = content[:file_ref_section_end] + '\n'.join(file_ref_entries) + '\n\t\t' + content[file_ref_section_end:]

# Find the main BobCamAgent group and add file references
# Look for the pattern that includes "BobCamApp.swift"
group_pattern = r'(children = \([^)]*A10001011B00000000000001 /\* BobCamApp\.swift \*/[^)]*)\);'
match = re.search(group_pattern, content, re.DOTALL)
if match:
    children_content = match.group(1)
    new_children = []
    for filename in files:
        file_ref_id = file_data[filename]['file_ref_id']
        new_children.append(f"\t\t\t\t{file_ref_id} /* {filename} */,")
    
    updated_children = children_content + ',\n' + '\n'.join(new_children)
    content = content.replace(match.group(1) + ');', updated_children + '\n\t\t\t);')

# Add to Sources build phase
sources_pattern = r'(/\* Sources \*/ = {[^}]*files = \([^)]*)'
match = re.search(sources_pattern, content, re.DOTALL)
if match:
    sources_content = match.group(1)
    new_sources = []
    for filename in files:
        build_id = file_data[filename]['build_file_id']
        new_sources.append(f"\t\t\t\t{build_id} /* {filename} in Sources */,")
    
    updated_sources = sources_content + ',\n' + '\n'.join(new_sources)
    content = content.replace(match.group(1), updated_sources)

# Write back the file
with open('BobCamAgent.xcodeproj/project.pbxproj', 'w') as f:
    f.write(content)

print(f"Successfully added {len(files)} files to the project:")
for filename in files:
    print(f"  - {filename}")