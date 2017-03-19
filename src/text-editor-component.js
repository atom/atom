const etch = require('etch')
const {CompositeDisposable} = require('event-kit')
const {Point, Range} = require('text-buffer')
const resizeDetector = require('element-resize-detector')({strategy: 'scroll'})
const TextEditor = require('./text-editor')
const {isPairedCharacter} = require('./text-utils')
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
const MOUSE_WHEEL_SCROLL_SENSITIVITY = 0.8

function scaleMouseDragAutoscrollDelta (delta) {
  return Math.pow(delta / 3, 3) / 280
}

module.exports =
class TextEditorComponent {
  constructor (props) {
    this.props = props

    if (!props.model) props.model = new TextEditor()
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

    this.disposables = new CompositeDisposable()
    this.updateScheduled = false
    this.measurements = null
    this.visible = false
    this.horizontalPositionsToMeasure = new Map() // Keys are rows with positions we want to measure, values are arrays of columns to measure
    this.horizontalPixelPositionsByScreenLineId = new Map() // Values are maps from column to horiontal pixel positions
    this.lineNodesByScreenLineId = new Map()
    this.textNodesByScreenLineId = new Map()
    this.pendingAutoscroll = null
    this.scrollTop = 0
    this.scrollLeft = 0
    this.previousScrollWidth = 0
    this.previousScrollHeight = 0
    this.lastKeydown = null
    this.lastKeydownBeforeKeypress = null
    this.accentedCharacterMenuIsOpen = false
    this.decorationsToRender = {
      lineNumbers: new Map(),
      lines: new Map(),
      highlights: new Map(),
      cursors: []
    }
    this.decorationsToMeasure = {
      highlights: new Map(),
      cursors: []
    }

    if (this.props.model) this.observeModel()
    resizeDetector.listenTo(this.element, this.didResize.bind(this))

    etch.updateSync(this)
  }

  update (props) {
    this.props = props
    this.scheduleUpdate()
  }

  scheduleUpdate () {
    if (!this.visible) return

    if (this.updatedSynchronously) {
      this.updateSync()
    } else if (!this.updateScheduled) {
      this.updateScheduled = true
      etch.getScheduler().updateDocument(() => {
        if (this.updateScheduled) this.updateSync()
      })
    }
  }

  updateSync () {
    this.updateScheduled = false
    if (this.nextUpdatePromise) {
      this.resolveNextUpdatePromise()
      this.nextUpdatePromise = null
      this.resolveNextUpdatePromise = null
    }

    this.horizontalPositionsToMeasure.clear()
    if (this.pendingAutoscroll) this.autoscrollVertically()
    this.populateVisibleRowRange()
    const longestLineToMeasure = this.checkForNewLongestLine()
    this.queryScreenLinesToRender()
    this.queryDecorationsToRender()

    etch.updateSync(this)

    this.measureHorizontalPositions()
    if (longestLineToMeasure) this.measureLongestLineWidth(longestLineToMeasure)
    this.updateAbsolutePositionedDecorations()

    etch.updateSync(this)

    if (this.pendingAutoscroll) {
      this.autoscrollHorizontally()
      this.pendingAutoscroll = null
    }
    this.currentFrameLineNumberGutterProps = null
  }

  checkIfScrollDimensionsChanged () {
    const scrollHeight = this.getScrollHeight()
    const scrollWidth = this.getScrollWidth()
    if (scrollHeight !== this.previousScrollHeight || scrollWidth !== this.previousScrollWidth) {
      this.previousScrollHeight = scrollHeight
      this.previousScrollWidth = scrollWidth
      return true
    } else {
      return false
    }
  }

  render () {
    const {model} = this.props

    const style = {}
    if (!model.getAutoHeight() && !model.getAutoWidth()) {
      style.contain = 'strict'
    }
    if (this.measurements) {
      if (model.getAutoHeight()) {
        style.height = this.getContentHeight() + 'px'
      }
      if (model.getAutoWidth()) {
        style.width = this.getGutterContainerWidth() + this.getContentWidth() + 'px'
      }
    }

    let attributes = null
    let className = 'editor'
    if (this.focused) className += ' is-focused'
    if (model.isMini()) {
      attributes = {mini: ''}
      className += ' mini'
    }

    return $('atom-text-editor',
      {
        className,
        style,
        attributes,
        tabIndex: -1,
        on: {
          focus: this.didFocus,
          blur: this.didBlur,
          mousewheel: this.didMouseWheel
        }
      },
      $.div(
        {
          ref: 'clientContainer',
          style: {
            position: 'relative',
            contain: 'strict',
            overflow: 'hidden',
            backgroundColor: 'inherit',
            width: '100%',
            height: '100%'
          }
        },
        this.renderGutterContainer(),
        this.renderScrollContainer()
      )
    )
  }

  renderGutterContainer () {
    if (this.props.model.isMini()) return null

    const innerStyle = {
      willChange: 'transform',
      backgroundColor: 'inherit'
    }
    if (this.measurements) {
      innerStyle.transform = `translateY(${-this.getScrollTop()}px)`
    }

    return $.div(
      {
        ref: 'gutterContainer',
        className: 'gutter-container',
        style: {
          position: 'relative',
          zIndex: 1,
          backgroundColor: 'inherit'
        }
      },
      $.div({style: innerStyle},
        this.renderLineNumberGutter()
      )
    )
  }

