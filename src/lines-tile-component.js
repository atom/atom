const HighlightsComponent = require('./highlights-component')
const ZERO_WIDTH_NBSP = '\ufeff'

module.exports = class LinesTileComponent {
  constructor ({presenter, id, domElementPool, assert}) {
    this.presenter = presenter
    this.id = id
    this.domElementPool = domElementPool
    this.assert = assert
    this.measuredLines = new Set()
    this.lineNodesByLineId = {}
    this.screenRowsByLineId = {}
    this.lineIdsByScreenRow = {}
    this.textNodesByLineId = {}
    this.insertionPointsBeforeLineById = {}
    this.insertionPointsAfterLineById = {}
    this.domNode = this.domElementPool.buildElement('div')
    this.domNode.style.position = 'absolute'
    this.domNode.style.display = 'block'
    this.highlightsComponent = new HighlightsComponent(this.domElementPool)
    this.domNode.appendChild(this.highlightsComponent.getDomNode())
  }

  destroy () {
    this.domElementPool.freeElementAndDescendants(this.domNode)
  }

  getDomNode () {
    return this.domNode
  }

  updateSync (state) {
    this.newState = state
    if (this.oldState == null) {
      this.oldState = {tiles: {}}
      this.oldState.tiles[this.id] = {lines: {}}
    }

    this.newTileState = this.newState.tiles[this.id]
    this.oldTileState = this.oldState.tiles[this.id]

    if (this.newState.backgroundColor !== this.oldState.backgroundColor) {
      this.domNode.style.backgroundColor = this.newState.backgroundColor
      this.oldState.backgroundColor = this.newState.backgroundColor
    }

    if (this.newTileState.zIndex !== this.oldTileState.zIndex) {
      this.domNode.style.zIndex = this.newTileState.zIndex
      this.oldTileState.zIndex = this.newTileState.zIndex
    }

    if (this.newTileState.display !== this.oldTileState.display) {
      this.domNode.style.display = this.newTileState.display
      this.oldTileState.display = this.newTileState.display
    }

    if (this.newTileState.height !== this.oldTileState.height) {
      this.domNode.style.height = this.newTileState.height + 'px'
      this.oldTileState.height = this.newTileState.height
    }

    if (this.newState.width !== this.oldState.width) {
      this.domNode.style.width = this.newState.width + 'px'
      this.oldState.width = this.newState.width
    }

    if (this.newTileState.top !== this.oldTileState.top || this.newTileState.left !== this.oldTileState.left) {
      this.domNode.style.transform = `translate3d(${this.newTileState.left}px, ${this.newTileState.top}px, 0px)`
      this.oldTileState.top = this.newTileState.top
      this.oldTileState.left = this.newTileState.left
    }

    this.updateLineNodes()
    this.highlightsComponent.updateSync(this.newTileState)
  }

  removeLineNodes () {
    for (const id of Object.keys(this.oldTileState.lines)) {
      this.removeLineNode(id)
    }
  }

  removeLineNode (id) {
    this.domElementPool.freeElementAndDescendants(this.lineNodesByLineId[id])
    this.removeBlockDecorationInsertionPointBeforeLine(id)
    this.removeBlockDecorationInsertionPointAfterLine(id)
    delete this.lineNodesByLineId[id]
    delete this.textNodesByLineId[id]
    delete this.lineIdsByScreenRow[this.screenRowsByLineId[id]]
    delete this.screenRowsByLineId[id]
    delete this.oldTileState.lines[id]
  }

  updateLineNodes () {
    for (const id of Object.keys(this.oldTileState.lines)) {
      if (!this.newTileState.lines.hasOwnProperty(id)) {
        this.removeLineNode(id)
      }
    }

    const newLineIds = []
    const newLineNodes = []
    for (const id of Object.keys(this.newTileState.lines)) {
      const lineState = this.newTileState.lines[id]
      if (this.oldTileState.lines.hasOwnProperty(id)) {
        this.updateLineNode(id)
      } else {
        newLineIds.push(id)
        newLineNodes.push(this.buildLineNode(id))
        this.screenRowsByLineId[id] = lineState.screenRow
        this.lineIdsByScreenRow[lineState.screenRow] = id
        this.oldTileState.lines[id] = Object.assign({}, lineState)
      }
    }

    while (newLineIds.length > 0) {
      const id = newLineIds.shift()
      const lineNode = newLineNodes.shift()
      this.lineNodesByLineId[id] = lineNode
      const nextNode = this.findNodeNextTo(lineNode)
      if (nextNode == null) {
        this.domNode.appendChild(lineNode)
      } else {
        this.domNode.insertBefore(lineNode, nextNode)
      }
      this.insertBlockDecorationInsertionPointBeforeLine(id)
      this.insertBlockDecorationInsertionPointAfterLine(id)
    }
  }

  removeBlockDecorationInsertionPointBeforeLine (id) {
    const insertionPoint = this.insertionPointsBeforeLineById[id]
    if (insertionPoint != null) {
      this.domElementPool.freeElementAndDescendants(insertionPoint)
      delete this.insertionPointsBeforeLineById[id]
    }
  }

  insertBlockDecorationInsertionPointBeforeLine (id) {
    const {hasPrecedingBlockDecorations, screenRow} = this.newTileState.lines[id]
    if (hasPrecedingBlockDecorations) {
      const lineNode = this.lineNodesByLineId[id]
      const insertionPoint = this.domElementPool.buildElement('content')
      this.domNode.insertBefore(insertionPoint, lineNode)
      this.insertionPointsBeforeLineById[id] = insertionPoint
      insertionPoint.dataset.screenRow = screenRow
      this.updateBlockDecorationInsertionPointBeforeLine(id)
    }
  }

  updateBlockDecorationInsertionPointBeforeLine (id) {
    const oldLineState = this.oldTileState.lines[id]
    const newLineState = this.newTileState.lines[id]
    const insertionPoint = this.insertionPointsBeforeLineById[id]
    if (insertionPoint != null) {
      if (newLineState.screenRow !== oldLineState.screenRow) {
        insertionPoint.dataset.screenRow = newLineState.screenRow
      }

      const precedingBlockDecorationsSelector = newLineState.precedingBlockDecorations
        .map((d) => `.atom--block-decoration-${d.id}`)
        .join(',')
      if (precedingBlockDecorationsSelector !== oldLineState.precedingBlockDecorationsSelector) {
        insertionPoint.setAttribute('select', precedingBlockDecorationsSelector)
        oldLineState.precedingBlockDecorationsSelector = precedingBlockDecorationsSelector
      }
    }
  }

  removeBlockDecorationInsertionPointAfterLine (id) {
    const insertionPoint = this.insertionPointsAfterLineById[id]
    if (insertionPoint != null) {
      this.domElementPool.freeElementAndDescendants(insertionPoint)
      delete this.insertionPointsAfterLineById[id]
    }
  }

  insertBlockDecorationInsertionPointAfterLine (id) {
    const {hasFollowingBlockDecorations, screenRow} = this.newTileState.lines[id]
    if (hasFollowingBlockDecorations) {
      const lineNode = this.lineNodesByLineId[id]
      const insertionPoint = this.domElementPool.buildElement('content')
      this.domNode.insertBefore(insertionPoint, lineNode.nextSibling)
      this.insertionPointsAfterLineById[id] = insertionPoint
      insertionPoint.dataset.screenRow = screenRow
      this.updateBlockDecorationInsertionPointAfterLine(id)
    }
  }

  updateBlockDecorationInsertionPointAfterLine (id) {
    const oldLineState = this.oldTileState.lines[id]
    const newLineState = this.newTileState.lines[id]
    const insertionPoint = this.insertionPointsAfterLineById[id]

    if (insertionPoint != null) {
      if (newLineState.screenRow !== oldLineState.screenRow) {
        insertionPoint.dataset.screenRow = newLineState.screenRow
      }

      const followingBlockDecorationsSelector = newLineState.followingBlockDecorations
        .map((d) => `.atom--block-decoration-${d.id}`)
        .join(',')
      if (followingBlockDecorationsSelector !== oldLineState.followingBlockDecorationsSelector) {
        insertionPoint.setAttribute('select', followingBlockDecorationsSelector)
        oldLineState.followingBlockDecorationsSelector = followingBlockDecorationsSelector
      }
    }
  }

  findNodeNextTo (node) {
    let i = 1 // skip highlights node
    while (i < this.domNode.children.length) {
      const nextNode = this.domNode.children[i]
      if (this.screenRowForNode(node) < this.screenRowForNode(nextNode)) {
        return nextNode
      }
      i++
    }
    return null
  }

  screenRowForNode (node) {
    return parseInt(node.dataset.screenRow)
  }

  buildLineNode (id) {
    const {lineText, tagCodes, screenRow, decorationClasses} = this.newTileState.lines[id]

    const lineNode = this.domElementPool.buildElement('div', 'line')
    lineNode.dataset.screenRow = screenRow
    if (decorationClasses != null) {
      for (const decorationClass of decorationClasses) {
        lineNode.classList.add(decorationClass)
      }
    }

    const textNodes = []
    let startIndex = 0
    let openScopeNode = lineNode
    for (const tagCode of tagCodes) {
      if (tagCode !== 0) {
        if (this.presenter.isCloseTagCode(tagCode)) {
          openScopeNode = openScopeNode.parentElement
        } else if (this.presenter.isOpenTagCode(tagCode)) {
          const scope = this.presenter.tagForCode(tagCode)
          const newScopeNode = this.domElementPool.buildElement('span', scope.replace(/\.+/g, ' '))
          openScopeNode.appendChild(newScopeNode)
          openScopeNode = newScopeNode
        } else {
          const textNode = this.domElementPool.buildText(lineText.substr(startIndex, tagCode))
          startIndex += tagCode
          openScopeNode.appendChild(textNode)
          textNodes.push(textNode)
        }
      }
    }

    if (startIndex === 0) {
      const textNode = this.domElementPool.buildText(' ')
      lineNode.appendChild(textNode)
      textNodes.push(textNode)
    }

    if (lineText.endsWith(this.presenter.displayLayer.foldCharacter)) {
      const textNode = this.domElementPool.buildText(ZERO_WIDTH_NBSP)
      lineNode.appendChild(textNode)
      textNodes.push(textNode)
    }

    this.textNodesByLineId[id] = textNodes
    return lineNode
  }

  updateLineNode (id) {
    const oldLineState = this.oldTileState.lines[id]
    const newLineState = this.newTileState.lines[id]
    const lineNode = this.lineNodesByLineId[id]
    const newDecorationClasses = newLineState.decorationClasses
    const oldDecorationClasses = oldLineState.decorationClasses

    if (oldDecorationClasses != null) {
      for (const decorationClass of oldDecorationClasses) {
        if (newDecorationClasses == null || !newDecorationClasses.includes(decorationClass)) {
          lineNode.classList.remove(decorationClass)
        }
      }
    }

    if (newDecorationClasses != null) {
      for (const decorationClass of newDecorationClasses) {
        if (oldDecorationClasses == null || !oldDecorationClasses.includes(decorationClass)) {
          lineNode.classList.add(decorationClass)
        }
      }
    }

    oldLineState.decorationClasses = newLineState.decorationClasses

    if (!oldLineState.hasPrecedingBlockDecorations && newLineState.hasPrecedingBlockDecorations) {
      this.insertBlockDecorationInsertionPointBeforeLine(id)
    } else if (oldLineState.hasPrecedingBlockDecorations && !newLineState.hasPrecedingBlockDecorations) {
      this.removeBlockDecorationInsertionPointBeforeLine(id)
    }

    if (!oldLineState.hasFollowingBlockDecorations && newLineState.hasFollowingBlockDecorations) {
      this.insertBlockDecorationInsertionPointAfterLine(id)
    } else if (oldLineState.hasFollowingBlockDecorations && !newLineState.hasFollowingBlockDecorations) {
      this.removeBlockDecorationInsertionPointAfterLine(id)
    }

    if (newLineState.screenRow !== oldLineState.screenRow) {
      lineNode.dataset.screenRow = newLineState.screenRow
      this.lineIdsByScreenRow[newLineState.screenRow] = id
      this.screenRowsByLineId[id] = newLineState.screenRow
    }

    this.updateBlockDecorationInsertionPointBeforeLine(id)
    this.updateBlockDecorationInsertionPointAfterLine(id)
    oldLineState.screenRow = newLineState.screenRow
    oldLineState.hasPrecedingBlockDecorations = newLineState.hasPrecedingBlockDecorations
    oldLineState.hasFollowingBlockDecorations = newLineState.hasFollowingBlockDecorations
  }

  lineNodeForScreenRow (screenRow) {
    return this.lineNodesByLineId[this.lineIdsByScreenRow[screenRow]]
  }

  lineNodeForLineId (lineId) {
    return this.lineNodesByLineId[lineId]
  }

  textNodesForLineId (lineId) {
    return this.textNodesByLineId[lineId].slice()
  }

  lineIdForScreenRow (screenRow) {
    return this.lineIdsByScreenRow[screenRow]
  }

  textNodesForScreenRow (screenRow) {
    const textNodes = this.textNodesByLineId[this.lineIdsByScreenRow[screenRow]]
    if (textNodes == null) {
      return null
    } else {
      return textNodes.slice()
    }
  }
}
