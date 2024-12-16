#!/bin/bash

set -x
set -o pipefail
unset LD_PRELOAD

REPO_OWNER="pepsizerosugar"
REPO_NAME="DDalKKak"
LOG_FILE_PATH="$(dirname "$0")/run.log"

log_message() {
    local level=${1:-'info'}
    local message=${2:-'DDalKKak'}
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $level - $message" >> "$LOG_FILE_PATH"
}

show_message() {
    local level=${1:-'info'}
    local message="$2"
    log_message "$level" "완료 메시지 표시: $message"
    kdialog --msgbox "$message"
}

log_and_show_message() {
    log_message "$1" "$2"
    show_message "$1" "$2"
}

fetch_release_info() {
    log_message "info" "최신 스크립트 버전 가져오는 중..."
    local api_url="https://api.github.com/repos/$REPO_OWNER/$REPO_NAME/releases/latest"
    LATEST_RELEASE_INFO=$(curl -s "$api_url")

    latest_version=$(echo "$LATEST_RELEASE_INFO" | jq -r '.tag_name')
    if [ -z "$latest_version" ] || [ "$latest_version" == "null" ]; then
        error_message="최신 릴리즈 버전을 가져올 수 없습니다."
        log_and_show_message "error" $error_message
        return 1
    fi

    log_message "info" "최신 버전: $latest_version"
}

verify_existing_version() {
    download_dir="DDalKKak_$latest_version"
    if [ -d "$download_dir" ]; then
        log_message "info" "디렉토리 '$download_dir'이 이미 존재합니다. 작업을 건너뜁니다."
        return 0
    else
        return 1
    fi
}

download_tarball() {
    log_message "info" "tarball 다운로드 URL 확인 중..."
    tarball_url=$(echo "$LATEST_RELEASE_INFO" | jq -r '.tarball_url')

    if [ -z "$tarball_url" ] || [ "$tarball_url" == "null" ]; then
        log_message "error" "최신 릴리즈 tarball URL을 가져올 수 없습니다."
        return 1
    fi
    log_message "info" "tarball URL: $tarball_url"

    log_message "info" "다운로드 중..."
    curl -L -H "Accept: application/vnd.github.v3.raw" -o source.tar.gz "$tarball_url"
    if [ $? -ne 0 ]; then
        log_and_show_message "error" "tarball 다운로드 실패."
        return 1
    fi
}

extract_tarball() {
    log_message "info" "압축 파일 형식 확인 중..."
    if ! file source.tar.gz | grep -q "gzip compressed data"; then
        log_and_show_message "error" "다운로드된 파일이 gzip 형식이 아닙니다."
        rm -f source.tar.gz
        return 1
    fi

    log_message "info" "최상위 디렉토리 확인 중..."
    top_level_dir=$(tar -tzf source.tar.gz | head -1 | cut -d "/" -f1)
    if [ -z "$top_level_dir" ]; then
        log_and_show_message "error" "압축 파일에 유효한 최상위 디렉토리가 없습니다."
        rm -f source.tar.gz
        return 1
    fi
    log_message "info" "압축 파일의 최상위 디렉토리: $top_level_dir"

    log_message "info" "압축 해제 중..."
    mkdir -p "$download_dir"
    tar -xzf source.tar.gz -C "$download_dir" --strip-components=1
    if [ $? -ne 0 ]; then
        log_and_show_message "error" "압축 해제 실패. 디렉토리 '$download_dir'을 삭제합니다."
        rm -rf "$download_dir"
        return 1
    fi
    log_message "info" "다운로드 및 압축 해제 완료: $download_dir"
    rm -f source.tar.gz
}

run_script() {
    cd "$download_dir" || exit

    log_message "info" "스크립트 실행 준비 중..."
    if [ ! -x "./tasks.sh" ]; then
        log_and_show_message "error" "tasks.sh 실행 파일이 없거나 실행 권한이 없습니다."
        return 1
    fi

    chmod +x ./tasks.sh
    ./tasks.sh
    if [ $? -ne 0 ]; then
        log_and_show_message "error" "tasks.sh 실행 실패."
        return 1
    fi

    log_message "info" "tasks.sh 실행 완료."
}

while :
do
    log_and_show_message "info" "스크립트 실행 시작"
    fetch_release_info
    if ! verify_existing_version; then
        download_tarball
        extract_tarball
    fi
    run_script
    break
done

