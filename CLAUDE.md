# Niche-Widgets

macOS app that turns theme images and text into widget designs using a local AI. Widgets are custom desktop panels, not WidgetKit.

## Stack
- Swift, SwiftUI, AppKit
- macOS 26 minimum, Apple Silicon
- No Electron, no third-party UI frameworks
- Local LLM via Ollama (qwen3:4b default)
- CLIP via Core ML and Apple Vision for image ranking and fit checks
- Image source: Pinterest only, through a hidden WKWebView with a persistent session

## Rules
- Write no comments in code
- Read docs/SPEC.md and the design folder before any UI work
- One build step per prompt, then stop so it can be tested
- Never commit keys, cookies, or cached images

## Architecture
- Widget model: one JSON schema shared by the editor, library, and desktop
- One renderer view draws a widget from its model
- Desktop manager: one transparent AppKit window per display at desktop level, every widget a Core Animation layer
- Edit mode enables drag, resize handles, and snapping; outside edit mode the window ignores mouse events
- Storage: local files in Application Support

## Performance budget
- Idle CPU under 0.5 percent with 50+ widgets
- No memory growth over time
- Downsample images to widget pixel size at load
- Pause animation and timers when the desktop is occluded, the screen sleeps, or a full-screen app is active
- Animate only transform and opacity on layers
- Unload the LLM and CLIP after each search

## Design
- Black matte translucent glass background
- Liquid glass buttons, clearly visible, all interactions animated with springs
- Clean, polished, consistent spacing
- Reference image: design/reference.png

## Build order
1. Scaffold, glass window, design system
2. Widget model and renderer
3. Chat UI and local LLM returning widget options as JSON
4. Pinterest login, harvester, caching
5. CLIP ranking and Vision fit checks
6. Editor with text and image prompts, undo
7. Library
8. Desktop panels with edit mode, drag, resize, snap
9. Polish, error states, launch at login
10. README and GitHub release