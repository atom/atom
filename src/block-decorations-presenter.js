/** @babel */

const {CompositeDisposable, Emitter} = require('event-kit')
const LineTopIndex = require('./linear-line-top-index')

module.exports =
class BlockDecorationsPresenter {
  constructor (model) {
    this.model = model
    this.disposables = new CompositeDisposable()
    this.emitter = new Emitter()
    this.firstUpdate = true
    this.lineTopIndex = new LineTopIndex
    this.blocksByDecoration = new Map
    this.decorationsByBlock = new Map
    this.observedDecorations = new Set

    this.observeModel()
  }

  destroy () {
    this.disposables.dispose()
  }

  onDidUpdateState (callback) {
    return this.emitter.on("did-update-state", callback)
  }

  setLineHeight (lineHeight) {
    this.lineTopIndex.setDefaultLineHeight(lineHeight)
  }

  observeModel () {
    this.lineTopIndex.setMaxRow(this.model.getScreenLineCount())
    this.lineTopIndex.setDefaultLineHeight(this.model.getLineHeightInPixels())
    this.disposables.add(this.model.onDidAddDecoration((decoration) => {
      this.observeDecoration(decoration)
    }))
    this.disposables.add(this.model.onDidChange(({start, end, screenDelta}) => {
      let oldExtent = end - start
      let newExtent = Math.max(0, end - start + screenDelta)
      this.lineTopIndex.splice(start, oldExtent, newExtent)
    }))
  }

  update () {
    if (this.firstUpdate) {
      this.fullUpdate()
      this.firstUpdate = false
    } else {
      this.incrementalUpdate()
    }
  }

  fullUpdate () {
    for (let decoration of this.model.getDecorations({type: "block"})) {
      this.observeDecoration(decoration)
    }
  }

  incrementalUpdate () {
  }

  setDimensionsForDecoration (decoration, width, height) {
    let block = this.blocksByDecoration.get(decoration)
    if (block) {
      this.lineTopIndex.resizeBlock(block, height)
    } else {
      this.observeDecoration(decoration)
      block = this.blocksByDecoration.get(decoration)
      this.lineTopIndex.resizeBlock(block, height)
    }

    this.emitter.emit("did-update-state")
  }

  heightForScreenRow (screenRow) {
    return this.lineTopIndex.bottomPixelPositionForRow(screenRow) - this.lineTopIndex.topPixelPositionForRow(screenRow)
  }

  decorationsForScreenRow (screenRow) {
    let blocks = this.lineTopIndex.allBlocks().filter((block) => block.row == screenRow)
    return blocks.map((block) => this.decorationsByBlock.get(block.id)).filter((decoration) => decoration)
  }

  getAllDecorationsByScreenRow () {
    let blocks = this.lineTopIndex.allBlocks()
    let decorationsByScreenRow = new Map
    for (let block of blocks) {
      let decoration = this.decorationsByBlock.get(block.id)
      if (decoration) {
        let decorations = decorationsByScreenRow.get(block.row) || []
        decorations.push(decoration)
        decorationsByScreenRow.set(block.row, decorations)
      }
    }

    return decorationsByScreenRow
  }

  observeDecoration (decoration) {
    if (!decoration.isType("block") || this.observedDecorations.has(decoration)) {
      return
    }

    // TODO: change this with a "on manual did change" event.
    let didMoveDisposable = decoration.getMarker().onDidChange((markerEvent) => {
      this.didMoveDecoration(decoration, markerEvent)
    })

    let didDestroyDisposable = decoration.onDidDestroy(() => {
      didMoveDisposable.dispose()
      didDestroyDisposable.dispose()
      this.observedDecorations.delete(decoration)
      this.didDestroyDecoration(decoration)
    })

    this.didAddDecoration(decoration)
    this.observedDecorations.add(decoration)
  }

  didAddDecoration (decoration) {
    let screenRow = decoration.getMarker().getHeadScreenPosition().row
    let block = this.lineTopIndex.insertBlock(screenRow, 0)
    this.decorationsByBlock.set(block, decoration)
    this.blocksByDecoration.set(decoration, block)
    this.emitter.emit("did-update-state")
  }

  didMoveDecoration (decoration, {oldHeadScreenPosition, newHeadScreenPosition}) {
    let block = this.blocksByDecoration.get(decoration)
    let newScreenRow = decoration.getMarker().getHeadScreenPosition().row
    this.lineTopIndex.moveBlock(block, newScreenRow)
    this.emitter.emit("did-update-state")
  }

  didDestroyDecoration (decoration) {
    let block = this.blocksByDecoration.get(decoration)
    if (block) {
      this.lineTopIndex.removeBlock(block)
      this.blocksByDecoration.delete(decoration)
      this.decorationsByBlock.delete(block)
    }
    this.emitter.emit("did-update-state")
  }
}
