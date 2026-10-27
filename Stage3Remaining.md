# Step 3 Report: Chat UI and Local LLM

Status as of 2026-10-27, when the session was stopped. Nothing has been committed. Every change is still uncommitted in the working tree on `main`.

## Summary

- Step 3 is mostly built.
- The last verified state passed all 63 tests, built with no compiler warnings, and worked end to end in the running app. Chips 1 and 2 returned six rendered options each.
- The very last change moved the loading animations to Core Animation. It builds with no warnings, but the tests were not rerun after it and it was not checked in the running app.
- The third chip ("pastel cloud sky") worked in a live run through the test harness. It was never completed through the app UI.
- On this Mac a full reply takes about 75 to 110 seconds. The model runs at about 17 tokens per second and each reply is about 1,250 tokens. See "Known issues".

## Files created

### LocalAI (new folder `NicheWidgets/LocalAI/`)

| File | Purpose |
|---|---|
| `OllamaClient.swift` | `actor OllamaClient` talking to `http://127.0.0.1:11434` with URLSession. Health check via `/api/tags` (ready, serverNotRunning, modelMissing). Streaming `/api/chat` parsed from newline-delimited JSON into an `AsyncThrowingStream<String, Error>`. Also has `complete`, `unload` (sends keep_alive 0) and `ping` (used by Test connection). Timeouts: 3 s health, 90 s idle, 300 s total. `OllamaError` cases: serverNotRunning, modelMissing, timeout, badResponse, cancelled. Cancelling the consuming task cancels the URLSession task, which closes the connection. |
| `JSONValue.swift` | JSON value type that keeps key order, with its own serializer. This was needed because `JSONEncoder` reorders keys and does not even give stable output between calls. Used for the schema, the request body, and history summaries. |
| `LocalAISettings.swift` | `@Observable` settings stored in UserDefaults. Model name defaults to `qwen3:4b`. Keep-alive is `ModelKeepAlive` (Unload = 0, 1 min, 5 min), default 1 min. |
| `WidgetDesignSchema.swift` | The JSON schema sent as Ollama's `format`. It uses enums for shapes, presets, kinds, weights, alignments, directions and fonts, a hex pattern, min/max ranges, exactly 6 options and 5 to 8 search terms. It is also the single place where the parser's clamp ranges are defined. |
| `PromptBuilder.swift` | Builds the system prompt (widget designer role, full schema, size presets with pixel sizes, field ranges, strict JSON only, `/no_think`) and the user message (text plus palette hex values). Caps history at 6 messages. `chatRequest` sets `think:false`, `format`, `keep_alive`, `num_ctx` 8192 and `num_predict` 4096. |
| `ResponseParser.swift` | Decodes the reply into `DesignResult` (aesthetic, searchTerms, options, palette). Reuses the existing `WidgetModel` defaulting decoder. Drops options with a missing or invalid shape, a non-object value, and so on. Clamps every value. Fixes invalid hex colors. Converts image backgrounds to gradients. Fills a missing background with a placeholder gradient built from the palette. Repair pass: strips `<think>` blocks and code fences, cuts out the outer `{…}`, and parses once more. Throws `.malformed` or `.noUsableOptions`. |
| `DesignGenerator.swift` | Runs the pipeline off the main thread (`@concurrent`). Streams tokens and reports progress phases (thinking, designing option N of 6, retrying). If parsing fails, it retries the request once. It hops to the main actor only when the phase changes. |

### Images

| File | Purpose |
|---|---|
| `Images/PaletteExtractor.swift` | ImageIO downsample to 64 px, then a colour histogram and weighted k-means seeded from the most common colours. Returns 5 hex colours, most dominant first, and pads with shades or tints when an image has fewer colours. |
| `Images/ImageAttachment.swift` | `ImageAttachment` (160 px thumbnail plus palette) and `ImageAttachmentLoader`, which loads from a URL or Data. Images are downsampled right away and the full-size image is never kept. Maximum 4 attachments. Palettes from several images are interleaved and deduplicated. |

### Studio UI

