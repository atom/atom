/* global ResizeObserver */

const etch = require('etch');
const { Point, Range } = require('text-buffer');
const LineTopIndex = require('line-top-index');
const TextEditor = require('./text-editor');
const { isPairedCharacter } = require('./text-utils');
const electron = require('electron');
const clipboard = electron.clipboard;
const $ = etch.dom;

let TextEditorElement;

const DEFAULT_ROWS_PER_TILE = 6;
const NORMAL_WIDTH_CHARACTER = 'x';
const DOUBLE_WIDTH_CHARACTER = '我';
const HALF_WIDTH_CHARACTER = 'ﾊ';
const KOREAN_CHARACTER = '세';
const NBSP_CHARACTER = '\u00a0';
const ZERO_WIDTH_NBSP_CHARACTER = '\ufeff';
const MOUSE_DRAG_AUTOSCROLL_MARGIN = 40;
const CURSOR_BLINK_RESUME_DELAY = 300;
const CURSOR_BLINK_PERIOD = 800;

function scaleMouseDragAutoscrollDelta(delta) {
  return Math.pow(delta / 3, 3) / 280;
}

module.exports = class TextEditorComponent {
  static setScheduler(scheduler) {
    etch.setScheduler(scheduler);
  }

  static getScheduler() {
    return etch.getScheduler();
  }

  static didUpdateStyles() {
    if (this.attachedComponents) {
      this.attachedComponents.forEach(component => {
        component.didUpdateStyles();
      });
    }
  }

  static didUpdateScrollbarStyles() {
    if (this.attachedComponents) {
      this.attachedComponents.forEach(component => {
        component.didUpdateScrollbarStyles();
      });
    }
  }

  constructor(props) {
    this.props = props;

    if (!props.model) {
      props.model = new TextEditor({
        mini: props.mini,
        readOnly: props.readOnly
      });
    }
    this.props.model.component = this;

    if (props.element) {
      this.element = props.element;
    } else {
      if (!TextEditorElement)
        TextEditorElement = require('./text-editor-element');
      this.element = new TextEditorElement();
    }
    this.element.initialize(this);
    this.virtualNode = $('atom-text-editor');
    this.virtualNode.domNode = this.element;
    this.refs = {};

    this.updateSync = this.updateSync.bind(this);
    this.didBlurHiddenInput = this.didBlurHiddenInput.bind(this);
    this.didFocusHiddenInput = this.didFocusHiddenInput.bind(this);
    this.didPaste = this.didPaste.bind(this);
    this.didTextInput = this.didTextInput.bind(this);
    this.didKeydown = this.didKeydown.bind(this);
    this.didKeyup = this.didKeyup.bind(this);
    this.didKeypress = this.didKeypress.bind(this);
    this.didCompositionStart = this.didCompositionStart.bind(this);
    this.didCompositionUpdate = this.didCompositionUpdate.bind(this);
    this.didCompositionEnd = this.didCompositionEnd.bind(this);

    this.updatedSynchronously = this.props.updatedSynchronously;
    this.didScrollDummyScrollbar = this.didScrollDummyScrollbar.bind(this);
    this.didMouseDownOnContent = this.didMouseDownOnContent.bind(this);
    this.debouncedResumeCursorBlinking = debounce(
      this.resumeCursorBlinking.bind(this),
      this.props.cursorBlinkResumeDelay || CURSOR_BLINK_RESUME_DELAY
    );
    this.lineTopIndex = new LineTopIndex();
    this.lineNodesPool = new NodePool();
    this.updateScheduled = false;
    this.suppressUpdates = false;
    this.hasInitialMeasurements = false;
    this.measurements = {
      lineHeight: 0,
      baseCharacterWidth: 0,
      doubleWidthCharacterWidth: 0,
      halfWidthCharacterWidth: 0,
      koreanCharacterWidth: 0,
      gutterContainerWidth: 0,
      lineNumberGutterWidth: 0,
      clientContainerHeight: 0,
      clientContainerWidth: 0,
      verticalScrollbarWidth: 0,
      horizontalScrollbarHeight: 0,
      longestLineWidth: 0
    };
    this.derivedDimensionsCache = {};
    this.visible = false;
    this.cursorsBlinking = false;
    this.cursorsBlinkedOff = false;
    this.nextUpdateOnlyBlinksCursors = null;
    this.linesToMeasure = new Map();
    this.extraRenderedScreenLines = new Map();
    this.horizontalPositionsToMeasure = new Map(); // Keys are rows with positions we want to measure, values are arrays of columns to measure
    this.horizontalPixelPositionsByScreenLineId = new Map(); // Values are maps from column to horizontal pixel positions
    this.blockDecorationsToMeasure = new Set();
    this.blockDecorationsByElement = new WeakMap();
    this.blockDecorationSentinel = document.createElement('div');
    this.blockDecorationSentinel.style.height = '1px';
    this.heightsByBlockDecoration = new WeakMap();
    this.blockDecorationResizeObserver = new ResizeObserver(
      this.didResizeBlockDecorations.bind(this)
    );
    this.lineComponentsByScreenLineId = new Map();
    this.overlayComponents = new Set();
    this.shouldRenderDummyScrollbars = true;
    this.remeasureScrollbars = false;
    this.pendingAutoscroll = null;
    this.scrollTopPending = false;
    this.scrollLeftPending = false;
    this.scrollTop = 0;
    this.scrollLeft = 0;
    this.previousScrollWidth = 0;
    this.previousScrollHeight = 0;
    this.lastKeydown = null;
    this.lastKeydownBeforeKeypress = null;
    this.accentedCharacterMenuIsOpen = false;
    this.remeasureGutterDimensions = false;
    this.guttersToRender = [this.props.model.getLineNumberGutter()];
    this.guttersVisibility = [this.guttersToRender[0].visible];
    this.idsByTileStartRow = new Map();
    this.nextTileId = 0;
    this.renderedTileStartRows = [];
    this.showLineNumbers = this.props.model.doesShowLineNumbers();
    this.lineNumbersToRender = {
      maxDigits: 2,
      bufferRows: [],
      screenRows: [],
      keys: [],
      softWrappedFlags: [],
      foldableFlags: []
    };
    this.decorationsToRender = {
      lineNumbers: new Map(),
      lines: null,
      highlights: [],
      cursors: [],
      overlays: [],
      customGutter: new Map(),
      blocks: new Map(),
      text: []
    };
    this.decorationsToMeasure = {
      highlights: [],
      cursors: new Map()
    };
    this.textDecorationsByMarker = new Map();
    this.textDecorationBoundaries = [];
    this.pendingScrollTopRow = this.props.initialScrollTopRow;
    this.pendingScrollLeftColumn = this.props.initialScrollLeftColumn;
    this.tabIndex =
      this.props.element && this.props.element.tabIndex
        ? this.props.element.tabIndex
        : -1;

    this.measuredContent = false;
    this.queryGuttersToRender();
    this.queryMaxLineNumberDigits();
    this.observeBlockDecorations();
    this.updateClassList();
    etch.updateSync(this);
  }

  update(props) {
    if (props.model !== this.props.model) {
      this.props.model.component = null;
      props.model.component = this;
    }
    this.props = props;
    this.scheduleUpdate();
  }

  pixelPositionForScreenPosition({ row, column }) {
    const top = this.pixelPositionAfterBlocksForRow(row);
    let left = column === 0 ? 0 : this.pixelLeftForRowAndColumn(row, column);
    if (left == null) {
      this.requestHorizontalMeasurement(row, column);
      this.updateSync();
      left = this.pixelLeftForRowAndColumn(row, column);
    }
    return { top, left };
  }

  scheduleUpdate(nextUpdateOnlyBlinksCursors = false) {
    if (!this.visible) return;
    if (this.suppressUpdates) return;

    this.nextUpdateOnlyBlinksCursors =
      this.nextUpdateOnlyBlinksCursors !== false &&
      nextUpdateOnlyBlinksCursors === true;

    if (this.updatedSynchronously) {
      this.updateSync();
    } else if (!this.updateScheduled) {
      this.updateScheduled = true;
      etch.getScheduler().updateDocument(() => {
        if (this.updateScheduled) this.updateSync(true);
      });
    }
  }

  updateSync(useScheduler = false) {
    // Don't proceed if we know we are not visible
    if (!this.visible) {
      this.updateScheduled = false;
      return;
    }

    // Don't proceed if we have to pay for a measurement anyway and detect
    // that we are no longer visible.
    if (
      (this.remeasureCharacterDimensions ||
        this.remeasureAllBlockDecorations) &&
      !this.isVisible()
    ) {
      if (this.resolveNextUpdatePromise) this.resolveNextUpdatePromise();
      this.updateScheduled = false;
      return;
    }

    const onlyBlinkingCursors = this.nextUpdateOnlyBlinksCursors;
    this.nextUpdateOnlyBlinksCursors = null;
    if (useScheduler && onlyBlinkingCursors) {
      this.refs.cursorsAndInput.updateCursorBlinkSync(this.cursorsBlinkedOff);
      if (this.resolveNextUpdatePromise) this.resolveNextUpdatePromise();
      this.updateScheduled = false;
      return;
    }

    if (this.remeasureCharacterDimensions) {
      const originalLineHeight = this.getLineHeight();
      const originalBaseCharacterWidth = this.getBaseCharacterWidth();
      const scrollTopRow = this.getScrollTopRow();
      const scrollLeftColumn = this.getScrollLeftColumn();

      this.measureCharacterDimensions();
      this.measureGutterDimensions();
      this.queryLongestLine();

      if (this.getLineHeight() !== originalLineHeight) {
        this.setScrollTopRow(scrollTopRow);
      }
      if (this.getBaseCharacterWidth() !== originalBaseCharacterWidth) {
        this.setScrollLeftColumn(scrollLeftColumn);
      }
      this.remeasureCharacterDimensions = false;
    }

    this.measureBlockDecorations();

    this.updateSyncBeforeMeasuringContent();
    if (useScheduler === true) {
      const scheduler = etch.getScheduler();
      scheduler.readDocument(() => {
        const restartFrame = this.measureContentDuringUpdateSync();
        scheduler.updateDocument(() => {
          if (restartFrame) {
            this.updateSync(true);
          } else {
            this.updateSyncAfterMeasuringContent();
          }
        });
      });
    } else {
      const restartFrame = this.measureContentDuringUpdateSync();
      if (restartFrame) {
        this.updateSync(false);
      } else {
        this.updateSyncAfterMeasuringContent();
      }
    }

    this.updateScheduled = false;
  }

  measureBlockDecorations() {
    if (this.remeasureAllBlockDecorations) {
      this.remeasureAllBlockDecorations = false;

      const decorations = this.props.model.getDecorations();
      for (var i = 0; i < decorations.length; i++) {
        const decoration = decorations[i];
        const marker = decoration.getMarker();
        if (marker.isValid() && decoration.getProperties().type === 'block') {
          this.blockDecorationsToMeasure.add(decoration);
        }
      }

      // Update the width of the line tiles to ensure block decorations are
      // measured with the most recent width.
      if (this.blockDecorationsToMeasure.size > 0) {
        this.updateSyncBeforeMeasuringContent();
      }
    }

    if (this.blockDecorationsToMeasure.size > 0) {
      const { blockDecorationMeasurementArea } = this.refs;
      const sentinelElements = new Set();

      blockDecorationMeasurementArea.appendChild(document.createElement('div'));
      this.blockDecorationsToMeasure.forEach(decoration => {
        const { item } = decoration.getProperties();
        const decorationElement = TextEditor.viewForItem(item);
        if (document.contains(decorationElement)) {
          const parentElement = decorationElement.parentElement;

          if (!decorationElement.previousSibling) {
            const sentinelElement = this.blockDecorationSentinel.cloneNode();
            parentElement.insertBefore(sentinelElement, decorationElement);
            sentinelElements.add(sentinelElement);
          }

          if (!decorationElement.nextSibling) {
            const sentinelElement = this.blockDecorationSentinel.cloneNode();
            parentElement.appendChild(sentinelElement);
            sentinelElements.add(sentinelElement);
          }

          this.didMeasureVisibleBlockDecoration = true;
        } else {
          blockDecorationMeasurementArea.appendChild(
            this.blockDecorationSentinel.cloneNode()
          );
          blockDecorationMeasurementArea.appendChild(decorationElement);
          blockDecorationMeasurementArea.appendChild(
            this.blockDecorationSentinel.cloneNode()
          );
        }
      });

      if (this.resizeBlockDecorationMeasurementsArea) {
        this.resizeBlockDecorationMeasurementsArea = false;
        this.refs.blockDecorationMeasurementArea.style.width =
          this.getScrollWidth() + 'px';
      }

      this.blockDecorationsToMeasure.forEach(decoration => {
        const { item } = decoration.getProperties();
        const decorationElement = TextEditor.viewForItem(item);
        const { previousSibling, nextSibling } = decorationElement;
        const height =
          nextSibling.getBoundingClientRect().top -
          previousSibling.getBoundingClientRect().bottom;
        this.heightsByBlockDecoration.set(decoration, height);
        this.lineTopIndex.resizeBlock(decoration, height);
      });

      sentinelElements.forEach(sentinelElement => sentinelElement.remove());
      while (blockDecorationMeasurementArea.firstChild) {
        blockDecorationMeasurementArea.firstChild.remove();
      }
      this.blockDecorationsToMeasure.clear();
    }
  }

  updateSyncBeforeMeasuringContent() {
    this.measuredContent = false;
    this.derivedDimensionsCache = {};
    this.updateModelSoftWrapColumn();
    if (this.pendingAutoscroll) {
      let { screenRange, options } = this.pendingAutoscroll;
      this.autoscrollVertically(screenRange, options);
      this.requestHorizontalMeasurement(
        screenRange.start.row,
        screenRange.start.column
      );
      this.requestHorizontalMeasurement(
        screenRange.end.row,
        screenRange.end.column
      );
    }
    this.populateVisibleRowRange(this.getRenderedStartRow());
    this.populateVisibleTiles();
    this.queryScreenLinesToRender();
    this.queryLongestLine();
    this.queryLineNumbersToRender();
    this.queryGuttersToRender();
    this.queryDecorationsToRender();
    this.queryExtraScreenLinesToRender();
    this.shouldRenderDummyScrollbars = !this.remeasureScrollbars;
    etch.updateSync(this);
    this.updateClassList();
    this.shouldRenderDummyScrollbars = true;
    this.didMeasureVisibleBlockDecoration = false;
  }

  measureContentDuringUpdateSync() {
    let gutterDimensionsChanged = false;
    if (this.remeasureGutterDimensions) {
      gutterDimensionsChanged = this.measureGutterDimensions();
      this.remeasureGutterDimensions = false;
    }
    const wasHorizontalScrollbarVisible =
      this.canScrollHorizontally() && this.getHorizontalScrollbarHeight() > 0;

    this.measureLongestLineWidth();
    this.measureHorizontalPositions();
    this.updateAbsolutePositionedDecorations();

    const isHorizontalScrollbarVisible =
      this.canScrollHorizontally() && this.getHorizontalScrollbarHeight() > 0;

    if (this.pendingAutoscroll) {
      this.derivedDimensionsCache = {};
      const { screenRange, options } = this.pendingAutoscroll;
      this.autoscrollHorizontally(screenRange, options);

      if (!wasHorizontalScrollbarVisible && isHorizontalScrollbarVisible) {
        this.autoscrollVertically(screenRange, options);
      }
      this.pendingAutoscroll = null;
    }

    this.linesToMeasure.clear();
    this.measuredContent = true;

    return (
      gutterDimensionsChanged ||
      wasHorizontalScrollbarVisible !== isHorizontalScrollbarVisible
    );
  }

  updateSyncAfterMeasuringContent() {
    this.derivedDimensionsCache = {};
    etch.updateSync(this);

    this.currentFrameLineNumberGutterProps = null;
    this.scrollTopPending = false;
    this.scrollLeftPending = false;
    if (this.remeasureScrollbars) {
      // Flush stored scroll positions to the vertical and the horizontal
      // scrollbars. This is because they have just been destroyed and recreated
      // as a result of their remeasurement, but we could not assign the scroll
      // top while they were initialized because they were not attached to the
      // DOM yet.
      this.refs.verticalScrollbar.flushScrollPosition();
      this.refs.horizontalScrollbar.flushScrollPosition();

      this.measureScrollbarDimensions();
      this.remeasureScrollbars = false;
      etch.updateSync(this);
    }

    this.derivedDimensionsCache = {};
    if (this.resolveNextUpdatePromise) this.resolveNextUpdatePromise();
  }

  render() {
    const { model } = this.props;
    const style = {};

    if (!model.getAutoHeight() && !model.getAutoWidth()) {
      style.contain = 'size';
    }

    let clientContainerHeight = '100%';
    let clientContainerWidth = '100%';
    if (this.hasInitialMeasurements) {
      if (model.getAutoHeight()) {
        clientContainerHeight =
          this.getContentHeight() + this.getHorizontalScrollbarHeight() + 'px';
      }
      if (model.getAutoWidth()) {
        style.width = 'min-content';
        clientContainerWidth =
          this.getGutterContainerWidth() +
          this.getContentWidth() +
          this.getVerticalScrollbarWidth() +
          'px';
      } else {
        style.width = this.element.style.width;
      }
    }

    let attributes = {};
    if (model.isMini()) {
      attributes.mini = '';
    }

    if (model.isReadOnly()) {
      attributes.readonly = '';
    }

    const dataset = { encoding: model.getEncoding() };
    const grammar = model.getGrammar();
    if (grammar && grammar.scopeName) {
      dataset.grammar = grammar.scopeName.replace(/\./g, ' ');
    }

    return $(
      'atom-text-editor',
      {
        // See this.updateClassList() for construction of the class name
        style,
        attributes,
        dataset,
        tabIndex: -1,
        on: { mousewheel: this.didMouseWheel }
      },
      $.div(
        {
          ref: 'clientContainer',
          style: {
            position: 'relative',
            contain: 'strict',
            overflow: 'hidden',
            backgroundColor: 'inherit',
            height: clientContainerHeight,
            width: clientContainerWidth
          }
        },
        this.renderGutterContainer(),
        this.renderScrollContainer()
      ),
      this.renderOverlayDecorations()
    );
  }

  renderGutterContainer() {
    if (this.props.model.isMini()) {
      return null;
    } else {
      return $(GutterContainerComponent, {
        ref: 'gutterContainer',
        key: 'gutterContainer',
        rootComponent: this,
        hasInitialMeasurements: this.hasInitialMeasurements,
        measuredContent: this.measuredContent,
        scrollTop: this.getScrollTop(),
        scrollHeight: this.getScrollHeight(),
        lineNumberGutterWidth: this.getLineNumberGutterWidth(),
        lineHeight: this.getLineHeight(),
        renderedStartRow: this.getRenderedStartRow(),
        renderedEndRow: this.getRenderedEndRow(),
        rowsPerTile: this.getRowsPerTile(),
        guttersToRender: this.guttersToRender,
        decorationsToRender: this.decorationsToRender,
        isLineNumberGutterVisible: this.props.model.isLineNumberGutterVisible(),
        showLineNumbers: this.showLineNumbers,
        lineNumbersToRender: this.lineNumbersToRender,
        didMeasureVisibleBlockDecoration: this.didMeasureVisibleBlockDecoration
      });
    }
  }

  renderScrollContainer() {
    const style = {
      position: 'absolute',
      contain: 'strict',
      overflow: 'hidden',
      top: 0,
      bottom: 0,
      backgroundColor: 'inherit'
    };

    if (this.hasInitialMeasurements) {
      style.left = this.getGutterContainerWidth() + 'px';
      style.width = this.getScrollContainerWidth() + 'px';
    }

    return $.div(
      {
        ref: 'scrollContainer',
        key: 'scrollContainer',
        className: 'scroll-view',
        style
      },
      this.renderContent(),
      this.renderDummyScrollbars()
    );
  }

  renderContent() {
    let style = {
      contain: 'strict',
      overflow: 'hidden',
      backgroundColor: 'inherit'
    };
    if (this.hasInitialMeasurements) {
      style.width = ceilToPhysicalPixelBoundary(this.getScrollWidth()) + 'px';
      style.height = ceilToPhysicalPixelBoundary(this.getScrollHeight()) + 'px';
      style.willChange = 'transform';
      style.transform = `translate(${-roundToPhysicalPixelBoundary(
        this.getScrollLeft()
      )}px, ${-roundToPhysicalPixelBoundary(this.getScrollTop())}px)`;
    }

    return $.div(
      {
        ref: 'content',
        on: { mousedown: this.didMouseDownOnContent },
        style
      },
      this.renderLineTiles(),
      this.renderBlockDecorationMeasurementArea(),
      this.renderCharacterMeasurementLine()
    );
  }

  renderHighlightDecorations() {
    return $(HighlightsComponent, {
      hasInitialMeasurements: this.hasInitialMeasurements,
      highlightDecorations: this.decorationsToRender.highlights.slice(),
      width: this.getScrollWidth(),
      height: this.getScrollHeight(),
      lineHeight: this.getLineHeight()
    });
  }

  renderLineTiles() {
    const style = {
      position: 'absolute',
      contain: 'strict',
      overflow: 'hidden'
    };

    const children = [];
    children.push(this.renderHighlightDecorations());

    if (this.hasInitialMeasurements) {
      const { lineComponentsByScreenLineId } = this;

      const startRow = this.getRenderedStartRow();
      const endRow = this.getRenderedEndRow();
      const rowsPerTile = this.getRowsPerTile();
      const tileWidth = this.getScrollWidth();

      for (let i = 0; i < this.renderedTileStartRows.length; i++) {
        const tileStartRow = this.renderedTileStartRows[i];
        const tileEndRow = Math.min(endRow, tileStartRow + rowsPerTile);
        const tileHeight =
          this.pixelPositionBeforeBlocksForRow(tileEndRow) -
          this.pixelPositionBeforeBlocksForRow(tileStartRow);

        children.push(
          $(LinesTileComponent, {
            key: this.idsByTileStartRow.get(tileStartRow),
            measuredContent: this.measuredContent,
            height: tileHeight,
            width: tileWidth,
            top: this.pixelPositionBeforeBlocksForRow(tileStartRow),
            lineHeight: this.getLineHeight(),
            renderedStartRow: startRow,
            tileStartRow,
            tileEndRow,
            screenLines: this.renderedScreenLines.slice(
              tileStartRow - startRow,
              tileEndRow - startRow
            ),
            lineDecorations: this.decorationsToRender.lines.slice(
              tileStartRow - startRow,
              tileEndRow - startRow
            ),
            textDecorations: this.decorationsToRender.text.slice(
              tileStartRow - startRow,
              tileEndRow - startRow
            ),
            blockDecorations: this.decorationsToRender.blocks.get(tileStartRow),
            displayLayer: this.props.model.displayLayer,
            nodePool: this.lineNodesPool,
            lineComponentsByScreenLineId
          })
        );
      }

      this.extraRenderedScreenLines.forEach((screenLine, screenRow) => {
        if (screenRow < startRow || screenRow >= endRow) {
          children.push(
            $(LineComponent, {
              key: 'extra-' + screenLine.id,
              offScreen: true,
              screenLine,
              screenRow,
              displayLayer: this.props.model.displayLayer,
              nodePool: this.lineNodesPool,
              lineComponentsByScreenLineId
            })
          );
        }
      });

      style.width = this.getScrollWidth() + 'px';
      style.height = this.getScrollHeight() + 'px';
    }

    children.push(this.renderPlaceholderText());
    children.push(this.renderCursorsAndInput());

    return $.div(
      { key: 'lineTiles', ref: 'lineTiles', className: 'lines', style },
      children
    );
  }

  renderCursorsAndInput() {
    return $(CursorsAndInputComponent, {
      ref: 'cursorsAndInput',
      key: 'cursorsAndInput',
      didBlurHiddenInput: this.didBlurHiddenInput,
      didFocusHiddenInput: this.didFocusHiddenInput,
      didTextInput: this.didTextInput,
      didPaste: this.didPaste,
      didKeydown: this.didKeydown,
      didKeyup: this.didKeyup,
      didKeypress: this.didKeypress,
      didCompositionStart: this.didCompositionStart,
      didCompositionUpdate: this.didCompositionUpdate,
      didCompositionEnd: this.didCompositionEnd,
      measuredContent: this.measuredContent,
      lineHeight: this.getLineHeight(),
      scrollHeight: this.getScrollHeight(),
      scrollWidth: this.getScrollWidth(),
      decorationsToRender: this.decorationsToRender,
      cursorsBlinkedOff: this.cursorsBlinkedOff,
      hiddenInputPosition: this.hiddenInputPosition,
      tabIndex: this.tabIndex
    });
  }

  renderPlaceholderText() {
    const { model } = this.props;
    if (model.isEmpty()) {
      const placeholderText = model.getPlaceholderText();
      if (placeholderText != null) {
        return $.div({ className: 'placeholder-text' }, placeholderText);
      }
    }
    return null;
  }

  renderCharacterMeasurementLine() {
    return $.div(
      {
        key: 'characterMeasurementLine',
        ref: 'characterMeasurementLine',
        className: 'line dummy',
        style: { position: 'absolute', visibility: 'hidden' }
      },
      $.span({ ref: 'normalWidthCharacterSpan' }, NORMAL_WIDTH_CHARACTER),
      $.span({ ref: 'doubleWidthCharacterSpan' }, DOUBLE_WIDTH_CHARACTER),
      $.span({ ref: 'halfWidthCharacterSpan' }, HALF_WIDTH_CHARACTER),
      $.span({ ref: 'koreanCharacterSpan' }, KOREAN_CHARACTER)
    );
  }

  renderBlockDecorationMeasurementArea() {
    return $.div({
      ref: 'blockDecorationMeasurementArea',
      key: 'blockDecorationMeasurementArea',
      style: {
        contain: 'strict',
        position: 'absolute',
        visibility: 'hidden',
        width: this.getScrollWidth() + 'px'
      }
    });
  }

  renderDummyScrollbars() {
    if (this.shouldRenderDummyScrollbars && !this.props.model.isMini()) {
      let scrollHeight, scrollTop, horizontalScrollbarHeight;
      let scrollWidth,
        scrollLeft,
        verticalScrollbarWidth,
        forceScrollbarVisible;
      let canScrollHorizontally, canScrollVertically;

      if (this.hasInitialMeasurements) {
        scrollHeight = this.getScrollHeight();
        scrollWidth = this.getScrollWidth();
        scrollTop = this.getScrollTop();
        scrollLeft = this.getScrollLeft();
        canScrollHorizontally = this.canScrollHorizontally();
        canScrollVertically = this.canScrollVertically();
        horizontalScrollbarHeight = this.getHorizontalScrollbarHeight();
        verticalScrollbarWidth = this.getVerticalScrollbarWidth();
        forceScrollbarVisible = this.remeasureScrollbars;
      } else {
        forceScrollbarVisible = true;
      }

      return [
        $(DummyScrollbarComponent, {
          ref: 'verticalScrollbar',
          orientation: 'vertical',
          didScroll: this.didScrollDummyScrollbar,
          didMouseDown: this.didMouseDownOnContent,
          canScroll: canScrollVertically,
          scrollHeight,
          scrollTop,
          horizontalScrollbarHeight,
          forceScrollbarVisible
        }),
        $(DummyScrollbarComponent, {
          ref: 'horizontalScrollbar',
          orientation: 'horizontal',
          didScroll: this.didScrollDummyScrollbar,
          didMouseDown: this.didMouseDownOnContent,
          canScroll: canScrollHorizontally,
          scrollWidth,
          scrollLeft,
          verticalScrollbarWidth,
          forceScrollbarVisible
        }),

        // Force a "corner" to render where the two scrollbars meet at the lower right
        $.div({
          ref: 'scrollbarCorner',
          className: 'scrollbar-corner',
          style: {
            position: 'absolute',
            height: '20px',
            width: '20px',
            bottom: 0,
            right: 0,
            overflow: 'scroll'
          }
        })
      ];
    } else {
      return null;
    }
  }

  renderOverlayDecorations() {
    return this.decorationsToRender.overlays.map(overlayProps =>
      $(
        OverlayComponent,
        Object.assign(
          {
            key: overlayProps.element,
            overlayComponents: this.overlayComponents,
            didResize: overlayComponent => {
              this.updateOverlayToRender(overlayProps);
              overlayComponent.update(overlayProps);
            }
          },
          overlayProps
        )
      )
    );
  }

  // Imperatively manipulate the class list of the root element to avoid
  // clearing classes assigned by package authors.
  updateClassList() {
    const { model } = this.props;

    const oldClassList = this.classList;
    const newClassList = ['editor'];
    if (this.focused) newClassList.push('is-focused');
    if (model.isMini()) newClassList.push('mini');
    for (var i = 0; i < model.selections.length; i++) {
      if (!model.selections[i].isEmpty()) {
        newClassList.push('has-selection');
        break;
      }
    }

    if (oldClassList) {
      for (let i = 0; i < oldClassList.length; i++) {
        const className = oldClassList[i];
        if (!newClassList.includes(className)) {
          this.element.classList.remove(className);
        }
      }
    }

    for (let i = 0; i < newClassList.length; i++) {
      this.element.classList.add(newClassList[i]);
    }

    this.classList = newClassList;
  }

  queryScreenLinesToRender() {
    const { model } = this.props;

    this.renderedScreenLines = model.displayLayer.getScreenLines(
      this.getRenderedStartRow(),
      this.getRenderedEndRow()
    );
  }

  queryLongestLine() {
    const { model } = this.props;

    const longestLineRow = model.getApproximateLongestScreenRow();
    const longestLine = model.screenLineForScreenRow(longestLineRow);
    if (
      longestLine !== this.previousLongestLine ||
      this.remeasureCharacterDimensions
    ) {
      this.requestLineToMeasure(longestLineRow, longestLine);
      this.longestLineToMeasure = longestLine;
      this.previousLongestLine = longestLine;
    }
  }

  queryExtraScreenLinesToRender() {
    this.extraRenderedScreenLines.clear();
    this.linesToMeasure.forEach((screenLine, row) => {
      if (row < this.getRenderedStartRow() || row >= this.getRenderedEndRow()) {
        this.extraRenderedScreenLines.set(row, screenLine);
      }
    });
  }

  queryLineNumbersToRender() {
    const { model } = this.props;
    if (!model.anyLineNumberGutterVisible()) return;
    if (this.showLineNumbers !== model.doesShowLineNumbers()) {
      this.remeasureGutterDimensions = true;
      this.showLineNumbers = model.doesShowLineNumbers();
    }

    this.queryMaxLineNumberDigits();

    const startRow = this.getRenderedStartRow();
    const endRow = this.getRenderedEndRow();
    const renderedRowCount = this.getRenderedRowCount();

    const bufferRows = model.bufferRowsForScreenRows(startRow, endRow);
    const screenRows = new Array(renderedRowCount);
    const keys = new Array(renderedRowCount);
    const foldableFlags = new Array(renderedRowCount);
    const softWrappedFlags = new Array(renderedRowCount);

    let previousBufferRow =
      startRow > 0 ? model.bufferRowForScreenRow(startRow - 1) : -1;
    let softWrapCount = 0;
    for (let row = startRow; row < endRow; row++) {
      const i = row - startRow;
      const bufferRow = bufferRows[i];
      if (bufferRow === previousBufferRow) {
        softWrapCount++;
        softWrappedFlags[i] = true;
        keys[i] = bufferRow + '-' + softWrapCount;
      } else {
        softWrapCount = 0;
        softWrappedFlags[i] = false;
        keys[i] = bufferRow;
      }

      const nextBufferRow = bufferRows[i + 1];
      if (bufferRow !== nextBufferRow) {
        foldableFlags[i] = model.isFoldableAtBufferRow(bufferRow);
      } else {
        foldableFlags[i] = false;
      }

      screenRows[i] = row;
      previousBufferRow = bufferRow;
    }

    // Delete extra buffer row at the end because it's not currently on screen.
    bufferRows.pop();

    this.lineNumbersToRender.bufferRows = bufferRows;
    this.lineNumbersToRender.screenRows = screenRows;
    this.lineNumbersToRender.keys = keys;
    this.lineNumbersToRender.foldableFlags = foldableFlags;
    this.lineNumbersToRender.softWrappedFlags = softWrappedFlags;
  }

  queryMaxLineNumberDigits() {
    const { model } = this.props;
    if (model.anyLineNumberGutterVisible()) {
      const maxDigits = Math.max(2, model.getLineCount().toString().length);
      if (maxDigits !== this.lineNumbersToRender.maxDigits) {
        this.remeasureGutterDimensions = true;
        this.lineNumbersToRender.maxDigits = maxDigits;
      }
    }
  }

  renderedScreenLineForRow(row) {
    return (
      this.renderedScreenLines[row - this.getRenderedStartRow()] ||
      this.extraRenderedScreenLines.get(row)
    );
  }

  queryGuttersToRender() {
    const oldGuttersToRender = this.guttersToRender;
    const oldGuttersVisibility = this.guttersVisibility;
    this.guttersToRender = this.props.model.getGutters();
    this.guttersVisibility = this.guttersToRender.map(g => g.visible);

    if (
      !oldGuttersToRender ||
      oldGuttersToRender.length !== this.guttersToRender.length
    ) {
      this.remeasureGutterDimensions = true;
    } else {
      for (let i = 0, length = this.guttersToRender.length; i < length; i++) {
        if (
          this.guttersToRender[i] !== oldGuttersToRender[i] ||
          this.guttersVisibility[i] !== oldGuttersVisibility[i]
        ) {
          this.remeasureGutterDimensions = true;
          break;
        }
      }
    }
  }

  queryDecorationsToRender() {
    this.decorationsToRender.lineNumbers.clear();
    this.decorationsToRender.lines = [];
    this.decorationsToRender.overlays.length = 0;
    this.decorationsToRender.customGutter.clear();
    this.decorationsToRender.blocks = new Map();
    this.decorationsToRender.text = [];
    this.decorationsToMeasure.highlights.length = 0;
    this.decorationsToMeasure.cursors.clear();
    this.textDecorationsByMarker.clear();
    this.textDecorationBoundaries.length = 0;

    const decorationsByMarker = this.props.model.decorationManager.decorationPropertiesByMarkerForScreenRowRange(
      this.getRenderedStartRow(),
      this.getRenderedEndRow()
    );

    decorationsByMarker.forEach((decorations, marker) => {
      const screenRange = marker.getScreenRange();
      const reversed = marker.isReversed();
      for (let i = 0; i < decorations.length; i++) {
        const decoration = decorations[i];
        this.addDecorationToRender(
          decoration.type,
          decoration,
          marker,
          screenRange,
          reversed
        );
      }
    });

    this.populateTextDecorationsToRender();
  }

  addDecorationToRender(type, decoration, marker, screenRange, reversed) {
    if (Array.isArray(type)) {
      for (let i = 0, length = type.length; i < length; i++) {
        this.addDecorationToRender(
          type[i],
          decoration,
          marker,
          screenRange,
          reversed
        );
      }
    } else {
      switch (type) {
        case 'line':
        case 'line-number':
          this.addLineDecorationToRender(
            type,
            decoration,
            screenRange,
            reversed
          );
          break;
        case 'highlight':
          this.addHighlightDecorationToMeasure(
            decoration,
            screenRange,
            marker.id
          );
          break;
        case 'cursor':
          this.addCursorDecorationToMeasure(
            decoration,
            marker,
            screenRange,
            reversed
          );
          break;
        case 'overlay':
          this.addOverlayDecorationToRender(decoration, marker);
          break;
        case 'gutter':
          this.addCustomGutterDecorationToRender(decoration, screenRange);
          break;
        case 'block':
          this.addBlockDecorationToRender(decoration, screenRange, reversed);
          break;
        case 'text':
          this.addTextDecorationToRender(decoration, screenRange, marker);
          break;
      }
    }
  }

  addLineDecorationToRender(type, decoration, screenRange, reversed) {
    let decorationsToRender;
    if (type === 'line') {
      decorationsToRender = this.decorationsToRender.lines;
    } else {
      const gutterName = decoration.gutterName || 'line-number';
      decorationsToRender = this.decorationsToRender.lineNumbers.get(
        gutterName
      );
      if (!decorationsToRender) {
        decorationsToRender = [];
        this.decorationsToRender.lineNumbers.set(
          gutterName,
          decorationsToRender
        );
      }
    }

    let omitLastRow = false;
    if (screenRange.isEmpty()) {
      if (decoration.onlyNonEmpty) return;
    } else {
      if (decoration.onlyEmpty) return;
      if (decoration.omitEmptyLastRow !== false) {
        omitLastRow = screenRange.end.column === 0;
      }
    }

    const renderedStartRow = this.getRenderedStartRow();
    let rangeStartRow = screenRange.start.row;
    let rangeEndRow = screenRange.end.row;

    if (decoration.onlyHead) {
      if (reversed) {
        rangeEndRow = rangeStartRow;
      } else {
        rangeStartRow = rangeEndRow;
      }
    }

    rangeStartRow = Math.max(rangeStartRow, this.getRenderedStartRow());
    rangeEndRow = Math.min(rangeEndRow, this.getRenderedEndRow() - 1);

    for (let row = rangeStartRow; row <= rangeEndRow; row++) {
      if (omitLastRow && row === screenRange.end.row) break;
      const currentClassName = decorationsToRender[row - renderedStartRow];
      const newClassName = currentClassName
        ? currentClassName + ' ' + decoration.class
        : decoration.class;
      decorationsToRender[row - renderedStartRow] = newClassName;
    }
  }

  addHighlightDecorationToMeasure(decoration, screenRange, key) {
    screenRange = constrainRangeToRows(
      screenRange,
      this.getRenderedStartRow(),
      this.getRenderedEndRow()
    );
    if (screenRange.isEmpty()) return;

    const {
      class: className,
      flashRequested,
      flashClass,
      flashDuration
    } = decoration;
    decoration.flashRequested = false;
    this.decorationsToMeasure.highlights.push({
      screenRange,
      key,
      className,
      flashRequested,
      flashClass,
      flashDuration
    });
    this.requestHorizontalMeasurement(
      screenRange.start.row,
      screenRange.start.column
    );
    this.requestHorizontalMeasurement(
      screenRange.end.row,
      screenRange.end.column
    );
  }

  addCursorDecorationToMeasure(decoration, marker, screenRange, reversed) {
    const { model } = this.props;
    if (!model.getShowCursorOnSelection() && !screenRange.isEmpty()) return;

    let decorationToMeasure = this.decorationsToMeasure.cursors.get(marker);
    if (!decorationToMeasure) {
      const isLastCursor = model.getLastCursor().getMarker() === marker;
      const screenPosition = reversed ? screenRange.start : screenRange.end;
      const { row, column } = screenPosition;

      if (row < this.getRenderedStartRow() || row >= this.getRenderedEndRow())
        return;

      this.requestHorizontalMeasurement(row, column);
      let columnWidth = 0;
      if (model.lineLengthForScreenRow(row) > column) {
        columnWidth = 1;
        this.requestHorizontalMeasurement(row, column + 1);
      }
      decorationToMeasure = { screenPosition, columnWidth, isLastCursor };
      this.decorationsToMeasure.cursors.set(marker, decorationToMeasure);
    }

    if (decoration.class) {
      if (decorationToMeasure.className) {
        decorationToMeasure.className += ' ' + decoration.class;
      } else {
        decorationToMeasure.className = decoration.class;
      }
    }

    if (decoration.style) {
      if (decorationToMeasure.style) {
        Object.assign(decorationToMeasure.style, decoration.style);
      } else {
        decorationToMeasure.style = Object.assign({}, decoration.style);
      }
    }
  }

  addOverlayDecorationToRender(decoration, marker) {
    const { class: className, item, position, avoidOverflow } = decoration;
    const element = TextEditor.viewForItem(item);
    const screenPosition =
      position === 'tail'
        ? marker.getTailScreenPosition()
        : marker.getHeadScreenPosition();

    this.requestHorizontalMeasurement(
      screenPosition.row,
      screenPosition.column
    );
    this.decorationsToRender.overlays.push({
      className,
      element,
      avoidOverflow,
      screenPosition
    });
  }

  addCustomGutterDecorationToRender(decoration, screenRange) {
    let decorations = this.decorationsToRender.customGutter.get(
      decoration.gutterName
    );
    if (!decorations) {
      decorations = [];
      this.decorationsToRender.customGutter.set(
        decoration.gutterName,
        decorations
      );
    }
    const top = this.pixelPositionAfterBlocksForRow(screenRange.start.row);
    const height =
      this.pixelPositionBeforeBlocksForRow(screenRange.end.row + 1) - top;

    decorations.push({
      className:
        'decoration' + (decoration.class ? ' ' + decoration.class : ''),
      element: TextEditor.viewForItem(decoration.item),
      top,
      height
    });
  }

  addBlockDecorationToRender(decoration, screenRange, reversed) {
    const { row } = reversed ? screenRange.start : screenRange.end;
    if (row < this.getRenderedStartRow() || row >= this.getRenderedEndRow())
      return;

    const tileStartRow = this.tileStartRowForRow(row);
    const screenLine = this.renderedScreenLines[
      row - this.getRenderedStartRow()
    ];

    let decorationsByScreenLine = this.decorationsToRender.blocks.get(
      tileStartRow
    );
    if (!decorationsByScreenLine) {
      decorationsByScreenLine = new Map();
      this.decorationsToRender.blocks.set(
        tileStartRow,
        decorationsByScreenLine
      );
    }

    let decorations = decorationsByScreenLine.get(screenLine.id);
    if (!decorations) {
      decorations = [];
      decorationsByScreenLine.set(screenLine.id, decorations);
    }
    decorations.push(decoration);

    // Order block decorations by increasing values of their "order" property. Break ties with "id", which mirrors
    // their creation sequence.
    decorations.sort((a, b) =>
      a.order !== b.order ? a.order - b.order : a.id - b.id
    );
  }

  addTextDecorationToRender(decoration, screenRange, marker) {
    if (screenRange.isEmpty()) return;

    let decorationsForMarker = this.textDecorationsByMarker.get(marker);
    if (!decorationsForMarker) {
      decorationsForMarker = [];
      this.textDecorationsByMarker.set(marker, decorationsForMarker);
      this.textDecorationBoundaries.push({
        position: screenRange.start,
        starting: [marker]
      });
      this.textDecorationBoundaries.push({
        position: screenRange.end,
        ending: [marker]
      });
    }
    decorationsForMarker.push(decoration);
  }

  populateTextDecorationsToRender() {
    // Sort all boundaries in ascending order of position
    this.textDecorationBoundaries.sort((a, b) =>
      a.position.compare(b.position)
    );

    // Combine adjacent boundaries with the same position
    for (let i = 0; i < this.textDecorationBoundaries.length; ) {
      const boundary = this.textDecorationBoundaries[i];
      const nextBoundary = this.textDecorationBoundaries[i + 1];
      if (nextBoundary && nextBoundary.position.isEqual(boundary.position)) {
        if (nextBoundary.starting) {
          if (boundary.starting) {
            boundary.starting.push(...nextBoundary.starting);
          } else {
            boundary.starting = nextBoundary.starting;
          }
        }

        if (nextBoundary.ending) {
          if (boundary.ending) {
            boundary.ending.push(...nextBoundary.ending);
          } else {
            boundary.ending = nextBoundary.ending;
          }
        }

        this.textDecorationBoundaries.splice(i + 1, 1);
      } else {
        i++;
      }
    }

    const renderedStartRow = this.getRenderedStartRow();
    const renderedEndRow = this.getRenderedEndRow();
    const containingMarkers = [];

    // Iterate over boundaries to build up text decorations.
    for (let i = 0; i < this.textDecorationBoundaries.length; i++) {
      const boundary = this.textDecorationBoundaries[i];

      // If multiple markers start here, sort them by order of nesting (markers ending later come first)
      if (boundary.starting && boundary.starting.length > 1) {
        boundary.starting.sort((a, b) => a.compare(b));
      }

      // If multiple markers start here, sort them by order of nesting (markers starting earlier come first)
      if (boundary.ending && boundary.ending.length > 1) {
        boundary.ending.sort((a, b) => b.compare(a));
      }

      // Remove markers ending here from containing markers array
      if (boundary.ending) {
        for (let j = boundary.ending.length - 1; j >= 0; j--) {
          containingMarkers.splice(
            containingMarkers.lastIndexOf(boundary.ending[j]),
            1
          );
        }
      }
      // Add markers starting here to containing markers array
      if (boundary.starting) containingMarkers.push(...boundary.starting);

      // Determine desired className and style based on containing markers
      let className, style;
      for (let j = 0; j < containingMarkers.length; j++) {
        const marker = containingMarkers[j];
        const decorations = this.textDecorationsByMarker.get(marker);
        for (let k = 0; k < decorations.length; k++) {
          const decoration = decorations[k];
          if (decoration.class) {
            if (className) {
              className += ' ' + decoration.class;
            } else {
              className = decoration.class;
            }
          }
          if (decoration.style) {
            if (style) {
              Object.assign(style, decoration.style);
            } else {
              style = Object.assign({}, decoration.style);
            }
          }
        }
      }

      // Add decoration start with className/style for current position's column,
      // and also for the start of every row up until the next decoration boundary
      if (boundary.position.row >= renderedStartRow) {
        this.addTextDecorationStart(
          boundary.position.row,
          boundary.position.column,
          className,
          style
        );
      }
      const nextBoundary = this.textDecorationBoundaries[i + 1];
      if (nextBoundary) {
        let row = Math.max(boundary.position.row + 1, renderedStartRow);
        const endRow = Math.min(nextBoundary.position.row, renderedEndRow);
        for (; row < endRow; row++) {
          this.addTextDecorationStart(row, 0, className, style);
        }

        if (
          row === nextBoundary.position.row &&
          nextBoundary.position.column !== 0
        ) {
          this.addTextDecorationStart(row, 0, className, style);
        }
      }
    }
  }

  addTextDecorationStart(row, column, className, style) {
    const renderedStartRow = this.getRenderedStartRow();
    let decorationStarts = this.decorationsToRender.text[
      row - renderedStartRow
    ];
    if (!decorationStarts) {
      decorationStarts = [];
      this.decorationsToRender.text[row - renderedStartRow] = decorationStarts;
    }
    decorationStarts.push({ column, className, style });
  }

  updateAbsolutePositionedDecorations() {
    this.updateHighlightsToRender();
    this.updateCursorsToRender();
    this.updateOverlaysToRender();
  }

  updateHighlightsToRender() {
    this.decorationsToRender.highlights.length = 0;
    for (let i = 0; i < this.decorationsToMeasure.highlights.length; i++) {
      const highlight = this.decorationsToMeasure.highlights[i];
      const { start, end } = highlight.screenRange;
      highlight.startPixelTop = this.pixelPositionAfterBlocksForRow(start.row);
      highlight.startPixelLeft = this.pixelLeftForRowAndColumn(
        start.row,
        start.column
      );
      highlight.endPixelTop =
        this.pixelPositionAfterBlocksForRow(end.row) + this.getLineHeight();
      highlight.endPixelLeft = this.pixelLeftForRowAndColumn(
        end.row,
        end.column
      );
      this.decorationsToRender.highlights.push(highlight);
    }
  }

  updateCursorsToRender() {
    this.decorationsToRender.cursors.length = 0;

    this.decorationsToMeasure.cursors.forEach(cursor => {
      const { screenPosition, className, style } = cursor;
      const { row, column } = screenPosition;

      const pixelTop = this.pixelPositionAfterBlocksForRow(row);
      const pixelLeft = this.pixelLeftForRowAndColumn(row, column);
      let pixelWidth;
      if (cursor.columnWidth === 0) {
        pixelWidth = this.getBaseCharacterWidth();
      } else {
        pixelWidth = this.pixelLeftForRowAndColumn(row, column + 1) - pixelLeft;
      }

      const cursorPosition = {
        pixelTop,
        pixelLeft,
        pixelWidth,
        className,
        style
      };
      this.decorationsToRender.cursors.push(cursorPosition);
      if (cursor.isLastCursor) this.hiddenInputPosition = cursorPosition;
    });
  }

  updateOverlayToRender(decoration) {
    const windowInnerHeight = this.getWindowInnerHeight();
    const windowInnerWidth = this.getWindowInnerWidth();
    const contentClientRect = this.refs.content.getBoundingClientRect();

    const { element, screenPosition, avoidOverflow } = decoration;
    const { row, column } = screenPosition;
    let wrapperTop =
      contentClientRect.top +
      this.pixelPositionAfterBlocksForRow(row) +
      this.getLineHeight();
    let wrapperLeft =
      contentClientRect.left + this.pixelLeftForRowAndColumn(row, column);
    const clientRect = element.getBoundingClientRect();

    if (avoidOverflow !== false) {
      const computedStyle = window.getComputedStyle(element);
      const elementTop = wrapperTop + parseInt(computedStyle.marginTop);
      const elementBottom = elementTop + clientRect.height;
      const flippedElementTop =
        wrapperTop -
        this.getLineHeight() -
        clientRect.height -
        parseInt(computedStyle.marginBottom);
      const elementLeft = wrapperLeft + parseInt(computedStyle.marginLeft);
      const elementRight = elementLeft + clientRect.width;

      if (elementBottom > windowInnerHeight && flippedElementTop >= 0) {
        wrapperTop -= elementTop - flippedElementTop;
      }
      if (elementLeft < 0) {
        wrapperLeft -= elementLeft;
      } else if (elementRight > windowInnerWidth) {
        wrapperLeft -= elementRight - windowInnerWidth;
      }
    }

    decoration.pixelTop = Math.round(wrapperTop);
    decoration.pixelLeft = Math.round(wrapperLeft);
  }

  updateOverlaysToRender() {
    const overlayCount = this.decorationsToRender.overlays.length;
    if (overlayCount === 0) return null;

    for (let i = 0; i < overlayCount; i++) {
      const decoration = this.decorationsToRender.overlays[i];
      this.updateOverlayToRender(decoration);
    }
  }

  didAttach() {
    if (!this.attached) {
      this.attached = true;
      this.intersectionObserver = new IntersectionObserver(entries => {
        const { intersectionRect } = entries[entries.length - 1];
        if (intersectionRect.width > 0 || intersectionRect.height > 0) {
          this.didShow();
        } else {
          this.didHide();
        }
      });
      this.intersectionObserver.observe(this.element);

      this.resizeObserver = new ResizeObserver(this.didResize.bind(this));
      this.resizeObserver.observe(this.element);

      if (this.refs.gutterContainer) {
        this.gutterContainerResizeObserver = new ResizeObserver(
          this.didResizeGutterContainer.bind(this)
        );
        this.gutterContainerResizeObserver.observe(
          this.refs.gutterContainer.element
        );
      }

      this.overlayComponents.forEach(component => component.didAttach());

      if (this.isVisible()) {
        this.didShow();

        if (this.refs.verticalScrollbar)
          this.refs.verticalScrollbar.flushScrollPosition();
        if (this.refs.horizontalScrollbar)
          this.refs.horizontalScrollbar.flushScrollPosition();
      } else {
        this.didHide();
      }
      if (!this.constructor.attachedComponents) {
        this.constructor.attachedComponents = new Set();
      }
      this.constructor.attachedComponents.add(this);
    }
  }

  didDetach() {
    if (this.attached) {
      this.intersectionObserver.disconnect();
      this.resizeObserver.disconnect();
      if (this.gutterContainerResizeObserver)
        this.gutterContainerResizeObserver.disconnect();
      this.overlayComponents.forEach(component => component.didDetach());

      this.didHide();
      this.attached = false;
      this.constructor.attachedComponents.delete(this);
    }
  }

  didShow() {
    if (!this.visible && this.isVisible()) {
      if (!this.hasInitialMeasurements) this.measureDimensions();
      this.visible = true;
      this.props.model.setVisible(true);
      this.resizeBlockDecorationMeasurementsArea = true;
      this.updateSync();
      this.flushPendingLogicalScrollPosition();
    }
  }

  didHide() {
    if (this.visible) {
      this.visible = false;
      this.props.model.setVisible(false);
    }
  }

  // Called by TextEditorElement so that focus events can be handled before
  // the element is attached to the DOM.
  didFocus() {
    // This element can be focused from a parent custom element's
    // attachedCallback before *its* attachedCallback is fired. This protects
    // against that case.
    if (!this.attached) this.didAttach();

    // The element can be focused before the intersection observer detects that
    // it has been shown for the first time. If this element is being focused,
    // it is necessarily visible, so we call `didShow` to ensure the hidden
    // input is rendered before we try to shift focus to it.
    if (!this.visible) this.didShow();

    if (!this.focused) {
      this.focused = true;
      this.startCursorBlinking();
      this.scheduleUpdate();
    }

    this.getHiddenInput().focus();
  }

  // Called by TextEditorElement so that this function is always the first
  // listener to be fired, even if other listeners are bound before creating
  // the component.
  didBlur(event) {
    if (event.relatedTarget === this.getHiddenInput()) {
      event.stopImmediatePropagation();
    }
  }

  didBlurHiddenInput(event) {
    if (
      this.element !== event.relatedTarget &&
      !this.element.contains(event.relatedTarget)
    ) {
      this.focused = false;
      this.stopCursorBlinking();
      this.scheduleUpdate();
      this.element.dispatchEvent(new FocusEvent(event.type, event));
    }
  }

  didFocusHiddenInput() {
    // Focusing the hidden input when it is off-screen causes the browser to
    // scroll it into view. Since we use synthetic scrolling this behavior
    // causes all the lines to disappear so we counteract it by always setting
    // the scroll position to 0.
    this.refs.scrollContainer.scrollTop = 0;
    this.refs.scrollContainer.scrollLeft = 0;
    if (!this.focused) {
      this.focused = true;
      this.startCursorBlinking();
      this.scheduleUpdate();
    }
  }

  didMouseWheel(event) {
    const scrollSensitivity = this.props.model.getScrollSensitivity() / 100;

    let { wheelDeltaX, wheelDeltaY } = event;

    if (Math.abs(wheelDeltaX) > Math.abs(wheelDeltaY)) {
      wheelDeltaX = wheelDeltaX * scrollSensitivity;
      wheelDeltaY = 0;
    } else {
      wheelDeltaX = 0;
      wheelDeltaY = wheelDeltaY * scrollSensitivity;
    }

    if (this.getPlatform() !== 'darwin' && event.shiftKey) {
      let temp = wheelDeltaX;
      wheelDeltaX = wheelDeltaY;
      wheelDeltaY = temp;
    }

    const scrollLeftChanged =
      wheelDeltaX !== 0 &&
      this.setScrollLeft(this.getScrollLeft() - wheelDeltaX);
    const scrollTopChanged =
      wheelDeltaY !== 0 && this.setScrollTop(this.getScrollTop() - wheelDeltaY);

    if (scrollLeftChanged || scrollTopChanged) {
      event.preventDefault();
      this.updateSync();
    }
  }

  didResize() {
    // Prevent the component from measuring the client container dimensions when
    // getting spurious resize events.
    if (this.isVisible()) {
      const clientContainerWidthChanged = this.measureClientContainerWidth();
      const clientContainerHeightChanged = this.measureClientContainerHeight();
      if (clientContainerWidthChanged || clientContainerHeightChanged) {
        if (clientContainerWidthChanged) {
          this.remeasureAllBlockDecorations = true;
        }

        this.resizeObserver.disconnect();
        this.scheduleUpdate();
        process.nextTick(() => {
          this.resizeObserver.observe(this.element);
        });
      }
    }
  }

  didResizeGutterContainer() {
    // Prevent the component from measuring the gutter dimensions when getting
    // spurious resize events.
    if (this.isVisible() && this.measureGutterDimensions()) {
      this.gutterContainerResizeObserver.disconnect();
      this.scheduleUpdate();
      process.nextTick(() => {
        this.gutterContainerResizeObserver.observe(
          this.refs.gutterContainer.element
        );
      });
    }
  }

  didScrollDummyScrollbar() {
    let scrollTopChanged = false;
    let scrollLeftChanged = false;
    if (!this.scrollTopPending) {
      scrollTopChanged = this.setScrollTop(
        this.refs.verticalScrollbar.element.scrollTop
      );
    }
    if (!this.scrollLeftPending) {
      scrollLeftChanged = this.setScrollLeft(
        this.refs.horizontalScrollbar.element.scrollLeft
      );
    }
    if (scrollTopChanged || scrollLeftChanged) this.updateSync();
  }

  didUpdateStyles() {
    this.remeasureCharacterDimensions = true;
    this.horizontalPixelPositionsByScreenLineId.clear();
    this.scheduleUpdate();
  }

  didUpdateScrollbarStyles() {
    if (!this.props.model.isMini()) {
      this.remeasureScrollbars = true;
      this.scheduleUpdate();
    }
  }

  didPaste(event) {
    // On Linux, Chromium translates a middle-button mouse click into a
    // mousedown event *and* a paste event. Since Atom supports the middle mouse
    // click as a way of closing a tab, we only want the mousedown event, not
    // the paste event. And since we don't use the `paste` event for any
    // behavior in Atom, we can no-op the event to eliminate this issue.
    // See https://github.com/atom/atom/pull/15183#issue-248432413.
    if (this.getPlatform() === 'linux') event.preventDefault();
  }

  didTextInput(event) {
    if (this.compositionCheckpoint) {
      this.props.model.revertToCheckpoint(this.compositionCheckpoint);
      this.compositionCheckpoint = null;
    }

    if (this.isInputEnabled()) {
      event.stopPropagation();

      // WARNING: If we call preventDefault on the input of a space
      // character, then the browser interprets the spacebar keypress as a
      // page-down command, causing spaces to scroll elements containing
      // editors. This means typing space will actually change the contents
      // of the hidden input, which will cause the browser to autoscroll the
      // scroll container to reveal the input if it is off screen (See
      // https://github.com/atom/atom/issues/16046). To correct for this
      // situation, we automatically reset the scroll position to 0,0 after
      // typing a space. None of this can really be tested.
      if (event.data === ' ') {
        window.setImmediate(() => {
          this.refs.scrollContainer.scrollTop = 0;
          this.refs.scrollContainer.scrollLeft = 0;
        });
      } else {
        event.preventDefault();
      }

      // If the input event is fired while the accented character menu is open it
      // means that the user has chosen one of the accented alternatives. Thus, we
      // will replace the original non accented character with the selected
      // alternative.
      if (this.accentedCharacterMenuIsOpen) {
        this.props.model.selectLeft();
      }

      this.props.model.insertText(event.data, { groupUndo: true });
    }
  }

  // We need to get clever to detect when the accented character menu is
  // opened on macOS. Usually, every keydown event that could cause input is
  // followed by a corresponding keypress. However, pressing and holding
  // long enough to open the accented character menu causes additional keydown
  // events to fire that aren't followed by their own keypress and textInput
  // events.
  //
  // Therefore, we assume the accented character menu has been deployed if,
  // before observing any keyup event, we observe events in the following
  // sequence:
  //
  // keydown(code: X), keypress, keydown(code: X)
  //
  // The code X must be the same in the keydown events that bracket the
  // keypress, meaning we're *holding* the _same_ key we intially pressed.
  // Got that?
  didKeydown(event) {
    // Stop dragging when user interacts with the keyboard. This prevents
    // unwanted selections in the case edits are performed while selecting text
    // at the same time. Modifier keys are exempt to preserve the ability to
    // add selections, shift-scroll horizontally while selecting.
    if (
      this.stopDragging &&
      event.key !== 'Control' &&
      event.key !== 'Alt' &&
      event.key !== 'Meta' &&
      event.key !== 'Shift'
    ) {
      this.stopDragging();
    }

    if (this.lastKeydownBeforeKeypress != null) {
      if (this.lastKeydownBeforeKeypress.code === event.code) {
        this.accentedCharacterMenuIsOpen = true;
      }

      this.lastKeydownBeforeKeypress = null;
    }

    this.lastKeydown = event;
  }

  didKeypress(event) {
    this.lastKeydownBeforeKeypress = this.lastKeydown;

    // This cancels the accented character behavior if we type a key normally
    // with the menu open.
    this.accentedCharacterMenuIsOpen = false;
  }

  didKeyup(event) {
    if (
      this.lastKeydownBeforeKeypress &&
      this.lastKeydownBeforeKeypress.code === event.code
    ) {
      this.lastKeydownBeforeKeypress = null;
    }
  }

  // The IME composition events work like this:
  //
  // User types 's', chromium pops up the completion helper
  //   1. compositionstart fired
  //   2. compositionupdate fired; event.data == 's'
  // User hits arrow keys to move around in completion helper
  //   3. compositionupdate fired; event.data == 's' for each arry key press
  // User escape to cancel OR User chooses a completion
  //   4. compositionend fired
  //   5. textInput fired; event.data == the completion string
  didCompositionStart() {
    // Workaround for Chromium not preventing composition events when
    // preventDefault is called on the keydown event that precipitated them.
    if (this.lastKeydown && this.lastKeydown.defaultPrevented) {
      this.getHiddenInput().disabled = true;
      process.nextTick(() => {
        // Disabling the hidden input makes it lose focus as well, so we have to
        // re-enable and re-focus it.
        this.getHiddenInput().disabled = false;
        this.getHiddenInput().focus();
      });
      return;
    }

    this.compositionCheckpoint = this.props.model.createCheckpoint();
    if (this.accentedCharacterMenuIsOpen) {
      this.props.model.selectLeft();
    }
  }

  didCompositionUpdate(event) {
    this.props.model.insertText(event.data, { select: true });
  }

  didCompositionEnd(event) {
    event.target.value = '';
  }

  didMouseDownOnContent(event) {
    const { model } = this.props;
    const { target, button, detail, ctrlKey, shiftKey, metaKey } = event;
    const platform = this.getPlatform();

    // Ignore clicks on block decorations.
    if (target) {
      let element = target;
      while (element && element !== this.element) {
        if (this.blockDecorationsByElement.has(element)) {
          return;
        }

        element = element.parentElement;
      }
    }

    const screenPosition = this.screenPositionForMouseEvent(event);

    if (button === 1) {
      model.setCursorScreenPosition(screenPosition, { autoscroll: false });

      // On Linux, pasting happens on middle click. A textInput event with the
      // contents of the selection clipboard will be dispatched by the browser
      // automatically on mouseup.
      if (platform === 'linux' && this.isInputEnabled())
        model.insertText(clipboard.readText('selection'));
      return;
    }

    if (button !== 0) return;

    // Ctrl-click brings up the context menu on macOS
    if (platform === 'darwin' && ctrlKey) return;

    if (target && target.matches('.fold-marker')) {
      const bufferPosition = model.bufferPositionForScreenPosition(
        screenPosition
      );
      model.destroyFoldsContainingBufferPositions([bufferPosition], false);
      return;
    }

    const allowMultiCursor = atom.config.get('core.editor.multiCursorOnClick');
    const addOrRemoveSelection =
      allowMultiCursor && (metaKey || (ctrlKey && platform !== 'darwin'));

    switch (detail) {
      case 1:
        if (addOrRemoveSelection) {
          const existingSelection = model.getSelectionAtScreenPosition(
            screenPosition
          );
          if (existingSelection) {
            if (model.hasMultipleCursors()) existingSelection.destroy();
          } else {
            model.addCursorAtScreenPosition(screenPosition, {
              autoscroll: false
            });
          }
        } else {
          if (shiftKey) {
            model.selectToScreenPosition(screenPosition, { autoscroll: false });
          } else {
            model.setCursorScreenPosition(screenPosition, {
              autoscroll: false
            });
          }
        }
        break;
      case 2:
        if (addOrRemoveSelection)
          model.addCursorAtScreenPosition(screenPosition, {
            autoscroll: false
          });
        model.getLastSelection().selectWord({ autoscroll: false });
        break;
      case 3:
        if (addOrRemoveSelection)
          model.addCursorAtScreenPosition(screenPosition, {
            autoscroll: false
          });
        model.getLastSelection().selectLine(null, { autoscroll: false });
        break;
    }

    this.handleMouseDragUntilMouseUp({
      didDrag: event => {
        this.autoscrollOnMouseDrag(event);
        const screenPosition = this.screenPositionForMouseEvent(event);
        model.selectToScreenPosition(screenPosition, {
          suppressSelectionMerge: true,
          autoscroll: false
        });
        this.updateSync();
      },
      didStopDragging: () => {
        model.finalizeSelections();
        model.mergeIntersectingSelections();
        this.updateSync();
      }
    });
  }

  didMouseDownOnLineNumberGutter(event) {
    const { model } = this.props;
    const { target, button, ctrlKey, shiftKey, metaKey } = event;

    // Only handle mousedown events for left mouse button
    if (button !== 0) return;

    const clickedScreenRow = this.screenPositionForMouseEvent(event).row;
    const startBufferRow = model.bufferPositionForScreenPosition([
      clickedScreenRow,
      0
    ]).row;

    if (
      target &&
      (target.matches('.foldable .icon-right') ||
        target.matches('.folded .icon-right'))
    ) {
      model.toggleFoldAtBufferRow(startBufferRow);
      return;
    }

    const addOrRemoveSelection =
      metaKey || (ctrlKey && this.getPlatform() !== 'darwin');
    const endBufferRow = model.bufferPositionForScreenPosition([
      clickedScreenRow,
      Infinity
    ]).row;
    const clickedLineBufferRange = Range(
      Point(startBufferRow, 0),
      Point(endBufferRow + 1, 0)
    );

    let initialBufferRange;
    if (shiftKey) {
      const lastSelection = model.getLastSelection();
      initialBufferRange = lastSelection.getBufferRange();
      lastSelection.setBufferRange(
        initialBufferRange.union(clickedLineBufferRange),
        {
          reversed: clickedScreenRow < lastSelection.getScreenRange().start.row,
          autoscroll: false,
          preserveFolds: true,
          suppressSelectionMerge: true
        }
      );
    } else {
      initialBufferRange = clickedLineBufferRange;
      if (addOrRemoveSelection) {
        model.addSelectionForBufferRange(clickedLineBufferRange, {
          autoscroll: false,
          preserveFolds: true
        });
      } else {
        model.setSelectedBufferRange(clickedLineBufferRange, {
          autoscroll: false,
          preserveFolds: true
        });
      }
    }

    const initialScreenRange = model.screenRangeForBufferRange(
      initialBufferRange
    );
    this.handleMouseDragUntilMouseUp({
      didDrag: event => {
        this.autoscrollOnMouseDrag(event, true);
        const dragRow = this.screenPositionForMouseEvent(event).row;
        const draggedLineScreenRange = Range(
          Point(dragRow, 0),
          Point(dragRow + 1, 0)
        );
        model
          .getLastSelection()
          .setScreenRange(draggedLineScreenRange.union(initialScreenRange), {
            reversed: dragRow < initialScreenRange.start.row,
            autoscroll: false,
            preserveFolds: true
          });
        this.updateSync();
      },
      didStopDragging: () => {
        model.mergeIntersectingSelections();
        this.updateSync();
      }
    });
  }

  handleMouseDragUntilMouseUp({ didDrag, didStopDragging }) {
    let dragging = false;
    let lastMousemoveEvent;

    const animationFrameLoop = () => {
      window.requestAnimationFrame(() => {
        if (dragging && this.visible) {
          didDrag(lastMousemoveEvent);
          animationFrameLoop();
        }
      });
    };

    function didMouseMove(event) {
      lastMousemoveEvent = event;
      if (!dragging) {
        dragging = true;
        animationFrameLoop();
      }
    }

    function didMouseUp() {
      this.stopDragging = null;
      window.removeEventListener('mousemove', didMouseMove);
      window.removeEventListener('mouseup', didMouseUp, { capture: true });
      if (dragging) {
        dragging = false;
        didStopDragging();
      }
    }

    window.addEventListener('mousemove', didMouseMove);
    window.addEventListener('mouseup', didMouseUp, { capture: true });
    this.stopDragging = didMouseUp;
  }

  autoscrollOnMouseDrag({ clientX, clientY }, verticalOnly = false) {
    var {
      top,
      bottom,
      left,
      right
    } = this.refs.scrollContainer.getBoundingClientRect(); // Using var to avoid deopt on += assignments below
    top += MOUSE_DRAG_AUTOSCROLL_MARGIN;
    bottom -= MOUSE_DRAG_AUTOSCROLL_MARGIN;
    left += MOUSE_DRAG_AUTOSCROLL_MARGIN;
    right -= MOUSE_DRAG_AUTOSCROLL_MARGIN;

    let yDelta, yDirection;
    if (clientY < top) {
      yDelta = top - clientY;
      yDirection = -1;
    } else if (clientY > bottom) {
      yDelta = clientY - bottom;
      yDirection = 1;
    }

    let xDelta, xDirection;
    if (clientX < left) {
      xDelta = left - clientX;
      xDirection = -1;
    } else if (clientX > right) {
      xDelta = clientX - right;
      xDirection = 1;
    }

    let scrolled = false;
    if (yDelta != null) {
      const scaledDelta = scaleMouseDragAutoscrollDelta(yDelta) * yDirection;
      scrolled = this.setScrollTop(this.getScrollTop() + scaledDelta);
    }

    if (!verticalOnly && xDelta != null) {
      const scaledDelta = scaleMouseDragAutoscrollDelta(xDelta) * xDirection;
      scrolled = this.setScrollLeft(this.getScrollLeft() + scaledDelta);
    }

    if (scrolled) this.updateSync();
  }

  screenPositionForMouseEvent(event) {
    return this.screenPositionForPixelPosition(
      this.pixelPositionForMouseEvent(event)
    );
  }

  pixelPositionForMouseEvent({ clientX, clientY }) {
    const scrollContainerRect = this.refs.scrollContainer.getBoundingClientRect();
    clientX = Math.min(
      scrollContainerRect.right,
      Math.max(scrollContainerRect.left, clientX)
    );
    clientY = Math.min(
      scrollContainerRect.bottom,
      Math.max(scrollContainerRect.top, clientY)
    );
    const linesRect = this.refs.lineTiles.getBoundingClientRect();
    return {
      top: clientY - linesRect.top,
      left: clientX - linesRect.left
    };
  }

  didUpdateSelections() {
    this.pauseCursorBlinking();
    this.scheduleUpdate();
  }

  pauseCursorBlinking() {
    this.stopCursorBlinking();
    this.debouncedResumeCursorBlinking();
  }

  resumeCursorBlinking() {
    this.cursorsBlinkedOff = true;
    this.startCursorBlinking();
  }

  stopCursorBlinking() {
    if (this.cursorsBlinking) {
      this.cursorsBlinkedOff = false;
      this.cursorsBlinking = false;
      window.clearInterval(this.cursorBlinkIntervalHandle);
      this.cursorBlinkIntervalHandle = null;
      this.scheduleUpdate();
    }
  }

  startCursorBlinking() {
    if (!this.cursorsBlinking) {
      this.cursorBlinkIntervalHandle = window.setInterval(() => {
        this.cursorsBlinkedOff = !this.cursorsBlinkedOff;
        this.scheduleUpdate(true);
      }, (this.props.cursorBlinkPeriod || CURSOR_BLINK_PERIOD) / 2);
      this.cursorsBlinking = true;
      this.scheduleUpdate(true);
    }
  }

  didRequestAutoscroll(autoscroll) {
    this.pendingAutoscroll = autoscroll;
    this.scheduleUpdate();
  }

  flushPendingLogicalScrollPosition() {
    let changedScrollTop = false;
    if (this.pendingScrollTopRow > 0) {
      changedScrollTop = this.setScrollTopRow(this.pendingScrollTopRow, false);
      this.pendingScrollTopRow = null;
    }

    let changedScrollLeft = false;
    if (this.pendingScrollLeftColumn > 0) {
      changedScrollLeft = this.setScrollLeftColumn(
        this.pendingScrollLeftColumn,
        false
      );
      this.pendingScrollLeftColumn = null;
    }

    if (changedScrollTop || changedScrollLeft) {
      this.updateSync();
    }
  }

  autoscrollVertically(screenRange, options) {
    const screenRangeTop = this.pixelPositionAfterBlocksForRow(
      screenRange.start.row
    );
    const screenRangeBottom =
      this.pixelPositionAfterBlocksForRow(screenRange.end.row) +
      this.getLineHeight();
    const verticalScrollMargin = this.getVerticalAutoscrollMargin();

    let desiredScrollTop, desiredScrollBottom;
    if (options && options.center) {
      const desiredScrollCenter = (screenRangeTop + screenRangeBottom) / 2;
      if (
        desiredScrollCenter < this.getScrollTop() ||
        desiredScrollCenter > this.getScrollBottom()
      ) {
        desiredScrollTop =
          desiredScrollCenter - this.getScrollContainerClientHeight() / 2;
        desiredScrollBottom =
          desiredScrollCenter + this.getScrollContainerClientHeight() / 2;
      }
    } else {
      desiredScrollTop = screenRangeTop - verticalScrollMargin;
      desiredScrollBottom = screenRangeBottom + verticalScrollMargin;
    }

    if (!options || options.reversed !== false) {
      if (desiredScrollBottom > this.getScrollBottom()) {
        this.setScrollBottom(desiredScrollBottom);
      }
      if (desiredScrollTop < this.getScrollTop()) {
        this.setScrollTop(desiredScrollTop);
      }
    } else {
      if (desiredScrollTop < this.getScrollTop()) {
        this.setScrollTop(desiredScrollTop);
      }
      if (desiredScrollBottom > this.getScrollBottom()) {
        this.setScrollBottom(desiredScrollBottom);
      }
    }

    return false;
  }

  autoscrollHorizontally(screenRange, options) {
    const horizontalScrollMargin = this.getHorizontalAutoscrollMargin();

    const gutterContainerWidth = this.getGutterContainerWidth();
    let left =
      this.pixelLeftForRowAndColumn(
        screenRange.start.row,
        screenRange.start.column
      ) + gutterContainerWidth;
    let right =
      this.pixelLeftForRowAndColumn(
        screenRange.end.row,
        screenRange.end.column
      ) + gutterContainerWidth;
    const desiredScrollLeft = Math.max(
      0,
      left - horizontalScrollMargin - gutterContainerWidth
    );
    const desiredScrollRight = Math.min(
      this.getScrollWidth(),
      right + horizontalScrollMargin
    );

    if (!options || options.reversed !== false) {
      if (desiredScrollRight > this.getScrollRight()) {
        this.setScrollRight(desiredScrollRight);
      }
      if (desiredScrollLeft < this.getScrollLeft()) {
        this.setScrollLeft(desiredScrollLeft);
      }
    } else {
      if (desiredScrollLeft < this.getScrollLeft()) {
        this.setScrollLeft(desiredScrollLeft);
      }
      if (desiredScrollRight > this.getScrollRight()) {
        this.setScrollRight(desiredScrollRight);
      }
    }
  }

  getVerticalAutoscrollMargin() {
    const maxMarginInLines = Math.floor(
      (this.getScrollContainerClientHeight() / this.getLineHeight() - 1) / 2
    );
    const marginInLines = Math.min(
      this.props.model.verticalScrollMargin,
      maxMarginInLines
    );
    return marginInLines * this.getLineHeight();
  }

  getHorizontalAutoscrollMargin() {
    const maxMarginInBaseCharacters = Math.floor(
      (this.getScrollContainerClientWidth() / this.getBaseCharacterWidth() -
        1) /
        2
    );
    const marginInBaseCharacters = Math.min(
      this.props.model.horizontalScrollMargin,
      maxMarginInBaseCharacters
    );
    return marginInBaseCharacters * this.getBaseCharacterWidth();
  }

  // This method is called at the beginning of a frame render to relay any
  // potential changes in the editor's width into the model before proceeding.
  updateModelSoftWrapColumn() {
    const { model } = this.props;
    const newEditorWidthInChars = this.getScrollContainerClientWidthInBaseCharacters();
    if (newEditorWidthInChars !== model.getEditorWidthInChars()) {
      this.suppressUpdates = true;

      const renderedStartRow = this.getRenderedStartRow();
      this.props.model.setEditorWidthInChars(newEditorWidthInChars);

      // Relaying a change in to the editor's client width may cause the
      // vertical scrollbar to appear or disappear, which causes the editor's
      // client width to change *again*. Make sure the display layer is fully
      // populated for the visible area before recalculating the editor's
      // width in characters. Then update the display layer *again* just in
      // case a change in scrollbar visibility causes lines to wrap
      // differently. We capture the renderedStartRow before resetting the
      // display layer because once it has been reset, we can't compute the
      // rendered start row accurately. 😥
      this.populateVisibleRowRange(renderedStartRow);
      this.props.model.setEditorWidthInChars(
        this.getScrollContainerClientWidthInBaseCharacters()
      );
      this.derivedDimensionsCache = {};

      this.suppressUpdates = false;
    }
  }

  // This method exists because it existed in the previous implementation and some
  // package tests relied on it
  measureDimensions() {
    this.measureCharacterDimensions();
    this.measureGutterDimensions();
    this.measureClientContainerHeight();
    this.measureClientContainerWidth();
    this.measureScrollbarDimensions();
    this.hasInitialMeasurements = true;
  }

  measureCharacterDimensions() {
    this.measurements.lineHeight = Math.max(
      1,
      this.refs.characterMeasurementLine.getBoundingClientRect().height
    );
    this.measurements.baseCharacterWidth = this.refs.normalWidthCharacterSpan.getBoundingClientRect().width;
    this.measurements.doubleWidthCharacterWidth = this.refs.doubleWidthCharacterSpan.getBoundingClientRect().width;
    this.measurements.halfWidthCharacterWidth = this.refs.halfWidthCharacterSpan.getBoundingClientRect().width;
    this.measurements.koreanCharacterWidth = this.refs.koreanCharacterSpan.getBoundingClientRect().width;

    this.props.model.setLineHeightInPixels(this.measurements.lineHeight);
    this.props.model.setDefaultCharWidth(
      this.measurements.baseCharacterWidth,
      this.measurements.doubleWidthCharacterWidth,
      this.measurements.halfWidthCharacterWidth,
      this.measurements.koreanCharacterWidth
    );
    this.lineTopIndex.setDefaultLineHeight(this.measurements.lineHeight);
  }

  measureGutterDimensions() {
    let dimensionsChanged = false;

    if (this.refs.gutterContainer) {
      const gutterContainerWidth = this.refs.gutterContainer.element
        .offsetWidth;
      if (gutterContainerWidth !== this.measurements.gutterContainerWidth) {
        dimensionsChanged = true;
        this.measurements.gutterContainerWidth = gutterContainerWidth;
      }
    } else {
      this.measurements.gutterContainerWidth = 0;
    }

    if (
      this.refs.gutterContainer &&
      this.refs.gutterContainer.refs.lineNumberGutter
    ) {
      const lineNumberGutterWidth = this.refs.gutterContainer.refs
        .lineNumberGutter.element.offsetWidth;
      if (lineNumberGutterWidth !== this.measurements.lineNumberGutterWidth) {
        dimensionsChanged = true;
        this.measurements.lineNumberGutterWidth = lineNumberGutterWidth;
      }
    } else {
      this.measurements.lineNumberGutterWidth = 0;
    }

    return dimensionsChanged;
  }

  measureClientContainerHeight() {
    const clientContainerHeight = this.refs.clientContainer.offsetHeight;
    if (clientContainerHeight !== this.measurements.clientContainerHeight) {
      this.measurements.clientContainerHeight = clientContainerHeight;
      return true;
    } else {
      return false;
    }
  }

  measureClientContainerWidth() {
    const clientContainerWidth = this.refs.clientContainer.offsetWidth;
    if (clientContainerWidth !== this.measurements.clientContainerWidth) {
      this.measurements.clientContainerWidth = clientContainerWidth;
      return true;
    } else {
      return false;
    }
  }

  measureScrollbarDimensions() {
    if (this.props.model.isMini()) {
      this.measurements.verticalScrollbarWidth = 0;
      this.measurements.horizontalScrollbarHeight = 0;
    } else {
      this.measurements.verticalScrollbarWidth = this.refs.verticalScrollbar.getRealScrollbarWidth();
      this.measurements.horizontalScrollbarHeight = this.refs.horizontalScrollbar.getRealScrollbarHeight();
    }
  }

  measureLongestLineWidth() {
    if (this.longestLineToMeasure) {
      const lineComponent = this.lineComponentsByScreenLineId.get(
        this.longestLineToMeasure.id
      );
      this.measurements.longestLineWidth =
        lineComponent.element.firstChild.offsetWidth;
      this.longestLineToMeasure = null;
    }
  }

  requestLineToMeasure(row, screenLine) {
    this.linesToMeasure.set(row, screenLine);
  }

  requestHorizontalMeasurement(row, column) {
    if (column === 0) return;

    const screenLine = this.props.model.screenLineForScreenRow(row);
    if (screenLine) {
      this.requestLineToMeasure(row, screenLine);

      let columns = this.horizontalPositionsToMeasure.get(row);
      if (columns == null) {
        columns = [];
        this.horizontalPositionsToMeasure.set(row, columns);
      }
      columns.push(column);
    }
  }

  measureHorizontalPositions() {
    this.horizontalPositionsToMeasure.forEach((columnsToMeasure, row) => {
      columnsToMeasure.sort((a, b) => a - b);

      const screenLine = this.renderedScreenLineForRow(row);
      const lineComponent = this.lineComponentsByScreenLineId.get(
        screenLine.id
      );

      if (!lineComponent) {
        const error = new Error(
          'Requested measurement of a line component that is not currently rendered'
        );
        error.metadata = {
          row,
          columnsToMeasure,
          renderedScreenLineIds: this.renderedScreenLines.map(line => line.id),
          extraRenderedScreenLineIds: Array.from(
            this.extraRenderedScreenLines.keys()
          ),
          lineComponentScreenLineIds: Array.from(
            this.lineComponentsByScreenLineId.keys()
          ),
          renderedStartRow: this.getRenderedStartRow(),
          renderedEndRow: this.getRenderedEndRow(),
          requestedScreenLineId: screenLine.id
        };
        throw error;
      }

      const lineNode = lineComponent.element;
      const textNodes = lineComponent.textNodes;
      let positionsForLine = this.horizontalPixelPositionsByScreenLineId.get(
        screenLine.id
      );
      if (positionsForLine == null) {
        positionsForLine = new Map();
        this.horizontalPixelPositionsByScreenLineId.set(
          screenLine.id,
          positionsForLine
        );
      }

      this.measureHorizontalPositionsOnLine(
        lineNode,
        textNodes,
        columnsToMeasure,
        positionsForLine
      );
    });
    this.horizontalPositionsToMeasure.clear();
  }

  measureHorizontalPositionsOnLine(
    lineNode,
    textNodes,
    columnsToMeasure,
    positions
  ) {
    let lineNodeClientLeft = -1;
    let textNodeStartColumn = 0;
    let textNodesIndex = 0;
    let lastTextNodeRight = null;

    // eslint-disable-next-line no-labels
    columnLoop: for (
      let columnsIndex = 0;
      columnsIndex < columnsToMeasure.length;
      columnsIndex++
    ) {
      const nextColumnToMeasure = columnsToMeasure[columnsIndex];
      while (textNodesIndex < textNodes.length) {
        if (nextColumnToMeasure === 0) {
          positions.set(0, 0);
          continue columnLoop; // eslint-disable-line no-labels
        }

        if (positions.has(nextColumnToMeasure)) continue columnLoop; // eslint-disable-line no-labels
        const textNode = textNodes[textNodesIndex];
        const textNodeEndColumn =
          textNodeStartColumn + textNode.textContent.length;

        if (nextColumnToMeasure < textNodeEndColumn) {
          let clientPixelPosition;
          if (nextColumnToMeasure === textNodeStartColumn) {
            clientPixelPosition = clientRectForRange(textNode, 0, 1).left;
          } else {
            clientPixelPosition = clientRectForRange(
              textNode,
              0,
              nextColumnToMeasure - textNodeStartColumn
            ).right;
          }

          if (lineNodeClientLeft === -1) {
            lineNodeClientLeft = lineNode.getBoundingClientRect().left;
          }

          positions.set(
            nextColumnToMeasure,
            Math.round(clientPixelPosition - lineNodeClientLeft)
          );
          continue columnLoop; // eslint-disable-line no-labels
        } else {
          textNodesIndex++;
          textNodeStartColumn = textNodeEndColumn;
        }
      }

      if (lastTextNodeRight == null) {
        const lastTextNode = textNodes[textNodes.length - 1];
        lastTextNodeRight = clientRectForRange(
          lastTextNode,
          0,
          lastTextNode.textContent.length
        ).right;
      }

      if (lineNodeClientLeft === -1) {
        lineNodeClientLeft = lineNode.getBoundingClientRect().left;
      }

      positions.set(
        nextColumnToMeasure,
        Math.round(lastTextNodeRight - lineNodeClientLeft)
      );
    }
  }

  rowForPixelPosition(pixelPosition) {
    return Math.max(0, this.lineTopIndex.rowForPixelPosition(pixelPosition));
  }

  heightForBlockDecorationsBeforeRow(row) {
    return (
      this.pixelPositionAfterBlocksForRow(row) -
      this.pixelPositionBeforeBlocksForRow(row)
    );
  }

  heightForBlockDecorationsAfterRow(row) {
    const currentRowBottom =
      this.pixelPositionAfterBlocksForRow(row) + this.getLineHeight();
    const nextRowTop = this.pixelPositionBeforeBlocksForRow(row + 1);
    return nextRowTop - currentRowBottom;
  }

  pixelPositionBeforeBlocksForRow(row) {
    return this.lineTopIndex.pixelPositionBeforeBlocksForRow(row);
  }

  pixelPositionAfterBlocksForRow(row) {
    return this.lineTopIndex.pixelPositionAfterBlocksForRow(row);
  }

  pixelLeftForRowAndColumn(row, column) {
    if (column === 0) return 0;
    const screenLine = this.renderedScreenLineForRow(row);
    if (screenLine) {
      const horizontalPositionsByColumn = this.horizontalPixelPositionsByScreenLineId.get(
        screenLine.id
      );
      if (horizontalPositionsByColumn) {
        return horizontalPositionsByColumn.get(column);
      }
    }
  }

  screenPositionForPixelPosition({ top, left }) {
    const { model } = this.props;

    const row = Math.min(
      this.rowForPixelPosition(top),
      model.getApproximateScreenLineCount() - 1
    );

    let screenLine = this.renderedScreenLineForRow(row);
    if (!screenLine) {
      this.requestLineToMeasure(row, model.screenLineForScreenRow(row));
      this.updateSyncBeforeMeasuringContent();
      this.measureContentDuringUpdateSync();
      screenLine = this.renderedScreenLineForRow(row);
    }

    const linesClientLeft = this.refs.lineTiles.getBoundingClientRect().left;
    const targetClientLeft = linesClientLeft + Math.max(0, left);
    const { textNodes } = this.lineComponentsByScreenLineId.get(screenLine.id);

    let containingTextNodeIndex;
    {
      let low = 0;
      let high = textNodes.length - 1;
      while (low <= high) {
        const mid = low + ((high - low) >> 1);
        const textNode = textNodes[mid];
        const textNodeRect = clientRectForRange(textNode, 0, textNode.length);

        if (targetClientLeft < textNodeRect.left) {
          high = mid - 1;
          containingTextNodeIndex = Math.max(0, mid - 1);
        } else if (targetClientLeft > textNodeRect.right) {
          low = mid + 1;
          containingTextNodeIndex = Math.min(textNodes.length - 1, mid + 1);
        } else {
          containingTextNodeIndex = mid;
          break;
        }
      }
    }
    const containingTextNode = textNodes[containingTextNodeIndex];
    let characterIndex = 0;
    {
      let low = 0;
      let high = containingTextNode.length - 1;
      while (low <= high) {
        const charIndex = low + ((high - low) >> 1);
        const nextCharIndex = isPairedCharacter(
          containingTextNode.textContent,
          charIndex
        )
          ? charIndex + 2
          : charIndex + 1;

        const rangeRect = clientRectForRange(
          containingTextNode,
          charIndex,
          nextCharIndex
        );
        if (targetClientLeft < rangeRect.left) {
          high = charIndex - 1;
          characterIndex = Math.max(0, charIndex - 1);
        } else if (targetClientLeft > rangeRect.right) {
          low = nextCharIndex;
          characterIndex = Math.min(
            containingTextNode.textContent.length,
            nextCharIndex
          );
        } else {
          if (targetClientLeft <= (rangeRect.left + rangeRect.right) / 2) {
            characterIndex = charIndex;
          } else {
            characterIndex = nextCharIndex;
          }
          break;
        }
      }
    }

    let textNodeStartColumn = 0;
    for (let i = 0; i < containingTextNodeIndex; i++) {
      textNodeStartColumn = textNodeStartColumn + textNodes[i].length;
    }
    const column = textNodeStartColumn + characterIndex;

    return Point(row, column);
  }

  didResetDisplayLayer() {
    this.spliceLineTopIndex(0, Infinity, Infinity);
    this.scheduleUpdate();
  }

  didChangeDisplayLayer(changes) {
    for (let i = 0; i < changes.length; i++) {
      const { oldRange, newRange } = changes[i];
      this.spliceLineTopIndex(
        newRange.start.row,
        oldRange.end.row - oldRange.start.row,
        newRange.end.row - newRange.start.row
      );
    }

    this.scheduleUpdate();
  }

  didChangeSelectionRange() {
    const { model } = this.props;

    if (this.getPlatform() === 'linux') {
      if (this.selectionClipboardImmediateId) {
        clearImmediate(this.selectionClipboardImmediateId);
      }

      this.selectionClipboardImmediateId = setImmediate(() => {
        this.selectionClipboardImmediateId = null;

        if (model.isDestroyed()) return;

        const selectedText = model.getSelectedText();
        if (selectedText) {
          // This uses ipcRenderer.send instead of clipboard.writeText because
          // clipboard.writeText is a sync ipcRenderer call on Linux and that
          // will slow down selections.
          electron.ipcRenderer.send(
            'write-text-to-selection-clipboard',
            selectedText
          );
        }
      });
    }
  }

  observeBlockDecorations() {
    const { model } = this.props;
    const decorations = model.getDecorations({ type: 'block' });
    for (let i = 0; i < decorations.length; i++) {
      this.addBlockDecoration(decorations[i]);
    }
  }

  addBlockDecoration(decoration, subscribeToChanges = true) {
    const marker = decoration.getMarker();
    const { item, position } = decoration.getProperties();
    const element = TextEditor.viewForItem(item);

    if (marker.isValid()) {
      const row = marker.getHeadScreenPosition().row;
      this.lineTopIndex.insertBlock(decoration, row, 0, position === 'after');
      this.blockDecorationsToMeasure.add(decoration);
      this.blockDecorationsByElement.set(element, decoration);
      this.blockDecorationResizeObserver.observe(element);

      this.scheduleUpdate();
    }

    if (subscribeToChanges) {
      let wasValid = marker.isValid();

      const didUpdateDisposable = marker.bufferMarker.onDidChange(
        ({ textChanged }) => {
          const isValid = marker.isValid();
          if (wasValid && !isValid) {
            wasValid = false;
            this.blockDecorationsToMeasure.delete(decoration);
            this.heightsByBlockDecoration.delete(decoration);
            this.blockDecorationsByElement.delete(element);
            this.blockDecorationResizeObserver.unobserve(element);
            this.lineTopIndex.removeBlock(decoration);
            this.scheduleUpdate();
          } else if (!wasValid && isValid) {
            wasValid = true;
            this.addBlockDecoration(decoration, false);
          } else if (isValid && !textChanged) {
            this.lineTopIndex.moveBlock(
              decoration,
              marker.getHeadScreenPosition().row
            );
            this.scheduleUpdate();
          }
        }
      );

      const didDestroyDisposable = decoration.onDidDestroy(() => {
        didUpdateDisposable.dispose();
        didDestroyDisposable.dispose();

        if (wasValid) {
          wasValid = false;
          this.blockDecorationsToMeasure.delete(decoration);
          this.heightsByBlockDecoration.delete(decoration);
          this.blockDecorationsByElement.delete(element);
          this.blockDecorationResizeObserver.unobserve(element);
          this.lineTopIndex.removeBlock(decoration);
          this.scheduleUpdate();
        }
      });
    }
  }

  didResizeBlockDecorations(entries) {
    if (!this.visible) return;

    for (let i = 0; i < entries.length; i++) {
      const { target, contentRect } = entries[i];
      const decoration = this.blockDecorationsByElement.get(target);
      const previousHeight = this.heightsByBlockDecoration.get(decoration);
      if (
        this.element.contains(target) &&
        contentRect.height !== previousHeight
      ) {
        this.invalidateBlockDecorationDimensions(decoration);
      }
    }
  }

  invalidateBlockDecorationDimensions(decoration) {
    this.blockDecorationsToMeasure.add(decoration);
    this.scheduleUpdate();
  }

  spliceLineTopIndex(startRow, oldExtent, newExtent) {
    const invalidatedBlockDecorations = this.lineTopIndex.splice(
      startRow,
      oldExtent,
      newExtent
    );
    invalidatedBlockDecorations.forEach(decoration => {
      const newPosition = decoration.getMarker().getHeadScreenPosition();
      this.lineTopIndex.moveBlock(decoration, newPosition.row);
    });
  }

  isVisible() {
    return this.element.offsetWidth > 0 || this.element.offsetHeight > 0;
  }

  getWindowInnerHeight() {
    return window.innerHeight;
  }

  getWindowInnerWidth() {
    return window.innerWidth;
  }

  getLineHeight() {
    return this.measurements.lineHeight;
  }

  getBaseCharacterWidth() {
    return this.measurements.baseCharacterWidth;
  }

  getLongestLineWidth() {
    return this.measurements.longestLineWidth;
  }

  getClientContainerHeight() {
    return this.measurements.clientContainerHeight;
  }

  getClientContainerWidth() {
    return this.measurements.clientContainerWidth;
  }

  getScrollContainerWidth() {
    if (this.props.model.getAutoWidth()) {
      return this.getScrollWidth();
    } else {
      return this.getClientContainerWidth() - this.getGutterContainerWidth();
    }
  }

  getScrollContainerHeight() {
    if (this.props.model.getAutoHeight()) {
      return this.getScrollHeight() + this.getHorizontalScrollbarHeight();
    } else {
      return this.getClientContainerHeight();
    }
  }

  getScrollContainerClientWidth() {
    return this.getScrollContainerWidth() - this.getVerticalScrollbarWidth();
  }

  getScrollContainerClientHeight() {
    return (
      this.getScrollContainerHeight() - this.getHorizontalScrollbarHeight()
    );
  }

  canScrollVertically() {
    const { model } = this.props;
    if (model.isMini()) return false;
    if (model.getAutoHeight()) return false;
    return this.getContentHeight() > this.getScrollContainerClientHeight();
  }

  canScrollHorizontally() {
    const { model } = this.props;
    if (model.isMini()) return false;
    if (model.getAutoWidth()) return false;
    if (model.isSoftWrapped()) return false;
    return this.getContentWidth() > this.getScrollContainerClientWidth();
  }

  getScrollHeight() {
    if (this.props.model.getScrollPastEnd()) {
      return (
        this.getContentHeight() +
        Math.max(
          3 * this.getLineHeight(),
          this.getScrollContainerClientHeight() - 3 * this.getLineHeight()
        )
      );
    } else if (this.props.model.getAutoHeight()) {
      return this.getContentHeight();
    } else {
      return Math.max(
        this.getContentHeight(),
        this.getScrollContainerClientHeight()
      );
    }
  }

  getScrollWidth() {
    const { model } = this.props;

    if (model.isSoftWrapped()) {
      return this.getScrollContainerClientWidth();
    } else if (model.getAutoWidth()) {
      return this.getContentWidth();
    } else {
      return Math.max(
        this.getContentWidth(),
        this.getScrollContainerClientWidth()
      );
    }
  }

  getContentHeight() {
    return this.pixelPositionAfterBlocksForRow(
      this.props.model.getApproximateScreenLineCount()
    );
  }

  getContentWidth() {
    return Math.ceil(this.getLongestLineWidth() + this.getBaseCharacterWidth());
  }

  getScrollContainerClientWidthInBaseCharacters() {
    return Math.floor(
      this.getScrollContainerClientWidth() / this.getBaseCharacterWidth()
    );
  }

  getGutterContainerWidth() {
    return this.measurements.gutterContainerWidth;
  }

  getLineNumberGutterWidth() {
    return this.measurements.lineNumberGutterWidth;
  }

  getVerticalScrollbarWidth() {
    return this.measurements.verticalScrollbarWidth;
  }

  getHorizontalScrollbarHeight() {
    return this.measurements.horizontalScrollbarHeight;
  }

  getRowsPerTile() {
    return this.props.rowsPerTile || DEFAULT_ROWS_PER_TILE;
  }

  tileStartRowForRow(row) {
    return row - (row % this.getRowsPerTile());
  }

  getRenderedStartRow() {
    if (this.derivedDimensionsCache.renderedStartRow == null) {
      this.derivedDimensionsCache.renderedStartRow = this.tileStartRowForRow(
        this.getFirstVisibleRow()
      );
    }

    return this.derivedDimensionsCache.renderedStartRow;
  }

  getRenderedEndRow() {
    if (this.derivedDimensionsCache.renderedEndRow == null) {
      this.derivedDimensionsCache.renderedEndRow = Math.min(
        this.props.model.getApproximateScreenLineCount(),
        this.getRenderedStartRow() +
          this.getVisibleTileCount() * this.getRowsPerTile()
      );
    }

    return this.derivedDimensionsCache.renderedEndRow;
  }

  getRenderedRowCount() {
    if (this.derivedDimensionsCache.renderedRowCount == null) {
      this.derivedDimensionsCache.renderedRowCount = Math.max(
        0,
        this.getRenderedEndRow() - this.getRenderedStartRow()
      );
    }

    return this.derivedDimensionsCache.renderedRowCount;
  }

  getRenderedTileCount() {
    if (this.derivedDimensionsCache.renderedTileCount == null) {
      this.derivedDimensionsCache.renderedTileCount = Math.ceil(
        this.getRenderedRowCount() / this.getRowsPerTile()
      );
    }

    return this.derivedDimensionsCache.renderedTileCount;
  }

  getFirstVisibleRow() {
    if (this.derivedDimensionsCache.firstVisibleRow == null) {
      this.derivedDimensionsCache.firstVisibleRow = this.rowForPixelPosition(
        this.getScrollTop()
      );
    }

    return this.derivedDimensionsCache.firstVisibleRow;
  }

  getLastVisibleRow() {
    if (this.derivedDimensionsCache.lastVisibleRow == null) {
      this.derivedDimensionsCache.lastVisibleRow = Math.min(
        this.props.model.getApproximateScreenLineCount() - 1,
        this.rowForPixelPosition(this.getScrollBottom())
      );
    }

    return this.derivedDimensionsCache.lastVisibleRow;
  }

  // We may render more tiles than needed if some contain block decorations,
  // but keeping this calculation simple ensures the number of tiles remains
  // fixed for a given editor height, which eliminates situations where a
  // tile is repeatedly added and removed during scrolling in certain
  // combinations of editor height and line height.
  getVisibleTileCount() {
    if (this.derivedDimensionsCache.visibleTileCount == null) {
      const editorHeightInTiles =
        this.getScrollContainerHeight() /
        this.getLineHeight() /
        this.getRowsPerTile();
      this.derivedDimensionsCache.visibleTileCount =
        Math.ceil(editorHeightInTiles) + 1;
    }
    return this.derivedDimensionsCache.visibleTileCount;
  }

  getFirstVisibleColumn() {
    return Math.floor(this.getScrollLeft() / this.getBaseCharacterWidth());
  }

  getScrollTop() {
    this.scrollTop = Math.min(this.getMaxScrollTop(), this.scrollTop);
    return this.scrollTop;
  }

  setScrollTop(scrollTop) {
    if (Number.isNaN(scrollTop) || scrollTop == null) return false;

    scrollTop = roundToPhysicalPixelBoundary(
      Math.max(0, Math.min(this.getMaxScrollTop(), scrollTop))
    );
    if (scrollTop !== this.scrollTop) {
      this.derivedDimensionsCache = {};
      this.scrollTopPending = true;
      this.scrollTop = scrollTop;
      this.element.emitter.emit('did-change-scroll-top', scrollTop);
      return true;
    } else {
      return false;
    }
  }

  getMaxScrollTop() {
    return Math.round(
      Math.max(
        0,
        this.getScrollHeight() - this.getScrollContainerClientHeight()
      )
    );
  }

  getScrollBottom() {
    return this.getScrollTop() + this.getScrollContainerClientHeight();
  }

  setScrollBottom(scrollBottom) {
    return this.setScrollTop(
      scrollBottom - this.getScrollContainerClientHeight()
    );
  }

  getScrollLeft() {
    return this.scrollLeft;
  }

  setScrollLeft(scrollLeft) {
    if (Number.isNaN(scrollLeft) || scrollLeft == null) return false;

    scrollLeft = roundToPhysicalPixelBoundary(
      Math.max(0, Math.min(this.getMaxScrollLeft(), scrollLeft))
    );
    if (scrollLeft !== this.scrollLeft) {
      this.scrollLeftPending = true;
      this.scrollLeft = scrollLeft;
      this.element.emitter.emit('did-change-scroll-left', scrollLeft);
      return true;
    } else {
      return false;
    }
  }

  getMaxScrollLeft() {
    return Math.round(
      Math.max(0, this.getScrollWidth() - this.getScrollContainerClientWidth())
    );
  }

  getScrollRight() {
    return this.getScrollLeft() + this.getScrollContainerClientWidth();
  }

  setScrollRight(scrollRight) {
    return this.setScrollLeft(
      scrollRight - this.getScrollContainerClientWidth()
    );
  }

  setScrollTopRow(scrollTopRow, scheduleUpdate = true) {
    if (this.hasInitialMeasurements) {
      const didScroll = this.setScrollTop(
        this.pixelPositionBeforeBlocksForRow(scrollTopRow)
      );
      if (didScroll && scheduleUpdate) {
        this.scheduleUpdate();
      }
      return didScroll;
    } else {
      this.pendingScrollTopRow = scrollTopRow;
      return false;
    }
  }

  getScrollTopRow() {
    if (this.hasInitialMeasurements) {
      return this.rowForPixelPosition(this.getScrollTop());
    } else {
      return this.pendingScrollTopRow || 0;
    }
  }

  setScrollLeftColumn(scrollLeftColumn, scheduleUpdate = true) {
    if (this.hasInitialMeasurements && this.getLongestLineWidth() != null) {
      const didScroll = this.setScrollLeft(
        scrollLeftColumn * this.getBaseCharacterWidth()
      );
      if (didScroll && scheduleUpdate) {
        this.scheduleUpdate();
      }
      return didScroll;
    } else {
      this.pendingScrollLeftColumn = scrollLeftColumn;
      return false;
    }
  }

  getScrollLeftColumn() {
    if (this.hasInitialMeasurements && this.getLongestLineWidth() != null) {
      return Math.round(this.getScrollLeft() / this.getBaseCharacterWidth());
    } else {
      return this.pendingScrollLeftColumn || 0;
    }
  }

  // Ensure the spatial index is populated with rows that are currently visible
  populateVisibleRowRange(renderedStartRow) {
    const { model } = this.props;
    const previousScreenLineCount = model.getApproximateScreenLineCount();

    const renderedEndRow =
      renderedStartRow + this.getVisibleTileCount() * this.getRowsPerTile();
    this.props.model.displayLayer.populateSpatialIndexIfNeeded(
      Infinity,
      renderedEndRow
    );

    // If the approximate screen line count changes, previously-cached derived
    // dimensions could now be out of date.
    if (model.getApproximateScreenLineCount() !== previousScreenLineCount) {
      this.derivedDimensionsCache = {};
    }
  }

  populateVisibleTiles() {
    const startRow = this.getRenderedStartRow();
    const endRow = this.getRenderedEndRow();
    const freeTileIds = [];
    for (let i = 0; i < this.renderedTileStartRows.length; i++) {
      const tileStartRow = this.renderedTileStartRows[i];
      if (tileStartRow < startRow || tileStartRow >= endRow) {
        const tileId = this.idsByTileStartRow.get(tileStartRow);
        freeTileIds.push(tileId);
        this.idsByTileStartRow.delete(tileStartRow);
      }
    }

    const rowsPerTile = this.getRowsPerTile();
    this.renderedTileStartRows.length = this.getRenderedTileCount();
    for (
      let tileStartRow = startRow, i = 0;
      tileStartRow < endRow;
      tileStartRow = tileStartRow + rowsPerTile, i++
    ) {
      this.renderedTileStartRows[i] = tileStartRow;
      if (!this.idsByTileStartRow.has(tileStartRow)) {
        if (freeTileIds.length > 0) {
          this.idsByTileStartRow.set(tileStartRow, freeTileIds.shift());
        } else {
          this.idsByTileStartRow.set(tileStartRow, this.nextTileId++);
        }
      }
    }

    this.renderedTileStartRows.sort(
      (a, b) => this.idsByTileStartRow.get(a) - this.idsByTileStartRow.get(b)
    );
  }

  getNextUpdatePromise() {
    if (!this.nextUpdatePromise) {
      this.nextUpdatePromise = new Promise(resolve => {
        this.resolveNextUpdatePromise = () => {
          this.nextUpdatePromise = null;
          this.resolveNextUpdatePromise = null;
          resolve();
        };
      });
    }
    return this.nextUpdatePromise;
  }

  setInputEnabled(inputEnabled) {
    this.props.model.update({ keyboardInputEnabled: inputEnabled });
  }

  isInputEnabled() {
    return (
      !this.props.model.isReadOnly() &&
      this.props.model.isKeyboardInputEnabled()
    );
  }

  getHiddenInput() {
    return this.refs.cursorsAndInput.refs.hiddenInput;
  }

  getPlatform() {
    return this.props.platform || process.platform;
  }

  getChromeVersion() {
    return this.props.chromeVersion || parseInt(process.versions.chrome);
  }
};

