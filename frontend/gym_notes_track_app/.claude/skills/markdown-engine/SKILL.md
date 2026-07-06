---
name: markdown-engine
description: Invariants for the custom markdown engine and note editor in Gym Notes - preview pipeline (MarkdownPreviewBloc, LineBasedMarkdownBuilder, MarkdownChunker), list grammar, ghost text, tags, callouts, toolbar shortcuts, and the local re_editor fork. USE FOR - any change touching lib/utils/line_based_markdown_builder.dart, markdown_chunker.dart, markdown_list_syntax.dart, ghost_text.dart, lib/bloc/markdown_preview/, markdown_render_service.dart, optimized_note_editor_page.dart, markdown_toolbar.dart, or packages/re_editor. Load together with gym-notes-context.
---

# Markdown Engine & Editor

Related docs: [docs/markdown-feature-ideas.md](../../../docs/markdown-feature-ideas.md) (candidate features + fit analysis) and [docs/tag-system-roadmap.md](../../../docs/tag-system-roadmap.md) (tag feature plan). The full invariant list lives in [COPILOT_CONTEXT.md](../../../COPILOT_CONTEXT.md) sections "Markdown Preview Pipeline", "Markdown Block Model And Chunking", "Markdown Lists", and "Ghost Text".

## The one hard constraint

**Every rendered span keeps its exact source offset.** The recursive inline parser (`_parseInline`) routes every leaf text run through `_applyHighlighting` with its exact source offset so search highlights and editor↔preview scroll mapping survive nested emphasis, links, escaping, ghosts, tags, and lists. When adding inline syntax, never break this offset threading.

## Preview pipeline layering (keep intact)

```
OptimizedNoteEditorPage
  -> MarkdownPreviewBloc -> MarkdownRenderService -> LineBasedMarkdownBuilder
       -> MarkdownChunker (block scan + chunk layout)
       -> MarkdownListSyntax (shared list grammar)
  -> MarkdownPreviewBlocView -> SourceMappedMarkdownView
```

- Bloc state is `Equatable`, primitives + `renderHandle: int` only. **Never put `InlineSpan` trees or builders in state** — widgets pull spans from `bloc.renderService.builder` on demand; heavy rebuilds are gated by `buildWhen` on `renderHandle` / `linesPerChunk` / `fontSize`.
- Content sync: `bloc.bindContentProvider(() => controller.text)` once in `initState`; `bloc.markContentDirty()` per keystroke; dispatch `PreviewContentRefreshRequested` for lazy/debounced refresh (500 ms, gated on `!_isLoading` and `state.hasTheme`); `PreviewContentChanged` only for eager pushes (toggle, checkbox, locale change, load). Never dispatch from `build()`.
- Theme dispatch (`PreviewThemeChanged`) only from `MarkdownPreviewBlocView` lifecycle hooks — never `build()`. Scroll progress bypasses the event queue via `bloc.scrollController.updateProgress(progress)`.
- Search sync: call `_searchController.updateContent(content)` from `_pushPreviewContent` / `_scheduleLivePreviewRefresh` when searching — never from `build()`.
- The page owns `final GlobalKey<SourceMappedMarkdownViewState> _previewViewKey` as a named field, bound via `scrollController.bindView(_previewViewKey)` and passed as `viewKey:` — never an inline anonymous key.
- Chunks are **block-aligned with variable line counts** — never compute `lineIndex ~/ linesPerChunk`; use `chunkStartLine(i)`, `chunkIndexForLine(line)`, `MarkdownRenderService.chunkStartLineForLine(line)`.
- Toolbar: reuse `_buildMarkdownBar({required bool enabled})` for both loading and loaded paths — never duplicate the `MarkdownBar(...)` tree.
- Preview links: validate schemes (`http`, `https`, `mailto`, `tel`) before `launchUrl` in `LaunchMode.externalApplication`; localized errors via `CustomSnackbar.showError`.

## Single-source-of-truth grammars (never fork them)

- `MarkdownChunker` (`lib/utils/markdown_chunker.dart`) — block model + chunk layout, shared by preview and the editor debug overlay. Multi-line blocks only (code fences, callouts); single-line content is implicit. New single-widget block types set `atomic: true`.
- `MarkdownListSyntax` (`lib/utils/markdown_list_syntax.dart`) — list grammar shared by editor (`MarkdownListUtils`: Enter-continuation, Tab/Shift-Tab) and renderer. **Never reintroduce a second list regex** — extend `MarkdownListSyntax`.
- `GhostText` (`lib/utils/ghost_text.dart`) — `{{ … }}` placeholder scanning, consumed by preview renderer, editor span builder, tap handling, and the `default_ghost` shortcut. Markers are concealed in the editor (transparent + ~0 width) so caret offsets never desync; tapping selects the run, nothing is mutated.
- `MarkdownCalloutSyntax` (`lib/utils/markdown_callout_syntax.dart`) — `> [!TIP]`-style callouts (types: note, tip, important, warning, caution, success, pr).
- Tags (`#tag`) — inline, Unicode-aware, render-only; tap routes to global search with `#` preserved by `normalizeForSearch`. Roadmap (shared `MarkdownTagSyntax` scanner, `TagIndex`) is in the tag roadmap doc.

## re_editor fork (`packages/re_editor/`)

Local perf-tuned fork — fix bugs in place but avoid API breaks. Preserve: `CodeLines.asString` 2-slot round-robin cache; `_hashCache` short-circuit comparisons; binary-search paragraph lookups in `_code_field.dart`; bounded LRU `_CodeParagraphCache` (512); 50 ms highlight debounce; new `CodeLines` mutation paths must call `cloneShallowDirty()` (never the public constructor).

## Editor hot-path rules

No per-keystroke string copies, synchronous DB writes, or expensive rebuilds on the typing path. Auto-save (`auto_save_service.dart`) debounce/interval/lifecycle-flush/retry behavior must stay reliable. Adaptive chunk sizing lives in `MarkdownChunker.adaptiveChunkSize` (cap 100), applied by the render service.
