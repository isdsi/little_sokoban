# Little Sokoban

A classic **Sokoban Level 1** game project built with the Godot 4 engine. It replicates the original 1982 Hiroyuki Imabayashi layout while incorporating modern visual effects, responsive HUD systems, and cross-platform controls.

## Key Features

1. **Hybrid Input Interface**
   - **Keyboard**: Navigate using the arrow keys or WASD keys.
   - **Gamepad**: Move with the D-pad or the left analog stick.
   - **Mouse**: Click on any empty floor or goal cell to pathfind and walk there automatically using `AStarGrid2D`. Mouse drag swipes are also supported.
   - **Touch Screen**: Swipe gestures and a translucent on-screen virtual D-pad.
   - **Seamless Input Switching**: Keyboard, mouse, gamepad, and touch inputs can switch instantly. Clicking HUD buttons with the mouse will not steal focus from controller/keyboard navigation.

2. **Xbox Gamepad Button Prompts & Mappings**
   - Xbox-style colored button prompts (`[Y]`, `[X]`, `[A]`) are rendered inside buttons for controller players:
   - **[Y] (Yellow)**: Undo the last step/push (`↺ UNDO`). Mapped to the controller's **Y** button.
   - **[X] (Blue)**: Reset the current level (`⟲ RESET`). Mapped to the controller's **X** button.
   - **[A] (Green)**: Restart from victory/game-over overlays (`PLAY/TRY AGAIN`). Mapped to the controller's **A** button.

3. **Core Game Mechanics**
   - **Real-Time HUD**: Reflects scores (+100 for each box on a goal), a 300-second countdown timer, and remaining lives as heart icons (❤).
   - **Unlimited Undo**: Undo steps with smooth reverse animations.
   - **Layering Correction**: Overlays render on top of the stage walls, ensuring menus are fully legible and not obscured.
   - **Animations**: Moving entities animate smoothly via Tweens.

## In-game Themes

You can dynamically switch between themes using the `MENU` button at the bottom of the screen (or by pressing `M` or `Escape` keys).

| Default Theme (Modern Style) | Kenney Theme (Classic Cartoon Style) |
|:---:|:---:|
| ![Default Theme](images/default.png) | ![Kenney Theme](images/kenney.png) |

## Stage Configurations (Original Level 1–50)