class DummyScrollbarComponent {
  constructor(props) {
    this.props = props;
    etch.initialize(this);
  }

  update(newProps) {
    const oldProps = this.props;
    this.props = newProps;
    etch.updateSync(this);

    const shouldFlushScrollPosition =
      newProps.scrollTop !== oldProps.scrollTop ||
      newProps.scrollLeft !== oldProps.scrollLeft;
    if (shouldFlushScrollPosition) this.flushScrollPosition();
  }

  flushScrollPosition() {
    if (this.props.orientation === 'horizontal') {
      this.element.scrollLeft = this.props.scrollLeft;
    } else {
      this.element.scrollTop = this.props.scrollTop;
    }
  }

  render() {
    const {
      orientation,
      scrollWidth,
      scrollHeight,
      verticalScrollbarWidth,
      horizontalScrollbarHeight,
      canScroll,
      forceScrollbarVisible,
      didScroll
    } = this.props;

    const outerStyle = {
      position: 'absolute',
      contain: 'content',
      zIndex: 1,
      willChange: 'transform'
    };
    if (!canScroll) outerStyle.visibility = 'hidden';

    const innerStyle = {};
    if (orientation === 'horizontal') {
      let right = verticalScrollbarWidth || 0;
      outerStyle.bottom = 0;
      outerStyle.left = 0;
      outerStyle.right = right + 'px';
      outerStyle.height = '15px';
      outerStyle.overflowY = 'hidden';
      outerStyle.overflowX = forceScrollbarVisible ? 'scroll' : 'auto';
      outerStyle.cursor = 'default';
      innerStyle.height = '15px';
      innerStyle.width = (scrollWidth || 0) + 'px';
    } else {
      let bottom = horizontalScrollbarHeight || 0;
      outerStyle.right = 0;
      outerStyle.top = 0;
      outerStyle.bottom = bottom + 'px';
      outerStyle.width = '15px';
      outerStyle.overflowX = 'hidden';
      outerStyle.overflowY = forceScrollbarVisible ? 'scroll' : 'auto';
      outerStyle.cursor = 'default';
      innerStyle.width = '15px';
      innerStyle.height = (scrollHeight || 0) + 'px';
    }

    return $.div(
      {
        className: `${orientation}-scrollbar`,
        style: outerStyle,
        on: {
          scroll: didScroll,
          mousedown: this.didMouseDown
        }
      },
      $.div({ style: innerStyle })
    );
  }