| File | Purpose |
|---|---|
| `Screens/Studio/ChatSession.swift` | `@Observable` session held at app level, so it survives switching tabs. Each `ChatMessage` is its own `@Observable` class, so streaming updates redraw only the active bubble. Handles send, retry, stop, new chat (which also unloads the model), health check, polling every 3 s only while the banner is shown, attachments, and a 6-message history built from compact result summaries. A run token stops a cancelled run from overwriting a newer one. |
| `Screens/Studio/ChatMessageList.swift` | Message list with auto-scroll to the bottom and a spring entrance for each bubble. Contains `ChatBubble` (user bubble with thumbnails and palette; assistant bubble showing typing, status, the result with its palette, or a friendly error with a Retry button), `PaletteStrip` and `TypingIndicator`. |
| `Screens/Studio/PromptTextView.swift` | `NSTextView` wrapper. Return sends; Shift+Return (or Option+Return) adds a newline. Grows from 1 to 5 lines. Accepts only text drops, so image drops reach the window. |
| `Screens/Studio/ModelStatusBanner.swift` | Banner for serverNotRunning ("Start the local model", `ollama serve`) and modelMissing (`ollama pull <model>`), with a copy-command chip and a Retry button. Also contains `ExamplePromptChips` (the three chips). |

### Settings

| File | Purpose |
|---|---|
| `Screens/Settings/LocalAISettingsSection.swift` | Model name field, keep-alive picker, and a Test connection button that runs a health check plus a 4-token reply and shows the result with the response time. |

### Design system

| File | Purpose |
|---|---|
| `DesignSystem/LayerPulse.swift` | Core Animation opacity pulse, used for the skeleton cards, typing dots and status dot. It builds; tests and the in-app check were not run (see "Not finished" item 1). |

### Tests

| File | Covers |
|---|---|
| `ResponseParserTests.swift` | Valid JSON, fenced JSON, think blocks, malformed JSON, missing fields, out-of-range values, wrong shapes dropped, no usable options, caps, and parsed options rendering through `WidgetSnapshot`. |
| `PromptBuilderTests.swift` | Schema and ranges present in the system prompt, palette in the user message, history cap, structured output with think set to false, stable schema text, property order. |
| `OllamaClientTests.swift` | Mock `URLProtocol`: streaming parse across chunks, request body fields, server down, model missing (both `/api/tags` and HTTP 404), error line inside the stream, truncated stream, timeout, cancellation closing the connection, error mapping. |
| `PaletteExtractorTests.swift` | 5 valid hex colours from a generated striped image, solid image, attachment downsampling, combined palette. |
| `ChatSessionTests.swift` | Send produces six options, missing model gives a friendly failure, malformed reply is retried then reported, New Chat clears everything, and 20 consecutive prompts grow memory by less than 8 MB. All against a mock server. |

## Files modified

- `App/NicheWidgetsApp.swift`: creates `LocalAISettings` and `ChatSession` and puts them in the environment.
- `DesignSystem/GlassTextField.swift`: the glass field styling was pulled out into a reusable `glassFieldChrome(isFocused:)` modifier. `GlassTextField` looks the same as before, and the prompt bar uses the same styling.
- `DesignSystem/Tokens.swift`: new tokens (warning colour, attachment, option caption, swatch, typing dot, banner icon, settings field width, drop inset, option stagger, typing duration, health poll interval, skeleton pulse opacity).
- `Screens/Settings/SettingsView.swift`: added the Local AI card and changed the subtitle wording.
- `Screens/Studio/StudioView.swift`: rewritten. Header with New Chat, status banner, chat column with an empty state and chips, options column (skeleton, then grid, then empty state, plus aesthetic, palette and search-term chips), drag and drop onto the window with a drop highlight.
- `Screens/Studio/PromptBar.swift`: rewritten. Attach button using `NSOpenPanel`, thumbnails with remove buttons, multiline field, Stop button that replaces Send while generating (Cmd+. also stops).
- `Screens/Studio/WidgetOptionsGrid.swift`: options are arranged into bento slots by aspect ratio. Caption row with the name and "Shape · Size". Hover and selected highlight; clicking only toggles selection. Staggered spring entrance. Skeleton grid. `BentoLayout` gained a `caption` parameter. The old placeholder "Add to Library" hover button was removed, because the library is step 7.

## Verified results

- **Tests:** 63 tests in 9 suites passed. This was the last full run before the Core Animation change.
- **Build:** no compiler warnings or errors at that point. The only output was the AppIntents metadata notice, which was already there before this step.
- **Live Ollama run:** through a temporary test, since deleted, all three chips returned 6 valid options. Times were 84 s, 112 s and 109 s, before the prompt was tightened.
- **App run:**
  - **Chip 1, leopard print cherry aesthetic:** the chip filled the prompt and focused it. Return sent it. The typing indicator, the "Thinking…" and "Designing option 3 of 6…" status, the skeleton grid and the Stop button all appeared. Then the aesthetic bubble with its palette, the search-term chips and 6 rendered cards appeared.
  - **Chip 2, dark academia desk setup:** worked the same way.
  - **Chip 3, pastel cloud sky:** sent from the app UI, but the session stopped before it finished.
