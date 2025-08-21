require 'xcodeproj'

# 프로젝트 파일 경로
project_path = 'BobCam-iOS/BobCamAgent/BobCamAgent.xcodeproj'
project = Xcodeproj::Project.open(project_path)

# 파일을 추가할 메인 타겟
target = project.targets.first

# 파일을 추가할 그룹 (프로젝트의 'BobCamAgent' 그룹)
group = project.groups.find { |g| g.display_name == 'BobCamAgent' } || project.main_group.new_group('BobCamAgent')

# 기존 파일 참조 삭제 (템플릿 파일)
group.files.find { |f| f.path.end_with?('BobCamAgentApp.swift') }&.remove_from_project
group.files.find { |f| f.path.end_with?('ContentView.swift') }&.remove_from_project

# 추가할 파일 및 폴더 목록
files_to_add = Dir.glob("BobCam-iOS/BobCamAgent/BobCamAgent/*.swift")
folders_to_add = ["BobCam-iOS/BobCamAgent/BobCamAgent/Monitoring", "BobCam-iOS/BobCamAgent/BobCamAgent/Utils"]

# 파일 추가
files_to_add.each do |file_path|
  file_name = File.basename(file_path)
  # 이미 존재하는지 확인
  unless group.files.any? { |f| f.path == file_name }
    file_ref = group.new_file(file_path)
    target.add_file_references([file_ref])
  end
end

# 폴더(그룹) 추가
folders_to_add.each do |folder_path|
    folder_name = File.basename(folder_path)
    # 이미 존재하는지 확인
    unless group.find_subpath(folder_name)
        folder_group = group.new_group(folder_name, folder_path)
        
        # 폴더 내의 swift 파일들을 찾아서 프로젝트와 타겟에 추가
        swift_files_in_folder = Dir.glob("#{folder_path}/**/*.swift")
        swift_files_in_folder.each do |swift_file|
            file_ref = folder_group.new_file(swift_file)
            target.add_file_references([file_ref])
        end
    end
end

# Info.plist 추가
info_plist_path = "BobCam-iOS/BobCamAgent/BobCamAgent/Info.plist"
unless group.files.any? { |f| f.path == 'Info.plist' }
    file_ref = group.new_file(info_plist_path)
    # Info.plist는 빌드 타겟에 직접 추가하지 않고, 빌드 설정에서 경로를 지정합니다.
    # 여기서는 파일 참조만 추가합니다.
end


project.save
puts "Xcode project updated successfully."
