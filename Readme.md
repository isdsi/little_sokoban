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

1. Download and install [Godot Engine 4.x](https://godotengine.org/).
2. Open Godot, import/choose this project folder, and open it.
3. Press `F5` or click the Play button in the top-right to run the main scene (`node_2d.tscn`).

## License

This project is licensed under the [MIT License](LICENSE). Feel free to modify, build, and redistribute.
