# Little Sokoban

A classic **Sokoban Level 1** game project built with the Godot 4 engine. It replicates the original 1982 Hiroyuki Imabayashi layout while incorporating modern visual effects, responsive HUD systems, and cross-platform controls.

## Key Features

1. **Hybrid Input Interface**
   - **Keyboard**: Navigate using the arrow keys or WASD keys.
   - **Gamepad**: Move with the D-pad or the left analog stick.
   - **Mouse**: Click on any empty floor or goal cell to pathfind and walk there automatically using `AStarGrid2D`. Mouse drag swipes are also supported.
   - **Touch Screen**: Swipe gestures and a translucent on-screen virtual D-pad.
   - **Seamless Focus Switching**: Clicking HUD buttons with the mouse will not steal controller/keyboard focus. We disable button focus-grabbing (`Control.FOCUS_NONE`) and release active UI focus instantly in `_input(event)` when keyboard/gamepad inputs are detected.

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

## Stage Map Layout (Original Level 1)

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
- `#` : Wall
- ` ` : Floor
- `.` : Goal (Storage target location)
- `$` : Cargo Box
- `@` : Player starting position

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
2. Run Python's built-in HTTP server directly (without writing any script files):
   ```bash
   python -m http.server 8000
   ```
3. Open Google Chrome or any modern browser and navigate to `http://localhost:8000`.

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