  didMouseDown(event) {
    let { bottom, right } = this.element.getBoundingClientRect();
    const clickedOnScrollbar =
      this.props.orientation === 'horizontal'
        ? event.clientY >= bottom - this.getRealScrollbarHeight()
        : event.clientX >= right - this.getRealScrollbarWidth();
    if (!clickedOnScrollbar) this.props.didMouseDown(event);
  }

  getRealScrollbarWidth() {
    return this.element.offsetWidth - this.element.clientWidth;
  }

  getRealScrollbarHeight() {
    return this.element.offsetHeight - this.element.clientHeight;
  }
}

class GutterContainerComponent {
  constructor(props) {
    this.props = props;
    etch.initialize(this);
  }

  update(props) {
    if (this.shouldUpdate(props)) {
      this.props = props;
      etch.updateSync(this);
    }
  }

  shouldUpdate(props) {
    return (
      !props.measuredContent ||
      props.lineNumberGutterWidth !== this.props.lineNumberGutterWidth
    );
  }

  render() {
    const {
      hasInitialMeasurements,
      scrollTop,
      scrollHeight,
      guttersToRender,
      decorationsToRender
    } = this.props;

    const innerStyle = {
      willChange: 'transform',
      display: 'flex'
    };

    if (hasInitialMeasurements) {
      innerStyle.transform = `translateY(${-roundToPhysicalPixelBoundary(
        scrollTop
      )}px)`;
    }

    return $.div(
      {
        ref: 'gutterContainer',
        key: 'gutterContainer',
        className: 'gutter-container',
        style: {
          position: 'relative',
          zIndex: 1,
          backgroundColor: 'inherit'
        }
      },
      $.div(
        { style: innerStyle },
        guttersToRender.map(gutter => {
          if (gutter.type === 'line-number') {
            return this.renderLineNumberGutter(gutter);
          } else {
            return $(CustomGutterComponent, {
              key: gutter,
              element: gutter.getElement(),
              name: gutter.name,
              visible: gutter.isVisible(),
              height: scrollHeight,
              decorations: decorationsToRender.customGutter.get(gutter.name)
            });
          }
        })
      )
    );
  }

