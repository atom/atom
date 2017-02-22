const etch = require('etch')
const $ = etch.dom
const TextEditorElement = require('./text-editor-element')

const ROWS_PER_TILE = 6
const NORMAL_WIDTH_CHARACTER = 'x'
const DOUBLE_WIDTH_CHARACTER = '我'
const HALF_WIDTH_CHARACTER = 'ﾊ'
const KOREAN_CHARACTER = '세'

const characterMeasurementSpans = {}
const characterMeasurementLineNode = etch.render($.div({className: 'line'},
  $.span({ref: 'normalWidthCharacterSpan'}, NORMAL_WIDTH_CHARACTER),
  $.span({ref: 'doubleWidthCharacterSpan'}, DOUBLE_WIDTH_CHARACTER),
  $.span({ref: 'halfWidthCharacterSpan'}, HALF_WIDTH_CHARACTER),
  $.span({ref: 'koreanCharacterSpan'}, KOREAN_CHARACTER)
), {refs: characterMeasurementSpans})

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
  }

  update (props) {
  }

  updateSync () {
    etch.updateSync(this)
  }

  render () {
    let style
    if (!this.getModel().getAutoHeight() && !this.getModel().getAutoWidth()) {
      style = {contain: 'strict'}
    }

    return $('atom-text-editor', {style},
      $.div({ref: 'scroller', onScroll: this.didScroll, className: 'scroll-view'},
        // $.div({
        //   style: {
        //     width: 'max-content',
        //     height: 'max-content',
        //     backgroundColor: 'inherit'
        //   }
        // },
          // this.renderGutterContainer(),
          this.renderLines()
        // )
      )
    )
  }

  renderGutterContainer () {
    return $.div({className: 'gutter-container'},
      this.measurements ? this.renderLineNumberGutter() : []
    )
  }

  renderLineNumberGutter () {
    const maxLineNumberDigits = Math.max(2, this.getModel().getLineCount().toString().length)

    const firstTileStartRow = this.getTileStartRow(this.getFirstVisibleRow())
    const lastTileStartRow = this.getTileStartRow(this.getLastVisibleRow())

    let tileNodes = []

    let currentTileStaticTop = 0
    let previousBufferRow = (firstTileStartRow > 0) ? this.getModel().bufferRowForScreenRow(firstTileStartRow - 1) : -1
    for (let tileStartRow = firstTileStartRow; tileStartRow <= lastTileStartRow; tileStartRow += ROWS_PER_TILE) {
      const currentTileEndRow = tileStartRow + ROWS_PER_TILE
      const lineNumberNodes = []

      for (let row = tileStartRow; row < currentTileEndRow; row++) {
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
        lineNumber = '\u00a0'.repeat(maxLineNumberDigits - lineNumber.length) + lineNumber

        lineNumberNodes.push($.div({className},
          lineNumber,
          $.div({className: 'icon-right'})
        ))

        previousBufferRow = bufferRow
      }

      const tileHeight = ROWS_PER_TILE * this.measurements.lineHeight
      const yTranslation = this.topPixelPositionForRow(tileStartRow) - currentTileStaticTop

      tileNodes.push($.div({
        style: {
          height: tileHeight + 'px',
          width: 'max-content',
          willChange: 'transform',
          transform: `translate3d(0, ${yTranslation}px, 0)`,
          backgroundColor: 'inherit',
          overflow: 'hidden'
        }
      }, lineNumberNodes))

      currentTileStaticTop += tileHeight
    }

    return $.div({className: 'gutter line-numbers', 'gutter-name': 'line-number'}, tileNodes)
  }

  renderLines () {
    const style = (this.measurements)
      ? {
        width: this.measurements.scrollWidth + 'px',
        height: this.getScrollHeight() + 'px'
      } : null

    return $.div({ref: 'lines', className: 'lines', style}, this.renderLineTiles())
  }

  renderLineTiles () {
    if (!this.measurements) return []

    const firstTileStartRow = this.getTileStartRow(this.getFirstVisibleRow())
    const visibleTileCount = Math.floor((this.getLastVisibleRow() - this.getFirstVisibleRow()) / ROWS_PER_TILE) + 2
    const lastTileStartRow = firstTileStartRow + ((visibleTileCount - 1) * ROWS_PER_TILE)

    const displayLayer = this.getModel().displayLayer
    const screenLines = displayLayer.getScreenLines(firstTileStartRow, lastTileStartRow + ROWS_PER_TILE)

    let tileNodes = new Array(visibleTileCount)
    for (let tileStartRow = firstTileStartRow; tileStartRow <= lastTileStartRow; tileStartRow += ROWS_PER_TILE) {
      const tileEndRow = tileStartRow + ROWS_PER_TILE
      const lineNodes = []
      for (let row = tileStartRow; row < tileEndRow; row++) {
        const screenLine = screenLines[row - firstTileStartRow]
        if (!screenLine) break
        lineNodes.push($(LineComponent, {key: screenLine.id, displayLayer, screenLine}))
      }

      const tileHeight = ROWS_PER_TILE * this.measurements.lineHeight
      const tileIndex = (tileStartRow / ROWS_PER_TILE) % visibleTileCount

      tileNodes[tileIndex] = $.div({
        key: tileIndex,
        dataset: {key: tileIndex},
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
    etch.updateSync(this)
  }

  didHide () {
    this.getModel().setVisible(false)
  }

  didScroll () {
    this.measureScrollPosition()
    this.updateSync()
  }

  performInitialMeasurements () {
    this.measurements = {}
    this.measureEditorDimensions()
    this.measureScrollPosition()
    this.measureCharacterDimensions()
    this.measureLongestLineWidth()
  }

  measureEditorDimensions () {
    this.measurements.scrollerHeight = this.refs.scroller.offsetHeight
  }

  measureScrollPosition () {
    this.measurements.scrollTop = this.refs.scroller.scrollTop
    this.measurements.scrollLeft = this.refs.scroller.scrollLeft
  }

  measureCharacterDimensions () {
    this.refs.lines.appendChild(characterMeasurementLineNode)
    this.measurements.lineHeight = characterMeasurementLineNode.getBoundingClientRect().height
    this.measurements.baseCharacterWidth = characterMeasurementSpans.normalWidthCharacterSpan.getBoundingClientRect().width
    this.measurements.doubleWidthCharacterWidth = characterMeasurementSpans.doubleWidthCharacterSpan.getBoundingClientRect().width
    this.measurements.halfWidthCharacterWidth = characterMeasurementSpans.halfWidthCharacterSpan.getBoundingClientRect().width
    this.measurements.koreanCharacterWidth = characterMeasurementSpans.koreanCharacterSpan.getBoundingClientRect().widt
    this.refs.lines.removeChild(characterMeasurementLineNode)
  }

  measureLongestLineWidth () {
    const displayLayer = this.getModel().displayLayer
    const rightmostPosition = displayLayer.getRightmostScreenPosition()
    this.measurements.scrollWidth = rightmostPosition.column * this.measurements.baseCharacterWidth
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

  getTileStartRow (row) {
    return row - (row % ROWS_PER_TILE)
  }

  getFirstVisibleRow () {
    const {scrollTop, lineHeight} = this.measurements
    return Math.floor(scrollTop / lineHeight)
  }

  getLastVisibleRow () {
    const {scrollTop, scrollerHeight, lineHeight} = this.measurements
    return this.getFirstVisibleRow() + Math.ceil(scrollerHeight / lineHeight)
  }

  topPixelPositionForRow (row) {
    return row * this.measurements.lineHeight
  }

  getScrollHeight () {
    return this.getModel().getApproximateScreenLineCount() * this.measurements.lineHeight
  }
}

class LineComponent {
  constructor ({displayLayer, screenLine}) {
    const {lineText, tagCodes} = screenLine
    this.element = document.createElement('div')
    this.element.classList.add('line')

    const textNodes = []
    let startIndex = 0
    let openScopeNode = this.element
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
