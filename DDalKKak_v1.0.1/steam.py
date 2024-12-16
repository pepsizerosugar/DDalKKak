import logging
import os
import subprocess
import sys
import time
from typing import Optional, Dict

import psutil
import vdf

logging.basicConfig(
    level=logging.DEBUG,
    format="%(asctime)s [%(levelname)s] %(name)s: %(message)s",
    filename="tasks.log",
    filemode="a",
    encoding="utf-8",
)
logger = logging.getLogger(__name__)


def get_steam_user_personas(
    steam_userdata_path: str = "~/.steam/steam/userdata",
) -> Dict[str, str]:
    """
    모든 Steam 유저의 PersonaName을 반환
    """
    steam_userdata_path = os.path.expanduser(steam_userdata_path)
    if not os.path.exists(steam_userdata_path):
        logger.error(
            f"Steam userdata 디렉토리를 찾을 수 없습니다: {steam_userdata_path}"
        )
        raise FileNotFoundError(
            f"Steam userdata 파일을 찾지 못했습니다.: {steam_userdata_path}"
        )

    user_personas = {}

    for user_id in os.listdir(steam_userdata_path):
        user_dir = os.path.join(steam_userdata_path, user_id)
        if os.path.isdir(user_dir) and user_id.isdigit():
            localconfig_path = os.path.join(
                user_dir, "config", "localconfig.vdf"
            )
            if os.path.exists(localconfig_path):
                try:
                    with open(localconfig_path, "r", encoding="utf-8") as file:
                        localconfig = vdf.load(file)
                        persona_name = (
                            localconfig.get("UserLocalConfigStore", {})
                            .get("friends")
                            .get("PersonaName")
                        )
                        if persona_name:
                            user_personas[user_id] = persona_name
                            logger.info(f"{user_id}: {persona_name} 발견")
                        else:
                            logger.warning(f"{user_id} 미발견")
                except Exception as e:
                    logger.error(
                        f"{user_id}에 해당하는 localconfig.vdf를 찾지 못했습니다 : {e}"
                    )

    return user_personas


def get_shortcuts_vdf_path(user_id: str) -> str:
    """
    Steam shortcuts.vdf 파일 경로 반환
    """
    base_path = os.path.expanduser("~/.steam/steam/userdata")
    path = f"{base_path}/{user_id}/config/shortcuts.vdf"
    (f"shortcuts.vdf 경로: {path}")
    return path


def find_file_path(file_name: str, search_path: str = "/") -> Optional[str]:
    """
    지정된 파일을 시스템에서 검색하여 경로를 반환
    """
    try:
        logger.info(f"{search_path} 하위에서 {file_name}을 찾습니다...")
        for root, dirs, files in os.walk(search_path):
            dirs[:] = [
                d
                for d in dirs
                if not os.path.join(root, d).startswith(
                    os.path.expanduser("~/.local/share/Trash")
                )
            ]
            if file_name in files:
                logger.info(f"파일 찾음: {os.path.join(root, file_name)}")
                return os.path.join(root, file_name)
    except Exception as e:
        logger.error(f"서칭하는데 에러가 발생했습니다 {file_name}: {e}")
    return None


def update_shortcuts(
    file_path: str = None,
    game_name: str = "Path of Exile 2",
    launch_options: str = None,
    use_proton: bool = True,
    proton_version: str = "proton_experimental",
) -> bool:
    """
    shortcuts.vdf에서 특정 게임의 Launch Options 업데이트
    """
    logger.info(
        f"shortcuts.vdf 업데이트 시작: 파일경로={file_path}, 게임명={game_name}, 옵션={launch_options}"
    )

    if not file_path or not os.path.exists(file_path):
        logger.error(f"유효하지 않은 파일 경로: {file_path}")
        return False

    try:
        with open(file_path, "rb") as file:
            shortcuts = vdf.binary_load(file)
        ("shortcuts.vdf 로딩 성공.")
    except Exception as e:
        logger.exception("shortcuts.vdf 로딩 중 오류 발생", exc_info=e)
        return False

    updated = False
    try:
        for key, game in shortcuts.get("shortcuts", {}).items():
            if game.get(
                "appname"
            ) == game_name or "PathOfExile_x64_KG.exe" in (
                game.get("exe", "") + game.get("StartDir", "")
            ):
                (f"key: {key}, game: {game}")
                (
                    f"{game_name} 또는 PathOfExile_x64_KG.exe를 포함한 게임 찾음. Launch Options 및 Proton 설정 업데이트."
                )
                game["LaunchOptions"] = launch_options or ""
                if use_proton:
                    game["compat_tool"] = proton_version
                updated = True
                break

        if not updated:
            logger.warning(
                f"{game_name} 또는 관련 exe를 포함한 게임을 찾을 수 없음."
            )
            logger.info(
                f"{game_name}게임을 등록하기 위해 실행 파일 검색 시작."
            )
            exe_path = find_file_path(
                "PathOfExile_x64_KG.exe", search_path="/home/deck"
            )
            if not exe_path:
                logger.error("PathOfExile_x64_KG.exe 파일을 찾을 수 없습니다.")
                return False

            logger.info(
                f"PathOfExile_x64_KG.exe 파일 위치를 찾아 등록을 추가합니다."
            )

            new_game = {
                "appid": -1171664189,
                "appname": "Path of Exile 2",
                "exe": f'"{exe_path}"',
                "StartDir": os.path.dirname(exe_path),
                "icon": "",
                "ShortcutPath": "",
                "LaunchOptions": launch_options or "",
                "compat_tool": proton_version if use_proton else "",
                "IsHidden": 0,
                "AllowDesktopConfig": 1,
                "AllowOverlay": 1,
                "OpenVR": 0,
                "Devkit": 0,
                "DevkitGameID": "",
                "DevkitOverrideAppID": 0,
                "LastPlayTime": 0,
                "FlatpakAppID": "",
                "tags": {},
            }
            shortcuts["shortcuts"][str(len(shortcuts["shortcuts"]))] = new_game
            logger.info("임시 게임 추가 성공.")

        with open(file_path, "wb") as file:
            vdf.binary_dump(shortcuts, file)
        logger.info("shortcuts.vdf 업데이트 성공.")
        return True
    except Exception as e:
        logger.exception("shortcuts.vdf 업데이트 중 오류 발생", exc_info=e)
        return False