  renderLineNumberGutter(gutter) {
    const {
      rootComponent,
      showLineNumbers,
      hasInitialMeasurements,
      lineNumbersToRender,
      renderedStartRow,
      renderedEndRow,
      rowsPerTile,
      decorationsToRender,
      didMeasureVisibleBlockDecoration,
      scrollHeight,
      lineNumberGutterWidth,
      lineHeight
    } = this.props;

    if (!gutter.isVisible()) {
      return null;
    }

    const oneTrueLineNumberGutter = gutter.name === 'line-number';
    const ref = oneTrueLineNumberGutter ? 'lineNumberGutter' : undefined;
    const width = oneTrueLineNumberGutter ? lineNumberGutterWidth : undefined;

    if (hasInitialMeasurements) {
      const {
        maxDigits,
        keys,
        bufferRows,
        screenRows,
        softWrappedFlags,
        foldableFlags
      } = lineNumbersToRender;
      return $(LineNumberGutterComponent, {
        ref,
        element: gutter.getElement(),
        name: gutter.name,
        className: gutter.className,
        labelFn: gutter.labelFn,
        onMouseDown: gutter.onMouseDown,
        onMouseMove: gutter.onMouseMove,
        rootComponent: rootComponent,
        startRow: renderedStartRow,
        endRow: renderedEndRow,
        rowsPerTile: rowsPerTile,
        maxDigits: maxDigits,
        keys: keys,
        bufferRows: bufferRows,
        screenRows: screenRows,
        softWrappedFlags: softWrappedFlags,
        foldableFlags: foldableFlags,
        decorations: decorationsToRender.lineNumbers.get(gutter.name) || [],
        blockDecorations: decorationsToRender.blocks,
        didMeasureVisibleBlockDecoration: didMeasureVisibleBlockDecoration,
        height: scrollHeight,
        width,
        lineHeight: lineHeight,
        showLineNumbers
      });
    } else {
      return $(LineNumberGutterComponent, {
        ref,
        element: gutter.getElement(),
        name: gutter.name,
        className: gutter.className,
        onMouseDown: gutter.onMouseDown,
        onMouseMove: gutter.onMouseMove,
        maxDigits: lineNumbersToRender.maxDigits,
        showLineNumbers
      });
    }
  }
}

