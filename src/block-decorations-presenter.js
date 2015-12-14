'use strict'

const EventKit = require('event-kit')

module.exports =
class BlockDecorationsPresenter {
  constructor (model, lineTopIndex) {
    this.model = model
    this.disposables = new EventKit.CompositeDisposable()
    this.emitter = new EventKit.Emitter()
    this.firstUpdate = true
    this.lineTopIndex = lineTopIndex
    this.blocksByDecoration = new Map()
    this.decorationsByBlock = new Map()
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
    this.disposables.add(this.model.onDidAddDecoration(this.observeDecoration.bind(this)))
    this.disposables.add(this.model.onDidChange((changeEvent) => {
      let oldExtent = changeEvent.end - changeEvent.start
      let newExtent = Math.max(0, changeEvent.end - changeEvent.start + changeEvent.screenDelta)
      this.lineTopIndex.splice(changeEvent.start, oldExtent, newExtent)
    }))
  }

  update () {
    if (this.firstUpdate) {
      for (let decoration of this.model.getDecorations({type: 'block'})) {
        this.observeDecoration(decoration)
      }
      this.firstUpdate = false
    }
  }

  setDimensionsForDecoration (decoration, width, height) {
    let block = this.blocksByDecoration.get(decoration)
    if (block) {
      this.lineTopIndex.resizeBlock(decoration.getMarker().id, height)
    } else {
      this.observeDecoration(decoration)
      this.lineTopIndex.resizeBlock(decoration.getMarker().id, height)
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

  decorationsForScreenRow (screenRow) {
    let blocks = this.lineTopIndex.allBlocks().filter((block) => block.row === screenRow)
    return blocks.map((block) => this.decorationsByBlock.get(block.id)).filter((decoration) => decoration)
  }

  decorationsForScreenRowRange (startRow, endRow, mouseWheelScreenRow) {
    let blocks = this.lineTopIndex.allBlocks()
    let decorationsByScreenRow = new Map()
    for (let block of blocks) {
      let decoration = this.decorationsByBlock.get(block.id)
      let hasntMeasuredDecoration = !this.measuredDecorations.has(decoration)
      let isWithinVisibleRange = startRow <= block.row && block.row < endRow
      let isVisible = isWithinVisibleRange || block.row === mouseWheelScreenRow
      if (decoration && (isVisible || hasntMeasuredDecoration)) {
        let decorations = decorationsByScreenRow.get(block.row) || []
        decorations.push({decoration, isVisible})
        decorationsByScreenRow.set(block.row, decorations)
      }
    }

    return decorationsByScreenRow
  }

  observeDecoration (decoration) {
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
      this.observedDecorations.delete(decoration)
      this.didDestroyDecoration(decoration)
    })

    this.disposables.add(didMoveDisposable)
    this.disposables.add(didDestroyDisposable)
    this.didAddDecoration(decoration)
    this.observedDecorations.add(decoration)
  }

  didAddDecoration (decoration) {
    let screenRow = decoration.getMarker().getHeadScreenPosition().row
    this.lineTopIndex.insertBlock(decoration.getMarker().id, screenRow, 0)
    this.decorationsByBlock.set(decoration.getMarker().id, decoration)
    this.blocksByDecoration.set(decoration, decoration.getMarker().id)
    this.emitter.emit('did-update-state')
  }

  didMoveDecoration (decoration, markerEvent) {
    if (markerEvent.textChanged) {
      // No need to move blocks because of a text change, because we already splice on buffer change.
      return
    }

    let newScreenRow = decoration.getMarker().getHeadScreenPosition().row
    this.lineTopIndex.moveBlock(decoration.getMarker().id, newScreenRow)
    this.emitter.emit('did-update-state')
  }

  didDestroyDecoration (decoration) {
    let block = this.blocksByDecoration.get(decoration)
    if (block) {
      this.lineTopIndex.removeBlock(decoration.getMarker().id)
      this.blocksByDecoration.delete(decoration)
      this.decorationsByBlock.delete(block)
    }
    this.emitter.emit('did-update-state')
  }
}
