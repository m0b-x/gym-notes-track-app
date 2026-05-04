import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../controllers/preview_scroll_controller.dart';
import '../../services/markdown_render_service.dart';
import '../../utils/line_based_markdown_builder.dart';
import 'markdown_preview_event.dart';
import 'markdown_preview_state.dart';

export 'markdown_preview_event.dart';
export 'markdown_preview_state.dart';

/// Coordinates the markdown preview rendering pipeline for a single
/// preview surface (typically one note editor page).
///
/// Owns a [MarkdownRenderService] and forwards input changes to it.
/// The bloc itself never produces or holds [InlineSpan] trees: when a
/// rebuild happens it bumps [MarkdownPreviewState.renderHandle] and
/// the consuming widget pulls spans from [renderService] on demand.
///
/// ### Theme dependency
///
/// The bloc is widget-free and therefore cannot resolve a [Theme]
/// itself. It relies on a mounted `MarkdownPreviewBlocView` (or any
/// equivalent caller) to dispatch [PreviewThemeChanged] before the
/// builder can be prepared. Until that first dispatch arrives,
/// content / font / search events are recorded into state but no
/// rendering work happens. Owners that need to read derived data
/// (e.g. `renderService.chunkCount`) before the view mounts should
/// dispatch `PreviewThemeChanged` themselves first.
///
/// Performance characteristics preserved from the previous in-widget
/// implementation:
///   * Builder is reused when none of the prepare-relevant inputs
///     changed (content, font, brightness, lines-per-chunk, debug,
///     search highlights, current highlight index).
///   * Builder is disposed and recreated when inputs change so that
///     gesture recognizers do not leak.
///   * Adaptive chunk sizing for large documents (delegated to the
///     service).
///   * Scroll progress updates are zero-cost: they emit a state with
///     an updated `progress` field and never touch the builder.
class MarkdownPreviewBloc
    extends Bloc<MarkdownPreviewEvent, MarkdownPreviewState> {
  final MarkdownRenderService _renderService;
  final PreviewScrollController _scrollController;

  /// Last theme inputs received. The bloc cannot prepare the builder
  /// without these — until [PreviewThemeChanged] arrives, any
  /// content/font changes are recorded in state but do not trigger a
  /// prepare call.
  Brightness? _brightness;
  LineMarkdownStyle Function(double fontSize)? _styleBuilder;
  bool _debugEnabled = false;

  /// Optional callbacks forwarded into every [LineBasedMarkdownBuilder]
  /// the service constructs. Set once via [bindCallbacks] from the
  /// owning widget; the bloc itself is widget-free.
  LinkTapCallback? _onLinkTap;
  CheckboxTapCallback? _onCheckboxTap;

  MarkdownPreviewBloc({MarkdownRenderService? renderService})
    : _renderService = renderService ?? MarkdownRenderService(),
      _scrollController = PreviewScrollController(),
      super(const MarkdownPreviewState()) {
    on<PreviewContentChanged>(_onContentChanged);
    on<PreviewFontSizeChanged>(_onFontSizeChanged);
    on<PreviewSearchUpdated>(_onSearchUpdated);
    on<PreviewLinesPerChunkChanged>(_onLinesPerChunkChanged);
    on<PreviewModeToggled>(_onModeToggled);
    on<PreviewThemeChanged>(_onThemeChanged);
  }

  /// The scroll controller owned by this bloc. Pass
  /// `controller.viewKey` as the `key:` of the underlying
  /// [SourceMappedMarkdownView] (the bloc-view wrapper does this
  /// automatically) so all imperative scroll calls resolve to the
  /// live state.
  PreviewScrollController get scrollController => _scrollController;

  /// Convenience: the same [ValueNotifier] used by
  /// `InteractivePreviewScrollbar`. Exposed so widgets can bind
  /// without reaching into [scrollController].
  ValueListenable<double> get scrollProgress => _scrollController.progress;

  // ─────────────────────────────────────────────────────────────────
  // Scroll facades — thin pass-throughs so call sites don’t need to
  // know about the controller. All preserve existing semantics.
  // ─────────────────────────────────────────────────────────────────

  void scrollToProgress(double value, {bool animate = false}) =>
      _scrollController.scrollToProgress(value, animate: animate);

  void scrollToTop({bool animate = true}) =>
      _scrollController.scrollToTop(animate: animate);

  void scrollToBottom({bool animate = true}) =>
      _scrollController.scrollToBottom(animate: animate);

  Future<bool> scrollToLineIndex(
    int lineIndex,
    int totalLines, {
    bool animate = true,
    Duration duration = const Duration(milliseconds: 300),
  }) => _scrollController.scrollToLineIndex(
    lineIndex,
    totalLines,
    animate: animate,
    duration: duration,
  );

  Future<bool> scrollToSourceOffset(int offset) =>
      _scrollController.scrollToSourceOffset(offset);

  void restoreProgress(
    double targetProgress, {
    Duration delay = const Duration(milliseconds: 150),
  }) => _scrollController.restoreProgress(targetProgress, delay: delay);

  void cancelPendingRestores() => _scrollController.cancelPendingRestores();

  int get currentLineIndex => _scrollController.currentLineIndex;

  /// The render service owned by this bloc. Widgets call
  /// `renderService.builder?.buildChunk(i)` to read spans for a
  /// specific chunk index.
  MarkdownRenderService get renderService => _renderService;

  /// Binds the link / checkbox callbacks used by the underlying
  /// builder. Safe to call multiple times; only the most recent
  /// callbacks are used on the next prepare.
  void bindCallbacks({
    LinkTapCallback? onLinkTap,
    CheckboxTapCallback? onCheckboxTap,
  }) {
    _onLinkTap = onLinkTap;
    _onCheckboxTap = onCheckboxTap;
  }

  /// Pre-warm the LRU chunk cache for [chunkIndex]. Forwarded to the
  /// service. Used by the view to look ahead in the scroll direction.
  void preWarmChunk(int chunkIndex) {
    _renderService.preWarmChunk(chunkIndex);
  }

  // ─────────────────────────────────────────────────────────────────
  // Event handlers
  // ─────────────────────────────────────────────────────────────────

  void _onContentChanged(
    PreviewContentChanged event,
    Emitter<MarkdownPreviewState> emit,
  ) {
    if (event.content == state.content && state.hasTheme) {
      // Identical content and we already prepared once — nothing to do.
      return;
    }
    final next = state.copyWith(content: event.content);
    _emitPrepared(next, emit);
  }

  void _onFontSizeChanged(
    PreviewFontSizeChanged event,
    Emitter<MarkdownPreviewState> emit,
  ) {
    if (event.fontSize == state.fontSize) return;
    _emitPrepared(state.copyWith(fontSize: event.fontSize), emit);
  }

  void _onSearchUpdated(
    PreviewSearchUpdated event,
    Emitter<MarkdownPreviewState> emit,
  ) {
    final next = state.copyWith(
      searchHighlights: event.highlights,
      clearSearchHighlights: event.highlights == null,
      currentHighlightIndex: event.currentIndex,
      clearCurrentHighlightIndex: event.currentIndex == null,
    );
    _emitPrepared(next, emit);
  }

  void _onLinesPerChunkChanged(
    PreviewLinesPerChunkChanged event,
    Emitter<MarkdownPreviewState> emit,
  ) {
    if (event.linesPerChunk == state.linesPerChunk) return;
    _emitPrepared(state.copyWith(linesPerChunk: event.linesPerChunk), emit);
  }

  void _onModeToggled(
    PreviewModeToggled event,
    Emitter<MarkdownPreviewState> emit,
  ) {
    if (event.isPreviewMode == state.isPreviewMode) return;
    emit(state.copyWith(isPreviewMode: event.isPreviewMode));
  }

  void _onThemeChanged(
    PreviewThemeChanged event,
    Emitter<MarkdownPreviewState> emit,
  ) {
    final brightnessChanged = _brightness != event.brightness;
    final debugChanged = _debugEnabled != event.debugEnabled;
    // Always update the cached style builder — even when
    // [brightness] / [debugEnabled] are unchanged the closure may
    // capture an updated theme tint. We only trigger a rebuild when
    // the cache key actually changes.
    _brightness = event.brightness;
    _styleBuilder = event.styleBuilder;
    _debugEnabled = event.debugEnabled;

    final hadTheme = state.hasTheme;
    if (!brightnessChanged && !debugChanged && hadTheme) {
      // No-op: cached factory updated for next prepare, no rebuild needed.
      return;
    }

    _emitPrepared(state.copyWith(hasTheme: true), emit);
  }

  // ─────────────────────────────────────────────────────────────────
  // Prepare
  // ─────────────────────────────────────────────────────────────────

  /// Calls into the render service with the current state + cached
  /// theme inputs and emits the resulting state.
  ///
  /// If theme has not yet been provided, only the input state change
  /// is emitted and the service is left untouched.
  void _emitPrepared(
    MarkdownPreviewState next,
    Emitter<MarkdownPreviewState> emit,
  ) {
    final brightness = _brightness;
    final styleBuilder = _styleBuilder;
    if (brightness == null || styleBuilder == null) {
      emit(next);
      return;
    }

    // Always rebuild the style with the *current* font size so the
    // builder receives a style whose [LineMarkdownStyle.baseFontSize]
    // matches what the view will render.
    final style = styleBuilder(next.fontSize);

    final rebuilt = _renderService.prepareWithStyle(
      data: next.content,
      fontSize: next.fontSize,
      brightness: brightness,
      style: style,
      linesPerChunk: next.linesPerChunk,
      debugEnabled: _debugEnabled,
      searchHighlights: next.searchHighlights,
      currentHighlightIndex: next.currentHighlightIndex,
      onLinkTap: _onLinkTap,
      onCheckboxTap: _onCheckboxTap,
    );

    if (rebuilt) {
      emit(next.copyWith(renderHandle: next.renderHandle + 1, hasTheme: true));
    } else {
      // No builder rebuild: still emit the new input state so
      // downstream observers see e.g. font/lines-per-chunk changes.
      // Equatable will short-circuit if nothing actually changed.
      emit(next.copyWith(hasTheme: true));
    }
  }

  @override
  Future<void> close() {
    _renderService.dispose();
    _scrollController.dispose();
    return super.close();
  }
}
