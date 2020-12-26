/* global ResizeObserver */

const etch = require('etch')
const {Point, Range} = require('text-buffer')
const LineTopIndex = require('line-top-index')
const TextEditor = require('./text-editor')
const {isPairedCharacter} = require('./text-utils')
const clipboard = require('./safe-clipboard')
const electron = require('electron')
const $ = etch.dom

let TextEditorElement

const DEFAULT_ROWS_PER_TILE = 6
const NORMAL_WIDTH_CHARACTER = 'x'
const DOUBLE_WIDTH_CHARACTER = '我'
const HALF_WIDTH_CHARACTER = 'ﾊ'
const KOREAN_CHARACTER = '세'
const NBSP_CHARACTER = '\u00a0'
const ZERO_WIDTH_NBSP_CHARACTER = '\ufeff'
const MOUSE_DRAG_AUTOSCROLL_MARGIN = 40
const CURSOR_BLINK_RESUME_DELAY = 300
const CURSOR_BLINK_PERIOD = 800

function scaleMouseDragAutoscrollDelta (delta) {
  return Math.pow(delta / 3, 3) / 280
}

module.exports =
class TextEditorComponent {
  static setScheduler (scheduler) {
    etch.setScheduler(scheduler)
  }

  static didUpdateStyles () {
    if (this.attachedComponents) {
      this.attachedComponents.forEach((component) => {
        component.didUpdateStyles()
      })
    }
  }

  static didUpdateScrollbarStyles () {
    if (this.attachedComponents) {
      this.attachedComponents.forEach((component) => {
        component.didUpdateScrollbarStyles()
      })
    }
  }

  constructor (props) {
    this.props = props

    if (!props.model) props.model = new TextEditor()
    this.props.model.component = this

    if (props.element) {
      this.element = props.element
    } else {
      if (!TextEditorElement) TextEditorElement = require('./text-editor-element')
      this.element = new TextEditorElement()
    }
    this.element.initialize(this)
    this.virtualNode = $('atom-text-editor')
    this.virtualNode.domNode = this.element
    this.refs = {}

    this.updateSync = this.updateSync.bind(this)
    this.didBlurHiddenInput = this.didBlurHiddenInput.bind(this)
    this.didFocusHiddenInput = this.didFocusHiddenInput.bind(this)
    this.didTextInput = this.didTextInput.bind(this)
    this.didKeydown = this.didKeydown.bind(this)
    this.didKeyup = this.didKeyup.bind(this)
    this.didKeypress = this.didKeypress.bind(this)
    this.didCompositionStart = this.didCompositionStart.bind(this)
    this.didCompositionUpdate = this.didCompositionUpdate.bind(this)
    this.didCompositionEnd = this.didCompositionEnd.bind(this)

    this.updatedSynchronously = this.props.updatedSynchronously
    this.didScrollDummyScrollbar = this.didScrollDummyScrollbar.bind(this)
    this.didMouseDownOnContent = this.didMouseDownOnContent.bind(this)
    this.lineTopIndex = new LineTopIndex()
    this.updateScheduled = false
    this.hasInitialMeasurements = false
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
    }
    this.derivedDimensionsCache = {}
    this.visible = false
    this.cursorsBlinking = false
    this.cursorsBlinkedOff = false
    this.nextUpdateOnlyBlinksCursors = null
    this.extraLinesToMeasure = null
    this.extraRenderedScreenLines = null
    this.horizontalPositionsToMeasure = new Map() // Keys are rows with positions we want to measure, values are arrays of columns to measure
    this.horizontalPixelPositionsByScreenLineId = new Map() // Values are maps from column to horiontal pixel positions
    this.blockDecorationsToMeasure = new Set()
    this.lineNodesByScreenLineId = new Map()
    this.textNodesByScreenLineId = new Map()
    this.overlayComponents = new Set()
    this.shouldRenderDummyScrollbars = true
    this.remeasureScrollbars = false
    this.pendingAutoscroll = null
    this.scrollTopPending = false
    this.scrollLeftPending = false
    this.scrollTop = 0
    this.scrollLeft = 0
    this.previousScrollWidth = 0
    this.previousScrollHeight = 0
    this.lastKeydown = null
    this.lastKeydownBeforeKeypress = null
    this.accentedCharacterMenuIsOpen = false
    this.remeasureGutterDimensions = false
    this.guttersToRender = [this.props.model.getLineNumberGutter()]
    this.guttersVisibility = [this.guttersToRender[0].visible]
    this.lineNumbersToRender = {
      maxDigits: 2,
      bufferRows: [],
      keys: [],
      softWrappedFlags: [],
      foldableFlags: []
    }
    this.decorationsToRender = {
      lineNumbers: null,
      lines: null,
      highlights: new Map(),
      cursors: [],
      overlays: [],
      customGutter: new Map(),
      blocks: new Map()
    }
    this.decorationsToMeasure = {
      highlights: new Map(),
      cursors: new Map()
    }
    this.pendingScrollTopRow = this.props.initialScrollTopRow
    this.pendingScrollLeftColumn = this.props.initialScrollLeftColumn

