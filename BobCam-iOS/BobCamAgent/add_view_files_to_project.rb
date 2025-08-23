#!/usr/bin/env ruby

require 'securerandom'

# Files to add to the project
new_files = [
  'CharacterOverlayView.swift',
  'MiniCameraView.swift',
  'GameStatsView.swift', 
  'ParentControlsView.swift'
]

pbxproj_path = './BobCamAgent.xcodeproj/project.pbxproj'

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

# Find the PBXBuildFile section and add new entries
build_file_section = content[/\/\* Begin PBXBuildFile section \*\/(.*?)\/\* End PBXBuildFile section \*\//m, 1]

new_build_files = new_files.map do |filename|
  build_id = file_data[filename][:build_file_id]
  file_ref_id = file_data[filename][:file_ref_id]
  "\t\t#{build_id} /* #{filename} in Sources */ = {isa = PBXBuildFile; fileRef = #{file_ref_id} /* #{filename} */; };"
end

# Insert the new build files
build_file_insertion_point = content.index('/* End PBXBuildFile section */')
build_file_content = new_build_files.join("\n") + "\n"
content.insert(build_file_insertion_point, build_file_content)

# Find the PBXFileReference section and add new entries
new_file_refs = new_files.map do |filename|
  file_ref_id = file_data[filename][:file_ref_id]
  "\t\t#{file_ref_id} /* #{filename} */ = {isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = #{filename}; sourceTree = \"<group>\"; };"
end

# Insert the new file references
file_ref_insertion_point = content.index('/* End PBXFileReference section */')
file_ref_content = new_file_refs.join("\n") + "\n"
content.insert(file_ref_insertion_point, file_ref_content)

# Find the main app group (BobCamAgent group) and add the files
# Look for the pattern that includes BobCamApp.swift and other main files
app_group_pattern = /(children = \((?:[^)]|\s)*?A10001011B00000000000001 \/\* BobCamApp\.swift \*\/,(?:[^)]|\s)*?)\);/m
if match = content.match(app_group_pattern)
  children_content = match[1]
  
  # Add the new files to the children list
  new_file_children = new_files.map do |filename|
    file_ref_id = file_data[filename][:file_ref_id]
    "\t\t\t\t#{file_ref_id} /* #{filename} */,"
  end
  
  updated_children = children_content + "\n" + new_file_children.join("\n")
  content.gsub!(app_group_pattern, "#{updated_children});")
end

# Find the Sources build phase and add the new build files
sources_pattern = /(\/\* Sources \*\/ = \{\s*isa = PBXSourcesBuildPhase;[^}]*files = \((?:[^)]|\s)*?)\s*\);/m
if match = content.match(sources_pattern)
  sources_content = match[1]
  
  # Add the new build files to the sources
  new_source_files = new_files.map do |filename|
    build_id = file_data[filename][:build_file_id]
    "\t\t\t\t#{build_id} /* #{filename} in Sources */,"
  end
  
  updated_sources = sources_content + "\n" + new_source_files.join("\n")
  content.gsub!(sources_pattern, "#{updated_sources}\n\t\t\t);")
end

# Write the updated content back
File.write(pbxproj_path, content)

puts "Successfully added #{new_files.count} files to the Xcode project:"
new_files.each { |f| puts "  - #{f}" }
puts "File IDs generated:"
file_data.each do |filename, ids|
  puts "  #{filename}: Build=#{ids[:build_file_id]}, Ref=#{ids[:file_ref_id]}"
end