class LineNumberGutterComponent {
  constructor(props) {
    this.props = props;
    this.element = this.props.element;
    this.virtualNode = $.div(null);
    this.virtualNode.domNode = this.element;
    this.nodePool = new NodePool();
    etch.updateSync(this);
  }

  update(newProps) {
    if (this.shouldUpdate(newProps)) {
      this.props = newProps;
      etch.updateSync(this);
    }
  }

  render() {
    const {
      rootComponent,
      showLineNumbers,
      height,
      width,
      startRow,
      endRow,
      rowsPerTile,
      maxDigits,
      keys,
      bufferRows,
      screenRows,
      softWrappedFlags,
      foldableFlags,
      decorations,
      className
    } = this.props;

    let children = null;

    if (bufferRows) {
      children = new Array(rootComponent.renderedTileStartRows.length);
      for (let i = 0; i < rootComponent.renderedTileStartRows.length; i++) {
        const tileStartRow = rootComponent.renderedTileStartRows[i];
        const tileEndRow = Math.min(endRow, tileStartRow + rowsPerTile);
        const tileChildren = new Array(tileEndRow - tileStartRow);
        for (let row = tileStartRow; row < tileEndRow; row++) {
          const indexInTile = row - tileStartRow;
          const j = row - startRow;
          const key = keys[j];
          const softWrapped = softWrappedFlags[j];
          const foldable = foldableFlags[j];
          const bufferRow = bufferRows[j];
          const screenRow = screenRows[j];

          let className = 'line-number';
          if (foldable) className = className + ' foldable';

          const decorationsForRow = decorations[row - startRow];
          if (decorationsForRow)
            className = className + ' ' + decorationsForRow;

          let number = null;
          if (showLineNumbers) {
            if (this.props.labelFn == null) {
              number = softWrapped ? '•' : bufferRow + 1;
              number =
                NBSP_CHARACTER.repeat(maxDigits - number.length) + number;
            } else {
              number = this.props.labelFn({
                bufferRow,
                screenRow,
                foldable,
                softWrapped,
                maxDigits
              });
            }
          }

          // We need to adjust the line number position to account for block
          // decorations preceding the current row and following the preceding
          // row. Note that we ignore the latter when the line number starts at
          // the beginning of the tile, because the tile will already be
          // positioned to take into account block decorations added after the
          // last row of the previous tile.
          let marginTop = rootComponent.heightForBlockDecorationsBeforeRow(row);
          if (indexInTile > 0)
            marginTop += rootComponent.heightForBlockDecorationsAfterRow(
              row - 1
            );

          tileChildren[row - tileStartRow] = $(LineNumberComponent, {
            key,
            className,
            width,
            bufferRow,
            screenRow,
            number,
            marginTop,
            nodePool: this.nodePool
          });
        }

        const tileTop = rootComponent.pixelPositionBeforeBlocksForRow(
          tileStartRow
        );
        const tileBottom = rootComponent.pixelPositionBeforeBlocksForRow(
          tileEndRow
        );
        const tileHeight = tileBottom - tileTop;
        const tileWidth = width != null && width > 0 ? width + 'px' : '';

        children[i] = $.div(
          {
            key: rootComponent.idsByTileStartRow.get(tileStartRow),
            style: {
              contain: 'layout style',
              position: 'absolute',
              top: 0,
              height: tileHeight + 'px',
              width: tileWidth,
              transform: `translateY(${tileTop}px)`
            }
          },
          ...tileChildren
        );
      }
    }

    let rootClassName = 'gutter line-numbers';
    if (className) {
      rootClassName += ' ' + className;
    }

    return $.div(
      {
        className: rootClassName,
        attributes: { 'gutter-name': this.props.name },
        style: {
          position: 'relative',
          height: ceilToPhysicalPixelBoundary(height) + 'px'
        },
        on: {
          mousedown: this.didMouseDown,
          mousemove: this.didMouseMove
        }
      },
      $.div(
        {
          key: 'placeholder',
          className: 'line-number dummy',
          style: { visibility: 'hidden' }
        },
        showLineNumbers ? '0'.repeat(maxDigits) : null,
        $.div({ className: 'icon-right' })
      ),
      children
    );
  }

