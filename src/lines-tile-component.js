const HighlightsComponent = require('./highlights-component')
const ZERO_WIDTH_NBSP = '\ufeff'

module.exports = class LinesTileComponent {
  constructor ({presenter, id, domElementPool, assert, views}) {
    this.id = id
    this.presenter = presenter
    this.views = views
    this.domElementPool = domElementPool
    this.assert = assert
    this.lineNodesByLineId = {}
    this.screenRowsByLineId = {}
    this.lineIdsByScreenRow = {}
    this.textNodesByLineId = {}
    this.blockDecorationNodesByLineIdAndDecorationId = {}
    this.domNode = this.domElementPool.buildElement('div')
    this.domNode.style.position = 'absolute'
    this.domNode.style.display = 'block'
    this.domNode.style.backgroundColor = 'inherit'
    this.highlightsComponent = new HighlightsComponent(this.domElementPool)
    this.domNode.appendChild(this.highlightsComponent.getDomNode())
  }

  destroy () {
    this.removeLineNodes()
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

  removeLineNode (lineId) {
    this.domElementPool.freeElementAndDescendants(this.lineNodesByLineId[lineId])
    for (const decorationId of Object.keys(this.oldTileState.lines[lineId].precedingBlockDecorations)) {
      const {topRulerNode, blockDecorationNode, bottomRulerNode} =
        this.blockDecorationNodesByLineIdAndDecorationId[lineId][decorationId]
      topRulerNode.remove()
      blockDecorationNode.remove()
      bottomRulerNode.remove()
    }
    for (const decorationId of Object.keys(this.oldTileState.lines[lineId].followingBlockDecorations)) {
      const {topRulerNode, blockDecorationNode, bottomRulerNode} =
        this.blockDecorationNodesByLineIdAndDecorationId[lineId][decorationId]
      topRulerNode.remove()
      blockDecorationNode.remove()
      bottomRulerNode.remove()
    }

    delete this.blockDecorationNodesByLineIdAndDecorationId[lineId]
    delete this.lineNodesByLineId[lineId]
    delete this.textNodesByLineId[lineId]
    delete this.lineIdsByScreenRow[this.screenRowsByLineId[lineId]]
    delete this.screenRowsByLineId[lineId]
    delete this.oldTileState.lines[lineId]
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
        // Avoid assigning state for block decorations, because we need to
        // process it later when updating the DOM.
        this.oldTileState.lines[id].precedingBlockDecorations = {}
        this.oldTileState.lines[id].followingBlockDecorations = {}
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
      // Insert a zero-width non-breaking whitespace, so that LinesYardstick can
      // take the fold-marker::after pseudo-element into account during
      // measurements when such marker is the last character on the line.
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

    if (newLineState.screenRow !== oldLineState.screenRow) {
      lineNode.dataset.screenRow = newLineState.screenRow
      this.lineIdsByScreenRow[newLineState.screenRow] = id
      this.screenRowsByLineId[id] = newLineState.screenRow
    }

    oldLineState.screenRow = newLineState.screenRow
  }

  removeDeletedBlockDecorations () {
    for (const lineId of Object.keys(this.newTileState.lines)) {
      const oldLineState = this.oldTileState.lines[lineId]
      const newLineState = this.newTileState.lines[lineId]
      for (const decorationId of Object.keys(oldLineState.precedingBlockDecorations)) {
        if (!newLineState.precedingBlockDecorations.hasOwnProperty(decorationId)) {
          const {topRulerNode, blockDecorationNode, bottomRulerNode} =
            this.blockDecorationNodesByLineIdAndDecorationId[lineId][decorationId]
          topRulerNode.remove()
          blockDecorationNode.remove()
          bottomRulerNode.remove()
          delete this.blockDecorationNodesByLineIdAndDecorationId[lineId][decorationId]
          delete oldLineState.precedingBlockDecorations[decorationId]
        }
      }
      for (const decorationId of Object.keys(oldLineState.followingBlockDecorations)) {
        if (!newLineState.followingBlockDecorations.hasOwnProperty(decorationId)) {
          const {topRulerNode, blockDecorationNode, bottomRulerNode} =
            this.blockDecorationNodesByLineIdAndDecorationId[lineId][decorationId]
          topRulerNode.remove()
          blockDecorationNode.remove()
          bottomRulerNode.remove()
          delete this.blockDecorationNodesByLineIdAndDecorationId[lineId][decorationId]
          delete oldLineState.followingBlockDecorations[decorationId]
        }
      }
    }
  }

  updateBlockDecorations () {
    for (const lineId of Object.keys(this.newTileState.lines)) {
      const oldLineState = this.oldTileState.lines[lineId]
      const newLineState = this.newTileState.lines[lineId]
      const lineNode = this.lineNodesByLineId[lineId]
      if (!this.blockDecorationNodesByLineIdAndDecorationId.hasOwnProperty(lineId)) {
        this.blockDecorationNodesByLineIdAndDecorationId[lineId] = {}
      }
      for (const decorationId of Object.keys(newLineState.precedingBlockDecorations)) {
        const oldBlockDecorationState = oldLineState.precedingBlockDecorations[decorationId]
        const newBlockDecorationState = newLineState.precedingBlockDecorations[decorationId]
        if (oldBlockDecorationState != null) {
          const {topRulerNode, blockDecorationNode, bottomRulerNode} =
            this.blockDecorationNodesByLineIdAndDecorationId[lineId][decorationId]
          if (oldBlockDecorationState.screenRow !== newBlockDecorationState.screenRow) {
            topRulerNode.remove()
            blockDecorationNode.remove()
            bottomRulerNode.remove()
            topRulerNode.dataset.screenRow = newBlockDecorationState.screenRow
            this.domNode.insertBefore(topRulerNode, lineNode)
            blockDecorationNode.dataset.screenRow = newBlockDecorationState.screenRow
            this.domNode.insertBefore(blockDecorationNode, lineNode)
            bottomRulerNode.dataset.screenRow = newBlockDecorationState.screenRow
            this.domNode.insertBefore(bottomRulerNode, lineNode)
          }
        } else {
          const topRulerNode = document.createElement('div')
          topRulerNode.dataset.screenRow = newBlockDecorationState.screenRow
          this.domNode.insertBefore(topRulerNode, lineNode)
          const blockDecorationNode = this.views.getView(newBlockDecorationState.decoration.getProperties().item)
          blockDecorationNode.dataset.screenRow = newBlockDecorationState.screenRow
          this.domNode.insertBefore(blockDecorationNode, lineNode)
          const bottomRulerNode = document.createElement('div')
          bottomRulerNode.dataset.screenRow = newBlockDecorationState.screenRow
          this.domNode.insertBefore(bottomRulerNode, lineNode)

          this.blockDecorationNodesByLineIdAndDecorationId[lineId][decorationId] =
            {topRulerNode, blockDecorationNode, bottomRulerNode}
        }
        oldLineState.precedingBlockDecorations[decorationId] = Object.assign({}, newBlockDecorationState)
      }
      for (const decorationId of Object.keys(newLineState.followingBlockDecorations)) {
        const oldBlockDecorationState = oldLineState.followingBlockDecorations[decorationId]
        const newBlockDecorationState = newLineState.followingBlockDecorations[decorationId]
        if (oldBlockDecorationState != null) {
          const {topRulerNode, blockDecorationNode, bottomRulerNode} =
            this.blockDecorationNodesByLineIdAndDecorationId[lineId][decorationId]
          if (oldBlockDecorationState.screenRow !== newBlockDecorationState.screenRow) {
            topRulerNode.remove()
            blockDecorationNode.remove()
            bottomRulerNode.remove()
            bottomRulerNode.dataset.screenRow = newBlockDecorationState.screenRow
            this.domNode.insertBefore(bottomRulerNode, lineNode.nextSibling)
            blockDecorationNode.dataset.screenRow = newBlockDecorationState.screenRow
            this.domNode.insertBefore(blockDecorationNode, lineNode.nextSibling)
            topRulerNode.dataset.screenRow = newBlockDecorationState.screenRow
            this.domNode.insertBefore(topRulerNode, lineNode.nextSibling)
          }
        } else {
          const bottomRulerNode = document.createElement('div')
          bottomRulerNode.dataset.screenRow = newBlockDecorationState.screenRow
          this.domNode.insertBefore(bottomRulerNode, lineNode.nextSibling)
          const blockDecorationNode = this.views.getView(newBlockDecorationState.decoration.getProperties().item)
          blockDecorationNode.dataset.screenRow = newBlockDecorationState.screenRow
          this.domNode.insertBefore(blockDecorationNode, lineNode.nextSibling)
          const topRulerNode = document.createElement('div')
          topRulerNode.dataset.screenRow = newBlockDecorationState.screenRow
          this.domNode.insertBefore(topRulerNode, lineNode.nextSibling)

          this.blockDecorationNodesByLineIdAndDecorationId[lineId][decorationId] =
            {topRulerNode, blockDecorationNode, bottomRulerNode}
        }
        oldLineState.followingBlockDecorations[decorationId] = Object.assign({}, newBlockDecorationState)
      }
    }
  }

  measureBlockDecorations () {
    for (const lineId of Object.keys(this.newTileState.lines)) {
      const newLineState = this.newTileState.lines[lineId]

      for (const decorationId of Object.keys(newLineState.precedingBlockDecorations)) {
        const {topRulerNode, blockDecorationNode, bottomRulerNode} =
          this.blockDecorationNodesByLineIdAndDecorationId[lineId][decorationId]
        const width = blockDecorationNode.offsetWidth
        const height = bottomRulerNode.offsetTop - topRulerNode.offsetTop
        const {decoration} = newLineState.precedingBlockDecorations[decorationId]
        this.presenter.setBlockDecorationDimensions(decoration, width, height)
      }
      for (const decorationId of Object.keys(newLineState.followingBlockDecorations)) {
        const {topRulerNode, blockDecorationNode, bottomRulerNode} =
          this.blockDecorationNodesByLineIdAndDecorationId[lineId][decorationId]
        const width = blockDecorationNode.offsetWidth
        const height = bottomRulerNode.offsetTop - topRulerNode.offsetTop
        const {decoration} = newLineState.followingBlockDecorations[decorationId]
        this.presenter.setBlockDecorationDimensions(decoration, width, height)
      }
    }
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
