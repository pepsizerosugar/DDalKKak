# DDalKKak

![Version](https://img.shields.io/badge/Version-1.0.3-green)
![Update](https://img.shields.io/badge/Update-2024.12.17-blue)
![Compatibility](https://img.shields.io/badge/Compatible-Steam_Deck-orange)
![GitHub all releases](https://img.shields.io/github/downloads/pepsizerosugar/DDalKKak/total?color=purple)

**DDalKKak**은 카카오게임즈 Path Of Exile 2를 **스팀덱**에서 보다 원활하게 실행할 수 있도록 돕는 자동화 도구입니다.
* 실행하기 위한 조건은 아래와 같습니다.
  1. SteamOS `마켓`을 통해 `Chrome` 설치.
  2. 해당 `Chrome`으로 `카카오 POE2 페이지`에 이미 `로그인`을 `한 번`이라도 한 상태.
  3. 카카오게임즈의 Path Of Exile 2를 이미 `비-스팀` 게임으로 `스팀`에 `등록`하고 즐기고 있는 상태.
* 사용자가 브라우저 상호작용 없이 `자동`으로 `인증 정보`를 확인하고, `게임 실행 토큰`과 `유저 아이디`를 파싱하기 위해 `사전조건이 필요`합니다.

<br>

## Features

- **자동 인증**: 카카오 인증 토큰 및 실행 옵션 자동 설정  
- **Steam 실행 옵션 설정**: 비-스팀 게임 등록 및 실행 옵션 업데이트  
- **자동 다운로드 및 실행**: 스크립트를 통해 모든 과정이 자동으로 진행됩니다.

<br>

## Getting Started

### Step 1: Konsole(이하 터미널)에서 스크립트 다운로드 및 부가 설정

1. 스팀덱의 **데스크톱 모드**로 전환합니다.  
2. 터미널을 열고 다음 명령어를 입력합니다:  
   ```bash
    wget https://raw.githubusercontent.com/pepsizerosugar/DDalKKak/main/run.sh -O ~/Downloads/run.sh
    chmod +x ~/Downloads/run.sh
   ```
3. 다운로드에 이슈가 없는 한, `run.sh`는 기본 `다운로드 폴더`에 다운로드됩니다.
4. 터미널은 잠시 놔두고, `파일 탐색기`로 다운로드 폴더로 진입해 `run.sh` 파일을 `오른쪽 클릭(L2)`하여 `속성`에 진입합니다.
5. 권한 -> `실행 가능` 옵션에 체크하고 확인을 클릭해 설정을 적용합니다.
6. `run.sh` 파일을 `오른쪽 클릭(L2)`하여 `Add to Steam`을 눌러 스팀에 등록합니다. (게이밍 모드에서 실행을 위해)
7. 다시 터미널로 돌아와 다음 명령어를 입력합니다:
   ```bash
    ~/Downloads/run.sh
   ```
8. Step 2의 내용이 `자동`으로 실행됩니다.

<br>

### Step 2: 자동 작업 실행
1. 스크립트가 자동으로 **최신 버전**의 DDalKKak 프로젝트를 다운로드합니다.  
2. `tasks.sh`를 실행하여 카카오 인증 및 스팀 실행옵션 설정 작업을 수행합니다.
  1. 작업 확인 창이 노출되며, 확인을 누르면 시작합니다.
  2. 만약 처음 실행하는 시점이라면, 실행 도중 `터미널`에서 `deck 암호 입력`이 필요할 수 있습니다.
3. 작업이 완료되면 `시스템을 재시작` 한다는 확인 창이 노출되며, `확인` 혹은 창을 닫으면 `시스템이 재시작` 됩니다.
  1. 만약 처음 실행하는 시점이라면, 실행 도중 `터미널`에서 `deck 암호 입력`이 필요할 수 있습니다.
5. 재시작 후 게이밍 모드에서 POE2를 실행하여 정상적으로 동작하는지 확인합니다.

<br>

### Step 3: 게이밍 모드에서 사용
1. Step 1의 6번 작업을 완료했으면, 최근 라이브러리에 추가 된 항목에 `run.sh` 이름으로 노출되어 있습니다.
2. 해당 게임을 선택해 실행합니다.
3. 프로그램 창이 나타나면 `확인`을 눌러 작업을 실행합니다.
4. 작업이 완료된 후 재시작 창에서 확인을 눌러 스팀덱을 재시작 합니다 (설정 적용을 위해 필수)