  shouldUpdate(newProps) {
    const oldProps = this.props;

    if (oldProps.showLineNumbers !== newProps.showLineNumbers) return true;
    if (oldProps.height !== newProps.height) return true;
    if (oldProps.width !== newProps.width) return true;
    if (oldProps.lineHeight !== newProps.lineHeight) return true;
    if (oldProps.startRow !== newProps.startRow) return true;
    if (oldProps.endRow !== newProps.endRow) return true;
    if (oldProps.rowsPerTile !== newProps.rowsPerTile) return true;
    if (oldProps.maxDigits !== newProps.maxDigits) return true;
    if (oldProps.labelFn !== newProps.labelFn) return true;
    if (oldProps.className !== newProps.className) return true;
    if (newProps.didMeasureVisibleBlockDecoration) return true;
    if (!arraysEqual(oldProps.keys, newProps.keys)) return true;
    if (!arraysEqual(oldProps.bufferRows, newProps.bufferRows)) return true;
    if (!arraysEqual(oldProps.foldableFlags, newProps.foldableFlags))
      return true;
    if (!arraysEqual(oldProps.decorations, newProps.decorations)) return true;

    let oldTileStartRow = oldProps.startRow;
    let newTileStartRow = newProps.startRow;
    while (
      oldTileStartRow < oldProps.endRow ||
      newTileStartRow < newProps.endRow
    ) {
      let oldTileBlockDecorations = oldProps.blockDecorations.get(
        oldTileStartRow
      );
      let newTileBlockDecorations = newProps.blockDecorations.get(
        newTileStartRow
      );

      if (oldTileBlockDecorations && newTileBlockDecorations) {
        if (oldTileBlockDecorations.size !== newTileBlockDecorations.size)
          return true;

        let blockDecorationsChanged = false;

        oldTileBlockDecorations.forEach((oldDecorations, screenLineId) => {
          if (!blockDecorationsChanged) {
            const newDecorations = newTileBlockDecorations.get(screenLineId);
            blockDecorationsChanged =
              newDecorations == null ||
              !arraysEqual(oldDecorations, newDecorations);
          }
        });
        if (blockDecorationsChanged) return true;

        newTileBlockDecorations.forEach((newDecorations, screenLineId) => {
          if (!blockDecorationsChanged) {
            const oldDecorations = oldTileBlockDecorations.get(screenLineId);
            blockDecorationsChanged = oldDecorations == null;
          }
        });
        if (blockDecorationsChanged) return true;
      } else if (oldTileBlockDecorations) {
        return true;
      } else if (newTileBlockDecorations) {
        return true;
      }

      oldTileStartRow += oldProps.rowsPerTile;
      newTileStartRow += newProps.rowsPerTile;
    }

    return false;
  }

