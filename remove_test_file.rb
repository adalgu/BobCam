
require 'xcodeproj'

# 현재 작업 디렉토리
current_dir = Dir.pwd

# 프로젝트 파일 경로
project_path = File.join(current_dir, 'BobCam-iOS/BobCamAgent/BobCamAgent.xcodeproj')
project = Xcodeproj::Project.open(project_path)

# 제거할 파일 경로
file_path = File.join(current_dir, 'BobCam-iOS/BobCamAgent/BobCamAgentTests/MultiModalEatingDetectionServiceTests.swift')

# 파일 참조 찾기
file_ref = project.files.find { |f| f.real_path.to_s == file_path }

if file_ref
  # 테스트 타겟에서 파일 참조 제거
  test_target = project.targets.find { |target| target.name == 'BobCamAgentTests' }
  test_target.source_build_phase.remove_file_reference(file_ref)

  # 그룹에서 파일 참조 제거
  file_ref.remove_from_project

  # 변경사항 저장
  project.save
  puts "Successfully removed #{file_path} from the project."
else
  puts "File not found in project: #{file_path}"
end
