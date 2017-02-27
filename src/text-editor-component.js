const etch = require('etch')
const {CompositeDisposable} = require('event-kit')
const $ = etch.dom
const TextEditorElement = require('./text-editor-element')
const resizeDetector = require('element-resize-detector')({strategy: 'scroll'})

const DEFAULT_ROWS_PER_TILE = 6
const NORMAL_WIDTH_CHARACTER = 'x'
const DOUBLE_WIDTH_CHARACTER = '我'
const HALF_WIDTH_CHARACTER = 'ﾊ'
const KOREAN_CHARACTER = '세'
const NBSP_CHARACTER = '\u00a0'

module.exports =
class TextEditorComponent {
  constructor (props) {
    this.props = props
    this.element = props.element || new TextEditorElement()
    this.element.initialize(this)
    this.virtualNode = $('atom-text-editor')
    this.virtualNode.domNode = this.element
    this.refs = {}

    this.disposables = new CompositeDisposable()
    this.updateScheduled = false
    this.measurements = null
    this.visible = false
    this.horizontalPositionsToMeasure = new Map() // Keys are rows with positions we want to measure, values are arrays of columns to measure
    this.horizontalPixelPositionsByScreenLine = new WeakMap() // Values are maps from column to horiontal pixel positions
    this.lineNodesByScreenLine = new WeakMap()
    this.textNodesByScreenLine = new WeakMap()
    this.cursorsToRender = []

    if (this.props.model) this.observeModel()
    resizeDetector.listenTo(this.element, this.didResize.bind(this))

    etch.updateSync(this)
  }

  update (props) {
    this.props = props
    this.scheduleUpdate()
  }

  scheduleUpdate () {
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

    if (this.staleMeasurements.editorDimensions) this.measureEditorDimensions()

    const longestLine = this.getLongestScreenLine()
    let measureLongestLine = false
    if (longestLine !== this.previousLongestLine) {
      this.longestLineToMeasure = longestLine
      this.previousLongestLine = longestLine
      measureLongestLine = true
    }

    this.horizontalPositionsToMeasure.clear()
    etch.updateSync(this)
    if (measureLongestLine) this.measureLongestLineWidth(longestLine)
    this.queryCursorsToRender()
    this.measureHorizontalPositions()
    this.positionCursorsToRender()

    etch.updateSync(this)
  }

  render () {
    let style
    if (!this.getModel().getAutoHeight() && !this.getModel().getAutoWidth()) {
      style = {contain: 'strict'}
    }

    return $('atom-text-editor', {style},
      $.div({ref: 'scroller', onScroll: this.didScroll, className: 'scroll-view'},
        $.div({
          style: {
            isolate: 'content',
            width: 'max-content',
            height: 'max-content',
            backgroundColor: 'inherit'
          }
        },
          this.renderGutterContainer(),
          this.renderContent()
        )
      )
    )
  }

  renderGutterContainer () {
    const props = {ref: 'gutterContainer', className: 'gutter-container'}

    if (this.measurements) {
      props.style = {
        position: 'relative',
        willChange: 'transform',
        transform: `translateX(${this.measurements.scrollLeft}px)`,
        zIndex: 1
      }
    }

    return $.div(props, this.renderLineNumberGutter())
  }

