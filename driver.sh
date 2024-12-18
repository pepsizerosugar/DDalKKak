#!/bin/bash

LOG_FILE_PATH="$(dirname "$0")/driver.log"
CHROME_INSTALL_DIR="${CHROME_INSTALL_DIR:-"$HOME/bin"}"
CHROME_TEMP_DIR="${CHROME_TEMP_DIR:-"/tmp/driver_install"}"

log_message() {
    local level=${1:-'info'}
    local message=${2:-'DDalKKak'}
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $level - $message" >> "$LOG_FILE_PATH"
}

command_exists() {
    command -v "$1" >/dev/null 2>&1
}

error_exit() {
    log_message "error" "$1"
    return 1
}

get_installed_chromedriver_version() {
    local chromedriver_path="$CHROME_INSTALL_DIR/chromedriver"

    if [ -f "$chromedriver_path" ]; then
        INSTALLED_VERSION=$("$chromedriver_path" --version 2>/dev/null | grep -Eo '[0-9]+\.[0-9]+\.[0-9]+')
        if [ -n "$INSTALLED_VERSION" ]; then
            log_message "info" "현재 설치된 ChromeDriver 버전: $INSTALLED_VERSION"
            echo "$INSTALLED_VERSION"
            return 0
        else
            log_message "error" "설치된 ChromeDriver 버전을 확인할 수 없습니다."
            return 1
        fi
    else
        log_message "info" "ChromeDriver가 설치되어 있지 않습니다."
        return 1
    fi
}

setup_directories() {
    log_message "info" "디렉토리 생성 중: $CHROME_INSTALL_DIR 및 $CHROME_TEMP_DIR"
    mkdir -p "$CHROME_INSTALL_DIR" || error_exit "디렉토리 생성 실패: $CHROME_INSTALL_DIR"
    mkdir -p "$CHROME_TEMP_DIR" || error_exit "디렉토리 생성 실패: $CHROME_TEMP_DIR"
}

get_chrome_version() {
    log_message "info" "Google Chrome 버전 확인 중..."
    if ! command_exists flatpak; then
        error_exit "Flatpak이 설치되어 있지 않습니다."
    fi

    CHROME_VERSION=$(flatpak run com.google.Chrome --version 2>/dev/null | grep -Eo '[0-9]+\.[0-9]+\.[0-9]+')
    if [ -z "$CHROME_VERSION" ]; then
        error_exit "Flatpak Google Chrome 버전을 확인할 수 없습니다."
    fi
    log_message "info" "감지된 Google Chrome 버전: $CHROME_VERSION"
}

get_chrome_major_version() {
    log_message "info" "Google Chrome 메이저 버전 확인 중..."
    CHROME_MAJOR_VERSION=$(echo "$CHROME_VERSION" | cut -d. -f1)
    log_message "info" "Google Chrome 메이저 버전: $CHROME_MAJOR_VERSION"
}

fetch_chromedriver_json() {
    log_message "info" "ChromeDriver 버전 정보 가져오는 중..."

    CHROMEDRIVER_URL_HTTP="http://googlechromelabs.github.io/chrome-for-testing/known-good-versions-with-downloads.json"
    CHROMEDRIVER_JSON=$(curl -sSL "$CHROMEDRIVER_URL_HTTP")

    if [ -z "$CHROMEDRIVER_JSON" ]; then
        log_message "warning" "HTTP 요청 실패. HTTPS로 인증서 검사를 비활성화하고 재시도합니다."

        CHROMEDRIVER_URL_HTTPS="https://googlechromelabs.github.io/chrome-for-testing/known-good-versions-with-downloads.json"
        CHROMEDRIVER_JSON=$(curl -sSL -k "$CHROMEDRIVER_URL_HTTPS")

        if [ -z "$CHROMEDRIVER_JSON" ]; then
            error_exit "HTTPS 요청도 실패했습니다. ChromeDriver JSON 데이터를 가져올 수 없습니다."
        fi
    fi

    log_message "info" "ChromeDriver JSON 데이터 가져오기 성공."
}

