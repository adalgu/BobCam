#!/usr/bin/env ruby

require 'xcodeproj'

# 현재 작업 디렉토리
current_dir = Dir.pwd

# 프로젝트 파일 경로
project_path = File.join(current_dir, 'BobCam-iOS/BobCamAgent/BobCamAgent.xcodeproj')
project = Xcodeproj::Project.open(project_path)

# 대상 그룹 찾기 (메인 앱 그룹)
target_group = project.main_group.find_subpath('BobCamAgent', true)

# 추가할 파일 경로
file_path = File.join(current_dir, 'BobCam-iOS/BobCamAgent/BobCamAgent/AppVersionInfo.swift')

# 파일 참조 생성 및 그룹에 추가
file_ref = target_group.new_file(file_path)

# 메인 앱 타겟에 파일 추가
app_target = project.targets.find { |target| target.name == 'BobCamAgent' }
app_target.add_file_references([file_ref])

# 변경사항 저장
project.save

puts "AppVersionInfo.swift added to BobCamAgent target successfully!"