# Little Sokoban (꼬마 소코반)

Godot 4 엔진 기반으로 개발된 클래식 **소코반 1스테이지(Sokoban Level 1)** 게임 프로젝트입니다. 1982년 히로유키 이마바야시(Hiroyuki Imabayashi)가 설계한 오리지널 맵 구성을 기반으로 하고 있으며, 다양한 조작 인터페이스와 세련된 시각 효과를 제공합니다.

## 주요 기능

1. **하이브리드 조작 인터페이스**
   - **키보드**: 방향키 및 WASD 키로 캐릭터 이동.
   - **게임패드**: D-pad 및 왼쪽 아날로그 스틱으로 캐릭터 이동.
   - **마우스**: 빈 공간이나 목표 지점을 클릭하면 `AStarGrid2D` 경로 알고리즘을 사용해 플레이어가 최단 경로로 자동 이동. 마우스 드래그를 통한 스와이프 조작도 지원.
   - **터치 스크린**: 스와이프 제스처 및 우측 하단에 위치한 반투명 가상 D-pad 버튼 지원.
   - **심리스 입력 전환**: 마우스 클릭 직후에도 키보드/패드 신호가 들어오면 입력 가로채기(포커스 뺏김) 없이 즉시 전환되어 유연하게 플레이할 수 있습니다.

2. **Xbox 게임패드 버튼 가이드 및 키 매핑**
   - 사용자 편의를 위해 UI 버튼 내부에 Xbox 패드 레이아웃 기준의 직관적인 영문 키 프롬프트(`[Y]`, `[X]`, `[A]`)를 색상별로 표시했습니다.
   - **[Y] (노란색)**: 직전 이동 및 상자 밀기 되돌리기 (`↺ UNDO`)
   - **[X] (파란색)**: 스테이지 초기화 (`⟲ RESET`)
   - **[A] (초록색)**: 승리/게임오버 화면에서 다시 시작 (`PLAY/TRY AGAIN`)

3. **게임 플레이 메커니즘**
   - **실시간 HUD**: 점수(상자 안착당 100점), 제한 시간(300초 카운트다운), 생명 수(❤ 하트 표시)를 실시간 반영.
   - **언두(Undo) 시스템**: 움직임 횟수 제한 없이 부드러운 역방향 애니메이션으로 상태를 되돌릴 수 있습니다.
   - **레이어 개선**: 승리 및 게임 오버 오버레이 화면이 스테이지 벽 상단에 완벽하게 덮이도록 드로우 인덱스를 제어하여 텍스트 가독성을 확보했습니다.
   - **애니메이션**: 플레이어의 한 보폭 및 상자가 밀릴 때 Tween 애니메이션 효과가 적용되어 부드러운 움직임을 제공합니다.

## 스테이지 맵 구성 (오리지널 1스테이지)

```text
    #####text
    #   #
    #$  #
  ###  $##
  #  $ $ #
### # ## #   ######
#   # ## #####  ..#
# $  $          ..#
##### ### #@##  ..#
    #     #########
    #######
```
- `#`: 벽 (Wall)
- ` `: 바닥 (Floor)
- `.`: 목적지 보관소 (Goal)
- `$`: 화물 상자 (Box)
- `@`: 작업반장 플레이어 (Player)

## 실행 방법

### 1. 소스 코드에서 실행 (Godot 에디터)