get_closest_chromedriver_version() {
    log_message "info" "호환되는 ChromeDriver 버전 찾는 중..."
    CLOSEST_VERSION=$(echo "$CHROMEDRIVER_JSON" | jq -r ".versions[] | select(.version | startswith(\"$CHROME_MAJOR_VERSION.\")) | .version" | sort -rV | head -1)
    if [ -z "$CLOSEST_VERSION" ]; then
        error_exit "ChromeDriver와 호환되는 버전을 찾을 수 없습니다."
    fi
    log_message "info" "가장 가까운 호환 ChromeDriver 버전: $CLOSEST_VERSION"

    CHROMEDRIVER_DOWNLOAD_URL=$(echo "$CHROMEDRIVER_JSON" | jq -r ".versions[] | select(.version==\"$CLOSEST_VERSION\") | .downloads.chromedriver[] | select(.platform==\"linux64\") | .url")
    if [ -z "$CHROMEDRIVER_DOWNLOAD_URL" ]; then
        error_exit "ChromeDriver 다운로드 URL을 찾을 수 없습니다."
    fi
}

download_chromedriver() {
    log_message "info" "ChromeDriver를 다운로드 중: $CHROMEDRIVER_DOWNLOAD_URL"
    curl -sSL "$CHROMEDRIVER_DOWNLOAD_URL" -o "$CHROME_TEMP_DIR/chromedriver-linux64.zip"
    if [ ! -f "$CHROME_TEMP_DIR/chromedriver-linux64.zip" ]; then
        error_exit "ChromeDriver를 다운로드하지 못했습니다."
    fi
}

extract_chromedriver() {
    log_message "info" "ChromeDriver 압축 해제 중..."
    unzip -qo "$CHROME_TEMP_DIR/chromedriver-linux64.zip" -d "$CHROME_TEMP_DIR" || error_exit "ChromeDriver 압축 해제 실패."
}

find_chromedriver() {
    log_message "info" "ChromeDriver 실행 파일 찾는 중..."
    CHROMEDRIVER_PATH=$(find "$CHROME_TEMP_DIR" -name "chromedriver" | head -1)
    if [ -z "$CHROMEDRIVER_PATH" ]; then
        error_exit "ChromeDriver 실행 파일을 찾을 수 없습니다."
    fi
}

install_chromedriver() {
    log_message "info" "ChromeDriver를 $CHROME_INSTALL_DIR에 설치 중..."
    mv "$CHROMEDRIVER_PATH" "$CHROME_INSTALL_DIR/" || error_exit "ChromeDriver 이동 실패."
    chmod +x "$CHROME_INSTALL_DIR/chromedriver" || error_exit "ChromeDriver 실행 권한 설정 실패."
}

add_to_path() {
    log_message "info" "ChromeDriver 경로를 PATH에 추가 중..."
    if ! echo "$PATH" | grep -q "$CHROME_INSTALL_DIR"; then
        log_message "info" "$CHROME_INSTALL_DIR 경로를 PATH에 추가합니다."
        echo 'export PATH=$HOME/bin:$PATH' >> "$HOME/.bashrc"
        export PATH="$CHROME_INSTALL_DIR:$PATH"
    else
        log_message "info" "ChromeDriver 경로가 이미 PATH에 포함되어 있습니다."
    fi
}

verify_installation() {
    log_message "info" "ChromeDriver 설치 확인 중..."
    "$CHROME_INSTALL_DIR/chromedriver" --version || error_exit "ChromeDriver 버전 확인 실패."
}

install_chromedriver_module() {
    setup_directories || return 1
    get_chrome_version || return 1
    get_chrome_major_version || return 1
    fetch_chromedriver_json || return 1
    get_closest_chromedriver_version || return 1
    download_chromedriver || return 1
    extract_chromedriver || return 1
    find_chromedriver || return 1
    install_chromedriver || return 1
    add_to_path || return 1
    verify_installation || return 1

    log_message "info" "ChromeDriver 설치가 성공적으로 완료되었습니다."
    return 0
}