def is_process_running(process_name: str) -> bool:
    """
    특정 프로세스가 실행 중인지 확인
    """
    for process in psutil.process_iter(attrs=["name"]):
        if process.info["name"] == process_name:
            return True
    return False


def kill_steam_and_restart_background() -> bool:
    """
    현재 실행 중인 Steam 프로세스를 종료 후 재시작
    """
    try:
        subprocess.run(["killall", "steam"], check=False)
    except subprocess.CalledProcessError as e:
        logger.exception(
            "Steam 프로세스를 종료하는 도중 오류 발생", exc_info=e
        )
    else:
        try:
            for _ in range(30):
                if not is_process_running("steam"):
                    ("Steam 프로세스가 정상적으로 종료되었습니다.")
                    break
                time.sleep(1)
            else:
                logger.error("Steam 종료 확인에 실패했습니다.")
                return False

            ("Steam 프로세스를 백그라운드에서 재실행합니다...")
            subprocess.run("steam &", shell=True, check=False)

            for _ in range(30):
                if is_process_running("steam"):
                    ("Steam이 정상적으로 재시작되었습니다.")
                    break
                time.sleep(1)
            else:
                logger.error("Steam 재시작 확인에 실패했습니다.")
                return False
            return True
        except Exception as e:
            logger.exception("Steam 재시작 도중 오류 발생", exc_info=e)
            return False


def update_steam_launch_options() -> None:
    """
    Steam shortcuts.vdf 파일 업데이트
    """
    logger.info("Steam shortcuts.vdf 파일 업데이트 시작...")
    if len(sys.argv) < 4:
        error_message = "Shortcuts 업데이트에 필요한 인자가 부족합니다."
        logger.error(error_message)
        print("TASK_2=0")
        print(f"ERROR_MESSAGE={error_message}")
        sys.exit(1)

    access_token = sys.argv[2]
    user_id = sys.argv[3]
    logger.info(
        f"Shortcuts 업데이트 시 사용할 Access Token: {access_token}, User Id: {user_id}"
    )

    user_personas = get_steam_user_personas()
    if not user_personas:
        error_message = "Steam 유저 정보를 찾을 수 없습니다."
        logger.error(error_message)
        print("TASK_2=0")
        print(f"ERROR_MESSAGE={error_message}")
        sys.exit(1)

    user_persona = next(iter(user_personas))
    logger.info(f"Steam 유저 정보: {user_persona}")
    file_path = get_shortcuts_vdf_path(user_persona)
    logger.info(f"shortcuts.vdf 파일 경로: {file_path}")

    if not os.path.exists(file_path):
        error_message = "shortcuts.vdf 파일을 찾을 수 없습니다."
        logger.error(error_message)
        print("TASK_2=0")
        print(f"ERROR_MESSAGE={error_message}")
        sys.exit(1)

    result = update_shortcuts(
        file_path=file_path,
        game_name="Path of Exile 2",
        launch_options=f"--kakao {access_token} {user_id}",
    )

    if result:
        logger.info("Shortcuts 업데이트 성공.")
        print("TASK_2=1")
    else:
        error_message = "Shortcuts 업데이트 실패."
        logger.error(error_message)
        print("TASK_2=0")
        print(f"ERROR_MESSAGE={error_message}")


if __name__ == "__main__":
    update_steam_launch_options()