  didMouseDown(event) {
    if (this.props.onMouseDown == null) {
      this.props.rootComponent.didMouseDownOnLineNumberGutter(event);
    } else {
      const { bufferRow, screenRow } = event.target.dataset;
      this.props.onMouseDown({
        bufferRow: parseInt(bufferRow, 10),
        screenRow: parseInt(screenRow, 10),
        domEvent: event
      });
    }
  }

  didMouseMove(event) {
    if (this.props.onMouseMove != null) {
      const { bufferRow, screenRow } = event.target.dataset;
      this.props.onMouseMove({
        bufferRow: parseInt(bufferRow, 10),
        screenRow: parseInt(screenRow, 10),
        domEvent: event
      });
    }
  }
}

class LineNumberComponent {
  constructor(props) {
    const {
      className,
      width,
      marginTop,
      bufferRow,
      screenRow,
      number,
      nodePool
    } = props;
    this.props = props;
    const style = {};
    if (width != null && width > 0) style.width = width + 'px';
    if (marginTop != null && marginTop > 0) style.marginTop = marginTop + 'px';
    this.element = nodePool.getElement('DIV', className, style);
    this.element.dataset.bufferRow = bufferRow;
    this.element.dataset.screenRow = screenRow;
    if (number) this.element.appendChild(nodePool.getTextNode(number));
    this.element.appendChild(nodePool.getElement('DIV', 'icon-right', null));
  }

  destroy() {
    this.element.remove();
    this.props.nodePool.release(this.element);
  }

  update(props) {
    const {
      nodePool,
      className,
      width,
      marginTop,
      bufferRow,
      screenRow,
      number
    } = props;

    if (this.props.bufferRow !== bufferRow)
      this.element.dataset.bufferRow = bufferRow;
    if (this.props.screenRow !== screenRow)
      this.element.dataset.screenRow = screenRow;
    if (this.props.className !== className) this.element.className = className;
    if (this.props.width !== width) {
      if (width != null && width > 0) {
        this.element.style.width = width + 'px';
      } else {
        this.element.style.width = '';
      }
    }
    if (this.props.marginTop !== marginTop) {
      if (marginTop != null && marginTop > 0) {
        this.element.style.marginTop = marginTop + 'px';
      } else {
        this.element.style.marginTop = '';
      }
    }

    if (this.props.number !== number) {
      if (this.props.number != null) {
        const numberNode = this.element.firstChild;
        numberNode.remove();
        nodePool.release(numberNode);
      }

      if (number != null) {
        this.element.insertBefore(
          nodePool.getTextNode(number),
          this.element.firstChild
        );
      }
    }

    this.props = props;
  }
}

class CustomGutterComponent {
  constructor(props) {
    this.props = props;
    this.element = this.props.element;
    this.virtualNode = $.div(null);
    this.virtualNode.domNode = this.element;
    etch.updateSync(this);
  }

  update(props) {
    this.props = props;
    etch.updateSync(this);
  }

  destroy() {
    etch.destroy(this);
  }

  render() {
    let className = 'gutter';
    if (this.props.className) {
      className += ' ' + this.props.className;
    }
    return $.div(
      {
        className,
        attributes: { 'gutter-name': this.props.name },
        style: {
          display: this.props.visible ? '' : 'none'
        }
      },
      $.div(
        {
          className: 'custom-decorations',
          style: { height: this.props.height + 'px' }
        },
        this.renderDecorations()
      )
    );
  }

  renderDecorations() {
    if (!this.props.decorations) return null;

    return this.props.decorations.map(({ className, element, top, height }) => {
      return $(CustomGutterDecorationComponent, {
        className,
        element,
        top,
        height
      });
    });
  }
}

class CustomGutterDecorationComponent {
  constructor(props) {
    this.props = props;
    this.element = document.createElement('div');
    const { top, height, className, element } = this.props;

    this.element.style.position = 'absolute';
    this.element.style.top = top + 'px';
    this.element.style.height = height + 'px';
    if (className != null) this.element.className = className;
    if (element != null) {
      this.element.appendChild(element);
      element.style.height = height + 'px';
    }
  }

  update(newProps) {
    const oldProps = this.props;
    this.props = newProps;

    if (newProps.top !== oldProps.top)
      this.element.style.top = newProps.top + 'px';
    if (newProps.height !== oldProps.height) {
      this.element.style.height = newProps.height + 'px';
      if (newProps.element)
        newProps.element.style.height = newProps.height + 'px';
    }
    if (newProps.className !== oldProps.className)
      this.element.className = newProps.className || '';
    if (newProps.element !== oldProps.element) {
      if (this.element.firstChild) this.element.firstChild.remove();
      if (newProps.element != null) {
        this.element.appendChild(newProps.element);
        newProps.element.style.height = newProps.height + 'px';
      }
    }
  }
}

class CursorsAndInputComponent {
  constructor(props) {
    this.props = props;
    etch.initialize(this);
  }

  update(props) {
    if (props.measuredContent) {
      this.props = props;
      etch.updateSync(this);
    }
  }

  updateCursorBlinkSync(cursorsBlinkedOff) {
    this.props.cursorsBlinkedOff = cursorsBlinkedOff;
    const className = this.getCursorsClassName();
    this.refs.cursors.className = className;
    this.virtualNode.props.className = className;
  }

  render() {
    const {
      lineHeight,
      decorationsToRender,
      scrollHeight,
      scrollWidth
    } = this.props;

    const className = this.getCursorsClassName();
    const cursorHeight = lineHeight + 'px';

    const children = [this.renderHiddenInput()];
    for (let i = 0; i < decorationsToRender.cursors.length; i++) {
      const {
        pixelLeft,
        pixelTop,
        pixelWidth,
        className: extraCursorClassName,
        style: extraCursorStyle
      } = decorationsToRender.cursors[i];
      let cursorClassName = 'cursor';
      if (extraCursorClassName) cursorClassName += ' ' + extraCursorClassName;

      const cursorStyle = {
        height: cursorHeight,
        width: Math.min(pixelWidth, scrollWidth - pixelLeft) + 'px',
        transform: `translate(${pixelLeft}px, ${pixelTop}px)`
      };
      if (extraCursorStyle) Object.assign(cursorStyle, extraCursorStyle);

      children.push(
        $.div({
          className: cursorClassName,
          style: cursorStyle
        })
      );
    }

    return $.div(
      {
        key: 'cursors',
        ref: 'cursors',
        className,
        style: {
          position: 'absolute',
          contain: 'strict',
          zIndex: 1,
          width: scrollWidth + 'px',
          height: scrollHeight + 'px',
          pointerEvents: 'none',
          userSelect: 'none'
        }
      },
      children
    );
  }

  getCursorsClassName() {
    return this.props.cursorsBlinkedOff ? 'cursors blink-off' : 'cursors';
  }

  renderHiddenInput() {
    const {
      lineHeight,
      hiddenInputPosition,
      didBlurHiddenInput,
      didFocusHiddenInput,
      didPaste,
      didTextInput,
      didKeydown,
      didKeyup,
      didKeypress,
      didCompositionStart,
      didCompositionUpdate,
      didCompositionEnd,
      tabIndex
    } = this.props;

    let top, left;
    if (hiddenInputPosition) {
      top = hiddenInputPosition.pixelTop;
      left = hiddenInputPosition.pixelLeft;
    } else {
      top = 0;
      left = 0;
    }

    return $.input({
      ref: 'hiddenInput',
      key: 'hiddenInput',
      className: 'hidden-input',
      on: {
        blur: didBlurHiddenInput,
        focus: didFocusHiddenInput,
        paste: didPaste,
        textInput: didTextInput,
        keydown: didKeydown,
        keyup: didKeyup,
        keypress: didKeypress,
        compositionstart: didCompositionStart,
        compositionupdate: didCompositionUpdate,
        compositionend: didCompositionEnd
      },
      tabIndex: tabIndex,
      style: {
        position: 'absolute',
        width: '1px',
        height: lineHeight + 'px',
        top: top + 'px',
        left: left + 'px',
        opacity: 0,
        padding: 0,
        border: 0
      }
    });
  }
}

class LinesTileComponent {
  constructor(props) {
    this.props = props;
    etch.initialize(this);
    this.createLines();
    this.updateBlockDecorations({}, props);
  }

  update(newProps) {
    if (this.shouldUpdate(newProps)) {
      const oldProps = this.props;
      this.props = newProps;
      etch.updateSync(this);
      if (!newProps.measuredContent) {
        this.updateLines(oldProps, newProps);
        this.updateBlockDecorations(oldProps, newProps);
      }
    }
  }

  destroy() {
    for (let i = 0; i < this.lineComponents.length; i++) {
      this.lineComponents[i].destroy();
    }
    this.lineComponents.length = 0;

    return etch.destroy(this);
  }

  render() {
    const { height, width, top } = this.props;

    return $.div(
      {
        style: {
          contain: 'layout style',
          position: 'absolute',
          height: height + 'px',
          width: width + 'px',
          transform: `translateY(${top}px)`
        }
      }
      // Lines and block decorations will be manually inserted here for efficiency
    );
  }

  createLines() {
    const {
      tileStartRow,
      screenLines,
      lineDecorations,
      textDecorations,
      nodePool,
      displayLayer,
      lineComponentsByScreenLineId
    } = this.props;

    this.lineComponents = [];
    for (let i = 0, length = screenLines.length; i < length; i++) {
      const component = new LineComponent({
        screenLine: screenLines[i],
        screenRow: tileStartRow + i,
        lineDecoration: lineDecorations[i],
        textDecorations: textDecorations[i],
        displayLayer,
        nodePool,
        lineComponentsByScreenLineId
      });
      this.element.appendChild(component.element);
      this.lineComponents.push(component);
    }
  }

  updateLines(oldProps, newProps) {
    var {
      screenLines,
      tileStartRow,
      lineDecorations,
      textDecorations,
      nodePool,
      displayLayer,
      lineComponentsByScreenLineId
    } = newProps;

    var oldScreenLines = oldProps.screenLines;
    var newScreenLines = screenLines;
    var oldScreenLinesEndIndex = oldScreenLines.length;
    var newScreenLinesEndIndex = newScreenLines.length;
    var oldScreenLineIndex = 0;
    var newScreenLineIndex = 0;
    var lineComponentIndex = 0;

    while (
      oldScreenLineIndex < oldScreenLinesEndIndex ||
      newScreenLineIndex < newScreenLinesEndIndex
    ) {
      var oldScreenLine = oldScreenLines[oldScreenLineIndex];
      var newScreenLine = newScreenLines[newScreenLineIndex];

      if (oldScreenLineIndex >= oldScreenLinesEndIndex) {
        var newScreenLineComponent = new LineComponent({
          screenLine: newScreenLine,
          screenRow: tileStartRow + newScreenLineIndex,
          lineDecoration: lineDecorations[newScreenLineIndex],
          textDecorations: textDecorations[newScreenLineIndex],
          displayLayer,
          nodePool,
          lineComponentsByScreenLineId
        });
        this.element.appendChild(newScreenLineComponent.element);
        this.lineComponents.push(newScreenLineComponent);

        newScreenLineIndex++;
        lineComponentIndex++;
      } else if (newScreenLineIndex >= newScreenLinesEndIndex) {
        this.lineComponents[lineComponentIndex].destroy();
        this.lineComponents.splice(lineComponentIndex, 1);

        oldScreenLineIndex++;
      } else if (oldScreenLine === newScreenLine) {
        var lineComponent = this.lineComponents[lineComponentIndex];
        lineComponent.update({
          screenRow: tileStartRow + newScreenLineIndex,
          lineDecoration: lineDecorations[newScreenLineIndex],
          textDecorations: textDecorations[newScreenLineIndex]
        });

        oldScreenLineIndex++;
        newScreenLineIndex++;
        lineComponentIndex++;
      } else {
        var oldScreenLineIndexInNewScreenLines = newScreenLines.indexOf(
          oldScreenLine
        );
        var newScreenLineIndexInOldScreenLines = oldScreenLines.indexOf(
          newScreenLine
        );
        if (
          newScreenLineIndex < oldScreenLineIndexInNewScreenLines &&
          oldScreenLineIndexInNewScreenLines < newScreenLinesEndIndex
        ) {
          var newScreenLineComponents = [];
          while (newScreenLineIndex < oldScreenLineIndexInNewScreenLines) {
            // eslint-disable-next-line no-redeclare
            var newScreenLineComponent = new LineComponent({
              screenLine: newScreenLines[newScreenLineIndex],
              screenRow: tileStartRow + newScreenLineIndex,
              lineDecoration: lineDecorations[newScreenLineIndex],
              textDecorations: textDecorations[newScreenLineIndex],
              displayLayer,
              nodePool,
              lineComponentsByScreenLineId
            });
            this.element.insertBefore(
              newScreenLineComponent.element,
              this.getFirstElementForScreenLine(oldProps, oldScreenLine)
            );
            newScreenLineComponents.push(newScreenLineComponent);

            newScreenLineIndex++;
          }

          this.lineComponents.splice(
            lineComponentIndex,
            0,
            ...newScreenLineComponents
          );
          lineComponentIndex =
            lineComponentIndex + newScreenLineComponents.length;
        } else if (
          oldScreenLineIndex < newScreenLineIndexInOldScreenLines &&
          newScreenLineIndexInOldScreenLines < oldScreenLinesEndIndex
        ) {
          while (oldScreenLineIndex < newScreenLineIndexInOldScreenLines) {
            this.lineComponents[lineComponentIndex].destroy();
            this.lineComponents.splice(lineComponentIndex, 1);

            oldScreenLineIndex++;
          }
        } else {
          var oldScreenLineComponent = this.lineComponents[lineComponentIndex];
          // eslint-disable-next-line no-redeclare
          var newScreenLineComponent = new LineComponent({
            screenLine: newScreenLines[newScreenLineIndex],
            screenRow: tileStartRow + newScreenLineIndex,
            lineDecoration: lineDecorations[newScreenLineIndex],
            textDecorations: textDecorations[newScreenLineIndex],
            displayLayer,
            nodePool,
            lineComponentsByScreenLineId
          });
          this.element.insertBefore(
            newScreenLineComponent.element,
            oldScreenLineComponent.element
          );
          oldScreenLineComponent.destroy();
          this.lineComponents[lineComponentIndex] = newScreenLineComponent;

          oldScreenLineIndex++;
          newScreenLineIndex++;
          lineComponentIndex++;
        }
      }
    }
  }

  getFirstElementForScreenLine(oldProps, screenLine) {
    var blockDecorations = oldProps.blockDecorations
      ? oldProps.blockDecorations.get(screenLine.id)
      : null;
    if (blockDecorations) {
      var blockDecorationElementsBeforeOldScreenLine = [];
      for (let i = 0; i < blockDecorations.length; i++) {
        var decoration = blockDecorations[i];
        if (decoration.position !== 'after') {
          blockDecorationElementsBeforeOldScreenLine.push(
            TextEditor.viewForItem(decoration.item)
          );
        }
      }

      for (
        let i = 0;
        i < blockDecorationElementsBeforeOldScreenLine.length;
        i++
      ) {
        var blockDecorationElement =
          blockDecorationElementsBeforeOldScreenLine[i];
        if (
          !blockDecorationElementsBeforeOldScreenLine.includes(
            blockDecorationElement.previousSibling
          )
        ) {
          return blockDecorationElement;
        }
      }
    }

    return oldProps.lineComponentsByScreenLineId.get(screenLine.id).element;
  }

  updateBlockDecorations(oldProps, newProps) {
    var { blockDecorations, lineComponentsByScreenLineId } = newProps;

    if (oldProps.blockDecorations) {
      oldProps.blockDecorations.forEach((oldDecorations, screenLineId) => {
        var newDecorations = newProps.blockDecorations
          ? newProps.blockDecorations.get(screenLineId)
          : null;
        for (var i = 0; i < oldDecorations.length; i++) {
          var oldDecoration = oldDecorations[i];
          if (newDecorations && newDecorations.includes(oldDecoration))
            continue;

          var element = TextEditor.viewForItem(oldDecoration.item);
          if (element.parentElement !== this.element) continue;

          element.remove();
        }
      });
    }

    if (blockDecorations) {
      blockDecorations.forEach((newDecorations, screenLineId) => {
        const oldDecorations = oldProps.blockDecorations
          ? oldProps.blockDecorations.get(screenLineId)
          : null;
        const lineNode = lineComponentsByScreenLineId.get(screenLineId).element;
        let lastAfter = lineNode;

        for (let i = 0; i < newDecorations.length; i++) {
          const newDecoration = newDecorations[i];
          const element = TextEditor.viewForItem(newDecoration.item);

          if (oldDecorations && oldDecorations.includes(newDecoration)) {
            if (newDecoration.position === 'after') {
              lastAfter = element;
            }
            continue;
          }

          if (newDecoration.position === 'after') {
            this.element.insertBefore(element, lastAfter.nextSibling);
            lastAfter = element;
          } else {
            this.element.insertBefore(element, lineNode);
          }
        }
      });
    }
  }