    this.measuredContent = false
    this.queryGuttersToRender()
    this.queryMaxLineNumberDigits()
    this.observeBlockDecorations()
    etch.updateSync(this)
  }

  update (props) {
    this.props = props
    this.scheduleUpdate()
  }

  pixelPositionForScreenPositionSync ({row, column}) {
    const top = this.pixelPositionAfterBlocksForRow(row)
    let left = column === 0 ? 0 : this.pixelLeftForRowAndColumn(row, column)
    if (left == null) {
      this.requestHorizontalMeasurement(row, column)
      this.updateSync()
      left = this.pixelLeftForRowAndColumn(row, column)
    }
    return {top, left}
  }

  screenPositionForPixelPositionSync (pixelPosition) {
    const {model} = this.props

    const row = Math.max(0, Math.min(
      this.rowForPixelPosition(pixelPosition.top),
      model.getApproximateScreenLineCount() - 1
    ))

    if (!this.renderedScreenLineForRow(row)) {
      this.requestExtraLineToMeasure(row, model.screenLineForScreenRow(row))
      this.updateSyncBeforeMeasuringContent()
      this.measureContentDuringUpdateSync()
    }
    return this.screenPositionForPixelPosition(pixelPosition)
  }

  scheduleUpdate (nextUpdateOnlyBlinksCursors = false) {
    if (!this.visible) return

    this.nextUpdateOnlyBlinksCursors =
      this.nextUpdateOnlyBlinksCursors !== false && nextUpdateOnlyBlinksCursors === true

    if (this.updatedSynchronously) {
      this.updateSync()
    } else if (!this.updateScheduled) {
      this.updateScheduled = true
      etch.getScheduler().updateDocument(() => {
        if (this.updateScheduled) this.updateSync(true)
      })
    }
  }

  updateSync (useScheduler = false) {
    this.updateScheduled = false

    // Don't proceed if we know we are not visible
    if (!this.visible) return

    // Don't proceed if we have to pay for a measurement anyway and detect
    // that we are no longer visible.
    if ((this.remeasureCharacterDimensions || this.remeasureAllBlockDecorations) && !this.isVisible()) {
      if (this.resolveNextUpdatePromise) this.resolveNextUpdatePromise()
      return
    }

    const onlyBlinkingCursors = this.nextUpdateOnlyBlinksCursors
    this.nextUpdateOnlyBlinksCursors = null
    if (useScheduler && onlyBlinkingCursors) {
      this.refs.cursorsAndInput.updateCursorBlinkSync(this.cursorsBlinkedOff)
      if (this.resolveNextUpdatePromise) this.resolveNextUpdatePromise()
      return
    }

    if (this.remeasureCharacterDimensions) {
      this.measureCharacterDimensions()
      this.measureGutterDimensions()
      this.remeasureCharacterDimensions = false
    }

    this.measureBlockDecorations()

    this.measuredContent = false
    this.updateSyncBeforeMeasuringContent()
    if (useScheduler === true) {
      const scheduler = etch.getScheduler()
      scheduler.readDocument(() => {
        this.measureContentDuringUpdateSync()
        this.measuredContent = true
        scheduler.updateDocument(() => {
          this.updateSyncAfterMeasuringContent()
        })
      })
    } else {
      this.measureContentDuringUpdateSync()
      this.measuredContent = true
      this.updateSyncAfterMeasuringContent()
    }

    this.derivedDimensionsCache = {}
    if (this.resolveNextUpdatePromise) this.resolveNextUpdatePromise()
  }

  measureBlockDecorations () {
    if (this.remeasureAllBlockDecorations) {
      this.remeasureAllBlockDecorations = false

      const decorations = this.props.model.getDecorations()
      for (var i = 0; i < decorations.length; i++) {
        const decoration = decorations[i]
        if (decoration.getProperties().type === 'block') {
          this.blockDecorationsToMeasure.add(decoration)
        }
      }

      // Update the width of the line tiles to ensure block decorations are
      // measured with the most recent width.
      if (this.blockDecorationsToMeasure.size > 0) {
        this.updateSyncBeforeMeasuringContent()
      }
    }

    if (this.blockDecorationsToMeasure.size > 0) {
      const {blockDecorationMeasurementArea} = this.refs
      const sentinelElements = new Set()

      blockDecorationMeasurementArea.appendChild(document.createElement('div'))
      this.blockDecorationsToMeasure.forEach((decoration) => {
        const {item} = decoration.getProperties()
        const decorationElement = TextEditor.viewForItem(item)
        if (document.contains(decorationElement)) {
          const parentElement = decorationElement.parentElement

          if (!decorationElement.previousSibling) {
            const sentinelElement = document.createElement('div')
            parentElement.insertBefore(sentinelElement, decorationElement)
            sentinelElements.add(sentinelElement)
          }

          if (!decorationElement.nextSibling) {
            const sentinelElement = document.createElement('div')
            parentElement.appendChild(sentinelElement)
            sentinelElements.add(sentinelElement)
          }

          this.didMeasureVisibleBlockDecoration = true
        } else {
          blockDecorationMeasurementArea.appendChild(decorationElement)
          blockDecorationMeasurementArea.appendChild(document.createElement('div'))
        }
      })

      this.blockDecorationsToMeasure.forEach((decoration) => {
        const {item} = decoration.getProperties()
        const decorationElement = TextEditor.viewForItem(item)
        const {previousSibling, nextSibling} = decorationElement
        const height = nextSibling.getBoundingClientRect().top - previousSibling.getBoundingClientRect().bottom
        this.lineTopIndex.resizeBlock(decoration, height)
      })

      sentinelElements.forEach((sentinelElement) => sentinelElement.remove())
      while (blockDecorationMeasurementArea.firstChild) {
        blockDecorationMeasurementArea.firstChild.remove()
      }
      this.blockDecorationsToMeasure.clear()
    }
  }

  updateSyncBeforeMeasuringContent () {
    this.derivedDimensionsCache = {}
    if (this.pendingAutoscroll) this.autoscrollVertically()
    this.populateVisibleRowRange()
    this.queryScreenLinesToRender()
    this.queryLineNumbersToRender()
    this.queryGuttersToRender()
    this.queryDecorationsToRender()
    this.shouldRenderDummyScrollbars = !this.remeasureScrollbars
    etch.updateSync(this)
    this.updateClassList()
    this.shouldRenderDummyScrollbars = true
    this.didMeasureVisibleBlockDecoration = false
  }

  measureContentDuringUpdateSync () {
    if (this.remeasureGutterDimensions) {
      this.measureGutterDimensions()
      this.remeasureGutterDimensions = false
    }
    const wasHorizontalScrollbarVisible = this.isHorizontalScrollbarVisible()

    this.extraRenderedScreenLines = this.extraLinesToMeasure
    this.extraLinesToMeasure = null
    this.measureLongestLineWidth()
    this.measureHorizontalPositions()
    this.updateAbsolutePositionedDecorations()

    if (this.pendingAutoscroll) {
      this.derivedDimensionsCache = {}
      this.autoscrollHorizontally()
      if (!wasHorizontalScrollbarVisible && this.isHorizontalScrollbarVisible()) {
        this.autoscrollVertically()
      }
      this.pendingAutoscroll = null
    }
  }

  updateSyncAfterMeasuringContent () {
    this.derivedDimensionsCache = {}
    etch.updateSync(this)

    this.currentFrameLineNumberGutterProps = null
    this.scrollTopPending = false
    this.scrollLeftPending = false
    if (this.remeasureScrollbars) {
      // Flush stored scroll positions to the vertical and the horizontal
      // scrollbars. This is because they have just been destroyed and recreated
      // as a result of their remeasurement, but we could not assign the scroll
      // top while they were initialized because they were not attached to the
      // DOM yet.
      this.refs.verticalScrollbar.flushScrollPosition()
      this.refs.horizontalScrollbar.flushScrollPosition()

      this.measureScrollbarDimensions()
      this.remeasureScrollbars = false
      etch.updateSync(this)
    }
  }

  render () {
    const {model} = this.props
    const style = {}

    if (!model.getAutoHeight() && !model.getAutoWidth()) {
      style.contain = 'size'
    }

    let clientContainerHeight = '100%'
    let clientContainerWidth = '100%'
    if (this.hasInitialMeasurements) {
      if (model.getAutoHeight()) {
        clientContainerHeight = this.getContentHeight()
        if (this.isHorizontalScrollbarVisible()) clientContainerHeight += this.getHorizontalScrollbarHeight()
        clientContainerHeight += 'px'
      }
      if (model.getAutoWidth()) {
        style.width = 'min-content'
        clientContainerWidth = this.getGutterContainerWidth() + this.getContentWidth()
        if (this.isVerticalScrollbarVisible()) clientContainerWidth += this.getVerticalScrollbarWidth()
        clientContainerWidth += 'px'
      } else {
        style.width = this.element.style.width
      }
    }

    let attributes = null
    if (model.isMini()) {
      attributes = {mini: ''}
    }

    const dataset = {encoding: model.getEncoding()}
    const grammar = model.getGrammar()
    if (grammar && grammar.scopeName) {
      dataset.grammar = grammar.scopeName.replace(/\./g, ' ')
    }

    return $('atom-text-editor',
      {
        // See this.updateClassList() for construction of the class name
        style,
        attributes,
        dataset,
        tabIndex: -1,
        on: {mousewheel: this.didMouseWheel}
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
    )
  }

  renderGutterContainer () {
    if (this.props.model.isMini()) {
      return null
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
        lineNumbersToRender: this.lineNumbersToRender,
        didMeasureVisibleBlockDecoration: this.didMeasureVisibleBlockDecoration
      })
    }
  }

  renderScrollContainer () {
    const style = {
      position: 'absolute',
      contain: 'strict',
      overflow: 'hidden',
      top: 0,
      bottom: 0,
      backgroundColor: 'inherit'
    }

    if (this.hasInitialMeasurements) {
      style.left = this.getGutterContainerWidth() + 'px'
      style.width = this.getScrollContainerWidth() + 'px'
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
    )
  }

  renderContent () {
    let children
    let style = {
      contain: 'strict',
      overflow: 'hidden',
      backgroundColor: 'inherit'
    }
    if (this.hasInitialMeasurements) {
      style.width = this.getScrollWidth() + 'px'
      style.height = this.getScrollHeight() + 'px'
      style.willChange = 'transform'
      style.transform = `translate(${-this.getScrollLeft()}px, ${-this.getScrollTop()}px)`
      children = [
        this.renderCursorsAndInput(),
        this.renderLineTiles(),
        this.renderBlockDecorationMeasurementArea(),
        this.renderCharacterMeasurementLine(),
        this.renderPlaceholderText()
      ]
    } else {
      children = [
        this.renderBlockDecorationMeasurementArea(),
        this.renderCharacterMeasurementLine()
      ]
    }

    return $.div(
      {
        ref: 'content',
        on: {mousedown: this.didMouseDownOnContent},
        style
      },
      children
    )
  }

  renderLineTiles () {
    const {lineNodesByScreenLineId, textNodesByScreenLineId} = this

    const startRow = this.getRenderedStartRow()
    const endRow = this.getRenderedEndRow()
    const rowsPerTile = this.getRowsPerTile()
    const tileWidth = this.getScrollWidth()

    const displayLayer = this.props.model.displayLayer
    const tileNodes = new Array(this.getRenderedTileCount())

    for (let tileStartRow = startRow; tileStartRow < endRow; tileStartRow = tileStartRow + rowsPerTile) {
      const tileEndRow = Math.min(endRow, tileStartRow + rowsPerTile)
      const tileHeight = this.pixelPositionBeforeBlocksForRow(tileEndRow) - this.pixelPositionBeforeBlocksForRow(tileStartRow)
      const tileIndex = this.tileIndexForTileStartRow(tileStartRow)

      tileNodes[tileIndex] = $(LinesTileComponent, {
        key: tileIndex,
        measuredContent: this.measuredContent,
        height: tileHeight,
        width: tileWidth,
        top: this.pixelPositionBeforeBlocksForRow(tileStartRow),
        lineHeight: this.getLineHeight(),
        renderedStartRow: startRow,
        tileStartRow,
        tileEndRow,
        screenLines: this.renderedScreenLines.slice(tileStartRow - startRow, tileEndRow - startRow),
        lineDecorations: this.decorationsToRender.lines.slice(tileStartRow - startRow, tileEndRow - startRow),
        blockDecorations: this.decorationsToRender.blocks.get(tileStartRow),
        highlightDecorations: this.decorationsToRender.highlights.get(tileStartRow),
        displayLayer,
        lineNodesByScreenLineId,
        textNodesByScreenLineId
      })
    }

    if (this.extraLinesToMeasure) {
      this.extraLinesToMeasure.forEach((screenLine, screenRow) => {
        if (screenRow < startRow || screenRow >= endRow) {
          tileNodes.push($(LineComponent, {
            key: 'extra-' + screenLine.id,
            screenLine,
            screenRow,
            displayLayer,
            lineNodesByScreenLineId,
            textNodesByScreenLineId
          }))
        }
      })
    }

    return $.div({
      key: 'lineTiles',
      ref: 'lineTiles',
      className: 'lines',
      style: {
        position: 'absolute',
        contain: 'strict',
        overflow: 'hidden',
        width: this.getScrollWidth() + 'px',
        height: this.getScrollHeight() + 'px'
      }
    }, tileNodes)
  }

  renderCursorsAndInput () {
    return $(CursorsAndInputComponent, {
      ref: 'cursorsAndInput',
      key: 'cursorsAndInput',
      didBlurHiddenInput: this.didBlurHiddenInput,
      didFocusHiddenInput: this.didFocusHiddenInput,
      didTextInput: this.didTextInput,
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
      hiddenInputPosition: this.hiddenInputPosition
    })
  }

  renderPlaceholderText () {
    const {model} = this.props
    if (model.isEmpty()) {
      const placeholderText = model.getPlaceholderText()
      if (placeholderText != null) {
        return $.div({className: 'placeholder-text'}, placeholderText)
      }
    }
    return null
  }

  renderCharacterMeasurementLine () {
    return $.div(
      {
        key: 'characterMeasurementLine',
        ref: 'characterMeasurementLine',
        className: 'line dummy',
        style: {position: 'absolute', visibility: 'hidden'}
      },
      $.span({ref: 'normalWidthCharacterSpan'}, NORMAL_WIDTH_CHARACTER),
      $.span({ref: 'doubleWidthCharacterSpan'}, DOUBLE_WIDTH_CHARACTER),
      $.span({ref: 'halfWidthCharacterSpan'}, HALF_WIDTH_CHARACTER),
      $.span({ref: 'koreanCharacterSpan'}, KOREAN_CHARACTER)
    )
  }

  renderBlockDecorationMeasurementArea () {
    return $.div({
      ref: 'blockDecorationMeasurementArea',
      key: 'blockDecorationMeasurementArea',
      style: {
        contain: 'strict',
        position: 'absolute',
        visibility: 'hidden'
      }
    })
  }

  renderDummyScrollbars () {
    if (this.shouldRenderDummyScrollbars && !this.props.model.isMini()) {
      let scrollHeight, scrollTop, horizontalScrollbarHeight
      let scrollWidth, scrollLeft, verticalScrollbarWidth, forceScrollbarVisible

      if (this.hasInitialMeasurements) {
        scrollHeight = this.getScrollHeight()
        scrollWidth = this.getScrollWidth()
        scrollTop = this.getScrollTop()
        scrollLeft = this.getScrollLeft()
        horizontalScrollbarHeight =
          this.isHorizontalScrollbarVisible()
          ? this.getHorizontalScrollbarHeight()
          : 0
        verticalScrollbarWidth =
          this.isVerticalScrollbarVisible()
          ? this.getVerticalScrollbarWidth()
          : 0
        forceScrollbarVisible = this.remeasureScrollbars
      } else {
        forceScrollbarVisible = true
      }

      const dummyScrollbarVnodes = [
        $(DummyScrollbarComponent, {
          ref: 'verticalScrollbar',
          orientation: 'vertical',
          didScroll: this.didScrollDummyScrollbar,
          didMousedown: this.didMouseDownOnContent,
          scrollHeight,
          scrollTop,
          horizontalScrollbarHeight,
          forceScrollbarVisible
        }),
        $(DummyScrollbarComponent, {
          ref: 'horizontalScrollbar',
          orientation: 'horizontal',
          didScroll: this.didScrollDummyScrollbar,
          didMousedown: this.didMouseDownOnContent,
          scrollWidth,
          scrollLeft,
          verticalScrollbarWidth,
          forceScrollbarVisible
        })
      ]

      // If both scrollbars are visible, push a dummy element to force a "corner"
      // to render where the two scrollbars meet at the lower right
      if (verticalScrollbarWidth > 0 && horizontalScrollbarHeight > 0) {
        dummyScrollbarVnodes.push($.div(
          {
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
          }
        ))
      }

      return dummyScrollbarVnodes
    } else {
      return null
    }
  }

  renderOverlayDecorations () {
    return this.decorationsToRender.overlays.map((overlayProps) =>
      $(OverlayComponent, Object.assign(
        {
          key: overlayProps.element,
          overlayComponents: this.overlayComponents,
          didResize: () => { this.updateSync() }
        },
        overlayProps
      ))
    )
  }

  // Imperatively manipulate the class list of the root element to avoid
  // clearing classes assigned by package authors.
  updateClassList () {
    const {model} = this.props

    const oldClassList = this.classList
    const newClassList = ['editor']
    if (this.focused) newClassList.push('is-focused')
    if (model.isMini()) newClassList.push('mini')
    for (var i = 0; i < model.selections.length; i++) {
      if (!model.selections[i].isEmpty()) {
        newClassList.push('has-selection')
        break
      }
    }

    if (oldClassList) {
      for (let i = 0; i < oldClassList.length; i++) {
        const className = oldClassList[i]
        if (!newClassList.includes(className)) {
          this.element.classList.remove(className)
        }
      }
    }

    for (let i = 0; i < newClassList.length; i++) {
      const className = newClassList[i]
      if (!oldClassList || !oldClassList.includes(className)) {
        this.element.classList.add(className)
      }
    }

    this.classList = newClassList
  }

  queryScreenLinesToRender () {
    const {model} = this.props

    this.renderedScreenLines = model.displayLayer.getScreenLines(
      this.getRenderedStartRow(),
      this.getRenderedEndRow()
    )

    const longestLineRow = model.getApproximateLongestScreenRow()
    const longestLine = model.screenLineForScreenRow(longestLineRow)
    if (longestLine !== this.previousLongestLine) {
      this.requestExtraLineToMeasure(longestLineRow, longestLine)
      this.longestLineToMeasure = longestLine
      this.previousLongestLine = longestLine
    }
  }

  queryLineNumbersToRender () {
    const {model} = this.props
    if (!model.isLineNumberGutterVisible()) return

    this.queryMaxLineNumberDigits()

    const startRow = this.getRenderedStartRow()
    const endRow = this.getRenderedEndRow()
    const renderedRowCount = this.getRenderedRowCount()

    const {bufferRows, keys, softWrappedFlags, foldableFlags} = this.lineNumbersToRender
    bufferRows.length = renderedRowCount
    keys.length = renderedRowCount
    foldableFlags.length = renderedRowCount

    let previousBufferRow = (startRow > 0) ? model.bufferRowForScreenRow(startRow - 1) : -1
    let softWrapCount = 0
    for (let row = startRow; row < endRow; row++) {
      const i = row - startRow
      const bufferRow = model.bufferRowForScreenRow(row)
      bufferRows[i] = bufferRow
      if (bufferRow === previousBufferRow) {
        softWrapCount++
        softWrappedFlags[i] = true
        foldableFlags[i] = false
        keys[i] = bufferRow + '-' + softWrapCount
      } else {
        softWrapCount = 0
        softWrappedFlags[i] = false
        foldableFlags[i] = model.isFoldableAtBufferRow(bufferRow)
        keys[i] = bufferRow
      }
      previousBufferRow = bufferRow
    }
  }

  queryMaxLineNumberDigits () {
    const {model} = this.props
    if (model.isLineNumberGutterVisible()) {
      const maxDigits = Math.max(2, model.getLineCount().toString().length)
      if (maxDigits !== this.lineNumbersToRender.maxDigits) {
        this.remeasureGutterDimensions = true
        this.lineNumbersToRender.maxDigits = maxDigits
      }
    }
  }

  renderedScreenLineForRow (row) {
    return (
      this.renderedScreenLines[row - this.getRenderedStartRow()] ||
      (this.extraRenderedScreenLines ? this.extraRenderedScreenLines.get(row) : null)
    )
  }

  queryGuttersToRender () {
    const oldGuttersToRender = this.guttersToRender
    const oldGuttersVisibility = this.guttersVisibility
    this.guttersToRender = this.props.model.getGutters()
    this.guttersVisibility = this.guttersToRender.map(g => g.visible)

    if (!oldGuttersToRender || oldGuttersToRender.length !== this.guttersToRender.length) {
      this.remeasureGutterDimensions = true
    } else {
      for (let i = 0, length = this.guttersToRender.length; i < length; i++) {
        if (this.guttersToRender[i] !== oldGuttersToRender[i] || this.guttersVisibility[i] !== oldGuttersVisibility[i]) {
          this.remeasureGutterDimensions = true
          break
        }
      }
    }
  }

  queryDecorationsToRender () {
    this.decorationsToRender.lineNumbers = []
    this.decorationsToRender.lines = []
    this.decorationsToRender.overlays.length = 0
    this.decorationsToRender.customGutter.clear()
    this.decorationsToRender.blocks = new Map()
    this.decorationsToMeasure.highlights.clear()
    this.decorationsToMeasure.cursors.clear()

    const decorationsByMarker =
      this.props.model.decorationManager.decorationPropertiesByMarkerForScreenRowRange(
        this.getRenderedStartRow(),
        this.getRenderedEndRow()
      )

    decorationsByMarker.forEach((decorations, marker) => {
      const screenRange = marker.getScreenRange()
      const reversed = marker.isReversed()
      for (let i = 0; i < decorations.length; i++) {
        const decoration = decorations[i]
        this.addDecorationToRender(decoration.type, decoration, marker, screenRange, reversed)
      }
    })
  }

  addDecorationToRender (type, decoration, marker, screenRange, reversed) {
    if (Array.isArray(type)) {
      for (let i = 0, length = type.length; i < length; i++) {
        this.addDecorationToRender(type[i], decoration, marker, screenRange, reversed)
      }
    } else {
      switch (type) {
        case 'line':
        case 'line-number':
          this.addLineDecorationToRender(type, decoration, screenRange, reversed)
          break
        case 'highlight':
          this.addHighlightDecorationToMeasure(decoration, screenRange, marker.id)
          break
        case 'cursor':
          this.addCursorDecorationToMeasure(decoration, marker, screenRange, reversed)
          break
        case 'overlay':
          this.addOverlayDecorationToRender(decoration, marker)
          break
        case 'gutter':
          this.addCustomGutterDecorationToRender(decoration, screenRange)
          break
        case 'block':
          this.addBlockDecorationToRender(decoration, screenRange, reversed)
          break
      }
    }
  }

  addLineDecorationToRender (type, decoration, screenRange, reversed) {
    const decorationsToRender = (type === 'line') ? this.decorationsToRender.lines : this.decorationsToRender.lineNumbers

    let omitLastRow = false
    if (screenRange.isEmpty()) {
      if (decoration.onlyNonEmpty) return
    } else {
      if (decoration.onlyEmpty) return
      if (decoration.omitEmptyLastRow !== false) {
        omitLastRow = screenRange.end.column === 0
      }
    }

    const renderedStartRow = this.getRenderedStartRow()
    let rangeStartRow = screenRange.start.row
    let rangeEndRow = screenRange.end.row

    if (decoration.onlyHead) {
      if (reversed) {
        rangeEndRow = rangeStartRow
      } else {
        rangeStartRow = rangeEndRow
      }
    }

    rangeStartRow = Math.max(rangeStartRow, this.getRenderedStartRow())
    rangeEndRow = Math.min(rangeEndRow, this.getRenderedEndRow() - 1)

    for (let row = rangeStartRow; row <= rangeEndRow; row++) {
      if (omitLastRow && row === screenRange.end.row) break
      const currentClassName = decorationsToRender[row - renderedStartRow]
      const newClassName = currentClassName ? currentClassName + ' ' + decoration.class : decoration.class
      decorationsToRender[row - renderedStartRow] = newClassName
    }
  }

  addHighlightDecorationToMeasure (decoration, screenRange, key) {
    screenRange = constrainRangeToRows(screenRange, this.getRenderedStartRow(), this.getRenderedEndRow())
    if (screenRange.isEmpty()) return

    const {class: className, flashRequested, flashClass, flashDuration} = decoration
    decoration.flashRequested = false

    let tileStartRow = this.tileStartRowForRow(screenRange.start.row)
    const rowsPerTile = this.getRowsPerTile()

    while (tileStartRow <= screenRange.end.row) {
      const tileEndRow = tileStartRow + rowsPerTile
      const screenRangeInTile = constrainRangeToRows(screenRange, tileStartRow, tileEndRow)

      let tileHighlights = this.decorationsToMeasure.highlights.get(tileStartRow)
      if (!tileHighlights) {
        tileHighlights = []
        this.decorationsToMeasure.highlights.set(tileStartRow, tileHighlights)
      }

      tileHighlights.push({
        screenRange: screenRangeInTile,
        key,
        className,
        flashRequested,
        flashClass,
        flashDuration
      })

      this.requestHorizontalMeasurement(screenRangeInTile.start.row, screenRangeInTile.start.column)
      this.requestHorizontalMeasurement(screenRangeInTile.end.row, screenRangeInTile.end.column)

      tileStartRow = tileStartRow + rowsPerTile
    }
  }

  addCursorDecorationToMeasure (decoration, marker, screenRange, reversed) {
    const {model} = this.props
    if (!model.getShowCursorOnSelection() && !screenRange.isEmpty()) return

    let decorationToMeasure = this.decorationsToMeasure.cursors.get(marker)
    if (!decorationToMeasure) {
      const isLastCursor = model.getLastCursor().getMarker() === marker
      const screenPosition = reversed ? screenRange.start : screenRange.end
      const {row, column} = screenPosition

      if (row < this.getRenderedStartRow() || row >= this.getRenderedEndRow()) return

      this.requestHorizontalMeasurement(row, column)
      let columnWidth = 0
      if (model.lineLengthForScreenRow(row) > column) {
        columnWidth = 1
        this.requestHorizontalMeasurement(row, column + 1)
      }
      decorationToMeasure = {screenPosition, columnWidth, isLastCursor}
      this.decorationsToMeasure.cursors.set(marker, decorationToMeasure)
    }

    if (decoration.class) {
      if (decorationToMeasure.className) {
        decorationToMeasure.className += ' ' + decoration.class
      } else {
        decorationToMeasure.className = decoration.class
      }
    }

    if (decoration.style) {
      if (decorationToMeasure.style) {
        Object.assign(decorationToMeasure.style, decoration.style)
      } else {
        decorationToMeasure.style = Object.assign({}, decoration.style)
      }
    }
  }

  addOverlayDecorationToRender (decoration, marker) {
    const {class: className, item, position, avoidOverflow} = decoration
    const element = TextEditor.viewForItem(item)
    const screenPosition = (position === 'tail')
      ? marker.getTailScreenPosition()
      : marker.getHeadScreenPosition()

    this.requestHorizontalMeasurement(screenPosition.row, screenPosition.column)
    this.decorationsToRender.overlays.push({className, element, avoidOverflow, screenPosition})
  }

  addCustomGutterDecorationToRender (decoration, screenRange) {
    let decorations = this.decorationsToRender.customGutter.get(decoration.gutterName)
    if (!decorations) {
      decorations = []
      this.decorationsToRender.customGutter.set(decoration.gutterName, decorations)
    }
    const top = this.pixelPositionAfterBlocksForRow(screenRange.start.row)
    const height = this.pixelPositionBeforeBlocksForRow(screenRange.end.row + 1) - top

    decorations.push({
      className: decoration.class,
      element: TextEditor.viewForItem(decoration.item),
      top,
      height
    })
  }

  addBlockDecorationToRender (decoration, screenRange, reversed) {
    const screenPosition = reversed ? screenRange.start : screenRange.end
    const tileStartRow = this.tileStartRowForRow(screenPosition.row)
    const screenLine = this.renderedScreenLines[screenPosition.row - this.getRenderedStartRow()]

    let decorationsByScreenLine = this.decorationsToRender.blocks.get(tileStartRow)
    if (!decorationsByScreenLine) {
      decorationsByScreenLine = new Map()
      this.decorationsToRender.blocks.set(tileStartRow, decorationsByScreenLine)
    }

    let decorations = decorationsByScreenLine.get(screenLine.id)
    if (!decorations) {
      decorations = []
      decorationsByScreenLine.set(screenLine.id, decorations)
    }
    decorations.push(decoration)
  }

  updateAbsolutePositionedDecorations () {
    this.updateHighlightsToRender()
    this.updateCursorsToRender()
    this.updateOverlaysToRender()
  }

  updateHighlightsToRender () {
    this.decorationsToRender.highlights.clear()
    this.decorationsToMeasure.highlights.forEach((highlights, tileRow) => {
      for (let i = 0, length = highlights.length; i < length; i++) {
        const highlight = highlights[i]
        const {start, end} = highlight.screenRange
        highlight.startPixelTop = this.pixelPositionAfterBlocksForRow(start.row)
        highlight.startPixelLeft = this.pixelLeftForRowAndColumn(start.row, start.column)
        highlight.endPixelTop = this.pixelPositionBeforeBlocksForRow(end.row + 1)
        highlight.endPixelLeft = this.pixelLeftForRowAndColumn(end.row, end.column)
      }
      this.decorationsToRender.highlights.set(tileRow, highlights)
    })
  }

  updateCursorsToRender () {
    this.decorationsToRender.cursors.length = 0

    this.decorationsToMeasure.cursors.forEach((cursor) => {
      const {screenPosition, className, style} = cursor
      const {row, column} = screenPosition

      const pixelTop = this.pixelPositionAfterBlocksForRow(row)
      const pixelLeft = this.pixelLeftForRowAndColumn(row, column)
      let pixelWidth
      if (cursor.columnWidth === 0) {
        pixelWidth = this.getBaseCharacterWidth()
      } else {
        pixelWidth = this.pixelLeftForRowAndColumn(row, column + 1) - pixelLeft
      }

      const cursorPosition = {pixelTop, pixelLeft, pixelWidth, className, style}
      this.decorationsToRender.cursors.push(cursorPosition)
      if (cursor.isLastCursor) this.hiddenInputPosition = cursorPosition
    })
  }

  updateOverlaysToRender () {
    const overlayCount = this.decorationsToRender.overlays.length
    if (overlayCount === 0) return null

    const windowInnerHeight = this.getWindowInnerHeight()
    const windowInnerWidth = this.getWindowInnerWidth()
    const contentClientRect = this.refs.content.getBoundingClientRect()
    for (let i = 0; i < overlayCount; i++) {
      const decoration = this.decorationsToRender.overlays[i]
      const {element, screenPosition, avoidOverflow} = decoration
      const {row, column} = screenPosition
      let wrapperTop = contentClientRect.top + this.pixelPositionAfterBlocksForRow(row) + this.getLineHeight()
      let wrapperLeft = contentClientRect.left + this.pixelLeftForRowAndColumn(row, column)

      if (avoidOverflow !== false) {
        const computedStyle = window.getComputedStyle(element)
        const elementHeight = element.offsetHeight
        const elementTop = wrapperTop + parseInt(computedStyle.marginTop)
        const elementBottom = elementTop + elementHeight
        const flippedElementTop = wrapperTop - this.getLineHeight() - elementHeight - parseInt(computedStyle.marginBottom)
        const elementLeft = wrapperLeft + parseInt(computedStyle.marginLeft)
        const elementRight = elementLeft + element.offsetWidth

        if (elementBottom > windowInnerHeight && flippedElementTop >= 0) {
          wrapperTop -= (elementTop - flippedElementTop)
        }
        if (elementLeft < 0) {
          wrapperLeft -= elementLeft
        } else if (elementRight > windowInnerWidth) {
          wrapperLeft -= (elementRight - windowInnerWidth)
        }
      }

      decoration.pixelTop = wrapperTop
      decoration.pixelLeft = wrapperLeft
    }
  }

  didAttach () {
    if (!this.attached) {
      this.attached = true
      this.intersectionObserver = new IntersectionObserver((entries) => {
        const {intersectionRect} = entries[entries.length - 1]
        if (intersectionRect.width > 0 || intersectionRect.height > 0) {
          this.didShow()
        } else {
          this.didHide()
        }
      })
      this.intersectionObserver.observe(this.element)

      this.resizeObserver = new ResizeObserver(this.didResize.bind(this))
      this.resizeObserver.observe(this.element)

      if (this.refs.gutterContainer) {
        this.gutterContainerResizeObserver = new ResizeObserver(this.didResizeGutterContainer.bind(this))
        this.gutterContainerResizeObserver.observe(this.refs.gutterContainer.element)
      }

      this.overlayComponents.forEach((component) => component.didAttach())

      if (this.isVisible()) {
        this.didShow()
      } else {
        this.didHide()
      }
      if (!this.constructor.attachedComponents) {
        this.constructor.attachedComponents = new Set()
      }
      this.constructor.attachedComponents.add(this)
    }
  }

  didDetach () {
    if (this.attached) {
      this.intersectionObserver.disconnect()
      this.resizeObserver.disconnect()
      if (this.gutterContainerResizeObserver) this.gutterContainerResizeObserver.disconnect()
      this.overlayComponents.forEach((component) => component.didDetach())

      this.didHide()
      this.attached = false
      this.constructor.attachedComponents.delete(this)
    }
  }

  didShow () {
    if (!this.visible && this.isVisible()) {
      if (!this.hasInitialMeasurements) this.measureDimensions()
      this.visible = true
      this.props.model.setVisible(true)
      this.updateSync()
      this.flushPendingLogicalScrollPosition()
    }
  }

  didHide () {
    if (this.visible) {
      this.visible = false
      this.props.model.setVisible(false)
    }
  }

  // Called by TextEditorElement so that focus events can be handled before
  // the element is attached to the DOM.
  didFocus () {
    // This element can be focused from a parent custom element's
    // attachedCallback before *its* attachedCallback is fired. This protects
    // against that case.
    if (!this.attached) this.didAttach()

    // The element can be focused before the intersection observer detects that
    // it has been shown for the first time. If this element is being focused,
    // it is necessarily visible, so we call `didShow` to ensure the hidden
    // input is rendered before we try to shift focus to it.
    if (!this.visible) this.didShow()

    if (!this.focused) {
      this.focused = true
      this.startCursorBlinking()
      this.scheduleUpdate()
    }

    // Transfer focus to the hidden input, but first ensure the input is in the
    // visible part of the scrolled content to avoid the browser trying to
    // auto-scroll to the form-field.
    const {hiddenInput} = this.refs.cursorsAndInput.refs
    hiddenInput.style.top = this.getScrollTop() + 'px'
    hiddenInput.style.left = this.getScrollLeft() + 'px'

    hiddenInput.focus()

    // Restore the previous position of the field now that it is already focused
    // and won't cause unwanted scrolling.
    if (this.hiddenInputPosition) {
      hiddenInput.style.top = this.hiddenInputPosition.pixelTop + 'px'
      hiddenInput.style.left = this.hiddenInputPosition.pixelLeft + 'px'
    } else {
      hiddenInput.style.top = 0
      hiddenInput.style.left = 0
    }
  }

  // Called by TextEditorElement so that this function is always the first
  // listener to be fired, even if other listeners are bound before creating
  // the component.
  didBlur (event) {
    if (event.relatedTarget === this.refs.cursorsAndInput.refs.hiddenInput) {
      event.stopImmediatePropagation()
    }
  }

  didBlurHiddenInput (event) {
    if (this.element !== event.relatedTarget && !this.element.contains(event.relatedTarget)) {
      this.focused = false
      this.stopCursorBlinking()
      this.scheduleUpdate()
      this.element.dispatchEvent(new FocusEvent(event.type, event))
    }
  }

  didFocusHiddenInput () {
    if (!this.focused) {
      this.focused = true
      this.startCursorBlinking()
      this.scheduleUpdate()
    }
  }

  didMouseWheel (event) {
    const scrollSensitivity = this.props.mouseWheelScrollSensitivity || 0.8

    let {deltaX, deltaY} = event
    deltaX = deltaX * scrollSensitivity
    deltaY = deltaY * scrollSensitivity

    if (this.getPlatform() !== 'darwin' && event.shiftKey) {
      let temp = deltaX
      deltaX = deltaY
      deltaY = temp
    }

    const scrollPositionChanged =
      this.setScrollLeft(this.getScrollLeft() + deltaX) ||
      this.setScrollTop(this.getScrollTop() + deltaY)

    if (scrollPositionChanged) this.updateSync()
  }

  didResize () {
    // Prevent the component from measuring the client container dimensions when
    // getting spurious resize events.
    if (this.isVisible()) {
      const clientContainerWidthChanged = this.measureClientContainerWidth()
      const clientContainerHeightChanged = this.measureClientContainerHeight()
      if (clientContainerWidthChanged || clientContainerHeightChanged) {
        if (clientContainerWidthChanged) {
          this.remeasureAllBlockDecorations = true
        }

        this.resizeObserver.disconnect()
        this.scheduleUpdate()
        process.nextTick(() => { this.resizeObserver.observe(this.element) })
      }
    }
  }

  didResizeGutterContainer () {
    // Prevent the component from measuring the gutter dimensions when getting
    // spurious resize events.
    if (this.isVisible() && this.measureGutterDimensions()) {
      this.gutterContainerResizeObserver.disconnect()
      this.scheduleUpdate()
      process.nextTick(() => { this.gutterContainerResizeObserver.observe(this.refs.gutterContainer.element) })
    }
  }

  didScrollDummyScrollbar () {
    let scrollTopChanged = false
    let scrollLeftChanged = false
    if (!this.scrollTopPending) {
      scrollTopChanged = this.setScrollTop(this.refs.verticalScrollbar.element.scrollTop)
    }
    if (!this.scrollLeftPending) {
      scrollLeftChanged = this.setScrollLeft(this.refs.horizontalScrollbar.element.scrollLeft)
    }
    if (scrollTopChanged || scrollLeftChanged) this.updateSync()
  }

  didUpdateStyles () {
    this.remeasureCharacterDimensions = true
    this.horizontalPixelPositionsByScreenLineId.clear()
    this.scheduleUpdate()
  }

  didUpdateScrollbarStyles () {
    if (!this.props.model.isMini()) {
      this.remeasureScrollbars = true
      this.scheduleUpdate()
    }
  }

  didTextInput (event) {
    if (!this.isInputEnabled()) return

    event.stopPropagation()

    // WARNING: If we call preventDefault on the input of a space character,
    // then the browser interprets the spacebar keypress as a page-down command,
    // causing spaces to scroll elements containing editors. This is impossible
    // to test.
    if (event.data !== ' ') event.preventDefault()

    if (this.compositionCheckpoint) {
      this.props.model.revertToCheckpoint(this.compositionCheckpoint)
      this.compositionCheckpoint = null
    }

    // If the input event is fired while the accented character menu is open it
    // means that the user has chosen one of the accented alternatives. Thus, we
    // will replace the original non accented character with the selected
    // alternative.
    if (this.accentedCharacterMenuIsOpen) {
      this.props.model.selectLeft()
    }

    this.props.model.insertText(event.data, {groupUndo: true})
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
  didKeydown (event) {
    if (this.lastKeydownBeforeKeypress != null) {
      if (this.lastKeydownBeforeKeypress.code === event.code) {
        this.accentedCharacterMenuIsOpen = true
      }

      this.lastKeydownBeforeKeypress = null
    }

    this.lastKeydown = event
  }

  didKeypress (event) {
    this.lastKeydownBeforeKeypress = this.lastKeydown
    this.lastKeydown = null

    // This cancels the accented character behavior if we type a key normally
    // with the menu open.
    this.accentedCharacterMenuIsOpen = false
  }

  didKeyup (event) {
    if (this.lastKeydownBeforeKeypress && this.lastKeydownBeforeKeypress.code === event.code) {
      this.lastKeydownBeforeKeypress = null
      this.lastKeydown = null
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
  didCompositionStart () {
    this.compositionCheckpoint = this.props.model.createCheckpoint()
    if (this.accentedCharacterMenuIsOpen) {
      this.props.model.selectLeft()
    }
  }

  didCompositionUpdate (event) {
    this.props.model.insertText(event.data, {select: true})
  }

  didCompositionEnd (event) {
    event.target.value = ''
  }

  didMouseDownOnContent (event) {
    const {model} = this.props
    const {target, button, detail, ctrlKey, shiftKey, metaKey} = event

    // Only handle mousedown events for left mouse button (or the middle mouse
    // button on Linux where it pastes the selection clipboard).
    if (!(button === 0 || (this.getPlatform() === 'linux' && button === 1))) return

    const screenPosition = this.screenPositionForMouseEvent(event)

    if (target && target.matches('.fold-marker')) {
      const bufferPosition = model.bufferPositionForScreenPosition(screenPosition)
      model.destroyFoldsIntersectingBufferRange(Range(bufferPosition, bufferPosition))
      return
    }

    // Handle middle mouse button only on Linux (paste clipboard)
    if (this.getPlatform() === 'linux' && button === 1) {
      const selection = clipboard.readText('selection')
      model.setCursorScreenPosition(screenPosition, {autoscroll: false})
      model.insertText(selection)
      return
    }

    const addOrRemoveSelection = metaKey || (ctrlKey && this.getPlatform() !== 'darwin')

    switch (detail) {
      case 1:
        if (addOrRemoveSelection) {
          const existingSelection = model.getSelectionAtScreenPosition(screenPosition)
          if (existingSelection) {
            if (model.hasMultipleCursors()) existingSelection.destroy()
          } else {
            model.addCursorAtScreenPosition(screenPosition)
          }
        } else {
          if (shiftKey) {
            model.selectToScreenPosition(screenPosition)
          } else {
            model.setCursorScreenPosition(screenPosition)
          }
        }
        break
      case 2:
        if (addOrRemoveSelection) model.addCursorAtScreenPosition(screenPosition)
        model.getLastSelection().selectWord({autoscroll: false})
        break
      case 3:
        if (addOrRemoveSelection) model.addCursorAtScreenPosition(screenPosition)
        model.getLastSelection().selectLine(null, {autoscroll: false})
        break
    }

    this.handleMouseDragUntilMouseUp({
      didDrag: (event) => {
        this.autoscrollOnMouseDrag(event)
        const screenPosition = this.screenPositionForMouseEvent(event)
        model.selectToScreenPosition(screenPosition, {suppressSelectionMerge: true, autoscroll: false})
        this.updateSync()
      },
      didStopDragging: () => {
        model.finalizeSelections()
        model.mergeIntersectingSelections()
        this.updateSync()
      }
    })
  }

  didMouseDownOnLineNumberGutter (event) {
    const {model} = this.props
    const {target, button, ctrlKey, shiftKey, metaKey} = event

    // Only handle mousedown events for left mouse button
    if (button !== 0) return

    const clickedScreenRow = this.screenPositionForMouseEvent(event).row
    const startBufferRow = model.bufferPositionForScreenPosition([clickedScreenRow, 0]).row

    if (target && target.matches('.foldable .icon-right')) {
      model.toggleFoldAtBufferRow(startBufferRow)
      return
    }

    const addOrRemoveSelection = metaKey || (ctrlKey && this.getPlatform() !== 'darwin')
    const endBufferRow = model.bufferPositionForScreenPosition([clickedScreenRow, Infinity]).row
    const clickedLineBufferRange = Range(Point(startBufferRow, 0), Point(endBufferRow + 1, 0))

    let initialBufferRange
    if (shiftKey) {
      const lastSelection = model.getLastSelection()
      initialBufferRange = lastSelection.getBufferRange()
      lastSelection.setBufferRange(initialBufferRange.union(clickedLineBufferRange), {
        reversed: clickedScreenRow < lastSelection.getScreenRange().start.row,
        autoscroll: false,
        preserveFolds: true,
        suppressSelectionMerge: true
      })
    } else {
      initialBufferRange = clickedLineBufferRange
      if (addOrRemoveSelection) {
        model.addSelectionForBufferRange(clickedLineBufferRange, {autoscroll: false, preserveFolds: true})
      } else {
        model.setSelectedBufferRange(clickedLineBufferRange, {autoscroll: false, preserveFolds: true})
      }
    }

    const initialScreenRange = model.screenRangeForBufferRange(initialBufferRange)
    this.handleMouseDragUntilMouseUp({
      didDrag: (event) => {
        this.autoscrollOnMouseDrag(event, true)
        const dragRow = this.screenPositionForMouseEvent(event).row
        const draggedLineScreenRange = Range(Point(dragRow, 0), Point(dragRow + 1, 0))
        model.getLastSelection().setScreenRange(draggedLineScreenRange.union(initialScreenRange), {
          reversed: dragRow < initialScreenRange.start.row,
          autoscroll: false,
          preserveFolds: true
        })
        this.updateSync()
      },
      didStopDragging: () => {
        model.mergeIntersectingSelections()
        this.updateSync()
      }
    })
  }

  handleMouseDragUntilMouseUp ({didDrag, didStopDragging}) {
    let dragging = false
    let lastMousemoveEvent

    const animationFrameLoop = () => {
      window.requestAnimationFrame(() => {
        if (dragging && this.visible) {
          didDrag(lastMousemoveEvent)
          animationFrameLoop()
        }
      })
    }

    function didMouseMove (event) {
      lastMousemoveEvent = event
      if (!dragging) {
        dragging = true
        animationFrameLoop()
      }
    }

    function didMouseUp () {
      window.removeEventListener('mousemove', didMouseMove)
      window.removeEventListener('mouseup', didMouseUp)
      if (dragging) {
        dragging = false
        didStopDragging()
      }
    }

    window.addEventListener('mousemove', didMouseMove)
    window.addEventListener('mouseup', didMouseUp)
  }

  autoscrollOnMouseDrag ({clientX, clientY}, verticalOnly = false) {
    var {top, bottom, left, right} = this.refs.scrollContainer.getBoundingClientRect() // Using var to avoid deopt on += assignments below
    top += MOUSE_DRAG_AUTOSCROLL_MARGIN
    bottom -= MOUSE_DRAG_AUTOSCROLL_MARGIN
    left += MOUSE_DRAG_AUTOSCROLL_MARGIN
    right -= MOUSE_DRAG_AUTOSCROLL_MARGIN

    let yDelta, yDirection
    if (clientY < top) {
      yDelta = top - clientY
      yDirection = -1
    } else if (clientY > bottom) {
      yDelta = clientY - bottom
      yDirection = 1
    }

    let xDelta, xDirection
    if (clientX < left) {
      xDelta = left - clientX
      xDirection = -1
    } else if (clientX > right) {
      xDelta = clientX - right
      xDirection = 1
    }

    let scrolled = false
    if (yDelta != null) {
      const scaledDelta = scaleMouseDragAutoscrollDelta(yDelta) * yDirection
      scrolled = this.setScrollTop(this.getScrollTop() + scaledDelta)
    }

    if (!verticalOnly && xDelta != null) {
      const scaledDelta = scaleMouseDragAutoscrollDelta(xDelta) * xDirection
      scrolled = this.setScrollLeft(this.getScrollLeft() + scaledDelta)
    }

    if (scrolled) this.updateSync()
  }

  screenPositionForMouseEvent (event) {
    return this.screenPositionForPixelPosition(this.pixelPositionForMouseEvent(event))
  }

  pixelPositionForMouseEvent ({clientX, clientY}) {
    const scrollContainerRect = this.refs.scrollContainer.getBoundingClientRect()
    clientX = Math.min(scrollContainerRect.right, Math.max(scrollContainerRect.left, clientX))
    clientY = Math.min(scrollContainerRect.bottom, Math.max(scrollContainerRect.top, clientY))
    const linesRect = this.refs.lineTiles.getBoundingClientRect()
    return {
      top: clientY - linesRect.top,
      left: clientX - linesRect.left
    }
  }

  didUpdateSelections () {
    this.pauseCursorBlinking()
    this.scheduleUpdate()
  }

  pauseCursorBlinking () {
    this.stopCursorBlinking()
    if (this.resumeCursorBlinkingTimeoutHandle) {
      window.clearTimeout(this.resumeCursorBlinkingTimeoutHandle)
    }
    this.resumeCursorBlinkingTimeoutHandle = window.setTimeout(() => {
      this.cursorsBlinkedOff = true
      this.startCursorBlinking()
      this.resumeCursorBlinkingTimeoutHandle = null
    }, (this.props.cursorBlinkResumeDelay || CURSOR_BLINK_RESUME_DELAY))
  }

  stopCursorBlinking () {
    if (this.cursorsBlinking) {
      this.cursorsBlinkedOff = false
      this.cursorsBlinking = false
      window.clearInterval(this.cursorBlinkIntervalHandle)
      this.cursorBlinkIntervalHandle = null
      this.scheduleUpdate()
    }
  }

  startCursorBlinking () {
    if (!this.cursorsBlinking) {
      this.cursorBlinkIntervalHandle = window.setInterval(() => {
        this.cursorsBlinkedOff = !this.cursorsBlinkedOff
        this.scheduleUpdate(true)
      }, (this.props.cursorBlinkPeriod || CURSOR_BLINK_PERIOD) / 2)
      this.cursorsBlinking = true
      this.scheduleUpdate(true)
    }
  }

  didRequestAutoscroll (autoscroll) {
    this.pendingAutoscroll = autoscroll
    this.scheduleUpdate()
  }

  flushPendingLogicalScrollPosition () {
    let changedScrollTop = false
    if (this.pendingScrollTopRow > 0) {
      changedScrollTop = this.setScrollTopRow(this.pendingScrollTopRow, false)
      this.pendingScrollTopRow = null
    }

    let changedScrollLeft = false
    if (this.pendingScrollLeftColumn > 0) {
      changedScrollLeft = this.setScrollLeftColumn(this.pendingScrollLeftColumn, false)
      this.pendingScrollLeftColumn = null
    }

    if (changedScrollTop || changedScrollLeft) {
      this.updateSync()
    }
  }

  autoscrollVertically () {
    const {screenRange, options} = this.pendingAutoscroll

    const screenRangeTop = this.pixelPositionAfterBlocksForRow(screenRange.start.row)
    const screenRangeBottom = this.pixelPositionAfterBlocksForRow(screenRange.end.row) + this.getLineHeight()
    const verticalScrollMargin = this.getVerticalAutoscrollMargin()

    this.requestHorizontalMeasurement(screenRange.start.row, screenRange.start.column)
    this.requestHorizontalMeasurement(screenRange.end.row, screenRange.end.column)

    let desiredScrollTop, desiredScrollBottom
    if (options && options.center) {
      const desiredScrollCenter = (screenRangeTop + screenRangeBottom) / 2
      if (desiredScrollCenter < this.getScrollTop() || desiredScrollCenter > this.getScrollBottom()) {
        desiredScrollTop = desiredScrollCenter - this.getScrollContainerClientHeight() / 2
        desiredScrollBottom = desiredScrollCenter + this.getScrollContainerClientHeight() / 2
      }
    } else {
      desiredScrollTop = screenRangeTop - verticalScrollMargin
      desiredScrollBottom = screenRangeBottom + verticalScrollMargin
    }

    if (!options || options.reversed !== false) {
      if (desiredScrollBottom > this.getScrollBottom()) {
        this.setScrollBottom(desiredScrollBottom)
      }
      if (desiredScrollTop < this.getScrollTop()) {
        this.setScrollTop(desiredScrollTop)
      }
    } else {
      if (desiredScrollTop < this.getScrollTop()) {
        this.setScrollTop(desiredScrollTop)
      }
      if (desiredScrollBottom > this.getScrollBottom()) {
        this.setScrollBottom(desiredScrollBottom)
      }
    }

    return false
  }

  autoscrollHorizontally () {
    const horizontalScrollMargin = this.getHorizontalAutoscrollMargin()

    const {screenRange, options} = this.pendingAutoscroll
    const gutterContainerWidth = this.getGutterContainerWidth()
    let left = this.pixelLeftForRowAndColumn(screenRange.start.row, screenRange.start.column) + gutterContainerWidth
    let right = this.pixelLeftForRowAndColumn(screenRange.end.row, screenRange.end.column) + gutterContainerWidth
    const desiredScrollLeft = Math.max(0, left - horizontalScrollMargin - gutterContainerWidth)
    const desiredScrollRight = Math.min(this.getScrollWidth(), right + horizontalScrollMargin)

    if (!options || options.reversed !== false) {
      if (desiredScrollRight > this.getScrollRight()) {
        this.setScrollRight(desiredScrollRight)
      }
      if (desiredScrollLeft < this.getScrollLeft()) {
        this.setScrollLeft(desiredScrollLeft)
      }
    } else {
      if (desiredScrollLeft < this.getScrollLeft()) {
        this.setScrollLeft(desiredScrollLeft)
      }
      if (desiredScrollRight > this.getScrollRight()) {
        this.setScrollRight(desiredScrollRight)
      }
    }
  }

  getVerticalAutoscrollMargin () {
    const maxMarginInLines = Math.floor(
      (this.getScrollContainerClientHeight() / this.getLineHeight() - 1) / 2
    )
    const marginInLines = Math.min(
      this.props.model.verticalScrollMargin,
      maxMarginInLines
    )
    return marginInLines * this.getLineHeight()
  }

  getHorizontalAutoscrollMargin () {
    const maxMarginInBaseCharacters = Math.floor(
      (this.getScrollContainerClientWidth() / this.getBaseCharacterWidth() - 1) / 2
    )
    const marginInBaseCharacters = Math.min(
      this.props.model.horizontalScrollMargin,
      maxMarginInBaseCharacters
    )
    return marginInBaseCharacters * this.getBaseCharacterWidth()
  }

  // This method exists because it existed in the previous implementation and some
  // package tests relied on it
  measureDimensions () {
    this.measureCharacterDimensions()
    this.measureGutterDimensions()
    this.measureClientContainerHeight()
    this.measureClientContainerWidth()
    this.measureScrollbarDimensions()
    this.hasInitialMeasurements = true
  }

  measureCharacterDimensions () {
    this.measurements.lineHeight = this.refs.characterMeasurementLine.getBoundingClientRect().height
    this.measurements.baseCharacterWidth = this.refs.normalWidthCharacterSpan.getBoundingClientRect().width
    this.measurements.doubleWidthCharacterWidth = this.refs.doubleWidthCharacterSpan.getBoundingClientRect().width
    this.measurements.halfWidthCharacterWidth = this.refs.halfWidthCharacterSpan.getBoundingClientRect().width
    this.measurements.koreanCharacterWidth = this.refs.koreanCharacterSpan.getBoundingClientRect().width

    this.props.model.setLineHeightInPixels(this.measurements.lineHeight)
    this.props.model.setDefaultCharWidth(
      this.measurements.baseCharacterWidth,
      this.measurements.doubleWidthCharacterWidth,
      this.measurements.halfWidthCharacterWidth,
      this.measurements.koreanCharacterWidth
    )
    this.lineTopIndex.setDefaultLineHeight(this.measurements.lineHeight)
  }

  measureGutterDimensions () {
    let dimensionsChanged = false

    if (this.refs.gutterContainer) {
      const gutterContainerWidth = this.refs.gutterContainer.element.offsetWidth
      if (gutterContainerWidth !== this.measurements.gutterContainerWidth) {
        dimensionsChanged = true
        this.measurements.gutterContainerWidth = gutterContainerWidth
      }
    } else {
      this.measurements.gutterContainerWidth = 0
    }

    if (this.refs.gutterContainer && this.refs.gutterContainer.refs.lineNumberGutter) {
      const lineNumberGutterWidth = this.refs.gutterContainer.refs.lineNumberGutter.element.offsetWidth
      if (lineNumberGutterWidth !== this.measurements.lineNumberGutterWidth) {
        dimensionsChanged = true
        this.measurements.lineNumberGutterWidth = lineNumberGutterWidth
      }
    } else {
      this.measurements.lineNumberGutterWidth = 0
    }

    return dimensionsChanged
  }

  measureClientContainerHeight () {
    const clientContainerHeight = this.refs.clientContainer.offsetHeight
    if (clientContainerHeight !== this.measurements.clientContainerHeight) {
      this.measurements.clientContainerHeight = clientContainerHeight
      return true
    } else {
      return false
    }
  }

  measureClientContainerWidth () {
    const clientContainerWidth = this.refs.clientContainer.offsetWidth
    if (clientContainerWidth !== this.measurements.clientContainerWidth) {
      this.measurements.clientContainerWidth = clientContainerWidth
      this.props.model.setEditorWidthInChars(this.getScrollContainerWidth() / this.getBaseCharacterWidth())
      return true
    } else {
      return false
    }
  }

  measureScrollbarDimensions () {
    if (this.props.model.isMini()) {
      this.measurements.verticalScrollbarWidth = 0
      this.measurements.horizontalScrollbarHeight = 0
    } else {
      this.measurements.verticalScrollbarWidth = this.refs.verticalScrollbar.getRealScrollbarWidth()
      this.measurements.horizontalScrollbarHeight = this.refs.horizontalScrollbar.getRealScrollbarHeight()
    }
  }

  measureLongestLineWidth () {
    if (this.longestLineToMeasure) {
      this.measurements.longestLineWidth = this.lineNodesByScreenLineId.get(this.longestLineToMeasure.id).firstChild.offsetWidth
      this.longestLineToMeasure = null
    }
  }

  requestExtraLineToMeasure (row, screenLine) {
    if (!this.extraLinesToMeasure) this.extraLinesToMeasure = new Map()
    this.extraLinesToMeasure.set(row, screenLine)
  }

  requestHorizontalMeasurement (row, column) {
    if (column === 0) return

    if (row < this.getRenderedStartRow() || row >= this.getRenderedEndRow()) {
      this.requestExtraLineToMeasure(row, this.props.model.screenLineForScreenRow(row))
    }

    let columns = this.horizontalPositionsToMeasure.get(row)
    if (columns == null) {
      columns = []
      this.horizontalPositionsToMeasure.set(row, columns)
    }
    columns.push(column)
  }

  measureHorizontalPositions () {
    this.horizontalPositionsToMeasure.forEach((columnsToMeasure, row) => {
      columnsToMeasure.sort((a, b) => a - b)

      const screenLine = this.renderedScreenLineForRow(row)
      const lineNode = this.lineNodesByScreenLineId.get(screenLine.id)

      if (!lineNode) {
        const error = new Error('Requested measurement of a line that is not currently rendered')
        error.metadata = {row, columnsToMeasure}
        throw error
      }

      const textNodes = this.textNodesByScreenLineId.get(screenLine.id)
      let positionsForLine = this.horizontalPixelPositionsByScreenLineId.get(screenLine.id)
      if (positionsForLine == null) {
        positionsForLine = new Map()
        this.horizontalPixelPositionsByScreenLineId.set(screenLine.id, positionsForLine)
      }

      this.measureHorizontalPositionsOnLine(lineNode, textNodes, columnsToMeasure, positionsForLine)
    })
    this.horizontalPositionsToMeasure.clear()
  }

  measureHorizontalPositionsOnLine (lineNode, textNodes, columnsToMeasure, positions) {
    let lineNodeClientLeft = -1
    let textNodeStartColumn = 0
    let textNodesIndex = 0
    let lastTextNodeRight = null

    columnLoop: // eslint-disable-line no-labels
    for (let columnsIndex = 0; columnsIndex < columnsToMeasure.length; columnsIndex++) {
      const nextColumnToMeasure = columnsToMeasure[columnsIndex]
      while (textNodesIndex < textNodes.length) {
        if (nextColumnToMeasure === 0) {
          positions.set(0, 0)
          continue columnLoop // eslint-disable-line no-labels
        }

        if (positions.has(nextColumnToMeasure)) continue columnLoop // eslint-disable-line no-labels
        const textNode = textNodes[textNodesIndex]
        const textNodeEndColumn = textNodeStartColumn + textNode.textContent.length

        if (nextColumnToMeasure < textNodeEndColumn) {
          let clientPixelPosition
          if (nextColumnToMeasure === textNodeStartColumn) {
            clientPixelPosition = clientRectForRange(textNode, 0, 1).left
          } else {
            clientPixelPosition = clientRectForRange(textNode, 0, nextColumnToMeasure - textNodeStartColumn).right
          }

          if (lineNodeClientLeft === -1) {
            lineNodeClientLeft = lineNode.getBoundingClientRect().left
          }

          positions.set(nextColumnToMeasure, Math.round(clientPixelPosition - lineNodeClientLeft))
          continue columnLoop // eslint-disable-line no-labels
        } else {
          textNodesIndex++
          textNodeStartColumn = textNodeEndColumn
        }
      }

      if (lastTextNodeRight == null) {
        const lastTextNode = textNodes[textNodes.length - 1]
        lastTextNodeRight = clientRectForRange(lastTextNode, 0, lastTextNode.textContent.length).right
      }

      if (lineNodeClientLeft === -1) {
        lineNodeClientLeft = lineNode.getBoundingClientRect().left
      }

      positions.set(nextColumnToMeasure, Math.round(lastTextNodeRight - lineNodeClientLeft))
    }
  }

  rowForPixelPosition (pixelPosition) {
    return Math.max(0, this.lineTopIndex.rowForPixelPosition(pixelPosition))
  }

  pixelPositionBeforeBlocksForRow (row) {
    return this.lineTopIndex.pixelPositionBeforeBlocksForRow(row)
  }

  pixelPositionAfterBlocksForRow (row) {
    return this.lineTopIndex.pixelPositionAfterBlocksForRow(row)
  }

  pixelLeftForRowAndColumn (row, column) {
    if (column === 0) return 0
    const screenLine = this.renderedScreenLineForRow(row)
    if (screenLine) {
      const horizontalPositionsByColumn = this.horizontalPixelPositionsByScreenLineId.get(screenLine.id)
      if (horizontalPositionsByColumn) {
        return horizontalPositionsByColumn.get(column)
      }
    }
  }

  screenPositionForPixelPosition ({top, left}) {
    const {model} = this.props

    const row = Math.min(
      this.rowForPixelPosition(top),
      model.getApproximateScreenLineCount() - 1
    )

    const linesClientLeft = this.refs.lineTiles.getBoundingClientRect().left
    const targetClientLeft = linesClientLeft + Math.max(0, left)
    const screenLine = this.renderedScreenLineForRow(row)
    const textNodes = this.textNodesByScreenLineId.get(screenLine.id)

    let containingTextNodeIndex
    {
      let low = 0
      let high = textNodes.length - 1
      while (low <= high) {
        const mid = low + ((high - low) >> 1)
        const textNode = textNodes[mid]
        const textNodeRect = clientRectForRange(textNode, 0, textNode.length)

        if (targetClientLeft < textNodeRect.left) {
          high = mid - 1
          containingTextNodeIndex = Math.max(0, mid - 1)
        } else if (targetClientLeft > textNodeRect.right) {
          low = mid + 1
          containingTextNodeIndex = Math.min(textNodes.length - 1, mid + 1)
        } else {
          containingTextNodeIndex = mid
          break
        }
      }
    }
    const containingTextNode = textNodes[containingTextNodeIndex]
    let characterIndex = 0
    {
      let low = 0
      let high = containingTextNode.length - 1
      while (low <= high) {
        const charIndex = low + ((high - low) >> 1)
        const nextCharIndex = isPairedCharacter(containingTextNode.textContent, charIndex)
          ? charIndex + 2
          : charIndex + 1

        const rangeRect = clientRectForRange(containingTextNode, charIndex, nextCharIndex)
        if (targetClientLeft < rangeRect.left) {
          high = charIndex - 1
          characterIndex = Math.max(0, charIndex - 1)
        } else if (targetClientLeft > rangeRect.right) {
          low = nextCharIndex
          characterIndex = Math.min(containingTextNode.textContent.length, nextCharIndex)
        } else {
          if (targetClientLeft <= ((rangeRect.left + rangeRect.right) / 2)) {
            characterIndex = charIndex
          } else {
            characterIndex = nextCharIndex
          }
          break
        }
      }
    }

    let textNodeStartColumn = 0
    for (let i = 0; i < containingTextNodeIndex; i++) {
      textNodeStartColumn = textNodeStartColumn + textNodes[i].length
    }
    const column = textNodeStartColumn + characterIndex

    return Point(row, column)
  }

  didResetDisplayLayer () {
    this.spliceLineTopIndex(0, Infinity, Infinity)
    this.scheduleUpdate()
  }

  didChangeDisplayLayer (changes) {
    for (let i = 0; i < changes.length; i++) {
      const {start, oldExtent, newExtent} = changes[i]
      this.spliceLineTopIndex(start.row, oldExtent.row, newExtent.row)
    }

    this.scheduleUpdate()
  }

  didChangeSelectionRange () {
    const {model} = this.props

    if (this.getPlatform() === 'linux') {
      if (this.selectionClipboardImmediateId) {
        clearImmediate(this.selectionClipboardImmediateId)
      }

      this.selectionClipboardImmediateId = setImmediate(() => {
        this.selectionClipboardImmediateId = null

        if (model.isDestroyed()) return

        const selectedText = model.getSelectedText()
        if (selectedText) {
          // This uses ipcRenderer.send instead of clipboard.writeText because
          // clipboard.writeText is a sync ipcRenderer call on Linux and that
          // will slow down selections.
          electron.ipcRenderer.send('write-text-to-selection-clipboard', selectedText)
        }
      })
    }
  }

  observeBlockDecorations () {
    const {model} = this.props
    const decorations = model.getDecorations({type: 'block'})
    for (let i = 0; i < decorations.length; i++) {
      this.didAddBlockDecoration(decorations[i])
    }
  }

  didAddBlockDecoration (decoration) {
    const marker = decoration.getMarker()
    const {position} = decoration.getProperties()
    const row = marker.getHeadScreenPosition().row
    this.lineTopIndex.insertBlock(decoration, row, 0, position === 'after')

    this.blockDecorationsToMeasure.add(decoration)

    const didUpdateDisposable = marker.bufferMarker.onDidChange((e) => {
      if (!e.textChanged) {
        this.lineTopIndex.moveBlock(decoration, marker.getHeadScreenPosition().row)
        this.scheduleUpdate()
      }
    })
    const didDestroyDisposable = decoration.onDidDestroy(() => {
      this.blockDecorationsToMeasure.delete(decoration)
      this.lineTopIndex.removeBlock(decoration)
      didUpdateDisposable.dispose()
      didDestroyDisposable.dispose()
      this.scheduleUpdate()
    })
  }

  invalidateBlockDecorationDimensions (decoration) {
    this.blockDecorationsToMeasure.add(decoration)
    this.scheduleUpdate()
  }

  spliceLineTopIndex (startRow, oldExtent, newExtent) {
    const invalidatedBlockDecorations = this.lineTopIndex.splice(startRow, oldExtent, newExtent)
    invalidatedBlockDecorations.forEach((decoration) => {
      const newPosition = decoration.getMarker().getHeadScreenPosition()
      this.lineTopIndex.moveBlock(decoration, newPosition.row)
    })
  }

  isVisible () {
    return this.element.offsetWidth > 0 || this.element.offsetHeight > 0
  }

  getWindowInnerHeight () {
    return window.innerHeight
  }

  getWindowInnerWidth () {
    return window.innerWidth
  }

  getLineHeight () {
    return this.measurements.lineHeight
  }

  getBaseCharacterWidth () {
    return this.measurements.baseCharacterWidth
  }

  getLongestLineWidth () {
    return this.measurements.longestLineWidth
  }

  getClientContainerHeight () {
    return this.measurements.clientContainerHeight
  }

  getClientContainerWidth () {
    return this.measurements.clientContainerWidth
  }

  getScrollContainerWidth () {
    if (this.props.model.getAutoWidth()) {
      return this.getScrollWidth()
    } else {
      return this.getClientContainerWidth() - this.getGutterContainerWidth()
    }
  }

  getScrollContainerHeight () {
    if (this.props.model.getAutoHeight()) {
      return this.getScrollHeight()
    } else {
      return this.getClientContainerHeight()
    }
  }

  getScrollContainerClientWidth () {
    if (this.isVerticalScrollbarVisible()) {
      return this.getScrollContainerWidth() - this.getVerticalScrollbarWidth()
    } else {
      return this.getScrollContainerWidth()
    }
  }

  getScrollContainerClientHeight () {
    if (this.isHorizontalScrollbarVisible()) {
      return this.getScrollContainerHeight() - this.getHorizontalScrollbarHeight()
    } else {
      return this.getScrollContainerHeight()
    }
  }

  isVerticalScrollbarVisible () {
    const {model} = this.props
    if (model.isMini()) return false
    if (model.getAutoHeight()) return false
    if (this.getContentHeight() > this.getScrollContainerHeight()) return true
    return (
      this.getContentWidth() > this.getScrollContainerWidth() &&
      this.getContentHeight() > (this.getScrollContainerHeight() - this.getHorizontalScrollbarHeight())
    )
  }

  isHorizontalScrollbarVisible () {
    const {model} = this.props
    if (model.isMini()) return false
    if (model.getAutoWidth()) return false
    if (model.isSoftWrapped()) return false
    if (this.getContentWidth() > this.getScrollContainerWidth()) return true
    return (
      this.getContentHeight() > this.getScrollContainerHeight() &&
      this.getContentWidth() > (this.getScrollContainerWidth() - this.getVerticalScrollbarWidth())
    )
  }

  getScrollHeight () {
    if (this.props.model.getScrollPastEnd()) {
      return this.getContentHeight() + Math.max(
        3 * this.getLineHeight(),
        this.getScrollContainerClientHeight() - (3 * this.getLineHeight())
      )
    } else {
      return this.getContentHeight()
    }
  }

  getScrollWidth () {
    const {model} = this.props

    if (model.isSoftWrapped()) {
      return this.getScrollContainerClientWidth()
    } else if (model.getAutoWidth()) {
      return this.getContentWidth()
    } else {
      return Math.max(this.getContentWidth(), this.getScrollContainerClientWidth())
    }
  }

  getContentHeight () {
    return this.pixelPositionAfterBlocksForRow(this.props.model.getApproximateScreenLineCount())
  }

  getContentWidth () {
    return Math.round(this.getLongestLineWidth() + this.getBaseCharacterWidth())
  }

  getGutterContainerWidth () {
    return this.measurements.gutterContainerWidth
  }

  getLineNumberGutterWidth () {
    return this.measurements.lineNumberGutterWidth
  }

  getVerticalScrollbarWidth () {
    return this.measurements.verticalScrollbarWidth
  }

  getHorizontalScrollbarHeight () {
    return this.measurements.horizontalScrollbarHeight
  }

  getRowsPerTile () {
    return this.props.rowsPerTile || DEFAULT_ROWS_PER_TILE
  }

  tileStartRowForRow (row) {
    return row - (row % this.getRowsPerTile())
  }

  tileIndexForTileStartRow (startRow) {
    return (startRow / this.getRowsPerTile()) % this.getRenderedTileCount()
  }

  getRenderedStartRow () {
    if (this.derivedDimensionsCache.renderedStartRow == null) {
      this.derivedDimensionsCache.renderedStartRow = this.tileStartRowForRow(this.getFirstVisibleRow())
    }

    return this.derivedDimensionsCache.renderedStartRow
  }

  getRenderedEndRow () {
    if (this.derivedDimensionsCache.renderedEndRow == null) {
      this.derivedDimensionsCache.renderedEndRow = Math.min(
        this.props.model.getApproximateScreenLineCount(),
        this.getRenderedStartRow() + this.getVisibleTileCount() * this.getRowsPerTile()
      )
    }

    return this.derivedDimensionsCache.renderedEndRow
  }

  getRenderedRowCount () {
    if (this.derivedDimensionsCache.renderedRowCount == null) {
      this.derivedDimensionsCache.renderedRowCount = Math.max(0, this.getRenderedEndRow() - this.getRenderedStartRow())
    }

    return this.derivedDimensionsCache.renderedRowCount
  }

  getRenderedTileCount () {
    if (this.derivedDimensionsCache.renderedTileCount == null) {
      this.derivedDimensionsCache.renderedTileCount = Math.ceil(this.getRenderedRowCount() / this.getRowsPerTile())
    }

    return this.derivedDimensionsCache.renderedTileCount
  }

  getFirstVisibleRow () {
    if (this.derivedDimensionsCache.firstVisibleRow == null) {
      this.derivedDimensionsCache.firstVisibleRow = this.rowForPixelPosition(this.getScrollTop())
    }

    return this.derivedDimensionsCache.firstVisibleRow
  }

  getLastVisibleRow () {
    if (this.derivedDimensionsCache.lastVisibleRow == null) {
      this.derivedDimensionsCache.lastVisibleRow = Math.min(
        this.props.model.getApproximateScreenLineCount() - 1,
        this.rowForPixelPosition(this.getScrollBottom())
      )
    }

    return this.derivedDimensionsCache.lastVisibleRow
  }

  getVisibleTileCount () {
    if (this.derivedDimensionsCache.visibleTileCount == null) {
      this.derivedDimensionsCache.visibleTileCount = Math.floor((this.getLastVisibleRow() - this.getFirstVisibleRow()) / this.getRowsPerTile()) + 2
    }

    return this.derivedDimensionsCache.visibleTileCount
  }

  getFirstVisibleColumn () {
    return Math.floor(this.getScrollLeft() / this.getBaseCharacterWidth())
  }

  getScrollTop () {
    this.scrollTop = Math.min(this.getMaxScrollTop(), this.scrollTop)
    return this.scrollTop
  }

  setScrollTop (scrollTop) {
    scrollTop = Math.round(Math.max(0, Math.min(this.getMaxScrollTop(), scrollTop)))
    if (scrollTop !== this.scrollTop) {
      this.derivedDimensionsCache = {}
      this.scrollTopPending = true
      this.scrollTop = scrollTop
      this.element.emitter.emit('did-change-scroll-top', scrollTop)
      return true
    } else {
      return false
    }
  }

  getMaxScrollTop () {
    return Math.max(0, this.getScrollHeight() - this.getScrollContainerClientHeight())
  }

  getScrollBottom () {
    return this.getScrollTop() + this.getScrollContainerClientHeight()
  }

  setScrollBottom (scrollBottom) {
    return this.setScrollTop(scrollBottom - this.getScrollContainerClientHeight())
  }

  getScrollLeft () {
    return this.scrollLeft
  }

  setScrollLeft (scrollLeft) {
    scrollLeft = Math.round(Math.max(0, Math.min(this.getMaxScrollLeft(), scrollLeft)))
    if (scrollLeft !== this.scrollLeft) {
      this.scrollLeftPending = true
      this.scrollLeft = scrollLeft
      this.element.emitter.emit('did-change-scroll-left', scrollLeft)
      return true
    } else {
      return false
    }
  }

  getMaxScrollLeft () {
    return Math.max(0, this.getScrollWidth() - this.getScrollContainerClientWidth())
  }

  getScrollRight () {
    return this.getScrollLeft() + this.getScrollContainerClientWidth()
  }

  setScrollRight (scrollRight) {
    return this.setScrollLeft(scrollRight - this.getScrollContainerClientWidth())
  }

  setScrollTopRow (scrollTopRow, scheduleUpdate = true) {
    if (this.hasInitialMeasurements) {
      const didScroll = this.setScrollTop(this.pixelPositionBeforeBlocksForRow(scrollTopRow))
      if (didScroll && scheduleUpdate) {
        this.scheduleUpdate()
      }
      return didScroll
    } else {
      this.pendingScrollTopRow = scrollTopRow
      return false
    }
  }

  getScrollTopRow () {
    if (this.hasInitialMeasurements) {
      return this.rowForPixelPosition(this.getScrollTop())
    } else {
      return this.pendingScrollTopRow || 0
    }
  }

  setScrollLeftColumn (scrollLeftColumn, scheduleUpdate = true) {
    if (this.hasInitialMeasurements && this.getLongestLineWidth() != null) {
      const didScroll = this.setScrollLeft(scrollLeftColumn * this.getBaseCharacterWidth())
      if (didScroll && scheduleUpdate) {
        this.scheduleUpdate()
      }
      return didScroll
    } else {
      this.pendingScrollLeftColumn = scrollLeftColumn
      return false
    }
  }

  getScrollLeftColumn () {
    if (this.hasInitialMeasurements && this.getLongestLineWidth() != null) {
      return Math.floor(this.getScrollLeft() / this.getBaseCharacterWidth())
    } else {
      return this.pendingScrollLeftColumn || 0
    }
  }

  // Ensure the spatial index is populated with rows that are currently
  // visible so we *at least* get the longest row in the visible range.
  populateVisibleRowRange () {
    const endRow = this.getRenderedStartRow() + this.getVisibleTileCount() * this.getRowsPerTile()
    this.props.model.displayLayer.populateSpatialIndexIfNeeded(Infinity, endRow)
  }

  getNextUpdatePromise () {
    if (!this.nextUpdatePromise) {
      this.nextUpdatePromise = new Promise((resolve) => {
        this.resolveNextUpdatePromise = () => {
          this.nextUpdatePromise = null
          this.resolveNextUpdatePromise = null
          resolve()
        }
      })
    }
    return this.nextUpdatePromise
  }

  setInputEnabled (inputEnabled) {
    this.props.inputEnabled = inputEnabled
  }

  isInputEnabled (inputEnabled) {
    return this.props.inputEnabled != null ? this.props.inputEnabled : true
  }

  getPlatform () {
    return this.props.platform || process.platform
  }
}

class DummyScrollbarComponent {
  constructor (props) {
    this.props = props
    etch.initialize(this)
  }

  update (newProps) {
    const oldProps = this.props
    this.props = newProps
    etch.updateSync(this)

    const shouldFlushScrollPosition = (
      newProps.scrollTop !== oldProps.scrollTop ||
      newProps.scrollLeft !== oldProps.scrollLeft
    )
    if (shouldFlushScrollPosition) this.flushScrollPosition()
  }

  flushScrollPosition () {
    if (this.props.orientation === 'horizontal') {
      this.element.scrollLeft = this.props.scrollLeft
    } else {
      this.element.scrollTop = this.props.scrollTop
    }
  }

  render () {
    const outerStyle = {
      position: 'absolute',
      contain: 'strict',
      zIndex: 1
    }
    const innerStyle = {}
    if (this.props.orientation === 'horizontal') {
      let right = (this.props.verticalScrollbarWidth || 0)
      outerStyle.bottom = 0
      outerStyle.left = 0
      outerStyle.right = right + 'px'
      outerStyle.height = '20px'
      outerStyle.overflowY = 'hidden'
      outerStyle.overflowX = this.props.forceScrollbarVisible ? 'scroll' : 'auto'
      innerStyle.height = '20px'
      innerStyle.width = (this.props.scrollWidth || 0) + 'px'
    } else {
      let bottom = (this.props.horizontalScrollbarHeight || 0)
      outerStyle.right = 0
      outerStyle.top = 0
      outerStyle.bottom = bottom + 'px'
      outerStyle.width = '20px'
      outerStyle.overflowX = 'hidden'
      outerStyle.overflowY = this.props.forceScrollbarVisible ? 'scroll' : 'auto'
      innerStyle.width = '20px'
      innerStyle.height = (this.props.scrollHeight || 0) + 'px'
    }

    return $.div(
      {
        className: `${this.props.orientation}-scrollbar`,
        style: outerStyle,
        on: {
          scroll: this.props.didScroll,
          mousedown: this.didMousedown
        }
      },
      $.div({style: innerStyle})
    )
  }

  didMousedown (event) {
    let {bottom, right} = this.element.getBoundingClientRect()
    const clickedOnScrollbar = (this.props.orientation === 'horizontal')
      ? event.clientY >= (bottom - this.getRealScrollbarHeight())
      : event.clientX >= (right - this.getRealScrollbarWidth())
    if (!clickedOnScrollbar) this.props.didMousedown(event)
  }

  getRealScrollbarWidth () {
    return this.element.offsetWidth - this.element.clientWidth
  }

  getRealScrollbarHeight () {
    return this.element.offsetHeight - this.element.clientHeight
  }
}

class GutterContainerComponent {
  constructor (props) {
    this.props = props
    etch.initialize(this)
  }

  update (props) {
    if (this.shouldUpdate(props)) {
      this.props = props
      etch.updateSync(this)
    }
  }

  shouldUpdate (props) {
    return (
      !props.measuredContent ||
      props.lineNumberGutterWidth !== this.props.lineNumberGutterWidth
    )
  }

  render () {
    const {hasInitialMeasurements, scrollTop, scrollHeight, guttersToRender, decorationsToRender} = this.props

    const innerStyle = {
      willChange: 'transform',
      display: 'flex'
    }

    if (hasInitialMeasurements) {
      innerStyle.transform = `translateY(${-scrollTop}px)`
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
      $.div({style: innerStyle},
        guttersToRender.map((gutter) => {
          if (gutter.name === 'line-number') {
            return this.renderLineNumberGutter(gutter)
          } else {
            return $(CustomGutterComponent, {
              key: gutter,
              element: gutter.getElement(),
              name: gutter.name,
              visible: gutter.isVisible(),
              height: scrollHeight,
              decorations: decorationsToRender.customGutter.get(gutter.name)
            })
          }
        })
      )
    )
  }

  renderLineNumberGutter (gutter) {
    const {
      rootComponent, isLineNumberGutterVisible, hasInitialMeasurements, lineNumbersToRender,
      renderedStartRow, renderedEndRow, rowsPerTile, decorationsToRender, didMeasureVisibleBlockDecoration,
      scrollHeight, lineNumberGutterWidth, lineHeight
    } = this.props

    if (!isLineNumberGutterVisible) return null

    if (hasInitialMeasurements) {
      const {maxDigits, keys, bufferRows, softWrappedFlags, foldableFlags} = lineNumbersToRender
      return $(LineNumberGutterComponent, {
        ref: 'lineNumberGutter',
        element: gutter.getElement(),
        rootComponent: rootComponent,
        startRow: renderedStartRow,
        endRow: renderedEndRow,
        rowsPerTile: rowsPerTile,
        maxDigits: maxDigits,
        keys: keys,
        bufferRows: bufferRows,
        softWrappedFlags: softWrappedFlags,
        foldableFlags: foldableFlags,
        decorations: decorationsToRender.lineNumbers,
        blockDecorations: decorationsToRender.blocks,
        didMeasureVisibleBlockDecoration: didMeasureVisibleBlockDecoration,
        height: scrollHeight,
        width: lineNumberGutterWidth,
        lineHeight: lineHeight
      })
    } else {
      return $(LineNumberGutterComponent, {
        ref: 'lineNumberGutter',
        element: gutter.getElement(),
        maxDigits: lineNumbersToRender.maxDigits
      })
    }
  }
}

class LineNumberGutterComponent {
  constructor (props) {
    this.props = props
    this.element = this.props.element
    this.virtualNode = $.div(null)
    this.virtualNode.domNode = this.element
    etch.updateSync(this)
  }

  update (newProps) {
    if (this.shouldUpdate(newProps)) {
      this.props = newProps
      etch.updateSync(this)
    }
  }

  render () {
    const {
      rootComponent, height, width, lineHeight, startRow, endRow, rowsPerTile,
      maxDigits, keys, bufferRows, softWrappedFlags, foldableFlags, decorations
    } = this.props

    let children = null

    if (bufferRows) {
      const renderedTileCount = rootComponent.getRenderedTileCount()
      children = new Array(renderedTileCount)

      for (let tileStartRow = startRow; tileStartRow < endRow; tileStartRow = tileStartRow + rowsPerTile) {
        const tileEndRow = Math.min(endRow, tileStartRow + rowsPerTile)
        const tileChildren = new Array(tileEndRow - tileStartRow)
        for (let row = tileStartRow; row < tileEndRow; row++) {
          const i = row - startRow
          const key = keys[i]
          const softWrapped = softWrappedFlags[i]
          const foldable = foldableFlags[i]
          const bufferRow = bufferRows[i]

          let className = 'line-number'
          if (foldable) className = className + ' foldable'

          const decorationsForRow = decorations[row - startRow]
          if (decorationsForRow) className = className + ' ' + decorationsForRow

          let number = softWrapped ? '•' : bufferRow + 1
          number = NBSP_CHARACTER.repeat(maxDigits - number.length) + number

          const lineNumberProps = {
            key,
            className,
            style: {width: width + 'px'},
            dataset: {bufferRow}
          }
          const currentRowTop = rootComponent.pixelPositionAfterBlocksForRow(row)
          const previousRowBottom = rootComponent.pixelPositionAfterBlocksForRow(row - 1) + lineHeight
          if (currentRowTop > previousRowBottom) {
            lineNumberProps.style.marginTop = (currentRowTop - previousRowBottom) + 'px'
          }

          tileChildren[row - tileStartRow] = $.div(lineNumberProps,
            number,
            $.div({className: 'icon-right'})
          )
        }

        const tileIndex = rootComponent.tileIndexForTileStartRow(tileStartRow)
        const tileTop = rootComponent.pixelPositionBeforeBlocksForRow(tileStartRow)
        const tileBottom = rootComponent.pixelPositionBeforeBlocksForRow(tileEndRow)
        const tileHeight = tileBottom - tileTop

        children[tileIndex] = $.div({
          key: tileIndex,
          style: {
            contain: 'strict',
            overflow: 'hidden',
            position: 'absolute',
            top: 0,
            height: tileHeight + 'px',
            width: width + 'px',
            willChange: 'transform',
            transform: `translateY(${tileTop}px)`,
            backgroundColor: 'inherit'
          }
        }, ...tileChildren)
      }
    }

    return $.div(
      {
        className: 'gutter line-bufferRows',
        attributes: {'gutter-name': 'line-number'},
        style: {position: 'relative', height: height + 'px'},
        on: {
          mousedown: this.didMouseDown
        }
      },
      $.div({key: 'placeholder', className: 'line-number dummy', style: {visibility: 'hidden'}},
        '0'.repeat(maxDigits),
        $.div({className: 'icon-right'})
      ),
      children
    )
  }

  shouldUpdate (newProps) {
    const oldProps = this.props

    if (oldProps.height !== newProps.height) return true
    if (oldProps.width !== newProps.width) return true
    if (oldProps.lineHeight !== newProps.lineHeight) return true
    if (oldProps.startRow !== newProps.startRow) return true
    if (oldProps.endRow !== newProps.endRow) return true
    if (oldProps.rowsPerTile !== newProps.rowsPerTile) return true
    if (oldProps.maxDigits !== newProps.maxDigits) return true
    if (newProps.didMeasureVisibleBlockDecoration) return true
    if (!arraysEqual(oldProps.keys, newProps.keys)) return true
    if (!arraysEqual(oldProps.bufferRows, newProps.bufferRows)) return true
    if (!arraysEqual(oldProps.foldableFlags, newProps.foldableFlags)) return true
    if (!arraysEqual(oldProps.decorations, newProps.decorations)) return true

    let oldTileStartRow = oldProps.startRow
    let newTileStartRow = newProps.startRow
    while (oldTileStartRow < oldProps.endRow || newTileStartRow < newProps.endRow) {
      let oldTileBlockDecorations = oldProps.blockDecorations.get(oldTileStartRow)
      let newTileBlockDecorations = newProps.blockDecorations.get(newTileStartRow)

      if (oldTileBlockDecorations && newTileBlockDecorations) {
        if (oldTileBlockDecorations.size !== newTileBlockDecorations.size) return true

        let blockDecorationsChanged = false

        oldTileBlockDecorations.forEach((oldDecorations, screenLineId) => {
          if (!blockDecorationsChanged) {
            const newDecorations = newTileBlockDecorations.get(screenLineId)
            blockDecorationsChanged = (newDecorations == null || !arraysEqual(oldDecorations, newDecorations))
          }
        })
        if (blockDecorationsChanged) return true

        newTileBlockDecorations.forEach((newDecorations, screenLineId) => {
          if (!blockDecorationsChanged) {
            const oldDecorations = oldTileBlockDecorations.get(screenLineId)
            blockDecorationsChanged = (oldDecorations == null)
          }
        })
        if (blockDecorationsChanged) return true
      } else if (oldTileBlockDecorations) {
        return true
      } else if (newTileBlockDecorations) {
        return true
      }

      oldTileStartRow += oldProps.rowsPerTile
      newTileStartRow += newProps.rowsPerTile
    }

    return false
  }

  didMouseDown (event) {
    this.props.rootComponent.didMouseDownOnLineNumberGutter(event)
  }
}

class CustomGutterComponent {
  constructor (props) {
    this.props = props
    this.element = this.props.element
    this.virtualNode = $.div(null)
    this.virtualNode.domNode = this.element
    etch.updateSync(this)
  }

  update (props) {
    this.props = props
    etch.updateSync(this)
  }

  destroy () {
    etch.destroy(this)
  }

  render () {
    return $.div(
      {
        className: 'gutter',
        attributes: {'gutter-name': this.props.name},
        style: {
          display: this.props.visible ? '' : 'none'
        }
      },
      $.div(
        {
          className: 'custom-decorations',
          style: {height: this.props.height + 'px'}
        },
        this.renderDecorations()
      )
    )
  }

  renderDecorations () {
    if (!this.props.decorations) return null

    return this.props.decorations.map(({className, element, top, height}) => {
      return $(CustomGutterDecorationComponent, {
        className,
        element,
        top,
        height
      })
    })
  }
}

class CustomGutterDecorationComponent {
  constructor (props) {
    this.props = props
    this.element = document.createElement('div')
    const {top, height, className, element} = this.props

    this.element.style.position = 'absolute'
    this.element.style.top = top + 'px'
    this.element.style.height = height + 'px'
    if (className != null) this.element.className = className
    if (element != null) this.element.appendChild(element)
  }

  update (newProps) {
    const oldProps = this.props
    this.props = newProps

    if (newProps.top !== oldProps.top) this.element.style.top = newProps.top + 'px'
    if (newProps.height !== oldProps.height) this.element.style.height = newProps.height + 'px'
    if (newProps.className !== oldProps.className) this.element.className = newProps.className || ''
    if (newProps.element !== oldProps.element) {
      if (this.element.firstChild) this.element.firstChild.remove()
      this.element.appendChild(newProps.element)
    }
  }
}

class CursorsAndInputComponent {
  constructor (props) {
    this.props = props
    etch.initialize(this)
  }

  update (props) {
    if (props.measuredContent) {
      this.props = props
      etch.updateSync(this)
    }
  }

  updateCursorBlinkSync (cursorsBlinkedOff) {
    this.props.cursorsBlinkedOff = cursorsBlinkedOff
    const className = this.getCursorsClassName()
    this.refs.cursors.className = className
    this.virtualNode.props.className = className
  }

  render () {
    const {lineHeight, decorationsToRender, scrollHeight, scrollWidth} = this.props

    const className = this.getCursorsClassName()
    const cursorHeight = lineHeight + 'px'

    const children = [this.renderHiddenInput()]
    for (let i = 0; i < decorationsToRender.cursors.length; i++) {
      const {pixelLeft, pixelTop, pixelWidth, className: extraCursorClassName, style: extraCursorStyle} = decorationsToRender.cursors[i]
      let cursorClassName = 'cursor'
      if (extraCursorClassName) cursorClassName += ' ' + extraCursorClassName

      const cursorStyle = {
        height: cursorHeight,
        width: pixelWidth + 'px',
        transform: `translate(${pixelLeft}px, ${pixelTop}px)`
      }
      if (extraCursorStyle) Object.assign(cursorStyle, extraCursorStyle)

      children.push($.div({
        className: cursorClassName,
        style: cursorStyle
      }))
    }

    return $.div({
      key: 'cursors',
      ref: 'cursors',
      className,
      style: {
        position: 'absolute',
        contain: 'strict',
        zIndex: 1,
        width: scrollWidth + 'px',
        height: scrollHeight + 'px',
        pointerEvents: 'none'
      }
    }, children)
  }

  getCursorsClassName () {
    return this.props.cursorsBlinkedOff ? 'cursors blink-off' : 'cursors'
  }

  renderHiddenInput () {
    const {
      lineHeight, hiddenInputPosition, didBlurHiddenInput, didFocusHiddenInput,
      didTextInput, didKeydown, didKeyup, didKeypress, didCompositionStart,
      didCompositionUpdate, didCompositionEnd
    } = this.props

    let top, left
    if (hiddenInputPosition) {
      top = hiddenInputPosition.pixelTop
      left = hiddenInputPosition.pixelLeft
    } else {
      top = 0
      left = 0
    }

    return $.input({
      ref: 'hiddenInput',
      key: 'hiddenInput',
      className: 'hidden-input',
      on: {
        blur: didBlurHiddenInput,
        focus: didFocusHiddenInput,
        textInput: didTextInput,
        keydown: didKeydown,
        keyup: didKeyup,
        keypress: didKeypress,
        compositionstart: didCompositionStart,
        compositionupdate: didCompositionUpdate,
        compositionend: didCompositionEnd
      },
      tabIndex: -1,
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
    })
  }
}

class LinesTileComponent {
  constructor (props) {
    this.props = props
    etch.initialize(this)
    this.createLines()
    this.updateBlockDecorations({}, props)
  }

  update (newProps) {
    if (this.shouldUpdate(newProps)) {
      const oldProps = this.props
      this.props = newProps
      etch.updateSync(this)
      if (!newProps.measuredContent) {
        this.updateLines(oldProps, newProps)
        this.updateBlockDecorations(oldProps, newProps)
      }
    }
  }

  destroy () {
    for (let i = 0; i < this.lineComponents.length; i++) {
      this.lineComponents[i].destroy()
    }
  }

  render () {
    const {height, width, top} = this.props

    return $.div(
      {
        style: {
          contain: 'strict',
          position: 'absolute',
          height: height + 'px',
          width: width + 'px',
          willChange: 'transform',
          transform: `translateY(${top}px)`,
          backgroundColor: 'inherit'
        }
      },
      this.renderHighlights()
      // Lines and block decorations will be manually inserted here for efficiency
    )
  }

  renderHighlights () {
    const {top, lineHeight, highlightDecorations} = this.props

    let children = null
    if (highlightDecorations) {
      const decorationCount = highlightDecorations.length
      children = new Array(decorationCount)
      for (let i = 0; i < decorationCount; i++) {
        const highlightProps = Object.assign(
          {parentTileTop: top, lineHeight},
          highlightDecorations[i]
        )
        children[i] = $(HighlightComponent, highlightProps)
        highlightDecorations[i].flashRequested = false
      }
    }

    return $.div(
      {
        className: 'highlights',
        style: {contain: 'layout'}
      },
      children
    )
  }

  createLines () {
    const {
      tileStartRow, screenLines, lineDecorations,
      displayLayer, lineNodesByScreenLineId, textNodesByScreenLineId
    } = this.props

    this.lineComponents = []
    for (let i = 0, length = screenLines.length; i < length; i++) {
      const component = new LineComponent({
        screenLine: screenLines[i],
        screenRow: tileStartRow + i,
        lineDecoration: lineDecorations[i],
        displayLayer,
        lineNodesByScreenLineId,
        textNodesByScreenLineId
      })
      this.element.appendChild(component.element)
      this.lineComponents.push(component)
    }
  }

  updateLines (oldProps, newProps) {
    var {
      screenLines, tileStartRow, lineDecorations,
      displayLayer, lineNodesByScreenLineId, textNodesByScreenLineId
    } = newProps

    var oldScreenLines = oldProps.screenLines
    var newScreenLines = screenLines
    var oldScreenLinesEndIndex = oldScreenLines.length
    var newScreenLinesEndIndex = newScreenLines.length
    var oldScreenLineIndex = 0
    var newScreenLineIndex = 0
    var lineComponentIndex = 0

    while (oldScreenLineIndex < oldScreenLinesEndIndex || newScreenLineIndex < newScreenLinesEndIndex) {
      var oldScreenLine = oldScreenLines[oldScreenLineIndex]
      var newScreenLine = newScreenLines[newScreenLineIndex]

      if (oldScreenLineIndex >= oldScreenLinesEndIndex) {
        var newScreenLineComponent = new LineComponent({
          screenLine: newScreenLine,
          screenRow: tileStartRow + newScreenLineIndex,
          lineDecoration: lineDecorations[newScreenLineIndex],
          displayLayer,
          lineNodesByScreenLineId,
          textNodesByScreenLineId
        })
        this.element.appendChild(newScreenLineComponent.element)
        this.lineComponents.push(newScreenLineComponent)

        newScreenLineIndex++
        lineComponentIndex++
      } else if (newScreenLineIndex >= newScreenLinesEndIndex) {
        this.lineComponents[lineComponentIndex].destroy()
        this.lineComponents.splice(lineComponentIndex, 1)

        oldScreenLineIndex++
      } else if (oldScreenLine === newScreenLine) {
        var lineComponent = this.lineComponents[lineComponentIndex]
        lineComponent.update({
          screenRow: tileStartRow + newScreenLineIndex,
          lineDecoration: lineDecorations[newScreenLineIndex]
        })

        oldScreenLineIndex++
        newScreenLineIndex++
        lineComponentIndex++
      } else {
        var oldScreenLineIndexInNewScreenLines = newScreenLines.indexOf(oldScreenLine)
        var newScreenLineIndexInOldScreenLines = oldScreenLines.indexOf(newScreenLine)
        if (newScreenLineIndex < oldScreenLineIndexInNewScreenLines && oldScreenLineIndexInNewScreenLines < newScreenLinesEndIndex) {
          var newScreenLineComponents = []
          while (newScreenLineIndex < oldScreenLineIndexInNewScreenLines) {
            var newScreenLineComponent = new LineComponent({ // eslint-disable-line no-redeclare
              screenLine: newScreenLines[newScreenLineIndex],
              screenRow: tileStartRow + newScreenLineIndex,
              lineDecoration: lineDecorations[newScreenLineIndex],
              displayLayer,
              lineNodesByScreenLineId,
              textNodesByScreenLineId
            })
            this.element.insertBefore(newScreenLineComponent.element, this.getFirstElementForScreenLine(oldProps, oldScreenLine))
            newScreenLineComponents.push(newScreenLineComponent)

            newScreenLineIndex++
          }

          this.lineComponents.splice(lineComponentIndex, 0, ...newScreenLineComponents)
          lineComponentIndex = lineComponentIndex + newScreenLineComponents.length
        } else if (oldScreenLineIndex < newScreenLineIndexInOldScreenLines && newScreenLineIndexInOldScreenLines < oldScreenLinesEndIndex) {
          while (oldScreenLineIndex < newScreenLineIndexInOldScreenLines) {
            this.lineComponents[lineComponentIndex].destroy()
            this.lineComponents.splice(lineComponentIndex, 1)

            oldScreenLineIndex++
          }
        } else {
          var oldScreenLineComponent = this.lineComponents[lineComponentIndex]
          var newScreenLineComponent = new LineComponent({ // eslint-disable-line no-redeclare
            screenLine: newScreenLines[newScreenLineIndex],
            screenRow: tileStartRow + newScreenLineIndex,
            lineDecoration: lineDecorations[newScreenLineIndex],
            displayLayer,
            lineNodesByScreenLineId,
            textNodesByScreenLineId
          })
          this.element.insertBefore(newScreenLineComponent.element, oldScreenLineComponent.element)
          // Instead of calling destroy on the component here we can simply
          // remove its associated element, thus skipping the
          // lineNodesByScreenLineId bookkeeping. This is possible because
          // lineNodesByScreenLineId has already been updated when creating the
          // new screen line component.
          oldScreenLineComponent.element.remove()
          this.lineComponents[lineComponentIndex] = newScreenLineComponent

          oldScreenLineIndex++
          newScreenLineIndex++
          lineComponentIndex++
        }
      }
    }
  }

  getFirstElementForScreenLine (oldProps, screenLine) {
    var blockDecorations = oldProps.blockDecorations ? oldProps.blockDecorations.get(screenLine.id) : null
    if (blockDecorations) {
      var blockDecorationElementsBeforeOldScreenLine = []
      for (let i = 0; i < blockDecorations.length; i++) {
        var decoration = blockDecorations[i]
        if (decoration.position !== 'after') {
          blockDecorationElementsBeforeOldScreenLine.push(
            TextEditor.viewForItem(decoration.item)
          )
        }
      }

      for (let i = 0; i < blockDecorationElementsBeforeOldScreenLine.length; i++) {
        var blockDecorationElement = blockDecorationElementsBeforeOldScreenLine[i]
        if (!blockDecorationElementsBeforeOldScreenLine.includes(blockDecorationElement.previousSibling)) {
          return blockDecorationElement
        }
      }
    }

    return oldProps.lineNodesByScreenLineId.get(screenLine.id)
  }

  updateBlockDecorations (oldProps, newProps) {
    var {blockDecorations, lineNodesByScreenLineId} = newProps

    if (oldProps.blockDecorations) {
      oldProps.blockDecorations.forEach((oldDecorations, screenLineId) => {
        var newDecorations = newProps.blockDecorations ? newProps.blockDecorations.get(screenLineId) : null
        for (var i = 0; i < oldDecorations.length; i++) {
          var oldDecoration = oldDecorations[i]
          if (newDecorations && newDecorations.includes(oldDecoration)) continue

          var element = TextEditor.viewForItem(oldDecoration.item)
          if (element.parentElement !== this.element) continue

          element.remove()
        }
      })
    }

    if (blockDecorations) {
      blockDecorations.forEach((newDecorations, screenLineId) => {
        var oldDecorations = oldProps.blockDecorations ? oldProps.blockDecorations.get(screenLineId) : null
        for (var i = 0; i < newDecorations.length; i++) {
          var newDecoration = newDecorations[i]
          if (oldDecorations && oldDecorations.includes(newDecoration)) continue

          var element = TextEditor.viewForItem(newDecoration.item)
          var lineNode = lineNodesByScreenLineId.get(screenLineId)
          if (newDecoration.position === 'after') {
            this.element.insertBefore(element, lineNode.nextSibling)
          } else {
            this.element.insertBefore(element, lineNode)
          }
        }
      })
    }
  }

  shouldUpdate (newProps) {
    const oldProps = this.props
    if (oldProps.top !== newProps.top) return true
    if (oldProps.height !== newProps.height) return true
    if (oldProps.width !== newProps.width) return true
    if (oldProps.lineHeight !== newProps.lineHeight) return true
    if (oldProps.tileStartRow !== newProps.tileStartRow) return true
    if (oldProps.tileEndRow !== newProps.tileEndRow) return true
    if (!arraysEqual(oldProps.screenLines, newProps.screenLines)) return true
    if (!arraysEqual(oldProps.lineDecorations, newProps.lineDecorations)) return true

    if (!oldProps.highlightDecorations && newProps.highlightDecorations) return true
    if (oldProps.highlightDecorations && !newProps.highlightDecorations) return true

    if (oldProps.highlightDecorations && newProps.highlightDecorations) {
      if (oldProps.highlightDecorations.length !== newProps.highlightDecorations.length) return true

      for (let i = 0, length = oldProps.highlightDecorations.length; i < length; i++) {
        const oldHighlight = oldProps.highlightDecorations[i]
        const newHighlight = newProps.highlightDecorations[i]
        if (oldHighlight.className !== newHighlight.className) return true
        if (newHighlight.flashRequested) return true
        if (oldHighlight.startPixelTop !== newHighlight.startPixelTop) return true
        if (oldHighlight.startPixelLeft !== newHighlight.startPixelLeft) return true
        if (oldHighlight.endPixelTop !== newHighlight.endPixelTop) return true
        if (oldHighlight.endPixelLeft !== newHighlight.endPixelLeft) return true
        if (!oldHighlight.screenRange.isEqual(newHighlight.screenRange)) return true
      }
    }

    if (oldProps.blockDecorations && newProps.blockDecorations) {
      if (oldProps.blockDecorations.size !== newProps.blockDecorations.size) return true

      let blockDecorationsChanged = false

      oldProps.blockDecorations.forEach((oldDecorations, screenLineId) => {
        if (!blockDecorationsChanged) {
          const newDecorations = newProps.blockDecorations.get(screenLineId)
          blockDecorationsChanged = (newDecorations == null || !arraysEqual(oldDecorations, newDecorations))
        }
      })
      if (blockDecorationsChanged) return true

      newProps.blockDecorations.forEach((newDecorations, screenLineId) => {
        if (!blockDecorationsChanged) {
          const oldDecorations = oldProps.blockDecorations.get(screenLineId)
          blockDecorationsChanged = (oldDecorations == null)
        }
      })
      if (blockDecorationsChanged) return true
    } else if (oldProps.blockDecorations) {
      return true
    } else if (newProps.blockDecorations) {
      return true
    }

    return false
  }
}

class LineComponent {
  constructor (props) {
    const {
      displayLayer,
      screenLine, screenRow,
      lineNodesByScreenLineId, textNodesByScreenLineId
    } = props
    this.props = props
    this.element = document.createElement('div')
    this.element.className = this.buildClassName()
    this.element.dataset.screenRow = screenRow
    lineNodesByScreenLineId.set(screenLine.id, this.element)

    const textNodes = []
    textNodesByScreenLineId.set(screenLine.id, textNodes)

    const {lineText, tags} = screenLine
    let startIndex = 0
    let openScopeNode = document.createElement('span')
    this.element.appendChild(openScopeNode)
    for (let i = 0; i < tags.length; i++) {
      const tag = tags[i]
      if (tag !== 0) {
        if (displayLayer.isCloseTag(tag)) {
          openScopeNode = openScopeNode.parentElement
        } else if (displayLayer.isOpenTag(tag)) {
          const newScopeNode = document.createElement('span')
          newScopeNode.className = displayLayer.classNameForTag(tag)
          openScopeNode.appendChild(newScopeNode)
          openScopeNode = newScopeNode
        } else {
          const textNode = document.createTextNode(lineText.substr(startIndex, tag))
          startIndex = startIndex + tag
          openScopeNode.appendChild(textNode)
          textNodes.push(textNode)
        }
      }
    }

    if (startIndex === 0) {
      const textNode = document.createTextNode(' ')
      this.element.appendChild(textNode)
      textNodes.push(textNode)
    }

    if (lineText.endsWith(displayLayer.foldCharacter)) {
      // Insert a zero-width non-breaking whitespace, so that LinesYardstick can
      // take the fold-marker::after pseudo-element into account during
      // measurements when such marker is the last character on the line.
      const textNode = document.createTextNode(ZERO_WIDTH_NBSP_CHARACTER)
      this.element.appendChild(textNode)
      textNodes.push(textNode)
    }
  }

  update (newProps) {
    if (this.props.lineDecoration !== newProps.lineDecoration) {
      this.props.lineDecoration = newProps.lineDecoration
      this.element.className = this.buildClassName()
    }

    if (this.props.screenRow !== newProps.screenRow) {
      this.props.screenRow = newProps.screenRow
      this.element.dataset.screenRow = newProps.screenRow
    }
  }

  destroy () {
    const {lineNodesByScreenLineId, textNodesByScreenLineId, screenLine} = this.props
    if (lineNodesByScreenLineId.get(screenLine.id) === this.element) {
      lineNodesByScreenLineId.delete(screenLine.id)
      textNodesByScreenLineId.delete(screenLine.id)
    }

    this.element.remove()
  }

  buildClassName () {
    const {lineDecoration} = this.props
    let className = 'line'
    if (lineDecoration != null) className = className + ' ' + lineDecoration
    return className
  }
}

class HighlightComponent {
  constructor (props) {
    this.props = props
    etch.initialize(this)
    if (this.props.flashRequested) this.performFlash()
  }

  update (newProps) {
    this.props = newProps
    etch.updateSync(this)
    if (newProps.flashRequested) this.performFlash()
  }

  performFlash () {
    const {flashClass, flashDuration} = this.props
    if (!this.timeoutsByClassName) this.timeoutsByClassName = new Map()

    // If a flash of this class is already in progress, clear it early and
    // flash again on the next frame to ensure CSS transitions apply to the
    // second flash.
    if (this.timeoutsByClassName.has(flashClass)) {
      window.clearTimeout(this.timeoutsByClassName.get(flashClass))
      this.timeoutsByClassName.delete(flashClass)
      this.element.classList.remove(flashClass)
      requestAnimationFrame(() => this.performFlash())
    } else {
      this.element.classList.add(flashClass)
      this.timeoutsByClassName.set(flashClass, window.setTimeout(() => {
        this.element.classList.remove(flashClass)
      }, flashDuration))
    }
  }

  render () {
    let {startPixelTop, endPixelTop} = this.props
    const {
      className, screenRange, parentTileTop, lineHeight,
      startPixelLeft, endPixelLeft
    } = this.props
    startPixelTop -= parentTileTop
    endPixelTop -= parentTileTop

    let regionClassName = 'region ' + className
    let children
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
      })
    } else {
      children = []
      children.push($.div({
        className: regionClassName,
        style: {
          position: 'absolute',
          boxSizing: 'border-box',
          top: startPixelTop + 'px',
          left: startPixelLeft + 'px',
          right: 0,
          height: lineHeight + 'px'
        }
      }))

      if (screenRange.end.row - screenRange.start.row > 1) {
        children.push($.div({
          className: regionClassName,
          style: {
            position: 'absolute',
            boxSizing: 'border-box',
            top: startPixelTop + lineHeight + 'px',
            left: 0,
            right: 0,
            height: endPixelTop - startPixelTop - (lineHeight * 2) + 'px'
          }
        }))
      }

      if (endPixelLeft > 0) {
        children.push($.div({
          className: regionClassName,
          style: {
            position: 'absolute',
            boxSizing: 'border-box',
            top: endPixelTop - lineHeight + 'px',
            left: 0,
            width: endPixelLeft + 'px',
            height: lineHeight + 'px'
          }
        }))
      }
    }

    return $.div({className: 'highlight ' + className}, children)
  }
}

