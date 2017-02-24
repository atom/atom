const etch = require('etch')
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
    etch.updateSync(this)

    resizeDetector.listenTo(this.element, this.didResize.bind(this))
  }

  update (props) {
    this.props = props
    this.scheduleUpdate()
  }

  scheduleUpdate () {
    if (this.updatedSynchronously) {
      this.updateSync()
    } else {
      etch.getScheduler().updateDocument(() => {
        this.updateSync()
      })
    }
  }

  updateSync () {
    if (this.nextUpdatePromise) {
      this.resolveNextUpdatePromise()
      this.nextUpdatePromise = null
      this.resolveNextUpdatePromise = null
    }

    if (this.staleMeasurements.editorDimensions) this.measureEditorDimensions()

    const longestLine = this.getLongestScreenLine()
    if (longestLine !== this.previousLongestLine) {
      this.longestLineToMeasure = longestLine
      etch.updateSync(this)
      this.measureLongestLineWidth()
      this.previousLongestLine = longestLine
      etch.updateSync(this)
    } else {
      etch.updateSync(this)
    }
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
          this.renderLines()
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
      const firstTileStartRow = this.getTileStartRow(firstVisibleRow)
      const visibleTileCount = Math.floor((lastVisibleRow - this.getFirstVisibleRow()) / this.getRowsPerTile()) + 2
      const lastTileStartRow = firstTileStartRow + ((visibleTileCount - 1) * this.getRowsPerTile())

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

  renderLines () {
    let children
    let style = {
      contain: 'strict',
      overflow: 'hidden'
    }
    if (this.measurements) {
      style.width = this.measurements.scrollWidth + 'px',
      style.height = this.getScrollHeight() + 'px'
      children = this.renderLineTiles()
    } else {
      children = $.div({ref: 'characterMeasurementLine', className: 'line'},
        $.span({ref: 'normalWidthCharacterSpan'}, NORMAL_WIDTH_CHARACTER),
        $.span({ref: 'doubleWidthCharacterSpan'}, DOUBLE_WIDTH_CHARACTER),
        $.span({ref: 'halfWidthCharacterSpan'}, HALF_WIDTH_CHARACTER),
        $.span({ref: 'koreanCharacterSpan'}, KOREAN_CHARACTER)
      )
    }

    return $.div({ref: 'lines', className: 'lines', style}, children)
  }

  renderLineTiles () {
    if (!this.measurements) return []

    const firstTileStartRow = this.getTileStartRow(this.getFirstVisibleRow())
    const visibleTileCount = Math.floor((this.getLastVisibleRow() - this.getFirstVisibleRow()) / this.getRowsPerTile()) + 2
    const lastTileStartRow = firstTileStartRow + ((visibleTileCount - 1) * this.getRowsPerTile())

    const displayLayer = this.getModel().displayLayer
    const screenLines = displayLayer.getScreenLines(firstTileStartRow, lastTileStartRow + this.getRowsPerTile())

    let tileNodes = new Array(visibleTileCount)
    for (let tileStartRow = firstTileStartRow; tileStartRow <= lastTileStartRow; tileStartRow += this.getRowsPerTile()) {
      const tileEndRow = tileStartRow + this.getRowsPerTile()
      const lineNodes = []
      for (let row = tileStartRow; row < tileEndRow; row++) {
        const screenLine = screenLines[row - firstTileStartRow]
        if (!screenLine) break

        const lineProps = {key: screenLine.id, displayLayer, screenLine}
        if (screenLine === this.longestLineToMeasure) {
          lineProps.ref = 'longestLineToMeasure'
          this.longestLineToMeasure = null
        }
        lineNodes.push($(LineComponent, lineProps))
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
        ref: 'longestLineToMeasure',
        key: this.longestLineToMeasure.id,
        displayLayer,
        screenLine: this.longestLineToMeasure
      }))
      this.longestLineToMeasure = null
    }

    return tileNodes
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
    this.getModel().setVisible(true)
    if (!this.measurements) this.performInitialMeasurements()
    this.updateSync()
  }

  didHide () {
    this.getModel().setVisible(false)
  }

  didScroll () {
    this.measureScrollPosition()
    this.updateSync()
  }

  didResize () {
    this.measureEditorDimensions()
    this.scheduleUpdate()
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
    this.measurements.scrollerHeight = this.refs.scroller.offsetHeight
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

  measureLongestLineWidth () {
    this.measurements.scrollWidth = this.refs.longestLineToMeasure.element.firstChild.offsetWidth
  }

  measureGutterDimensions () {
    this.measurements.lineNumberGutterWidth = this.refs.lineNumberGutter.offsetWidth
  }

  getModel () {
    if (!this.props.model) {
      const TextEditor = require('./text-editor')
      this.props.model = new TextEditor()
    }
    return this.props.model
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
  constructor ({displayLayer, screenLine}) {
    const {lineText, tagCodes} = screenLine
    this.element = document.createElement('div')
    this.element.classList.add('line')

    const textNodes = []
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

    // this.textNodesByLineId[id] = textNodes
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