  shouldUpdate(newProps) {
    const oldProps = this.props;
    if (oldProps.top !== newProps.top) return true;
    if (oldProps.height !== newProps.height) return true;
    if (oldProps.width !== newProps.width) return true;
    if (oldProps.lineHeight !== newProps.lineHeight) return true;
    if (oldProps.tileStartRow !== newProps.tileStartRow) return true;
    if (oldProps.tileEndRow !== newProps.tileEndRow) return true;
    if (!arraysEqual(oldProps.screenLines, newProps.screenLines)) return true;
    if (!arraysEqual(oldProps.lineDecorations, newProps.lineDecorations))
      return true;

    if (oldProps.blockDecorations && newProps.blockDecorations) {
      if (oldProps.blockDecorations.size !== newProps.blockDecorations.size)
        return true;

      let blockDecorationsChanged = false;

      oldProps.blockDecorations.forEach((oldDecorations, screenLineId) => {
        if (!blockDecorationsChanged) {
          const newDecorations = newProps.blockDecorations.get(screenLineId);
          blockDecorationsChanged =
            newDecorations == null ||
            !arraysEqual(oldDecorations, newDecorations);
        }
      });
      if (blockDecorationsChanged) return true;

      newProps.blockDecorations.forEach((newDecorations, screenLineId) => {
        if (!blockDecorationsChanged) {
          const oldDecorations = oldProps.blockDecorations.get(screenLineId);
          blockDecorationsChanged = oldDecorations == null;
        }
      });
      if (blockDecorationsChanged) return true;
    } else if (oldProps.blockDecorations) {
      return true;
    } else if (newProps.blockDecorations) {
      return true;
    }

    if (oldProps.textDecorations.length !== newProps.textDecorations.length)
      return true;
    for (let i = 0; i < oldProps.textDecorations.length; i++) {
      if (
        !textDecorationsEqual(
          oldProps.textDecorations[i],
          newProps.textDecorations[i]
        )
      )
        return true;
    }

    return false;
  }
}

class LineComponent {
  constructor(props) {
    const {
      nodePool,
      screenRow,
      screenLine,
      lineComponentsByScreenLineId,
      offScreen
    } = props;
    this.props = props;
    this.element = nodePool.getElement('DIV', this.buildClassName(), null);
    this.element.dataset.screenRow = screenRow;
    this.textNodes = [];

    if (offScreen) {
      this.element.style.position = 'absolute';
      this.element.style.visibility = 'hidden';
      this.element.dataset.offScreen = true;
    }

    this.appendContents();
    lineComponentsByScreenLineId.set(screenLine.id, this);
  }

  update(newProps) {
    if (this.props.lineDecoration !== newProps.lineDecoration) {
      this.props.lineDecoration = newProps.lineDecoration;
      this.element.className = this.buildClassName();
    }

    if (this.props.screenRow !== newProps.screenRow) {
      this.props.screenRow = newProps.screenRow;
      this.element.dataset.screenRow = newProps.screenRow;
    }

    if (
      !textDecorationsEqual(
        this.props.textDecorations,
        newProps.textDecorations
      )
    ) {
      this.props.textDecorations = newProps.textDecorations;
      this.element.firstChild.remove();
      this.appendContents();
    }
  }

  destroy() {
    const { nodePool, lineComponentsByScreenLineId, screenLine } = this.props;

    if (lineComponentsByScreenLineId.get(screenLine.id) === this) {
      lineComponentsByScreenLineId.delete(screenLine.id);
    }

    this.element.remove();
    nodePool.release(this.element);
  }

  appendContents() {
    const { displayLayer, nodePool, screenLine, textDecorations } = this.props;

    this.textNodes.length = 0;

    const { lineText, tags } = screenLine;
    let openScopeNode = nodePool.getElement('SPAN', null, null);
    this.element.appendChild(openScopeNode);

    let decorationIndex = 0;
    let column = 0;
    let activeClassName = null;
    let activeStyle = null;
    let nextDecoration = textDecorations
      ? textDecorations[decorationIndex]
      : null;
    if (nextDecoration && nextDecoration.column === 0) {
      column = nextDecoration.column;
      activeClassName = nextDecoration.className;
      activeStyle = nextDecoration.style;
      nextDecoration = textDecorations[++decorationIndex];
    }

    for (let i = 0; i < tags.length; i++) {
      const tag = tags[i];
      if (tag !== 0) {
        if (displayLayer.isCloseTag(tag)) {
          openScopeNode = openScopeNode.parentElement;
        } else if (displayLayer.isOpenTag(tag)) {
          const newScopeNode = nodePool.getElement(
            'SPAN',
            displayLayer.classNameForTag(tag),
            null
          );
          openScopeNode.appendChild(newScopeNode);
          openScopeNode = newScopeNode;
        } else {
          const nextTokenColumn = column + tag;
          while (nextDecoration && nextDecoration.column <= nextTokenColumn) {
            const text = lineText.substring(column, nextDecoration.column);
            this.appendTextNode(
              openScopeNode,
              text,
              activeClassName,
              activeStyle
            );
            column = nextDecoration.column;
            activeClassName = nextDecoration.className;
            activeStyle = nextDecoration.style;
            nextDecoration = textDecorations[++decorationIndex];
          }

          if (column < nextTokenColumn) {
            const text = lineText.substring(column, nextTokenColumn);
            this.appendTextNode(
              openScopeNode,
              text,
              activeClassName,
              activeStyle
            );
            column = nextTokenColumn;
          }
        }
      }
    }

    if (column === 0) {
      const textNode = nodePool.getTextNode(' ');
      this.element.appendChild(textNode);
      this.textNodes.push(textNode);
    }

    if (lineText.endsWith(displayLayer.foldCharacter)) {
      // Insert a zero-width non-breaking whitespace, so that LinesYardstick can
      // take the fold-marker::after pseudo-element into account during
      // measurements when such marker is the last character on the line.
      const textNode = nodePool.getTextNode(ZERO_WIDTH_NBSP_CHARACTER);
      this.element.appendChild(textNode);
      this.textNodes.push(textNode);
    }
  }

  appendTextNode(openScopeNode, text, activeClassName, activeStyle) {
    const { nodePool } = this.props;

    if (activeClassName || activeStyle) {
      const decorationNode = nodePool.getElement(
        'SPAN',
        activeClassName,
        activeStyle
      );
      openScopeNode.appendChild(decorationNode);
      openScopeNode = decorationNode;
    }

    const textNode = nodePool.getTextNode(text);
    openScopeNode.appendChild(textNode);
    this.textNodes.push(textNode);
  }

  buildClassName() {
    const { lineDecoration } = this.props;
    let className = 'line';
    if (lineDecoration != null) className = className + ' ' + lineDecoration;
    return className;
  }
}

class HighlightsComponent {
  constructor(props) {
    this.props = {};
    this.element = document.createElement('div');
    this.element.className = 'highlights';
    this.element.style.contain = 'strict';
    this.element.style.position = 'absolute';
    this.element.style.overflow = 'hidden';
    this.element.style.userSelect = 'none';
    this.highlightComponentsByKey = new Map();
    this.update(props);
  }

  destroy() {
    this.highlightComponentsByKey.forEach(highlightComponent => {
      highlightComponent.destroy();
    });
    this.highlightComponentsByKey.clear();
  }

  update(newProps) {
    if (this.shouldUpdate(newProps)) {
      this.props = newProps;
      const { height, width, lineHeight, highlightDecorations } = this.props;

      this.element.style.height = height + 'px';
      this.element.style.width = width + 'px';

      const visibleHighlightDecorations = new Set();
      if (highlightDecorations) {
        for (let i = 0; i < highlightDecorations.length; i++) {
          const highlightDecoration = highlightDecorations[i];
          const highlightProps = Object.assign(
            { lineHeight },
            highlightDecorations[i]
          );

          let highlightComponent = this.highlightComponentsByKey.get(
            highlightDecoration.key
          );
          if (highlightComponent) {
            highlightComponent.update(highlightProps);
          } else {
            highlightComponent = new HighlightComponent(highlightProps);
            this.element.appendChild(highlightComponent.element);
            this.highlightComponentsByKey.set(
              highlightDecoration.key,
              highlightComponent
            );
          }

          highlightDecorations[i].flashRequested = false;
          visibleHighlightDecorations.add(highlightDecoration.key);
        }
      }

      this.highlightComponentsByKey.forEach((highlightComponent, key) => {
        if (!visibleHighlightDecorations.has(key)) {
          highlightComponent.destroy();
          this.highlightComponentsByKey.delete(key);
        }
      });
    }
  }

  shouldUpdate(newProps) {
    const oldProps = this.props;

    if (!newProps.hasInitialMeasurements) return false;

    if (oldProps.width !== newProps.width) return true;
    if (oldProps.height !== newProps.height) return true;
    if (oldProps.lineHeight !== newProps.lineHeight) return true;
    if (!oldProps.highlightDecorations && newProps.highlightDecorations)
      return true;
    if (oldProps.highlightDecorations && !newProps.highlightDecorations)
      return true;
    if (oldProps.highlightDecorations && newProps.highlightDecorations) {
      if (
        oldProps.highlightDecorations.length !==
        newProps.highlightDecorations.length
      )
        return true;

      for (
        let i = 0, length = oldProps.highlightDecorations.length;
        i < length;
        i++
      ) {
        const oldHighlight = oldProps.highlightDecorations[i];
        const newHighlight = newProps.highlightDecorations[i];
        if (oldHighlight.className !== newHighlight.className) return true;
        if (newHighlight.flashRequested) return true;
        if (oldHighlight.startPixelTop !== newHighlight.startPixelTop)
          return true;
        if (oldHighlight.startPixelLeft !== newHighlight.startPixelLeft)
          return true;
        if (oldHighlight.endPixelTop !== newHighlight.endPixelTop) return true;
        if (oldHighlight.endPixelLeft !== newHighlight.endPixelLeft)
          return true;
        if (!oldHighlight.screenRange.isEqual(newHighlight.screenRange))
          return true;
      }
    }
  }
}

class HighlightComponent {
  constructor(props) {
    this.props = props;
    etch.initialize(this);
    if (this.props.flashRequested) this.performFlash();
  }

  destroy() {
    if (this.timeoutsByClassName) {
      this.timeoutsByClassName.forEach(timeout => {
        window.clearTimeout(timeout);
      });
      this.timeoutsByClassName.clear();
    }

    return etch.destroy(this);
  }

  update(newProps) {
    this.props = newProps;
    etch.updateSync(this);
    if (newProps.flashRequested) this.performFlash();
  }

  performFlash() {
    const { flashClass, flashDuration } = this.props;
    if (!this.timeoutsByClassName) this.timeoutsByClassName = new Map();

    // If a flash of this class is already in progress, clear it early and
    // flash again on the next frame to ensure CSS transitions apply to the
    // second flash.
    if (this.timeoutsByClassName.has(flashClass)) {
      window.clearTimeout(this.timeoutsByClassName.get(flashClass));
      this.timeoutsByClassName.delete(flashClass);
      this.element.classList.remove(flashClass);
      requestAnimationFrame(() => this.performFlash());
    } else {
      this.element.classList.add(flashClass);
      this.timeoutsByClassName.set(
        flashClass,
        window.setTimeout(() => {
          this.element.classList.remove(flashClass);
        }, flashDuration)
      );
    }
  }

  render() {
    const {
      className,
      screenRange,
      lineHeight,
      startPixelTop,
      startPixelLeft,
      endPixelTop,
      endPixelLeft
    } = this.props;
    const regionClassName = 'region ' + className;

    let children;
    if (screenRange.start.row === screenRange.end.row) {
      children = $.div({
        className: regionClassName,
        style: {
          position: 'absolute',
          boxSizing: 'border-box',
          top: startPixelTop + 'px',
          left: startPixelLeft + 'px',
          width: endPixelLeft - startPixelLeft + 'px',
          height: lineHeight + 'px'
        }
      });
    } else {
      children = [];
      children.push(
        $.div({
          className: regionClassName,
          style: {
            position: 'absolute',
            boxSizing: 'border-box',
            top: startPixelTop + 'px',
            left: startPixelLeft + 'px',
            right: 0,
            height: lineHeight + 'px'
          }
        })
      );

      if (screenRange.end.row - screenRange.start.row > 1) {
        children.push(
          $.div({
            className: regionClassName,
            style: {
              position: 'absolute',
              boxSizing: 'border-box',
              top: startPixelTop + lineHeight + 'px',
              left: 0,
              right: 0,
              height: endPixelTop - startPixelTop - lineHeight * 2 + 'px'
            }
          })
        );
      }

      if (endPixelLeft > 0) {
        children.push(
          $.div({
            className: regionClassName,
            style: {
              position: 'absolute',
              boxSizing: 'border-box',
              top: endPixelTop - lineHeight + 'px',
              left: 0,
              width: endPixelLeft + 'px',
              height: lineHeight + 'px'
            }
          })
        );
      }
    }

    return $.div({ className: 'highlight ' + className }, children);
  }
}

class OverlayComponent {
  constructor(props) {
    this.props = props;
    this.element = document.createElement('atom-overlay');
    if (this.props.className != null)
      this.element.classList.add(this.props.className);
    this.element.appendChild(this.props.element);
    this.element.style.position = 'fixed';
    this.element.style.zIndex = 4;
    this.element.style.top = (this.props.pixelTop || 0) + 'px';
    this.element.style.left = (this.props.pixelLeft || 0) + 'px';
    this.currentContentRect = null;

    // Synchronous DOM updates in response to resize events might trigger a
    // "loop limit exceeded" error. We disconnect the observer before
    // potentially mutating the DOM, and then reconnect it on the next tick.
    // Note: ResizeObserver calls its callback when .observe is called
    this.resizeObserver = new ResizeObserver(entries => {
      const { contentRect } = entries[0];

      if (
        this.currentContentRect &&
        (this.currentContentRect.width !== contentRect.width ||
          this.currentContentRect.height !== contentRect.height)
      ) {
        this.resizeObserver.disconnect();
        this.props.didResize(this);
        process.nextTick(() => {
          this.resizeObserver.observe(this.props.element);
        });
      }

      this.currentContentRect = contentRect;
    });
    this.didAttach();
    this.props.overlayComponents.add(this);
  }

  destroy() {
    this.props.overlayComponents.delete(this);
    this.didDetach();
  }

  getNextUpdatePromise() {
    if (!this.nextUpdatePromise) {
      this.nextUpdatePromise = new Promise(resolve => {
        this.resolveNextUpdatePromise = () => {
          this.nextUpdatePromise = null;
          this.resolveNextUpdatePromise = null;
          resolve();
        };
      });
    }
    return this.nextUpdatePromise;
  }

  update(newProps) {
    const oldProps = this.props;
    this.props = Object.assign({}, oldProps, newProps);
    if (this.props.pixelTop != null)
      this.element.style.top = this.props.pixelTop + 'px';
    if (this.props.pixelLeft != null)
      this.element.style.left = this.props.pixelLeft + 'px';
    if (newProps.className !== oldProps.className) {
      if (oldProps.className != null)
        this.element.classList.remove(oldProps.className);
      if (newProps.className != null)
        this.element.classList.add(newProps.className);
    }

    if (this.resolveNextUpdatePromise) this.resolveNextUpdatePromise();
  }

  didAttach() {
    this.resizeObserver.observe(this.props.element);
  }

  didDetach() {
    this.resizeObserver.disconnect();
  }
}

let rangeForMeasurement;
function clientRectForRange(textNode, startIndex, endIndex) {
  if (!rangeForMeasurement) rangeForMeasurement = document.createRange();
  rangeForMeasurement.setStart(textNode, startIndex);
  rangeForMeasurement.setEnd(textNode, endIndex);
  return rangeForMeasurement.getBoundingClientRect();
}

function textDecorationsEqual(oldDecorations, newDecorations) {
  if (!oldDecorations && newDecorations) return false;
  if (oldDecorations && !newDecorations) return false;
  if (oldDecorations && newDecorations) {
    if (oldDecorations.length !== newDecorations.length) return false;
    for (let j = 0; j < oldDecorations.length; j++) {
      if (oldDecorations[j].column !== newDecorations[j].column) return false;
      if (oldDecorations[j].className !== newDecorations[j].className)
        return false;
      if (!objectsEqual(oldDecorations[j].style, newDecorations[j].style))
        return false;
    }
  }
  return true;
}

function arraysEqual(a, b) {
  if (a.length !== b.length) return false;
  for (let i = 0, length = a.length; i < length; i++) {
    if (a[i] !== b[i]) return false;
  }
  return true;
}

function objectsEqual(a, b) {
  if (!a && b) return false;
  if (a && !b) return false;
  if (a && b) {
    for (const key in a) {
      if (a[key] !== b[key]) return false;
    }
    for (const key in b) {
      if (a[key] !== b[key]) return false;
    }
  }
  return true;
}

function constrainRangeToRows(range, startRow, endRow) {
  if (range.start.row < startRow || range.end.row >= endRow) {
    range = range.copy();
    if (range.start.row < startRow) {
      range.start.row = startRow;
      range.start.column = 0;
    }
    if (range.end.row >= endRow) {
      range.end.row = endRow;
      range.end.column = 0;
    }
  }
  return range;
}

function debounce(fn, wait) {
  let timestamp, timeout;

  function later() {
    const last = Date.now() - timestamp;
    if (last < wait && last >= 0) {
      timeout = setTimeout(later, wait - last);
    } else {
      timeout = null;
      fn();
    }
  }

  return function() {
    timestamp = Date.now();
    if (!timeout) timeout = setTimeout(later, wait);
  };
}

class NodePool {
  constructor() {
    this.elementsByType = {};
    this.textNodes = [];
  }

  getElement(type, className, style) {
    var element;
    var elementsByDepth = this.elementsByType[type];
    if (elementsByDepth) {
      while (elementsByDepth.length > 0) {
        var elements = elementsByDepth[elementsByDepth.length - 1];
        if (elements && elements.length > 0) {
          element = elements.pop();
          if (elements.length === 0) elementsByDepth.pop();
          break;
        } else {
          elementsByDepth.pop();
        }
      }
    }

    if (element) {
      element.className = className || '';
      element.attributeStyleMap.forEach((value, key) => {
        if (!style || style[key] == null) element.style[key] = '';
      });
      if (style) Object.assign(element.style, style);
      for (const key in element.dataset) delete element.dataset[key];
      while (element.firstChild) element.firstChild.remove();
      return element;
    } else {
      var newElement = document.createElement(type);
      if (className) newElement.className = className;
      if (style) Object.assign(newElement.style, style);
      return newElement;
    }
  }

  getTextNode(text) {
    if (this.textNodes.length > 0) {
      var node = this.textNodes.pop();
      node.textContent = text;
      return node;
    } else {
      return document.createTextNode(text);
    }
  }

  release(node, depth = 0) {
    var { nodeName } = node;
    if (nodeName === '#text') {
      this.textNodes.push(node);
    } else {
      var elementsByDepth = this.elementsByType[nodeName];
      if (!elementsByDepth) {
        elementsByDepth = [];
        this.elementsByType[nodeName] = elementsByDepth;
      }

      var elements = elementsByDepth[depth];
      if (!elements) {
        elements = [];
        elementsByDepth[depth] = elements;
      }

      elements.push(node);
      for (var i = 0; i < node.childNodes.length; i++) {
        this.release(node.childNodes[i], depth + 1);
      }
    }
  }
}

function roundToPhysicalPixelBoundary(virtualPixelPosition) {
  const virtualPixelsPerPhysicalPixel = 1 / window.devicePixelRatio;
  return (
    Math.round(virtualPixelPosition / virtualPixelsPerPhysicalPixel) *
    virtualPixelsPerPhysicalPixel
  );
}

function ceilToPhysicalPixelBoundary(virtualPixelPosition) {
  const virtualPixelsPerPhysicalPixel = 1 / window.devicePixelRatio;
  return (
    Math.ceil(virtualPixelPosition / virtualPixelsPerPhysicalPixel) *
    virtualPixelsPerPhysicalPixel
  );
}