class OverlayComponent {
  constructor (props) {
    this.props = props
    this.element = document.createElement('atom-overlay')
    if (this.props.className != null) this.element.classList.add(this.props.className)
    this.element.appendChild(this.props.element)
    this.element.style.position = 'fixed'
    this.element.style.zIndex = 4
    this.element.style.top = (this.props.pixelTop || 0) + 'px'
    this.element.style.left = (this.props.pixelLeft || 0) + 'px'

    // Synchronous DOM updates in response to resize events might trigger a
    // "loop limit exceeded" error. We disconnect the observer before
    // potentially mutating the DOM, and then reconnect it on the next tick.
    this.resizeObserver = new ResizeObserver(() => {
      this.resizeObserver.disconnect()
      this.props.didResize()
      process.nextTick(() => { this.resizeObserver.observe(this.element) })
    })
    this.didAttach()
    this.props.overlayComponents.add(this)
  }

  destroy () {
    this.props.overlayComponents.delete(this)
    this.didDetach()
  }

  update (newProps) {
    const oldProps = this.props
    this.props = newProps
    if (this.props.pixelTop != null) this.element.style.top = this.props.pixelTop + 'px'
    if (this.props.pixelLeft != null) this.element.style.left = this.props.pixelLeft + 'px'
    if (newProps.className !== oldProps.className) {
      if (oldProps.className != null) this.element.classList.remove(oldProps.className)
      if (newProps.className != null) this.element.classList.add(newProps.className)
    }
  }

  didAttach () {
    this.resizeObserver.observe(this.element)
  }

  didDetach () {
    this.resizeObserver.disconnect()
  }
}

let rangeForMeasurement
function clientRectForRange (textNode, startIndex, endIndex) {
  if (!rangeForMeasurement) rangeForMeasurement = document.createRange()
  rangeForMeasurement.setStart(textNode, startIndex)
  rangeForMeasurement.setEnd(textNode, endIndex)
  return rangeForMeasurement.getBoundingClientRect()
}

function arraysEqual (a, b) {
  if (a.length !== b.length) return false
  for (let i = 0, length = a.length; i < length; i++) {
    if (a[i] !== b[i]) return false
  }
  return true
}

function constrainRangeToRows (range, startRow, endRow) {
  if (range.start.row < startRow || range.end.row >= endRow) {
    range = range.copy()
    if (range.start.row < startRow) {
      range.start.row = startRow
      range.start.column = 0
    }
    if (range.end.row >= endRow) {
      range.end.row = endRow
      range.end.column = 0
    }
  }
  return range
}
