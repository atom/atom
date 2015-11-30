/** @babel */

const {Emitter} = require('event-kit')

module.exports =
class BlockDecorationsPresenter {
  constructor (model) {
    this.model = model
    this.emitter = new Emitter()
    this.blockDecorationsDimensionsById = new Map
    this.blockDecorationsByScreenRow = new Map
    this.heightsByScreenRow = new Map
  }

  onDidUpdateState (callback) {
    return this.emitter.on('did-update-state', callback)
  }

  update () {
    this.heightsByScreenRow.clear()
    this.blockDecorationsByScreenRow.clear()
    let blockDecorations = new Map

    // TODO: move into DisplayBuffer
    for (let decoration of this.model.getDecorations({type: "block"})) {
      blockDecorations.set(decoration.id, decoration)
    }

    for (let [decorationId] of this.blockDecorationsDimensionsById) {
      if (!blockDecorations.has(decorationId)) {
        this.blockDecorationsDimensionsById.delete(decorationId)
      }
    }

    for (let [decorationId, decoration] of blockDecorations) {
      let screenRow = decoration.getMarker().getHeadScreenPosition().row
      this.addBlockDecorationToScreenRow(screenRow, decoration)
      if (this.hasMeasuredBlockDecoration(decoration)) {
        this.addHeightToScreenRow(
          screenRow,
          this.blockDecorationsDimensionsById.get(decorationId).height
        )
      }
    }
  }

  setBlockDecorationDimensions (decoration, width, height) {
    this.blockDecorationsDimensionsById.set(decoration.id, {width, height})
    this.emitter.emit('did-update-state')
  }

  blockDecorationsHeightForScreenRow (screenRow) {
    return Number(this.heightsByScreenRow.get(screenRow)) || 0
  }

  addHeightToScreenRow (screenRow, height) {
    let previousHeight = this.blockDecorationsHeightForScreenRow(screenRow)
    let newHeight = previousHeight + height
    this.heightsByScreenRow.set(screenRow, newHeight)
  }

  addBlockDecorationToScreenRow (screenRow, decoration) {
    let decorations = this.blockDecorationsForScreenRow(screenRow) || []
    decorations.push(decoration)
    this.blockDecorationsByScreenRow.set(screenRow, decorations)
  }

  blockDecorationsForScreenRow (screenRow) {
    return this.blockDecorationsByScreenRow.get(screenRow)
  }

  hasMeasuredBlockDecoration (decoration) {
    return this.blockDecorationsDimensionsById.has(decoration.id)
  }
}
