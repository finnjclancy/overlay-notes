# Overlay Notes

Overlay Notes is a native macOS notes overlay that stays visible above other apps, including fullscreen windows.

## Features

- Always-on-top floating notes window
- Edit mode and transparent read-only overlay mode
- Global shortcuts to show or hide the window, switch mode, and cycle text color
- Adjustable text size
- Preserved pasted formatting for tabs, line breaks, and bullets
- Remembers window position

## Run

```zsh
./Scripts/run_app.sh
```

## Build

```zsh
./Scripts/build_app.sh
```

The built app bundle is created at `dist/Overlay Notes.app`.

## Shortcuts

- `Control + Option + Command + N`: show or hide the window
- `Control + Option + Command + R`: toggle edit and read-only mode
- `Control + Option + Command + C`: cycle text color

## Requirements

- macOS
- Xcode Command Line Tools

Install the command line tools if needed:

```zsh
xcode-select --install
```