1. [Godot Engine 4.x](https://godotengine.org/)를 설치합니다.
2. Godot 에디터를 실행한 후 이 프로젝트 폴더를 불러와 열어줍니다.
3. `F5` 키를 누르거나 우측 상단의 플레이 버튼을 클릭하여 `node_2d.tscn` 메인 씬을 실행합니다.

### 2. 빌드된 실행 파일로 실행 (플랫폼별)

#### Windows
- `build/windows/` 폴더로 이동하여 `little_sokoban.exe` 파일을 더블 클릭하여 실행합니다.

#### macOS
- `build/macos/little_sokoban.zip` 압축 파일을 해제한 뒤 생성된 `.app` 실행 파일을 구동합니다.

#### Web (웹 브라우저)
웹 빌드 버전을 크롬 등 브라우저에서 실행하려면 CORS 보안 정책 우회를 위해 반드시 로컬 HTTP 웹 서버를 통해 구동해야 합니다.

1. 터미널(PowerShell 또는 CMD)을 열고 웹 빌드 디렉터리로 이동합니다.
   ```bash
   cd build/web
   ```
2. 별도의 스크립트 파일 작성 없이, 파이썬 내장 HTTP 서버 모듈을 실행합니다.
   ```bash
   python -m http.server 8000
   ```
3. 크롬 브라우저를 열고 `http://localhost:8000` 주소로 접속합니다.

> [!NOTE]
> 만약 브라우저 콘솔에 `SharedArrayBuffer` 오류가 발생하며 게임이 구동되지 않는다면(Godot 4 멀티스레드 빌드 특징), 파이썬 스크립트 파일 생성 없이 아래와 같이 단일 행 터미널 명령어를 입력하여 보안 헤더가 적용된 서버를 바로 실행할 수 있습니다.
> ```bash
> python -c "from http.server import HTTPServer, SimpleHTTPRequestHandler; GodotHandler = type('GodotHandler', (SimpleHTTPRequestHandler,), {'end_headers': lambda self: [self.send_header('Cross-Origin-Opener-Policy', 'same-origin'), self.send_header('Cross-Origin-Embedder-Policy', 'require-corp'), SimpleHTTPRequestHandler.end_headers(self)]}); print('Serving on http://localhost:8000'); HTTPServer(('localhost', 8000), GodotHandler).serve_forever()"
> ```

#### Android
- 빌드된 `build/android/little_sokoban.apk` 파일을 Android 기기 또는 에뮬레이터에 설치하여 실행합니다.

#### iOS
- macOS에서 `build/ios/little_sokoban.xcodeproj` 프로젝트 파일을 Xcode로 열어 프로젝트를 빌드한 후, iOS 시뮬레이터나 연결된 기기에 앱을 올려 실행합니다.

## CLI 빌드/내보내기 명령

Godot 커맨드 라인 인터페이스(CLI)를 사용해 게임을 빌드할 수 있습니다. 명령어를 실행하기 전, Godot 에디터의 프로젝트 내보내기 설정(프로젝트 -> 내보내기)에서 각 플랫폼별 내보내기 프리셋을 먼저 등록해 주어야 합니다 (`export_presets.cfg` 파일 생성 필요).

먼저, 빌드 산출물을 저장할 디렉토리를 생성합니다:
```bash
mkdir -p build/web build/android build/ios build/windows build/macos
```

그 다음 아래의 수출 명령어를 실행합니다 (`godot` 환경 변수가 등록되지 않은 경우 Godot 실행 파일의 절대 경로를 입력해 주세요):

- **Windows Desktop (`.exe`)**:
  ```bash
  godot --headless --export-release "Windows Desktop" build/windows/little_sokoban.exe
  ```
- **macOS Desktop (`.zip` / `.app`)**:
  ```bash
  godot --headless --export-release "macOS" build/macos/little_sokoban.zip
  ```
- **Web (웹 브라우저용 `index.html`)**:
  ```bash
  godot --headless --export-release "Web" build/web/index.html
  ```
- **Android (`.apk`)**:
  ```bash
  godot --headless --export-release "Android" build/android/little_sokoban.apk
  ```
- **iOS (`Xcode 프로젝트`)**:
  ```bash
  godot --headless --export-release "iOS" build/ios/little_sokoban.xcodeproj
  ```

## 라이센스 (License)

본 프로젝트는 [MIT License](LICENSE) 하에 배포됩니다. 자유롭게 수정 및 배포하실 수 있습니다.

