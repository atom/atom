/** @babel */

const {CompositeDisposable, Emitter} = require('event-kit')

module.exports =
class BlockDecorationsPresenter {
  constructor (model) {
    this.model = model
    this.disposables = new CompositeDisposable()
    this.emitter = new Emitter()
    this.decorationsByScreenRow = new Map
    this.heightByScreenRow = new Map
    this.screenRowByDecoration = new Map
    this.dimensionsByDecoration = new Map
    this.moveOperationsByDecoration = new Map
    this.addOperationsByDecoration = new Map
    this.changeOperationsByDecoration = new Map
    this.firstUpdate = true

    this.observeModel()
  }

  destroy () {
    this.disposables.dispose()
  }

  onDidUpdateState (callback) {
    return this.emitter.on("did-update-state", callback)
  }

  observeModel () {
    this.disposables.add(
      this.model.onDidAddDecoration((decoration) => this.observeDecoration(decoration))
    )
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
    this.decorationsByScreenRow.clear()
    this.screenRowByDecoration.clear()
    this.moveOperationsByDecoration.clear()
    this.addOperationsByDecoration.clear()

    for (let decoration of this.model.getDecorations({type: "block"})) {
      let screenRow = decoration.getMarker().getHeadScreenPosition().row
      this.addDecorationToScreenRow(screenRow, decoration)
      this.observeDecoration(decoration)
    }
  }

  incrementalUpdate () {
    for (let [changedDecoration] of this.changeOperationsByDecoration) {
      let screenRow = changedDecoration.getMarker().getHeadScreenPosition().row
      this.recalculateScreenRowHeight(screenRow)
    }

    for (let [addedDecoration] of this.addOperationsByDecoration) {
      let screenRow = addedDecoration.getMarker().getHeadScreenPosition().row
      this.addDecorationToScreenRow(screenRow, addedDecoration)
    }

    for (let [movedDecoration, moveOperations] of this.moveOperationsByDecoration) {
      let {oldHeadScreenPosition} = moveOperations[0]
      let {newHeadScreenPosition} = moveOperations[moveOperations.length - 1]
      this.removeDecorationFromScreenRow(oldHeadScreenPosition.row, movedDecoration)
      this.addDecorationToScreenRow(newHeadScreenPosition.row, movedDecoration)
    }

    this.addOperationsByDecoration.clear()
    this.moveOperationsByDecoration.clear()
    this.changeOperationsByDecoration.clear()
  }

  setDimensionsForDecoration (decoration, width, height) {
    this.changeOperationsByDecoration.set(decoration, true)
    this.dimensionsByDecoration.set(decoration, {width, height})
    this.emitter.emit("did-update-state")
  }

  heightForScreenRow (screenRow) {
    return this.heightByScreenRow.get(screenRow) || 0
  }

  addDecorationToScreenRow (screenRow, decoration) {
    let decorations = this.getDecorationsByScreenRow(screenRow)
    if (!decorations.has(decoration)) {
      decorations.add(decoration)
      this.screenRowByDecoration.set(decoration, screenRow)
      this.recalculateScreenRowHeight(screenRow)
    }
  }

  removeDecorationFromScreenRow (screenRow, decoration) {
    if (!Number.isInteger(screenRow) || !decoration) {
      return
    }

    let decorations = this.getDecorationsByScreenRow(screenRow)
    if (decorations.has(decoration)) {
      decorations.delete(decoration)
      this.recalculateScreenRowHeight(screenRow)
    }
  }

  getDecorationsByScreenRow (screenRow) {
    if (!this.decorationsByScreenRow.has(screenRow)) {
      this.decorationsByScreenRow.set(screenRow, new Set())
    }

    return this.decorationsByScreenRow.get(screenRow)
  }

  getDecorationDimensions (decoration) {
    return this.dimensionsByDecoration.get(decoration) || {width: 0, height: 0}
  }

  recalculateScreenRowHeight (screenRow) {
    let height = 0
    for (let decoration of this.getDecorationsByScreenRow(screenRow)) {
      height += this.getDecorationDimensions(decoration).height
    }
    this.heightByScreenRow.set(screenRow, height)
  }

  observeDecoration (decoration) {
    if (!decoration.isType("block")) {
      return
    }

    let didMoveDisposable = decoration.getMarker().onDidChange((markerEvent) => {
      this.didMoveDecoration(decoration, markerEvent)
    })

    let didDestroyDisposable = decoration.onDidDestroy(() => {
      didMoveDisposable.dispose()
      didDestroyDisposable.dispose()
      this.didDestroyDecoration(decoration)
    })

    this.didAddDecoration(decoration)
  }

  didAddDecoration (decoration) {
    this.addOperationsByDecoration.set(decoration, true)
    this.emitter.emit("did-update-state")
  }

  didMoveDecoration (decoration, markerEvent) {
    let moveOperations = this.moveOperationsByDecoration.get(decoration) || []
    moveOperations.push(markerEvent)
    this.moveOperationsByDecoration.set(decoration, moveOperations)
    this.emitter.emit("did-update-state")
  }

  didDestroyDecoration (decoration) {
    this.moveOperationsByDecoration.delete(decoration)
    this.addOperationsByDecoration.delete(decoration)

    this.removeDecorationFromScreenRow(
      this.screenRowByDecoration.get(decoration), decoration
    )
    this.emitter.emit("did-update-state")
  }
}
