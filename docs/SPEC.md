# Spec

## Flow
1. User drops theme images and text into the chat.
2. The local LLM expands the aesthetic into Pinterest search terms.
3. The hidden harvester collects pin images from Pinterest.
4. CLIP ranks them against the aesthetic. Vision checks crop, margins, and legibility per widget shape.
5. The app shows a grid of widget options in different shapes and sizes.
6. Each option is editable by text prompt or image prompt, with undo and redo.
7. Add to Library saves the widget.
8. Add to Desktop enters edit mode: drag, resize from corners, snap, then Done.

## Pinterest
- One-time sign-in sheet in a WKWebView. The password is never seen by the app.
- Persistent session through a named WKWebsiteDataStore.
- Harvesting runs in an off-screen window, throttled, one at a time, 100 to 200 pins per search.
- Every query is cached. Repeats never hit Pinterest.
- On session expiry or a checkpoint, show a clear state and offer re-login.
- No fallback source.

## First launch
- Download the local model with a progress screen.
- Show the Pinterest sign-in sheet with a note to use a secondary account.

## Widget schema
- id, name, shape, size, image reference, source link, text, style, position, created date

## Shapes and sizes
- Square, wide pill, tall card, circle, rounded rectangle, in small, medium, large, and extra large

## Library
- Rename, duplicate, delete, add to desktop

## Distribution
- GitHub Releases with a zipped unsigned app
- README explains right-click then Open, and the Pinterest terms risk