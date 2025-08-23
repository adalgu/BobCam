#!/usr/bin/env ruby

require 'securerandom'

# Phase 1.2 view files to add to the project
new_files = [
  'CharacterOverlayView.swift',
  'MiniCameraView.swift', 
  'GameStatsView.swift',
  'ParentControlsView.swift'
]

pbxproj_path = './BobCamAgent.xcodeproj/project.pbxproj'

puts "Adding Phase 1.2 Character Overlay UI files..."
puts "Files to add: #{new_files.join(', ')}"

# Read the project file
content = File.read(pbxproj_path)

# Generate unique IDs for each file (2 IDs per file: PBXBuildFile and PBXFileReference)
file_data = {}
new_files.each do |filename|
  file_data[filename] = {
    build_file_id: "A1#{SecureRandom.hex(12).upcase}1B00000000000001",
    file_ref_id: "A1#{SecureRandom.hex(12).upcase}1B00000000000001"
  }
end

puts "\nGenerated IDs:"
file_data.each do |filename, ids|
  puts "  #{filename}:"
  puts "    Build: #{ids[:build_file_id]}"
  puts "    Ref:   #{ids[:file_ref_id]}"
end

# Add to PBXBuildFile section
new_build_files = new_files.map do |filename|
  build_id = file_data[filename][:build_file_id]
  file_ref_id = file_data[filename][:file_ref_id]
  "\t\t#{build_id} /* #{filename} in Sources */ = {isa = PBXBuildFile; fileRef = #{file_ref_id} /* #{filename} */; };"
end

# Insert before "/* End PBXBuildFile section */"
build_file_insertion_point = content.index('/* End PBXBuildFile section */')
if build_file_insertion_point
  build_file_content = new_build_files.join("\n") + "\n\t\t"
  content.insert(build_file_insertion_point, build_file_content)
  puts "\n✓ Added to PBXBuildFile section"
else
  puts "\n✗ Could not find PBXBuildFile section"
  exit 1
end

# Add to PBXFileReference section
new_file_refs = new_files.map do |filename|
  file_ref_id = file_data[filename][:file_ref_id]
  "\t\t#{file_ref_id} /* #{filename} */ = {isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = #{filename}; sourceTree = \"<group>\"; };"
end

# Insert before "/* End PBXFileReference section */"
file_ref_insertion_point = content.index('/* End PBXFileReference section */')
if file_ref_insertion_point
  file_ref_content = new_file_refs.join("\n") + "\n\t\t"
  content.insert(file_ref_insertion_point, file_ref_content)
  puts "✓ Added to PBXFileReference section"
else
  puts "✗ Could not find PBXFileReference section"
  exit 1
end

# Find the main BobCamAgent group and add file references
# Looking for the group that contains BobCamApp.swift
group_pattern = /(children = \([^)]*A10001011B00000000000001 \/\* BobCamApp\.swift \*\/[^)]*)\);/m
match = content.match(group_pattern)

if match
  children_content = match[1]
  
  # Add new file references to the children list
  new_file_children = new_files.map do |filename|
    file_ref_id = file_data[filename][:file_ref_id]
    "\t\t\t\t#{file_ref_id} /* #{filename} */,"
  end
  
  # Insert the new files after ContentView.swift
  updated_children = children_content.gsub(
    /(A10001031B00000000000001 \/\* ContentView\.swift \*\/,)/,
    "\\1\n#{new_file_children.join("\n")}"
  )
  
  content.gsub!(group_pattern, "#{updated_children});")
  puts "✓ Added to main BobCamAgent group"
else
  puts "✗ Could not find main BobCamAgent group"
  exit 1
end

# Add to Sources build phase
sources_pattern = /(\/\* Sources \*\/ = \{[^}]*files = \([^)]*)/m
match = content.match(sources_pattern)

if match
  sources_content = match[1]
  
  # Add new build files to sources
  new_source_files = new_files.map do |filename|
    build_id = file_data[filename][:build_file_id]
    "\t\t\t\t#{build_id} /* #{filename} in Sources */,"
  end
  
  # Insert after ContentView.swift in Sources
  updated_sources = sources_content.gsub(
    /(A10001021B00000000000001 \/\* ContentView\.swift in Sources \*\/,)/,
    "\\1\n#{new_source_files.join("\n")}"
  )
  
  content.gsub!(sources_pattern, updated_sources)
  puts "✓ Added to Sources build phase"
else
  puts "✗ Could not find Sources build phase"
  exit 1
end

# Write the updated content back
File.write(pbxproj_path, content)

puts "\n🎉 Successfully added #{new_files.count} Phase 1.2 files to the Xcode project:"
new_files.each { |f| puts "  ✓ #{f}" }

puts "\nNext steps:"
puts "1. Open the project in Xcode to verify files are added"
puts "2. Build and test the character overlay system"
puts "3. Verify all view integrations work correctly"