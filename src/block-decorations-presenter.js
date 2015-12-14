'use strict'

const EventKit = require('event-kit')

module.exports =
class BlockDecorationsPresenter {
  constructor (model, lineTopIndex) {
    this.model = model
    this.disposables = new EventKit.CompositeDisposable()
    this.emitter = new EventKit.Emitter()
    this.lineTopIndex = lineTopIndex
    this.observedDecorations = new Set()
    this.measuredDecorations = new Set()

    this.observeModel()
  }

  destroy () {
    this.disposables.dispose()
  }

  onDidUpdateState (callback) {
    return this.emitter.on('did-update-state', callback)
  }

  setLineHeight (lineHeight) {
    this.lineTopIndex.setDefaultLineHeight(lineHeight)
  }

  observeModel () {
    this.disposables.add(this.model.onDidAddDecoration(this.didAddDecoration.bind(this)))
    this.disposables.add(this.model.onDidChange((changeEvent) => {
      let oldExtent = changeEvent.end - changeEvent.start
      let newExtent = Math.max(0, changeEvent.end - changeEvent.start + changeEvent.screenDelta)
      this.lineTopIndex.splice(changeEvent.start, oldExtent, newExtent)
    }))

    for (let decoration of this.model.getDecorations({type: 'block'})) {
      this.didAddDecoration(decoration)
    }
  }

  setDimensionsForDecoration (decoration, width, height) {
    if (this.observedDecorations.has(decoration)) {
      this.lineTopIndex.resizeBlock(decoration.getId(), height)
    } else {
      this.didAddDecoration(decoration)
      this.lineTopIndex.resizeBlock(decoration.getId(), height)
    }

    this.measuredDecorations.add(decoration)
    this.emitter.emit('did-update-state')
  }

  invalidateDimensionsForDecoration (decoration) {
    this.measuredDecorations.delete(decoration)
    this.emitter.emit('did-update-state')
  }

  measurementsChanged () {
    this.measuredDecorations.clear()
    this.emitter.emit('did-update-state')
  }

  didAddDecoration (decoration) {
    if (!decoration.isType('block') || this.observedDecorations.has(decoration)) {
      return
    }

    let didMoveDisposable = decoration.getMarker().bufferMarker.onDidChange((markerEvent) => {
      this.didMoveDecoration(decoration, markerEvent)
    })

    let didDestroyDisposable = decoration.onDidDestroy(() => {
      this.disposables.remove(didMoveDisposable)
      this.disposables.remove(didDestroyDisposable)
      didMoveDisposable.dispose()
      didDestroyDisposable.dispose()
      this.didDestroyDecoration(decoration)
    })

    let screenRow = decoration.getMarker().getHeadScreenPosition().row
    this.lineTopIndex.insertBlock(decoration.getId(), screenRow, 0)

    this.observedDecorations.add(decoration)
    this.disposables.add(didMoveDisposable)
    this.disposables.add(didDestroyDisposable)
    this.emitter.emit('did-update-state')
  }

  didMoveDecoration (decoration, markerEvent) {
    if (markerEvent.textChanged) {
      // No need to move blocks because of a text change, because we already splice on buffer change.
      return
    }

    let newScreenRow = decoration.getMarker().getHeadScreenPosition().row
    this.lineTopIndex.moveBlock(decoration.getId(), newScreenRow)
    this.emitter.emit('did-update-state')
  }

  didDestroyDecoration (decoration) {
    if (this.observedDecorations.has(decoration)) {
      this.lineTopIndex.removeBlock(decoration.getId())
      this.observedDecorations.delete(decoration)
      this.emitter.emit('did-update-state')
    }
  }
}
