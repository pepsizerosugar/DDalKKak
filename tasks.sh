#!/bin/bash

set -x
set -o pipefail
unset LD_PRELOAD

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/driver.sh"

LOG_FILE_PATH="$(dirname "$0")/run.log"
CHROMEDRIVER_PATH="$CHROME_INSTALL_DIR/chromedriver"

log_message() {
    local level=${1:-'info'}
    local message=${2:-'DDalKKak'}
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $level - $message" >> "$LOG_FILE_PATH"
}

define_progress_window() {
    log_message "info" "작업 진행창 정의 중"
    echo $(kdialog --progressbar "작업을 준비 중입니다..." 0)
}

update_progress_window() {
    local window_id="$1"
    local message="$2"
    local bus_name
    local object_path

    bus_name=$(echo "$window_id" | awk '{print $1}')
    object_path=$(echo "$window_id" | awk '{print $2}')

    log_message "info" "진행창 업데이트: $message"
    qdbus "$bus_name" "$object_path" setLabelText "$message" || log_message "error" "qdbus 호출 실패: $message"
}

close_progress_window() {
    local window_id="$1"
    local bus_name
    local object_path

    bus_name=$(echo "$window_id" | awk '{print $1}')
    object_path=$(echo "$window_id" | awk '{print $2}')

    log_message "info" "진행창 닫기 시도"
    qdbus "$bus_name" "$object_path" close || log_message "error" "qdbus 창 닫기 실패"
}

check_progress_window_alive() {
    local window_id="$1"
    if [[ -n "$window_id" ]]; then
        local bus_name
        local object_path

        if echo "$window_id" | grep -q ' '; then
            bus_name=$(echo "$window_id" | awk '{print $1}')
            object_path=$(echo "$window_id" | awk '{print $2}')
        else
            log_message "error" "올바르지 않은 window_id 형식: $window_id"
            return 1
        fi

        if [[ -z "$object_path" ]]; then
            log_message "error" "object_path가 비어 있습니다: $window_id"
            return 1
        fi

        if qdbus "$bus_name" "$object_path" >/dev/null 2>&1; then
            return 0
        else
            log_message "error" "진행창 확인 실패: $window_id"
            return 1
        fi
    else
        return 1
    fi
}


show_done_message() {
    local message="$1"
    log_message "info" "완료 메시지 표시: $message"
    kdialog --msgbox "$message"
}

process_error() {
    local window_id="$1"
    local error_message="$2"

    log_message "error" "오류 처리 중: $error_message"

    if check_progress_window_alive "$window_id"; then
        close_progress_window "$window_id"
    fi

    show_done_message "$error_message"
    exit 1
}