This project features the complete set of **all 50 original classic Sokoban stages** designed by Hiroyuki Imabayashi. The full stage data is stored and managed within the [levels_data.gd](./levels_data.gd) file, which is loaded dynamically as the player progresses. (Source: [XSokoban.xsb](https://raw.githubusercontent.com/x-hgg-x/sokoban-go/master/levels/XSokoban.xsb) from [x-hgg-x/sokoban-go](https://github.com/x-hgg-x/sokoban-go) repository)

### Map Character Rules (Standard XSB)
- `#`: Wall
- ` ` (space): Floor
- `.`: Goal (Storage target location)
- `$`: Cargo Box
- `@`: Player starting position
- `*`: Cargo Box on Goal
- `+`: Player on Goal

### Representative Map Layout (Level 1 Example)
```text
    #####
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

## Level & Solution Pipeline

This project adopts a Data-Driven Design pattern. It includes a Python utility script to compile the raw Sokoban level data file (`.sok`) into game-ready resources.

- **Source Level Data**: [`levels_data.sok`](./levels_data.sok) (Contains 50 original stages and optimal solution keys)
- **Compilation Script**: [`convert_sok.py`](./convert_sok.py)
- **Generated Outputs**:
  - [`levels_data.gd`](./levels_data.gd): The map data script loaded dynamically by Godot at runtime
  - [`levels_data_solution.json`](./levels_data_solution.json): JSON dataset mapping level indices to the optimal solving paths used by the test automation

### How to Compile Level Data
To compile the raw SOK level packs, run the following command in your terminal:
```bash
python convert_sok.py levels_data.sok
```
*Note: To prevent losing existing solution progress, the compilation script implements a merge fallback logic that safely preserves solutions in `levels_data_solution.json` if new ones are omitted in the `.sok` file.*

## Test Automation

To ensure the robustness and reliability of in-game logic, a **Test Automation System** has been built utilizing Godot 4's native virtual input injection API (`Input.parse_input_event`).

- **GDScript Test Runner**: [`test_runner.gd`](./test_runner.gd) (Instantiated dynamically to run sequence steps inside Godot)
- **Python Wrapper**: [`test_runner.py`](./test_runner.py) (Launches the Godot subprocess headlessly or headfully, collects logs, and asserts success exit codes)

For detailed architectures and usage instructions (including scenarios, monitoring options, and Docker environments), please refer to the [Test Automation Specification (test_runner.md)](./test_runner.md).

### Quick Test Execution Example
Run the python script specifying scenario options:
```bash
# Verify stages starting from Level 5 visually in headful mode (Scenario 1)
python test_runner.py --scenario 1 --monitor --level 5
```

## How to Run

### 1. Running from Source (Godot Editor)

1. Download and install [Godot Engine 4.x](https://godotengine.org/).
2. Open the Godot Project Manager, import/choose this project folder, and open it.
3. Press `F5` or click the Play button in the top-right to run the main scene (`node_2d.tscn`).

### 2. Running Exported Builds (by Platform)

#### Windows
- Navigate to the `build/windows/` folder and double-click `little_sokoban.exe`.

#### macOS
- Extract the zip archive at `build/macos/little_sokoban.zip` and run the extracted app bundle.

#### Web (HTML5)
To run the Web build, you must run a local HTTP server inside the `build/web` folder to avoid browser CORS policy blocks.

1. Open your terminal and navigate to the web build directory:
   ```bash
   cd build/web
   ```
2. Run Python's built-in HTTP server directly:
   ```bash
   python -m http.server 8000
   ```
3. Open a browser and navigate to `http://localhost:8000`.

> [!NOTE]
> If the game fails to load due to `SharedArrayBuffer` being missing (common in Godot 4 multi-threaded builds), you can launch a server with security headers using a single-line Python command directly in your terminal:
> ```bash
> python -c "from http.server import HTTPServer, SimpleHTTPRequestHandler; GodotHandler = type('GodotHandler', (SimpleHTTPRequestHandler,), {'end_headers': lambda self: [self.send_header('Cross-Origin-Opener-Policy', 'same-origin'), self.send_header('Cross-Origin-Embedder-Policy', 'require-corp'), SimpleHTTPRequestHandler.end_headers(self)]}); print('Serving on http://localhost:8000'); HTTPServer(('localhost', 8000), GodotHandler).serve_forever()"
> ```

#### Android
- Transfer and install `build/android/little_sokoban.apk` onto your Android device or emulator.

#### iOS
- Open the Xcode project `build/ios/little_sokoban.xcodeproj` in Xcode on a macOS machine, build the project, and run it on an iOS simulator or connected device.

## CLI Export/Build Commands

You can build the game using the Godot command-line interface. Before exporting, ensure you have configured the corresponding export presets in the Godot Editor (Project -> Export), which creates the `export_presets.cfg` file.

Additionally, you must have the **Export Templates** installed for your Godot version. If you are building on a clean machine or in a new environment, you can run the provided PowerShell setup script to automatically download and install the matching export templates:

```powershell
./install_templates.ps1
```

First, create the output directories:
```bash
mkdir -p build/web build/android build/ios build/windows build/macos
```

Then run the export commands (replace `godot` with the path to your Godot executable if it's not in your PATH):

- **Windows Desktop (`.exe`)**:
  ```bash
  godot --headless --export-release "Windows Desktop" build/windows/little_sokoban.exe
  ```
- **macOS Desktop (`.zip` / `.app`)**:
  ```bash
  godot --headless --export-release "macOS" build/macos/little_sokoban.zip
  ```
- **Web (`index.html`)**:
  ```bash
  godot --headless --export-release "Web" build/web/index.html
  ```
- **Android (`.apk`)**:
  ```bash
  godot --headless --export-release "Android" build/android/little_sokoban.apk
  ```
- **iOS (`Xcode project`)**:
  ```bash
  godot --headless --export-release "iOS" build/ios/little_sokoban.xcodeproj
  ```

## License

This project is licensed under the [MIT License](LICENSE). Feel free to modify, build, and redistribute.
