require 'xcodeproj'

# 현재 작업 디렉토리
current_dir = Dir.pwd

# 프로젝트 파일 경로
project_path = File.join(current_dir, 'BobCam-iOS/BobCamAgent/BobCamAgent.xcodeproj')
project = Xcodeproj::Project.open(project_path)

# 대상 그룹 찾기
target_group = project.main_group.find_subpath('BobCamAgent', true)

# 추가할 파일 경로
file_path = File.join(current_dir, 'BobCam-iOS/BobCamAgent/BobCamAgent/MultiModalEatingDetectionService.swift')

# 파일 참조 생성 및 그룹에 추가
file_ref = target_group.new_file(file_path)

# 주 타겟에 파일 추가
main_target = project.targets.find { |target| target.name == 'BobCamAgent' }
main_target.add_file_references([file_ref])

# 변경사항 저장
project.save