  renderLineNumberGutter () {
    const {model} = this.props

    if (!model.isLineNumberGutterVisible()) return null

    if (this.currentFrameLineNumberGutterProps) {
      return $(LineNumberGutterComponent, this.currentFrameLineNumberGutterProps)
    }

    const maxLineNumberDigits = Math.max(2, model.getLineCount().toString().length)

    if (this.measurements) {
      const startRow = this.getRenderedStartRow()
      const endRow = this.getRenderedEndRow()
      const renderedRowCount = this.getRenderedRowCount()
      const bufferRows = new Array(renderedRowCount)
      const foldableFlags = new Array(renderedRowCount)
      const softWrappedFlags = new Array(renderedRowCount)
      const lineNumberDecorations = new Array(renderedRowCount)

      let previousBufferRow = (startRow > 0) ? model.bufferRowForScreenRow(startRow - 1) : -1
      for (let row = startRow; row < endRow; row++) {
        const i = row - startRow
        const bufferRow = model.bufferRowForScreenRow(row)
        bufferRows[i] = bufferRow
        softWrappedFlags[i] = bufferRow === previousBufferRow
        foldableFlags[i] = model.isFoldableAtBufferRow(bufferRow)
        lineNumberDecorations[i] = this.decorationsToRender.lineNumbers.get(row)
        previousBufferRow = bufferRow
      }

      const rowsPerTile = this.getRowsPerTile()

      this.currentFrameLineNumberGutterProps = {
        ref: 'lineNumberGutter',
        parentComponent: this,
        height: this.getScrollHeight(),
        width: this.getLineNumberGutterWidth(),
        lineHeight: this.getLineHeight(),
        startRow, endRow, rowsPerTile, maxLineNumberDigits,
        bufferRows, lineNumberDecorations, softWrappedFlags,
        foldableFlags
      }

      return $(LineNumberGutterComponent, this.currentFrameLineNumberGutterProps)
    } else {
      return $.div(
        {
          ref: 'lineNumberGutter',
          className: 'gutter line-numbers',
          'gutter-name': 'line-number'
        },
        $.div({className: 'line-number'},
          '0'.repeat(maxLineNumberDigits),
          $.div({className: 'icon-right'})
        )
      )
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

    if (this.measurements) {
      style.left = this.getGutterContainerWidth() + 'px'
      style.width = this.getScrollContainerWidth() + 'px'
    }

    return $.div(
      {
        ref: 'scrollContainer',
        className: 'scroll-view',
        style
      },
      this.renderContent()
    )
  }

  renderContent () {
    let children
    let style = {
      contain: 'strict',
      overflow: 'hidden',
      backgroundColor: 'inherit'
    }
    if (this.measurements) {
      style.width = this.getScrollWidth() + 'px'
      style.height = this.getScrollHeight() + 'px'
      style.willChange = 'transform'
      style.transform = `translate(${-this.getScrollLeft()}px, ${-this.getScrollTop()}px)`
      children = [
        this.renderCursorsAndInput(),
        this.renderLineTiles(),
        this.renderPlaceholderText()
      ]
    } else {
      children = $.div({ref: 'characterMeasurementLine', className: 'line'},
        $.span({ref: 'normalWidthCharacterSpan'}, NORMAL_WIDTH_CHARACTER),
        $.span({ref: 'doubleWidthCharacterSpan'}, DOUBLE_WIDTH_CHARACTER),
        $.span({ref: 'halfWidthCharacterSpan'}, HALF_WIDTH_CHARACTER),
        $.span({ref: 'koreanCharacterSpan'}, KOREAN_CHARACTER)
      )
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
    if (!this.measurements) return []

    const {lineNodesByScreenLineId, textNodesByScreenLineId} = this

    const startRow = this.getRenderedStartRow()
    const endRow = this.getRenderedEndRow()
    const rowsPerTile = this.getRowsPerTile()
    const tileHeight = this.getLineHeight() * rowsPerTile
    const tileWidth = this.getScrollWidth()

    const displayLayer = this.props.model.displayLayer
    const tileNodes = new Array(this.getRenderedTileCount())

    for (let tileStartRow = startRow; tileStartRow < endRow; tileStartRow += rowsPerTile) {
      const tileEndRow = Math.min(endRow, tileStartRow + rowsPerTile)
      const tileIndex = this.tileIndexForTileStartRow(tileStartRow)

      const lineDecorations = new Array(tileEndRow - tileStartRow)
      for (let row = tileStartRow; row < tileEndRow; row++) {
        lineDecorations[row - tileStartRow] = this.decorationsToRender.lines.get(row)
      }
      const highlightDecorations = this.decorationsToRender.highlights.get(tileStartRow)

      tileNodes[tileIndex] = $(LinesTileComponent, {
        key: tileIndex,
        height: tileHeight,
        width: tileWidth,
        top: this.topPixelPositionForRow(tileStartRow),
        lineHeight: this.getLineHeight(),
        screenLines: this.renderedScreenLines.slice(tileStartRow - startRow, tileEndRow - startRow),
        lineDecorations,
        highlightDecorations,
        displayLayer,
        lineNodesByScreenLineId,
        textNodesByScreenLineId
      })
    }

    if (this.longestLineToMeasure != null && (this.longestLineToMeasureRow < startRow || this.longestLineToMeasureRow >= endRow)) {
      tileNodes.push($(LineComponent, {
        key: this.longestLineToMeasure.id,
        screenLine: this.longestLineToMeasure,
        displayLayer,
        lineNodesByScreenLineId,
        textNodesByScreenLineId
      }))
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
        height: this.getScrollHeight() + 'px',
        backgroundColor: 'inherit'
      }
    }, tileNodes)
  }

