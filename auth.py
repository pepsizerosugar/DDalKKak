import glob
import json
import logging
import os

from selenium import webdriver
from selenium.webdriver.chrome.options import Options
from selenium.webdriver.chrome.service import Service
from selenium.webdriver.common.by import By
from selenium.webdriver.support import expected_conditions as EC
from selenium.webdriver.support.ui import WebDriverWait

logging.basicConfig(
    level=logging.DEBUG,
    format="%(asctime)s [%(levelname)s] %(message)s",
    filename="tasks.log",
    filemode="a",
    encoding="utf-8",
)
logger = logging.getLogger(__name__)


def find_chrome_binary_path() -> str:
    """
    Flatpak으로 설치된 Chrome 실행 파일 경로를 동적으로 검색
    """
    logger.info("Chrome 실행 파일 경로 검색 중...")

    flatpak_path_map = {
        "_": "~/.local/share/flatpak/app/com.google.Chrome/",
        "__": "/var/lib/flatpak/app/com.google.Chrome/",
    }

    for _, path in flatpak_path_map.items():
        flatpak_path = os.path.expanduser(path)
        binary_glob = os.path.join(
            flatpak_path, "x86_64/stable/*/files/extra/chrome"
        )
        binary_path = glob.glob(binary_glob)
        if binary_path:
            logger.info(f"Chrome 실행 파일 경로: {binary_path[0]}")
            return binary_path[0]

    error_msg = "Chrome 실행 파일을 찾을 수 없습니다. Flatpak Chrome이 설치되었는지 확인하세요."
    logger.error(error_msg)
    raise FileNotFoundError(error_msg)


def find_user_data_dir() -> str:
    """
    Flatpak Chrome의 사용자 데이터 디렉터리 경로를 동적으로 검색
    """
    logger.info("Chrome 사용자 데이터 디렉터리 경로 검색 중...")
    user_data_base = os.path.expanduser(
        "~/.var/app/com.google.Chrome/config/google-chrome/"
    )
    if os.path.exists(user_data_base):
        logger.info(f"Chrome 사용자 데이터 디렉터리 경로: {user_data_base}")
        return user_data_base
    error_msg = "사용자 데이터 디렉터리를 찾을 수 없습니다. Flatpak Chrome이 설치되었는지 확인하세요."
    logger.error(error_msg)
    raise FileNotFoundError(error_msg)


def setup_webdriver() -> webdriver.Chrome:
    """
    Selenium WebDriver를 설정하고 반환
    """
    logger.info("Selenium WebDriver 설정 중...")
    chrome_options = Options()
    try:
        chrome_binary_path = find_chrome_binary_path()
        user_data_dir = find_user_data_dir()
    except FileNotFoundError as e:
        logger.error(e)
        exit(1)

    chrome_options.binary_location = chrome_binary_path
    chrome_options.add_argument("--profile-directory=Default")
    chrome_options.add_argument(f"--user-data-dir={user_data_dir}")
    chrome_options.add_argument("--headless")
    chrome_options.add_argument("--no-sandbox")
    chrome_options.add_argument("--disable-dev-shm-usage")
    chrome_options.add_argument("--disable-gpu")

    chromedriver_path = os.getenv(
        "CHROMEDRIVER_PATH", "/home/deck/bin/chromedriver"
    )
    service = Service(chromedriver_path)

    logger.info("WebDriver를 초기화 중...")
    driver = webdriver.Chrome(service=service, options=chrome_options)
    logger.info("WebDriver 초기화 완료.")
    return driver


def handle_error(message, level) -> None:
    """
    에러 메시지 처리 및 로그 기록
    """
    if level == "error":
        logger.error(message)
    elif level == "warning":
        logger.warning(message)
    print(f"ERROR_MESSAGE={message}")


def get_status_message(status) -> str:
    """
    상태 코드에 따른 메시지 반환
    """
    status_messages = {
        "NEED_DAUM_LOGIN": "로그인 필요",
        "NEED_AUTH_CHANGE_IP": "재인증 필요",
    }
    return status_messages.get(status, "알 수 없는 상태")


def perform_api_request(driver: webdriver.Chrome) -> bool:
    """
    API를 통해 access_token, user_id 파싱
    """
    preparation_url = (
        "https://pubsvc.game.daum.net/gamestart/poe2.html?actionType=user"
    )
    api_url = "https://poe2-gamestart-web-api.game.daum.net/token/poe2?actionType=user"

    request_payload = '{"txId":null,"code":null,"webdriver":false}'
    headers = {
        "authority": "poe2-gamestart-web-api.game.daum.net",
        "accept": "application/json",
        "content-type": "application/json; charset=UTF-8",
        "origin": "https://pubsvc.game.daum.net",
        "referer": "https://pubsvc.game.daum.net/",
    }

    try:
        logger.info("사전 작업 페이지에 접속 중...")
        driver.get(preparation_url)

        logger.info("페이지 로드 대기 중...")
        WebDriverWait(driver, 10).until(
            EC.presence_of_element_located((By.TAG_NAME, "body"))
        )

        logger.info("API 호출을 위한 JavaScript 실행 중...")
        response = driver.execute_script(
            f"""
            return fetch("{api_url}", {{
                method: "POST",
                headers: {json.dumps(headers)},
                body: {json.dumps(request_payload)},
                credentials: "include"
            }})
            .then(response => response.json())
            .catch(error => {{ return {{ error: error.message }} }});
            """
        )

        logger.info("API 응답 처리 중...")
        if "error" in response:
            handle_error(
                f"API 호출 중 오류 발생: 데스크톱 모드에서 보안 인증이 필요합니다.",
                "error",
            )
            return False

        status = response.get("status")
        if status != "PASS":
            handle_error(
                f"API 호출 실패: {get_status_message(status)} (status={status})",
                "warning",
            )
            return False

        token, mid = response.get("token"), response.get("mid")
        if not token or not mid:
            handle_error(
                "응답에 token 또는 mid가 포함되지 않았습니다.", "warning"
            )
            return False

        logger.info(f"token: {token}")
        logger.info(f"mid: {mid}")
        print(f"ACCESS_TOKEN={token}")
        print(f"USER_ID={mid}")
        return True

    except Exception as e:
        handle_error(f"API 요청 중 예외 발생: {e}", "error")
        return False


def get_token_and_mid() -> None:
    logger.info("WebDriver 설정 시작...")
    driver = setup_webdriver()
    try:
        logger.info("API 요청 수행 시작...")
        result = perform_api_request(driver)

        if result:
            print("TASK_1=1")
        else:
            print("TASK_1=0")
    finally:
        logger.info("WebDriver 종료 중...")
        driver.quit()
        logger.info("WebDriver 종료 완료.")


if __name__ == "__main__":
    get_token_and_mid()