install() {
    log_message "info" "설치 프로세스 시작"
    WINDOW_ID=$(define_progress_window)
    log_message "info" "진행창 ID: $WINDOW_ID"

    log_message "info" "ChromeDriver 설치 확인 중..."
    if ! get_installed_chromedriver_version; then
        update_progress_window "$WINDOW_ID" "디렉토리 설정 중..."
        setup_directories || { update_progress_window "$WINDOW_ID" "오류: 디렉토리 설정 실패"; close_progress_window "$WINDOW_ID"; exit 1; }

        update_progress_window "$WINDOW_ID" "Chrome 버전 확인 중..."
        get_chrome_version || { update_progress_window "$WINDOW_ID" "오류: Chrome 버전 확인 실패"; close_progress_window "$WINDOW_ID"; exit 1; }

        update_progress_window "$WINDOW_ID" "Chrome 메이저 버전 확인 중..."
        get_chrome_major_version || { update_progress_window "$WINDOW_ID" "오류: Chrome 메이저 버전 확인 실패"; close_progress_window "$WINDOW_ID"; exit 1; }

        update_progress_window "$WINDOW_ID" "ChromeDriver 버전 정보 가져오는 중..."
        fetch_chromedriver_json || { update_progress_window "$WINDOW_ID" "오류: ChromeDriver JSON 데이터 가져오기 실패"; close_progress_window "$WINDOW_ID"; exit 1; }

        update_progress_window "$WINDOW_ID" "호환되는 ChromeDriver 버전 찾는 중..."
        get_closest_chromedriver_version || { update_progress_window "$WINDOW_ID" "오류: 호환되는 ChromeDriver 버전 찾기 실패"; close_progress_window "$WINDOW_ID"; exit 1; }

        update_progress_window "$WINDOW_ID" "ChromeDriver 다운로드 중..."
        download_chromedriver || { update_progress_window "$WINDOW_ID" "오류: ChromeDriver 다운로드 실패"; close_progress_window "$WINDOW_ID"; exit 1; }

        update_progress_window "$WINDOW_ID" "ChromeDriver 압축 해제 중..."
        extract_chromedriver || { update_progress_window "$WINDOW_ID" "오류: ChromeDriver 압축 해제 실패"; close_progress_window "$WINDOW_ID"; exit 1; }

        update_progress_window "$WINDOW_ID" "ChromeDriver 실행 파일 찾는 중..."
        find_chromedriver || { update_progress_window "$WINDOW_ID" "오류: ChromeDriver 실행 파일 찾기 실패"; close_progress_window "$WINDOW_ID"; exit 1; }

        update_progress_window "$WINDOW_ID" "ChromeDriver 설치 중..."
        install_chromedriver || { update_progress_window "$WINDOW_ID" "오류: ChromeDriver 설치 실패"; close_progress_window "$WINDOW_ID"; exit 1; }

        update_progress_window "$WINDOW_ID" "ChromeDriver 경로를 PATH에 추가 중..."
        add_to_path || { update_progress_window "$WINDOW_ID" "오류: ChromeDriver PATH 추가 실패"; close_progress_window "$WINDOW_ID"; exit 1; }

        update_progress_window "$WINDOW_ID" "ChromeDriver 설치 확인 중..."
        verify_installation || { update_progress_window "$WINDOW_ID" "오류: ChromeDriver 설치 확인 실패"; close_progress_window "$WINDOW_ID"; exit 1; }
    else
        log_message "info" "ChromeDriver가 이미 설치되어 있어, 스크립트 실행으로 넘어갑니다."
    fi

    update_progress_window "$WINDOW_ID" "스크립트 실행 중..."
    task
}

task() {
    log_message "info" "태스크 실행 중: auth.py 실행"
    TASK_RESULT=$("python" auth.py get_token_and_mid 2>&1)
    log_message "info" "auth.py 결과: $TASK_RESULT"

    if ! echo "$TASK_RESULT" | grep -q "TASK_1=1"; then
        ERROR_MESSAGE=$(echo "$TASK_RESULT" | grep "^ERROR_MESSAGE=" | cut -d'=' -f2-)
        process_error "$WINDOW_ID" "$ERROR_MESSAGE"
    fi

    ACCESS_TOKEN=$(echo "$TASK_RESULT" | grep "^ACCESS_TOKEN=" | cut -d'=' -f2-)
    USER_ID=$(echo "$TASK_RESULT" | grep "^USER_ID=" | cut -d'=' -f2-)

    log_message "info" "태스크 실행 중: steam.py 실행"
    TASK_RESULT=$("python" steam.py update_steam_launch_options "$ACCESS_TOKEN" "$USER_ID" 2>&1)
    log_message "info" "steam.py 결과: $TASK_RESULT"

    if ! echo "$TASK_RESULT" | grep -q "TASK_2=1"; then
        ERROR_MESSAGE=$(echo "$TASK_RESULT" | grep "^ERROR_MESSAGE=" | cut -d'=' -f2-)
        process_error "$WINDOW_ID" "$ERROR_MESSAGE"
    fi
}

while :
do
    log_message "info" "스크립트 실행 시작"
    if [ -f "$CHROMEDRIVER_PATH" ]; then
        log_message "info" "ChromeDriver 존재 확인됨, 태스크 실행"
        task
    else
        log_message "info" "ChromeDriver 미존재, 설치 프로세스 시작"
        install
    fi

    EXIT_CODE=$?
    if [ $EXIT_CODE -eq 0 ]; then
        log_message "info" "작업 성공, 시스템 재부팅 준비"
        if check_progress_window_alive "$WINDOW_ID"; then
            close_progress_window "$WINDOW_ID"
        fi
        show_done_message "작업이 완료되었습니다.\n확인을 누르면 재부팅됩니다."
        #reboot
    else
        log_message "error" "작업 실패"
        show_done_message "작업 중 오류가 발생했습니다."
    fi
    break

done