  renderLineNumberGutter () {
    const maxLineNumberDigits = Math.max(2, this.getModel().getLineCount().toString().length)

    let props = {
      ref: 'lineNumberGutter',
      className: 'gutter line-numbers',
      'gutter-name': 'line-number'
    }
    let children

    if (this.measurements) {
      props.style = {
        contain: 'strict',
        overflow: 'hidden',
        height: this.getScrollHeight() + 'px',
        width: this.measurements.lineNumberGutterWidth + 'px'
      }

      const approximateLastScreenRow = this.getModel().getApproximateScreenLineCount() - 1
      const firstVisibleRow = this.getFirstVisibleRow()
      const lastVisibleRow = this.getLastVisibleRow()
      const firstTileStartRow = this.getFirstTileStartRow()
      const visibleTileCount = this.getVisibleTileCount()
      const lastTileStartRow = this.getLastTileStartRow()

      children = new Array(visibleTileCount)

      let previousBufferRow = (firstTileStartRow > 0) ? this.getModel().bufferRowForScreenRow(firstTileStartRow - 1) : -1
      for (let tileStartRow = firstTileStartRow; tileStartRow <= lastTileStartRow; tileStartRow += this.getRowsPerTile()) {
        const currentTileEndRow = tileStartRow + this.getRowsPerTile()
        const lineNumberNodes = []

        for (let row = tileStartRow; row < currentTileEndRow && row <= approximateLastScreenRow; row++) {
          const bufferRow = this.getModel().bufferRowForScreenRow(row)
          const foldable = this.getModel().isFoldableAtBufferRow(bufferRow)
          const softWrapped = (bufferRow === previousBufferRow)

          let className = 'line-number'
          let lineNumber
          if (softWrapped) {
            lineNumber = '•'
          } else {
            if (foldable) className += ' foldable'
            lineNumber = (bufferRow + 1).toString()
          }
          lineNumber = NBSP_CHARACTER.repeat(maxLineNumberDigits - lineNumber.length) + lineNumber

          lineNumberNodes.push($.div({className},
            lineNumber,
            $.div({className: 'icon-right'})
          ))

          previousBufferRow = bufferRow
        }

        const tileIndex = (tileStartRow / this.getRowsPerTile()) % visibleTileCount
        const tileHeight = this.getRowsPerTile() * this.measurements.lineHeight

        children[tileIndex] = $.div({
          style: {
            contain: 'strict',
            overflow: 'hidden',
            position: 'absolute',
            height: tileHeight + 'px',
            width: this.measurements.lineNumberGutterWidth + 'px',
            willChange: 'transform',
            transform: `translateY(${this.topPixelPositionForRow(tileStartRow)}px)`,
            backgroundColor: 'inherit'
          }
        }, lineNumberNodes)
      }
    } else {
      children = $.div({className: 'line-number'},
        '0'.repeat(maxLineNumberDigits),
        $.div({className: 'icon-right'})
      )
    }

    return $.div(props, children)
  }

  renderContent () {
    let children
    let style = {
      contain: 'strict',
      overflow: 'hidden'
    }
    if (this.measurements) {
      const width = this.measurements.scrollWidth + 'px'
      const height = this.getScrollHeight() + 'px'
      style.width = width
      style.height = height
      children = [
        this.renderCursors(width, height),
        this.renderLineTiles(width, height)
      ]
    } else {
      children = $.div({ref: 'characterMeasurementLine', className: 'line'},
        $.span({ref: 'normalWidthCharacterSpan'}, NORMAL_WIDTH_CHARACTER),
        $.span({ref: 'doubleWidthCharacterSpan'}, DOUBLE_WIDTH_CHARACTER),
        $.span({ref: 'halfWidthCharacterSpan'}, HALF_WIDTH_CHARACTER),
        $.span({ref: 'koreanCharacterSpan'}, KOREAN_CHARACTER)
      )
    }

    return $.div({style}, children)
  }