- **Idle CPU after a reply:** 0.0 to 0.2 percent. App memory was about 12 to 37 MB.
- **CPU during generation:** about 38 to 42 percent. A profile traced this to SwiftUI redrawing every frame for `repeatForever` animations. The Core Animation change is meant to fix this; it builds but has not been measured.

## Not finished

1. **Final change only partly verified.** `LayerPulse.swift` was added, and the skeleton, `TypingIndicator` and the status line in `ChatMessageList.swift` were switched to use it. It builds with no warnings. The tests were not rerun after it, it was not checked in the running app, and CPU during generation was not measured again.
2. **Chip 3 in the app UI** was never completed.
3. **Memory flat across 20 live prompts** was not tested against the real model; 20 prompts at about 90 s each was too long. It was tested with 20 prompts against a mock server through the full `ChatSession`, where memory grew by less than 8 MB.
4. **Not exercised by hand in the app:**
   - attaching images with `NSOpenPanel`
   - dragging images onto the window
   - removing a thumbnail
   - Shift+Return
   - Stop during generation
   - Retry on an error
   - the banner when Ollama is stopped
   - Settings → Test connection
   - New Chat while generating

   Many of these paths have unit tests, but none were tried in the app.
5. **No commit was made.**

## Known issues and judgment calls

- **Slow replies.** About 17 tok/s for about 1,250 tokens. Ways to speed it up:
  - make some fields optional in the schema (`fontName`, `alignment`, `background.color`) to cut tokens
  - show each option card as soon as its JSON object finishes, rather than all six at the end (beyond the current spec)
  - default to a smaller or faster model
- **`think:false` alone did not stop reasoning text** in a plain request on this Ollama (0.40.11) with `qwen3:4b`. With `format` set, the reply is forced to be JSON and the measured thinking output was 0 tokens. `/no_think` is also added to the prompts.
- **History** sends compact result summaries (aesthetic, search terms, and each option's name, shape, size and colours), not the raw reply. This keeps 6 messages within `num_ctx` 8192.
- **keep_alive.** Each request uses the keep-alive setting (default 60 s). New Chat sends an explicit unload (keep_alive 0). Nothing is sent when the app quits; Ollama's keep-alive unloads the model on its own.
- **Model quality.** Gradients often use two very close colours and text sizes are sometimes tiny. The prompt was tightened afterwards (distinct palette, varied content, compact JSON), but the effect was not measured.
- **Settings overlap.** The old placeholder toggle "Unload models after search" in Performance overlaps with the new keep-alive picker. It was left alone, since it is also meant for CLIP later.
- **Window position.** `osascript` clicks during testing showed the window position moving between launches. It has not been looked into and may be the saved window frame.

## Remaining from the original prompt, by section

- **LLM client:** done.
- **Prompt pipeline:** done.
- **Chat UI:** built. Hand-testing items are listed in "Not finished" item 4. The typing shimmer is now a Core Animation dot pulse rather than the gradient shimmer. It builds but has not been checked in the app.
- **Settings:** built, not hand-tested.
- **Tests:** done. All four required areas are covered, and they passed before the final change.
- **Quality bar:**
  - Only the active message updates: done by design.
  - No polling when ready: done.
  - Idle CPU near zero: verified.
  - Memory flat across 20 prompts: verified against a mock server only.
  - No force unwraps in app code: yes. The test target has none either.
  - CPU during generation: a fix builds but has not been measured.
- **Run the app with the three chips:** 2 of 3 done in the UI; all 3 done live through the harness.
- **Final report to the user:** this file.

## Next steps

1. Run the tests: `xcodebuild -project Niche-Widgets.xcodeproj -scheme Niche-Widgets -destination 'platform=macOS' test`. The last build already succeeded.
2. Launch the app, run the "pastel cloud sky" chip, and measure CPU during generation with `top -pid $(pgrep -x Niche-Widgets)`. It should fall well below 40 percent.
3. Hand-test the items in "Not finished" item 4. For the banner: quit Ollama, open Studio, check the banner and that it polls, run `ollama serve`, and check the banner clears.
4. Commit as "Step 3: chat UI and local LLM".
