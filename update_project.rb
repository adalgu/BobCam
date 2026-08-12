#!/usr/bin/env ruby
require 'xcodeproj'

project_path = 'BobCamAgent.xcodeproj'
project = Xcodeproj::Project.open(project_path)

target = project.targets.find { |t| t.name == 'BobCamAgent' }

# Find main group
main_group = project.main_group.find_subpath('BobCamAgent', true)

# Create new group structure
def find_or_create_group(parent, name, path)
  existing = parent.children.find { |c| c.is_a?(Xcodeproj::Project::Object::PBXGroup) && c.name == name }
  return existing if existing
  parent.new_group(name, path)
end

app_group = find_or_create_group(main_group, 'App', 'App')
views_group = find_or_create_group(main_group, 'Views', 'Views')
components_group = find_or_create_group(views_group, 'Components', 'Components')
services_group = find_or_create_group(main_group, 'Services', 'Services')
protocols_group = find_or_create_group(services_group, 'Protocols', 'Protocols')
models_group = find_or_create_group(main_group, 'Models', 'Models')
utilities_group = find_or_create_group(main_group, 'Utilities', 'Utilities')

# Define files to add
files = {
  app_group => ['BobCamAgent/App/BobCamAgentApp.swift'],
  views_group => [
    'BobCamAgent/Views/MainView.swift',
    'BobCamAgent/Views/SettingsView.swift',
    'BobCamAgent/Views/StatisticsView.swift',
    'BobCamAgent/Views/VideoSelectionView.swift'
  ],
  components_group => [
    'BobCamAgent/Views/Components/NudgeOverlay.swift',
    'BobCamAgent/Views/Components/ParentControlBar.swift',
    'BobCamAgent/Views/Components/PraiseOverlay.swift',
    'BobCamAgent/Views/Components/TouchBlockingView.swift',
    'BobCamAgent/Views/Components/VideoPlayerView.swift',
    'BobCamAgent/Views/Components/YouTubePlayerView.swift'
  ],
  services_group => [
    'BobCamAgent/Services/CameraService.swift',
    'BobCamAgent/Services/FeedbackService.swift',
    'BobCamAgent/Services/StatisticsService.swift',
    'BobCamAgent/Services/VideoService.swift',
    'BobCamAgent/Services/VisionService.swift'
  ],
  protocols_group => [
    'BobCamAgent/Services/Protocols/CameraServiceProtocol.swift',
    'BobCamAgent/Services/Protocols/FeedbackServiceProtocol.swift',
    'BobCamAgent/Services/Protocols/VideoServiceProtocol.swift',
    'BobCamAgent/Services/Protocols/VisionServiceProtocol.swift'
  ],
  models_group => [
    'BobCamAgent/Models/AppSettings.swift',
    'BobCamAgent/Models/EatingState.swift',
    'BobCamAgent/Models/FeedbackState.swift',
    'BobCamAgent/Models/MealSession.swift'
  ],
  utilities_group => [
    'BobCamAgent/Utilities/Constants.swift'
  ]
}

# Add files to groups and target
files.each do |group, file_paths|
  file_paths.each do |file_path|
    next unless File.exist?(file_path)
    
    file_name = File.basename(file_path)
    
    # Check if file already exists in group
    existing = group.files.find { |f| f.path == file_name }
    if existing
      puts "Skipping existing: #{file_path}"
      next
    end
    
    file_ref = group.new_file(file_path)
    target.source_build_phase.add_file_reference(file_ref)
    puts "Added: #{file_path}"
  end
end

project.save

puts "\nProject updated successfully!"