  renderLineTiles (width, height) {
    if (!this.measurements) return []

    const {lineNodesByScreenLine, textNodesByScreenLine} = this

    const firstTileStartRow = this.getFirstTileStartRow()
    const visibleTileCount = this.getVisibleTileCount()
    const lastTileStartRow = this.getLastTileStartRow()

    const displayLayer = this.getModel().displayLayer
    const screenLines = displayLayer.getScreenLines(firstTileStartRow, lastTileStartRow + this.getRowsPerTile())

    let tileNodes = new Array(visibleTileCount)
    for (let tileStartRow = firstTileStartRow; tileStartRow <= lastTileStartRow; tileStartRow += this.getRowsPerTile()) {
      const tileEndRow = tileStartRow + this.getRowsPerTile()
      const lineNodes = []
      for (let row = tileStartRow; row < tileEndRow; row++) {
        const screenLine = screenLines[row - firstTileStartRow]
        if (!screenLine) break
        lineNodes.push($(LineComponent, {
          key: screenLine.id,
          screenLine,
          displayLayer,
          lineNodesByScreenLine,
          textNodesByScreenLine
        }))
        if (screenLine === this.longestLineToMeasure) {
          this.longestLineToMeasure = null
        }
      }

      const tileHeight = this.getRowsPerTile() * this.measurements.lineHeight
      const tileIndex = (tileStartRow / this.getRowsPerTile()) % visibleTileCount

      tileNodes[tileIndex] = $.div({
        key: tileIndex,
        style: {
          contain: 'strict',
          position: 'absolute',
          height: tileHeight + 'px',
          width: this.measurements.scrollWidth + 'px',
          willChange: 'transform',
          transform: `translateY(${this.topPixelPositionForRow(tileStartRow)}px)`,
          backgroundColor: 'inherit'
        }
      }, lineNodes)
    }

    if (this.longestLineToMeasure) {
      tileNodes.push($(LineComponent, {
        key: this.longestLineToMeasure.id,
        screenLine: this.longestLineToMeasure,
        displayLayer,
        lineNodesByScreenLine,
        textNodesByScreenLine
      }))
      this.longestLineToMeasure = null
    }

    return $.div({
      key: 'lineTiles',
      className: 'lines',
      style: {
        position: 'absolute',
        contain: 'strict',
        width, height
      }
    }, tileNodes)
  }

  renderCursors (width, height) {
    const cursorHeight = this.measurements.lineHeight + 'px'

    return $.div({
      key: 'cursors',
      className: 'cursors',
      style: {
        position: 'absolute',
        contain: 'strict',
        width, height
      }
    },
      this.cursorsToRender.map(({pixelLeft, pixelTop, pixelWidth}) =>
        $.div({
          className: 'cursor',
          style: {
            height: cursorHeight,
            width: pixelWidth + 'px',
            transform: `translate(${pixelLeft}px, ${pixelTop}px)`
          }
        })
      )
    )
  }

  queryCursorsToRender () {
    const model = this.getModel()
    const cursorMarkers = model.selectionsMarkerLayer.findMarkers({
      intersectsScreenRowRange: [
        this.getRenderedStartRow(),
        this.getRenderedEndRow() - 1,
      ]
    })

    this.cursorsToRender.length = cursorMarkers.length
    for (let i = 0; i < cursorMarkers.length; i++) {
      const screenPosition = cursorMarkers[i].getHeadScreenPosition()
      const {row, column} = screenPosition
      this.requestHorizontalMeasurement(row, column)
      let columnWidth = 0
      if (model.lineLengthForScreenRow(row) > column) {
        columnWidth = 1
        this.requestHorizontalMeasurement(row, column + 1)
      }
      this.cursorsToRender[i] = {
        screenPosition, columnWidth,
        pixelTop: 0, pixelLeft: 0, pixelWidth: 0
      }
    }
  }

  positionCursorsToRender () {
    const height = this.measurements.lineHeight + 'px'
    for (let i = 0; i < this.cursorsToRender.length; i++) {
      const cursorToRender = this.cursorsToRender[i]
      const {row, column} = cursorToRender.screenPosition

      const pixelTop = this.pixelTopForScreenRow(row)
      const pixelLeft = this.pixelLeftForScreenRowAndColumn(row, column)
      const pixelRight = (cursorToRender.columnWidth === 0)
        ? pixelLeft
        : this.pixelLeftForScreenRowAndColumn(row, column + 1)
      const pixelWidth = pixelRight - pixelLeft

      cursorToRender.pixelTop = pixelTop
      cursorToRender.pixelLeft = pixelLeft
      cursorToRender.pixelWidth = pixelWidth
    }
  }

