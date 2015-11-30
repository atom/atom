/** @babel */

const {Emitter} = require('event-kit')

module.exports =
class BlockDecorationsPresenter {
  constructor (model) {
    this.model = model
    this.emitter = new Emitter()
    this.dimensionsByDecorationId = new Map
    this.decorationsByScreenRow = new Map
    this.heightsByScreenRow = new Map
  }

  onDidUpdateState (callback) {
    return this.emitter.on('did-update-state', callback)
  }

  update () {
    this.heightsByScreenRow.clear()
    this.decorationsByScreenRow.clear()
    let decorations = new Map

    // TODO: move into DisplayBuffer
    for (let decoration of this.model.getDecorations({type: "block"})) {
      decorations.set(decoration.id, decoration)
    }

    for (let [decorationId] of this.dimensionsByDecorationId) {
      if (!decorations.has(decorationId)) {
        this.dimensionsByDecorationId.delete(decorationId)
      }
    }

    for (let [decorationId, decoration] of decorations) {
      let screenRow = decoration.getMarker().getHeadScreenPosition().row
      this.addDecorationToScreenRow(screenRow, decoration)
      if (this.hasMeasurementsForDecoration(decoration)) {
        this.addHeightToScreenRow(
          screenRow,
          this.dimensionsByDecorationId.get(decorationId).height
        )
      }
    }
  }

  setDimensionsForDecoration (decoration, width, height) {
    this.dimensionsByDecorationId.set(decoration.id, {width, height})
    this.emitter.emit('did-update-state')
  }

  heightForScreenRow (screenRow) {
    return Number(this.heightsByScreenRow.get(screenRow)) || 0
  }

  addHeightToScreenRow (screenRow, height) {
    let previousHeight = this.heightForScreenRow(screenRow)
    let newHeight = previousHeight + height
    this.heightsByScreenRow.set(screenRow, newHeight)
  }

  addDecorationToScreenRow (screenRow, decoration) {
    let decorations = this.getDecorationsByScreenRow(screenRow) || []
    decorations.push(decoration)
    this.decorationsByScreenRow.set(screenRow, decorations)
  }

  getDecorationsByScreenRow (screenRow) {
    return this.decorationsByScreenRow.get(screenRow)
  }

  hasMeasurementsForDecoration (decoration) {
    return this.dimensionsByDecorationId.has(decoration.id)
  }
}
