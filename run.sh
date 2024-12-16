#!/bin/bash

REPO_OWNER="pepsizerosugar"
REPO_NAME="DDalKKak"

LOG_FILE_PATH="$(dirname "$0")/run.log"

log_message() {
    local level=${1:-'info'}
    local message=${2:-'DDalKKak'}
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $level - $message" >> "$LOG_FILE_PATH"
}

get_latest_release_info() {
    LATEST_RELEASE_API="https://api.github.com/repos/$REPO_OWNER/$REPO_NAME/releases/latest"
    LATEST_RELEASE_INFO=$(curl -s $LATEST_RELEASE_API)

    latest_version=$(echo $LATEST_RELEASE_INFO | grep '"tag_name"' | cut -d '"' -f 4)
    if [ -z "$latest_version" ]; then
      log_message "error" "최신 릴리즈 버전을 가져올 수 없습니다."
      exit 1
    fi

    log_message "info" "최신 버전: $latest_version"
}

check_existing_version() {
    download_dir="DDalKKak_$latest_version"

    if [ -d "$download_dir" ]; then
      log_message "info" "디렉토리 '$download_dir'이 이미 존재합니다. 작업을 건너뜁니다."
      exit 0
    fi
}

download_and_extract() {
    tarball_url=$(echo $LATEST_RELEASE_INFO | grep "tarball_url" | cut -d '"' -f 4)
    if [ -z "$tarball_url" ]; then
      log_message "error" "최신 릴리즈 tarball URL을 가져올 수 없습니다."
      exit 1
    fi

    log_message "info" "최신 릴리즈 tarball URL: $tarball_url"

    log_message "info" "다운로드 중..."
    curl -L -o source.tar.gz $tarball_url

    if [ $? -ne 0 ]; then
      log_message "error" "tarball 다운로드 실패."
      exit 1
    fi

    log_message "info" "압축 해제 중..."
    mkdir -p "$download_dir"

    tar -xzf source.tar.gz -C "$download_dir" --strip-components=1

    if [ $? -ne 0 ]; then
      log_message "error" "tarball 압축 해제 실패. 디렉토리 '$download_dir'을 삭제합니다."
      rm -rf "$download_dir"
      exit 1
    fi
}

execute_run_script() {
    cd "$download_dir"

    log_message "info" "스크립트 실행 준비 중..."
    if [ ! -x "./run.sh" ]; then
      log_message "error" "run.sh 실행 파일이 없거나 실행 권한이 없습니다."
      exit 1
    fi

    chmod +x ./run.sh
    ./run.sh

    if [ $? -ne 0 ]; then
      log_message "error" "run.sh 실행 실패."
      exit 1
    fi

    log_message "info" "run.sh 실행 완료."
}

main() {
    get_latest_release_info
    check_existing_version
    download_and_extract
    execute_run_script
}

main