  didAttach () {
    this.intersectionObserver = new IntersectionObserver((entries) => {
      const {intersectionRect} = entries[entries.length - 1]
      if (intersectionRect.width > 0 || intersectionRect.height > 0) {
        this.didShow()
      } else {
        this.didHide()
      }
    })
    this.intersectionObserver.observe(this.element)
    if (this.isVisible()) this.didShow()
  }

  didShow () {
    if (!this.visible) {
      this.visible = true
      this.getModel().setVisible(true)
      if (!this.measurements) this.performInitialMeasurements()
      this.updateSync()
    }
  }

  didHide () {
    if (this.visible) {
      this.visible = false
      this.getModel().setVisible(false)
    }
  }

  didScroll () {
    this.measureScrollPosition()
    this.updateSync()
  }

  didResize () {
    if (this.measureEditorDimensions()) {
      this.scheduleUpdate()
    }
  }

  performInitialMeasurements () {
    this.measurements = {}
    this.staleMeasurements = {}
    this.measureEditorDimensions()
    this.measureScrollPosition()
    this.measureCharacterDimensions()
    this.measureGutterDimensions()
  }

  measureEditorDimensions () {
    const scrollerHeight = this.refs.scroller.offsetHeight
    if (scrollerHeight !== this.measurements.scrollerHeight) {
      this.measurements.scrollerHeight = this.refs.scroller.offsetHeight
      return true
    } else {
      return false
    }
  }

  measureScrollPosition () {
    this.measurements.scrollTop = this.refs.scroller.scrollTop
    this.measurements.scrollLeft = this.refs.scroller.scrollLeft
  }

  measureCharacterDimensions () {
    this.measurements.lineHeight = this.refs.characterMeasurementLine.getBoundingClientRect().height
    this.measurements.baseCharacterWidth = this.refs.normalWidthCharacterSpan.getBoundingClientRect().width
    this.measurements.doubleWidthCharacterWidth = this.refs.doubleWidthCharacterSpan.getBoundingClientRect().width
    this.measurements.halfWidthCharacterWidth = this.refs.halfWidthCharacterSpan.getBoundingClientRect().width
    this.measurements.koreanCharacterWidth = this.refs.koreanCharacterSpan.getBoundingClientRect().widt
  }

  measureLongestLineWidth (screenLine) {
    this.measurements.scrollWidth = this.lineNodesByScreenLine.get(screenLine).firstChild.offsetWidth
  }

  measureGutterDimensions () {
    this.measurements.lineNumberGutterWidth = this.refs.lineNumberGutter.offsetWidth
  }