  renderCursorsAndInput () {
    const cursorHeight = this.getLineHeight() + 'px'

    const children = [this.renderHiddenInput()]

    for (let i = 0; i < this.decorationsToRender.cursors.length; i++) {
      const {pixelLeft, pixelTop, pixelWidth} = this.decorationsToRender.cursors[i]
      children.push($.div({
        className: 'cursor',
        style: {
          height: cursorHeight,
          width: pixelWidth + 'px',
          transform: `translate(${pixelLeft}px, ${pixelTop}px)`
        }
      }))
    }

    return $.div({
      key: 'cursors',
      className: 'cursors',
      style: {
        position: 'absolute',
        contain: 'strict',
        zIndex: 1,
        width: this.getScrollWidth() + 'px',
        height: this.getScrollHeight() + 'px'
      }
    }, children)
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

  renderHiddenInput () {
    let top, left
    if (this.hiddenInputPosition) {
      top = this.hiddenInputPosition.pixelTop
      left = this.hiddenInputPosition.pixelLeft
    } else {
      top = 0
      left = 0
    }

    return $.input({
      ref: 'hiddenInput',
      key: 'hiddenInput',
      className: 'hidden-input',
      on: {
        blur: this.didBlurHiddenInput,
        focus: this.didFocusHiddenInput,
        textInput: this.didTextInput,
        keydown: this.didKeydown,
        keyup: this.didKeyup,
        keypress: this.didKeypress,
        compositionstart: this.didCompositionStart,
        compositionupdate: this.didCompositionUpdate,
        compositionend: this.didCompositionEnd
      },
      tabIndex: -1,
      style: {
        position: 'absolute',
        width: '1px',
        height: this.getLineHeight() + 'px',
        top: top + 'px',
        left: left + 'px',
        opacity: 0,
        padding: 0,
        border: 0
      }
    })
  }

  // This is easier to mock
  getPlatform () {
    return process.platform
  }

  queryScreenLinesToRender () {
    this.renderedScreenLines = this.props.model.displayLayer.getScreenLines(
      this.getRenderedStartRow(),
      this.getRenderedEndRow()
    )
  }

  renderedScreenLineForRow (row) {
    return this.renderedScreenLines[row - this.getRenderedStartRow()]
  }

  queryDecorationsToRender () {
    this.decorationsToRender.lineNumbers.clear()
    this.decorationsToRender.lines.clear()
    this.decorationsToMeasure.highlights.clear()
    this.decorationsToMeasure.cursors.length = 0

    const decorationsByMarker =
      this.props.model.decorationManager.decorationPropertiesByMarkerForScreenRowRange(
        this.getRenderedStartRow(),
        this.getRenderedEndRow()
      )

    decorationsByMarker.forEach((decorations, marker) => {
      const screenRange = marker.getScreenRange()
      const reversed = marker.isReversed()
      for (let i = 0, length = decorations.length; i < decorations.length; i++) {
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
          this.addCursorDecorationToMeasure(marker, screenRange, reversed)
          break
      }
    }
  }

  addLineDecorationToRender (type, decoration, screenRange, reversed) {
    const decorationsByRow = (type === 'line') ? this.decorationsToRender.lines : this.decorationsToRender.lineNumbers

    let omitLastRow = false
    if (screenRange.isEmpty()) {
      if (decoration.onlyNonEmpty) return
    } else {
      if (decoration.onlyEmpty) return
      if (decoration.omitEmptyLastRow !== false) {
        omitLastRow = screenRange.end.column === 0
      }
    }

    let startRow = screenRange.start.row
    let endRow = screenRange.end.row

    if (decoration.onlyHead) {
      if (reversed) {
        endRow = startRow
      } else {
        startRow = endRow
      }
    }

    startRow = Math.max(startRow, this.getRenderedStartRow())
    endRow = Math.min(endRow, this.getRenderedEndRow() - 1)

    for (let row = startRow; row <= endRow; row++) {
      if (omitLastRow && row === screenRange.end.row) break
      const currentClassName = decorationsByRow.get(row)
      const newClassName = currentClassName ? currentClassName + ' ' + decoration.class : decoration.class
      decorationsByRow.set(row, newClassName)
    }
  }

  addHighlightDecorationToMeasure(decoration, screenRange, key) {
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
        key, className, flashRequested, flashClass, flashDuration
      })

      this.requestHorizontalMeasurement(screenRangeInTile.start.row, screenRangeInTile.start.column)
      this.requestHorizontalMeasurement(screenRangeInTile.end.row, screenRangeInTile.end.column)

      tileStartRow += rowsPerTile
    }
  }

  addCursorDecorationToMeasure (marker, screenRange, reversed) {
    const {model} = this.props
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
    this.decorationsToMeasure.cursors.push({screenPosition, columnWidth, isLastCursor})
  }

  updateAbsolutePositionedDecorations () {
    this.updateHighlightsToRender()
    this.updateCursorsToRender()
  }

  updateHighlightsToRender () {
    this.decorationsToRender.highlights.clear()
    this.decorationsToMeasure.highlights.forEach((highlights, tileRow) => {
      for (let i = 0, length = highlights.length; i < length; i++) {
        const highlight = highlights[i]
        const {start, end} = highlight.screenRange
        highlight.startPixelTop = this.pixelTopForRow(start.row)
        highlight.startPixelLeft = this.pixelLeftForRowAndColumn(start.row, start.column)
        highlight.endPixelTop = this.pixelTopForRow(end.row + 1)
        highlight.endPixelLeft = this.pixelLeftForRowAndColumn(end.row, end.column)
      }
      this.decorationsToRender.highlights.set(tileRow, highlights)
    })
  }

  updateCursorsToRender () {
    this.decorationsToRender.cursors.length = 0

    const height = this.getLineHeight() + 'px'
    for (let i = 0; i < this.decorationsToMeasure.cursors.length; i++) {
      const cursor = this.decorationsToMeasure.cursors[i]
      const {row, column} = cursor.screenPosition

      const pixelTop = this.pixelTopForRow(row)
      const pixelLeft = this.pixelLeftForRowAndColumn(row, column)
      const pixelRight = (cursor.columnWidth === 0)
        ? pixelLeft
        : this.pixelLeftForRowAndColumn(row, column + 1)
      const pixelWidth = pixelRight - pixelLeft

      const cursorPosition = {pixelTop, pixelLeft, pixelWidth}
      this.decorationsToRender.cursors[i] = cursorPosition
      if (cursor.isLastCursor) this.hiddenInputPosition = cursorPosition
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
      if (this.isVisible()) {
        this.didShow()
      } else {
        this.didHide()
      }
    }
  }

  didDetach () {
    if (this.attached) {
      this.didHide()
      this.attached = false
    }
  }

  didShow () {
    if (!this.visible) {
      this.visible = true
      if (!this.measurements) this.performInitialMeasurements()
      this.props.model.setVisible(true)
      this.updateSync()
    }
  }

  didHide () {
    if (this.visible) {
      this.visible = false
      this.props.model.setVisible(false)
    }
  }

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
      this.scheduleUpdate()
    }

    // Transfer focus to the hidden input, but first ensure the input is in the
    // visible part of the scrolled content to avoid the browser trying to
    // auto-scroll to the form-field.
    const {hiddenInput} = this.refs
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

  didBlur (event) {
    if (event.relatedTarget === this.refs.hiddenInput) {
      event.stopImmediatePropagation()
    }
  }

  didBlurHiddenInput (event) {
    if (this.element !== event.relatedTarget && !this.element.contains(event.relatedTarget)) {
      this.focused = false
      this.scheduleUpdate()
      this.element.dispatchEvent(new FocusEvent(event.type, event))
    }
  }

  didFocusHiddenInput () {
    if (!this.focused) {
      this.focused = true
      this.scheduleUpdate()
    }
  }

  didMouseWheel (eveWt) {
    let {deltaX, deltaY} = event
    deltaX = deltaX * MOUSE_WHEEL_SCROLL_SENSITIVITY
    deltaY = deltaY * MOUSE_WHEEL_SCROLL_SENSITIVITY

    const scrollPositionChanged =
      this.setScrollLeft(this.getScrollLeft() + deltaX) ||
      this.setScrollTop(this.getScrollTop() + deltaY)

    if (scrollPositionChanged) this.updateSync()
  }

  didResize () {
    if (this.measureClientContainerDimensions()) {
      this.scheduleUpdate()
    }
  }

  didTextInput (event) {
    event.stopPropagation()

    // WARNING: If we call preventDefault on the input of a space character,
    // then the browser interprets the spacebar keypress as a page-down command,
    // causing spaces to scroll elements containing editors. This is impossible
    // to test.
    if (event.data !== ' ') event.preventDefault()

    // TODO: Deal with disabled input
    // if (!this.isInputEnabled()) return

    if (this.compositionCheckpoint) {
      this.props.model.revertToCheckpoint(this.compositionCheckpoint)
      this.compositionCheckpoint = null
    }

    // Undo insertion of the original non-accented character so it is discarded
    // from the history and does not reappear on undo
    if (this.accentedCharacterMenuIsOpen) {
      this.props.model.undo()
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
  // keydown(keyCode: X), keypress, keydown(keyCode: X)
  //
  // The keyCode X must be the same in the keydown events that bracket the
  // keypress, meaning we're *holding* the _same_ key we intially pressed.
  // Got that?
  didKeydown (event) {
    if (this.lastKeydownBeforeKeypress != null) {
      if (this.lastKeydownBeforeKeypress.keyCode === event.keyCode) {
        this.accentedCharacterMenuIsOpen = true
        this.props.model.selectLeft()
      }
      this.lastKeydownBeforeKeypress = null
    } else {
      this.lastKeydown = event
    }
  }

  didKeypress () {
    this.lastKeydownBeforeKeypress = this.lastKeydown
    this.lastKeydown = null

    // This cancels the accented character behavior if we type a key normally
    // with the menu open.
    this.accentedCharacterMenuIsOpen = false
  }

  didKeyup () {
    this.lastKeydownBeforeKeypress = null
    this.lastKeydown = null
  }

  // The IME composition events work like this:
  //
  // User types 's', chromium pops up the completion helper
  //   1. compositionstart fired
  //   2. compositionupdate fired; event.data == 's'
  // User hits arrow keys to move around in completion helper
  //   3. compositionupdate fired; event.data == 's' for each arry key press
  // User escape to cancel
  //   4. compositionend fired
  // OR User chooses a completion
  //   4. compositionend fired
  //   5. textInput fired; event.data == the completion string
  didCompositionStart () {
    this.compositionCheckpoint = this.props.model.createCheckpoint()
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
    let {top, bottom, left, right} = this.refs.scrollContainer.getBoundingClientRect()
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

  screenPositionForMouseEvent ({clientX, clientY}) {
    const scrollContainerRect = this.refs.scrollContainer.getBoundingClientRect()
    clientX = Math.min(scrollContainerRect.right, Math.max(scrollContainerRect.left, clientX))
    clientY = Math.min(scrollContainerRect.bottom, Math.max(scrollContainerRect.top, clientY))
    const linesRect = this.refs.lineTiles.getBoundingClientRect()
    return this.screenPositionForPixelPosition({
      top: clientY - linesRect.top,
      left: clientX - linesRect.left
    })
  }

  didRequestAutoscroll (autoscroll) {
    this.pendingAutoscroll = autoscroll
    this.scheduleUpdate()
  }

  autoscrollVertically () {
    const {screenRange, options} = this.pendingAutoscroll

    const screenRangeTop = this.pixelTopForRow(screenRange.start.row)
    const screenRangeBottom = this.pixelTopForRow(screenRange.end.row) + this.getLineHeight()
    const verticalScrollMargin = this.getVerticalAutoscrollMargin()

    this.requestHorizontalMeasurement(screenRange.start.row, screenRange.start.column)
    this.requestHorizontalMeasurement(screenRange.end.row, screenRange.end.column)

    let desiredScrollTop, desiredScrollBottom
    if (options && options.center) {
      const desiredScrollCenter = (screenRangeTop + screenRangeBottom) / 2
      if (desiredScrollCenter < this.getScrollTop() || desiredScrollCenter > this.getScrollBottom()) {
        desiredScrollTop = desiredScrollCenter - this.measurements.clientHeight / 2
        desiredScrollBottom = desiredScrollCenter + this.measurements.clientHeight / 2
      }
    } else {
      desiredScrollTop = screenRangeTop - verticalScrollMargin
      desiredScrollBottom = screenRangeBottom + verticalScrollMargin
    }

    if (!options || options.reversed !== false) {
      if (desiredScrollBottom > this.getScrollBottom()) {
        return this.setScrollBottom(desiredScrollBottom, true)
      }
      if (desiredScrollTop < this.getScrollTop()) {
        return this.setScrollTop(desiredScrollTop, true)
      }
    } else {
      if (desiredScrollTop < this.getScrollTop()) {
        return this.setScrollTop(desiredScrollTop, true)
      }
      if (desiredScrollBottom > this.getScrollBottom()) {
        return this.setScrollBottom(desiredScrollBottom, true)
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
        this.setScrollRight(desiredScrollRight, true)
      }
      if (desiredScrollLeft < this.getScrollLeft()) {
        this.setScrollLeft(desiredScrollLeft, true)
      }
    } else {
      if (desiredScrollLeft < this.getScrollLeft()) {
        this.setScrollLeft(desiredScrollLeft, true)
      }
      if (desiredScrollRight > this.getScrollRight()) {
        this.setScrollRight(desiredScrollRight, true)
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

  performInitialMeasurements () {
    this.measurements = {}
    this.measureCharacterDimensions()
    this.measureGutterDimensions()
    this.measureClientContainerDimensions()
  }

  measureClientContainerDimensions () {
    if (!this.measurements) return false

    let dimensionsChanged = false
    const clientContainerHeight = this.refs.clientContainer.offsetHeight
    const clientContainerWidth = this.refs.clientContainer.offsetWidth
    if (clientContainerHeight !== this.measurements.clientContainerHeight) {
      this.measurements.clientContainerHeight = clientContainerHeight
      dimensionsChanged = true
    }
    if (clientContainerWidth !== this.measurements.clientContainerWidth) {
      this.measurements.clientContainerWidth = clientContainerWidth
      this.props.model.setEditorWidthInChars(this.getScrollContainerWidth() / this.getBaseCharacterWidth())
      dimensionsChanged = true
    }
    return dimensionsChanged
  }

  measureCharacterDimensions () {
    this.measurements.lineHeight = this.refs.characterMeasurementLine.getBoundingClientRect().height
    this.measurements.baseCharacterWidth = this.refs.normalWidthCharacterSpan.getBoundingClientRect().width
    this.measurements.doubleWidthCharacterWidth = this.refs.doubleWidthCharacterSpan.getBoundingClientRect().width
    this.measurements.halfWidthCharacterWidth = this.refs.halfWidthCharacterSpan.getBoundingClientRect().width
    this.measurements.koreanCharacterWidth = this.refs.koreanCharacterSpan.getBoundingClientRect().widt

    this.props.model.setDefaultCharWidth(
      this.measurements.baseCharacterWidth,
      this.measurements.doubleWidthCharacterWidth,
      this.measurements.halfWidthCharacterWidth,
      this.measurements.koreanCharacterWidth
    )
  }

  checkForNewLongestLine () {
    const {model} = this.props
    const longestLineRow = model.getApproximateLongestScreenRow()
    const longestLine = model.screenLineForScreenRow(longestLineRow)
    if (longestLine !== this.previousLongestLine) {
      this.longestLineToMeasure = longestLine
      this.longestLineToMeasureRow = longestLineRow
      this.previousLongestLine = longestLine
      return longestLine
    }
  }

  measureLongestLineWidth (screenLine) {
    this.measurements.longestLineWidth = this.lineNodesByScreenLineId.get(screenLine.id).firstChild.offsetWidth
    this.longestLineToMeasureRow = null
    this.longestLineToMeasure = null
  }

  measureGutterDimensions () {
    if (this.refs.lineNumberGutter) {
      this.measurements.lineNumberGutterWidth = this.refs.lineNumberGutter.offsetWidth
    } else {
      this.measurements.lineNumberGutterWidth = 0
    }
  }

  requestHorizontalMeasurement (row, column) {
    if (column === 0) return
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
  }

  measureHorizontalPositionsOnLine (lineNode, textNodes, columnsToMeasure, positions) {
    let lineNodeClientLeft = -1
    let textNodeStartColumn = 0
    let textNodesIndex = 0

    columnLoop:
    for (let columnsIndex = 0; columnsIndex < columnsToMeasure.length; columnsIndex++) {
      while (textNodesIndex < textNodes.length) {
        const nextColumnToMeasure = columnsToMeasure[columnsIndex]
        if (nextColumnToMeasure === 0) {
          positions.set(0, 0)
          continue columnLoop
        }
        if (nextColumnToMeasure >= lineNode.textContent.length) {

        }
        if (positions.has(nextColumnToMeasure)) continue columnLoop
        const textNode = textNodes[textNodesIndex]
        const textNodeEndColumn = textNodeStartColumn + textNode.textContent.length

        if (nextColumnToMeasure <= textNodeEndColumn) {
          let clientPixelPosition
          if (nextColumnToMeasure === textNodeStartColumn) {
            clientPixelPosition = clientRectForRange(textNode, 0, 1).left
          } else {
            clientPixelPosition = clientRectForRange(textNode, 0, nextColumnToMeasure - textNodeStartColumn).right
          }
          if (lineNodeClientLeft === -1) lineNodeClientLeft = lineNode.getBoundingClientRect().left
          positions.set(nextColumnToMeasure, clientPixelPosition - lineNodeClientLeft)
          continue columnLoop
        } else {
          textNodesIndex++
          textNodeStartColumn = textNodeEndColumn
        }
      }
    }
  }

  pixelTopForRow (row) {
    return row * this.getLineHeight()
  }

  pixelLeftForRowAndColumn (row, column) {
    if (column === 0) return 0
    const screenLine = this.renderedScreenLineForRow(row)
    return this.horizontalPixelPositionsByScreenLineId.get(screenLine.id).get(column)
  }

  screenPositionForPixelPosition({top, left}) {
    const {model} = this.props

    const row = Math.min(
      Math.max(0, Math.floor(top / this.measurements.lineHeight)),
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
      textNodeStartColumn += textNodes[i].length
    }
    const column = textNodeStartColumn + characterIndex

    return Point(row, column)
  }

  observeModel () {
    const {model} = this.props
    model.component = this
    const scheduleUpdate = this.scheduleUpdate.bind(this)
    this.disposables.add(model.selectionsMarkerLayer.onDidUpdate(scheduleUpdate))
    this.disposables.add(model.displayLayer.onDidChangeSync(scheduleUpdate))
    this.disposables.add(model.onDidUpdateDecorations(scheduleUpdate))
    this.disposables.add(model.onDidRequestAutoscroll(this.didRequestAutoscroll.bind(this)))
  }

  isVisible () {
    return this.element.offsetWidth > 0 || this.element.offsetHeight > 0
  }

  getLineHeight () {
    return this.measurements.lineHeight
  }

  getBaseCharacterWidth () {
    return this.measurements ? this.measurements.baseCharacterWidth : null
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

  getScrollContainerHeightInLines () {
    return Math.ceil(this.getScrollContainerHeight() / this.getLineHeight())
  }

  getScrollContainerClientWidth () {
    return this.getScrollContainerWidth()
  }

  getScrollContainerClientHeight () {
    return this.getScrollContainerHeight()
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
    return this.props.model.getApproximateScreenLineCount() * this.getLineHeight()
  }

  getContentWidth () {
    return Math.round(this.getLongestLineWidth() + this.getBaseCharacterWidth())
  }

  getGutterContainerWidth () {
    return this.getLineNumberGutterWidth()
  }

  getLineNumberGutterWidth () {
    return this.measurements.lineNumberGutterWidth
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

  getFirstTileStartRow () {
    return this.tileStartRowForRow(this.getFirstVisibleRow())
  }

  getRenderedStartRow () {
    return this.getFirstTileStartRow()
  }

  getRenderedEndRow () {
    return Math.min(
      this.props.model.getApproximateScreenLineCount(),
      this.getFirstTileStartRow() + this.getVisibleTileCount() * this.getRowsPerTile()
    )
  }

  getRenderedRowCount () {
    return Math.max(0, this.getRenderedEndRow() - this.getRenderedStartRow())
  }

  getRenderedTileCount () {
    return Math.ceil(this.getRenderedRowCount() / this.getRowsPerTile())
  }

  getFirstVisibleRow () {
    return Math.floor(this.getScrollTop() / this.getLineHeight())
  }

  getLastVisibleRow () {
    return Math.min(
      this.props.model.getApproximateScreenLineCount() - 1,
      this.getFirstVisibleRow() + this.getScrollContainerHeightInLines()
    )
  }

  getVisibleTileCount () {
    return Math.floor((this.getLastVisibleRow() - this.getFirstVisibleRow()) / this.getRowsPerTile()) + 2
  }


  getScrollTop () {
    this.scrollTop = Math.min(this.getMaxScrollTop(), this.scrollTop)
    return this.scrollTop
  }

  setScrollTop (scrollTop, suppressUpdate = false) {
    scrollTop = Math.round(Math.max(0, Math.min(this.getMaxScrollTop(), scrollTop)))
    if (scrollTop !== this.scrollTop) {
      this.scrollTop = scrollTop
      if (!suppressUpdate) this.scheduleUpdate()
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

  setScrollBottom (scrollBottom, suppressUpdate = false) {
    return this.setScrollTop(scrollBottom - this.getScrollContainerClientHeight(), suppressUpdate)
  }

  getScrollLeft () {
    // this.scrollLeft = Math.min(this.getMaxScrollLeft(), this.scrollLeft)
    return this.scrollLeft
  }

  setScrollLeft (scrollLeft, suppressUpdate = false) {
    scrollLeft = Math.round(Math.max(0, Math.min(this.getMaxScrollLeft(), scrollLeft)))
    if (scrollLeft !== this.scrollLeft) {
      this.scrollLeft = scrollLeft
      if (!suppressUpdate) this.scheduleUpdate()
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

  setScrollRight (scrollRight, suppressUpdate = false) {
    return this.setScrollLeft(scrollRight - this.getScrollContainerClientWidth(), suppressUpdate)
  }

  // Ensure the spatial index is populated with rows that are currently
  // visible so we *at least* get the longest row in the visible range.
  populateVisibleRowRange () {
    const endRow = this.getFirstTileStartRow() + this.getVisibleTileCount() * this.getRowsPerTile()
    this.props.model.displayLayer.populateSpatialIndexIfNeeded(Infinity, endRow)
  }

  topPixelPositionForRow (row) {
    return row * this.getLineHeight()
  }

  getNextUpdatePromise () {
    if (!this.nextUpdatePromise) {
      this.nextUpdatePromise = new Promise((resolve) => {
        this.resolveNextUpdatePromise = resolve
      })
    }
    return this.nextUpdatePromise
  }
}

class LineNumberGutterComponent {
  constructor (props) {
    this.props = props
    etch.initialize(this)
  }

  update (newProps) {
    if (this.shouldUpdate(newProps)) {
      this.props = newProps
      etch.updateSync(this)
    }
  }

  render () {
    const {
      parentComponent, height, width, lineHeight, startRow, endRow, rowsPerTile,
      maxLineNumberDigits, bufferRows, softWrappedFlags, foldableFlags,
      lineNumberDecorations
    } = this.props

    const renderedTileCount = parentComponent.getRenderedTileCount()
    const children = new Array(renderedTileCount)
    const tileHeight = rowsPerTile * lineHeight + 'px'
    const tileWidth = width + 'px'

    let softWrapCount = 0
    for (let tileStartRow = startRow; tileStartRow < endRow; tileStartRow += rowsPerTile) {
      const tileEndRow = Math.min(endRow, tileStartRow + rowsPerTile)
      const tileChildren = new Array(tileEndRow - tileStartRow)
      for (let row = tileStartRow; row < tileEndRow; row++) {
        const i = row - startRow
        const bufferRow = bufferRows[i]
        const softWrapped = softWrappedFlags[i]
        const foldable = foldableFlags[i]
        let key, lineNumber
        let className = 'line-number'
        if (softWrapped) {
          softWrapCount++
          key = `${bufferRow}-${softWrapCount}`
          lineNumber = '•'
        } else {
          softWrapCount = 0
          key = bufferRow
          lineNumber = (bufferRow + 1).toString()
          if (foldable) className += ' foldable'
        }

        const lineNumberDecoration = lineNumberDecorations[i]
        if (lineNumberDecoration != null) className += ' ' + lineNumberDecoration

        lineNumber = NBSP_CHARACTER.repeat(maxLineNumberDigits - lineNumber.length) + lineNumber

        tileChildren[row - tileStartRow] = $.div({key, className},
          lineNumber,
          $.div({className: 'icon-right'})
        )
      }

      const tileIndex = parentComponent.tileIndexForTileStartRow(tileStartRow)
      const top = tileStartRow * lineHeight

      children[tileIndex] = $.div({
        key: tileIndex,
        on: {
          mousedown: this.didMouseDown
        },
        style: {
          contain: 'strict',
          overflow: 'hidden',
          position: 'absolute',
          height: tileHeight,
          width: tileWidth,
          willChange: 'transform',
          transform: `translateY(${top}px)`,
          backgroundColor: 'inherit'
        }
      }, ...tileChildren)
    }

    return $.div(
      {
        className: 'gutter line-numbers',
        'gutter-name': 'line-number',
        style: {
          contain: 'strict',
          overflow: 'hidden',
          height: height + 'px',
          width: tileWidth
        }
      },
      ...children
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
    if (oldProps.maxLineNumberDigits !== newProps.maxLineNumberDigits) return true
    if (!arraysEqual(oldProps.bufferRows, newProps.bufferRows)) return true
    if (!arraysEqual(oldProps.softWrappedFlags, newProps.softWrappedFlags)) return true
    if (!arraysEqual(oldProps.foldableFlags, newProps.foldableFlags)) return true
    if (!arraysEqual(oldProps.lineNumberDecorations, newProps.lineNumberDecorations)) return true
    return false
  }

  didMouseDown (event) {
    this.props.parentComponent.didMouseDownOnLineNumberGutter(event)
  }
}

class LinesTileComponent {
  constructor (props) {
    this.props = props
    etch.initialize(this)
  }

  update (newProps) {
    if (this.shouldUpdate(newProps)) {
      this.props = newProps
      etch.updateSync(this)
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
      this.renderHighlights(),
      this.renderLines()
    )

  }

  renderHighlights () {
    const {top, height, width, lineHeight, highlightDecorations} = this.props

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
        style: {
          position: 'absolute',
          contain: 'strict',
          height: height + 'px',
          width: width + 'px'
        },
      }, children
    )
  }

  renderLines () {
    const {
      height, width, top,
      screenLines, lineDecorations, displayLayer,
      lineNodesByScreenLineId, textNodesByScreenLineId,
    } = this.props

    const children = new Array(screenLines.length)
    for (let i = 0, length = screenLines.length; i < length; i++) {
      const screenLine = screenLines[i]
      if (!screenLine) {
        children.length = i
        break
      }
      children[i] = $(LineComponent, {
        key: screenLine.id,
        screenLine,
        lineDecoration: lineDecorations[i],
        displayLayer,
        lineNodesByScreenLineId,
        textNodesByScreenLineId
      })
    }

    return $.div({
      style: {
        position: 'absolute',
        contain: 'strict',
        height: height + 'px',
        width: width + 'px'
      }
    }, children)
  }

  shouldUpdate (newProps) {
    const oldProps = this.props
    if (oldProps.top !== newProps.top) return true
    if (oldProps.height !== newProps.height) return true
    if (oldProps.width !== newProps.width) return true
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
        if (oldHighlight.startPixelLeft !== newHighlight.startPixelLeft) return true
        if (oldHighlight.endPixelLeft !== newHighlight.endPixelLeft) return true
        if (!oldHighlight.screenRange.isEqual(newHighlight.screenRange)) return true
      }
    }

    return false
  }
}

class LineComponent {
  constructor (props) {
    const {displayLayer, screenLine, lineDecoration, lineNodesByScreenLineId, textNodesByScreenLineId} = props
    this.props = props
    this.element = document.createElement('div')
    this.element.className = this.buildClassName()
    lineNodesByScreenLineId.set(screenLine.id, this.element)

    const textNodes = []
    textNodesByScreenLineId.set(screenLine.id, textNodes)

    const {lineText, tagCodes} = screenLine
    let startIndex = 0
    let openScopeNode = document.createElement('span')
    this.element.appendChild(openScopeNode)
    for (let i = 0; i < tagCodes.length; i++) {
      const tagCode = tagCodes[i]
      if (tagCode !== 0) {
        if (displayLayer.isCloseTagCode(tagCode)) {
          openScopeNode = openScopeNode.parentElement
        } else if (displayLayer.isOpenTagCode(tagCode)) {
          const scope = displayLayer.tagForCode(tagCode)
          const newScopeNode = document.createElement('span')
          newScopeNode.className = classNameForScopeName(scope)
          openScopeNode.appendChild(newScopeNode)
          openScopeNode = newScopeNode
        } else {
          const textNode = document.createTextNode(lineText.substr(startIndex, tagCode))
          startIndex += tagCode
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
      this.props = newProps
      this.element.className = this.buildClassName()
    }
  }

  destroy () {
    const {lineNodesByScreenLineId, textNodesByScreenLineId, screenLine} = this.props
    if (lineNodesByScreenLineId.get(screenLine.id) === this.element) {
      lineNodesByScreenLineId.delete(screenLine.id)
      textNodesByScreenLineId.delete(screenLine.id)
    }
  }

  buildClassName () {
    const {lineDecoration} = this.props
    let className = 'line'
    if (lineDecoration != null) className += ' ' + lineDecoration
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
      startPixelLeft, endPixelLeft,
    } = this.props
    startPixelTop -= parentTileTop
    endPixelTop -= parentTileTop

    let children
    if (screenRange.start.row === screenRange.end.row) {
      children = $.div({
        className: 'region',
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
        className: 'region',
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
          className: 'region',
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
          className: 'region',
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

const classNamesByScopeName = new Map()
function classNameForScopeName (scopeName) {
  let classString = classNamesByScopeName.get(scopeName)
  if (classString == null) {
    classString = scopeName.replace(/\.+/g, ' ')
    classNamesByScopeName.set(scopeName, classString)
  }
  return classString
}

let rangeForMeasurement
function clientRectForRange (textNode, startIndex, endIndex) {
  if (!rangeForMeasurement) rangeForMeasurement = document.createRange()
  rangeForMeasurement.setStart(textNode, startIndex)
  rangeForMeasurement.setEnd(textNode, endIndex)
  return rangeForMeasurement.getBoundingClientRect()
}

function arraysEqual(a, b) {
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