  requestHorizontalMeasurement (row, column) {
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

      const screenLine = this.getModel().displayLayer.getScreenLine(row)
      const lineNode = this.lineNodesByScreenLine.get(screenLine)
      const textNodes = this.textNodesByScreenLine.get(screenLine)
      let positionsForLine = this.horizontalPixelPositionsByScreenLine.get(screenLine)
      if (positionsForLine == null) {
        positionsForLine = new Map()
        this.horizontalPixelPositionsByScreenLine.set(screenLine, positionsForLine)
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
        if (positions.has(nextColumnToMeasure)) continue columnLoop
        const textNode = textNodes[textNodesIndex]
        const textNodeEndColumn = textNodeStartColumn + textNode.textContent.length

        if (nextColumnToMeasure <= textNodeEndColumn) {
          let clientPixelPosition
          if (nextColumnToMeasure === textNodeStartColumn) {
            const range = getRangeForMeasurement()
            range.setStart(textNode, 0)
            range.setEnd(textNode, 1)
            clientPixelPosition = range.getBoundingClientRect().left
          } else {
            const range = getRangeForMeasurement()
            range.setStart(textNode, 0)
            range.setEnd(textNode, nextColumnToMeasure - textNodeStartColumn)
            clientPixelPosition = range.getBoundingClientRect().right
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

  pixelTopForScreenRow (row) {
    return row * this.measurements.lineHeight
  }

  pixelLeftForScreenRowAndColumn (row, column) {
    const screenLine = this.getModel().displayLayer.getScreenLine(row)
    return this.horizontalPixelPositionsByScreenLine.get(screenLine).get(column)
  }

  getModel () {
    if (!this.props.model) {
      const TextEditor = require('./text-editor')
      this.props.model = new TextEditor()
      this.observeModel()
    }
    return this.props.model
  }

  observeModel () {
    const {model} = this.props
    this.disposables.add(model.selectionsMarkerLayer.onDidUpdate(this.scheduleUpdate.bind(this)))
  }

  isVisible () {
    return this.element.offsetWidth > 0 || this.element.offsetHeight > 0
  }

  getBaseCharacterWidth () {
    return this.measurements ? this.measurements.baseCharacterWidth : null
  }

  getScrollTop () {
    return this.measurements ? this.measurements.scrollTop : null
  }

  getScrollLeft () {
    return this.measurements ? this.measurements.scrollLeft : null
  }

  getRowsPerTile () {
    return this.props.rowsPerTile || DEFAULT_ROWS_PER_TILE
  }

  getTileStartRow (row) {
    return row - (row % this.getRowsPerTile())
  }

  getVisibleTileCount () {
    return Math.floor((this.getLastVisibleRow() - this.getFirstVisibleRow()) / this.getRowsPerTile()) + 2
  }

  getFirstTileStartRow () {
    return this.getTileStartRow(this.getFirstVisibleRow())
  }

  getLastTileStartRow () {
    return this.getFirstTileStartRow() + ((this.getVisibleTileCount() - 1) * this.getRowsPerTile())
  }

  getRenderedStartRow () {
    return this.getFirstTileStartRow()
  }

  getRenderedEndRow () {
    return this.getFirstTileStartRow() + this.getVisibleTileCount() * this.getRowsPerTile()
  }

  getFirstVisibleRow () {
    const {scrollTop, lineHeight} = this.measurements
    return Math.floor(scrollTop / lineHeight)
  }

  getLastVisibleRow () {
    const {scrollTop, scrollerHeight, lineHeight} = this.measurements
    return Math.min(
      this.getModel().getApproximateScreenLineCount() - 1,
      this.getFirstVisibleRow() + Math.ceil(scrollerHeight / lineHeight)
    )
  }

  topPixelPositionForRow (row) {
    return row * this.measurements.lineHeight
  }

  getScrollHeight () {
    return this.getModel().getApproximateScreenLineCount() * this.measurements.lineHeight
  }

  getLongestScreenLine () {
    const model = this.getModel()
    // Ensure the spatial index is populated with rows that are currently
    // visible so we *at least* get the longest row in the visible range.
    const renderedEndRow = this.getTileStartRow(this.getLastVisibleRow()) + this.getRowsPerTile()
    model.displayLayer.populateSpatialIndexIfNeeded(Infinity, renderedEndRow)
    return model.screenLineForScreenRow(model.getApproximateLongestScreenRow())
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

class LineComponent {
  constructor ({displayLayer, screenLine, lineNodesByScreenLine, textNodesByScreenLine}) {
    this.element = document.createElement('div')
    this.element.classList.add('line')
    lineNodesByScreenLine.set(screenLine, this.element)

    const textNodes = []
    textNodesByScreenLine.set(screenLine, textNodes)

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
      const textNode = document.createTextNode(ZERO_WIDTH_NBSP)
      this.element.appendChild(textNode)
      textNodes.push(textNode)
    }
  }

  update () {}
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
function getRangeForMeasurement () {
  if (!rangeForMeasurement) rangeForMeasurement = document.createRange()
  return rangeForMeasurement
}
