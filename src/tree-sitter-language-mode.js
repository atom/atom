const Parser = require('tree-sitter')
const {Point, Range} = require('text-buffer')
const {Patch} = require('superstring')
const {Emitter, Disposable} = require('event-kit')
const ScopeDescriptor = require('./scope-descriptor')
const TokenizedLine = require('./tokenized-line')
const TextMateLanguageMode = require('./text-mate-language-mode')

let nextId = 0
const MAX_RANGE = new Range(Point.ZERO, Point.INFINITY).freeze()

class TreeSitterLanguageMode {
  static _patchSyntaxNode () {
    if (!Parser.SyntaxNode.prototype.hasOwnProperty('text')) {
      Object.defineProperty(Parser.SyntaxNode.prototype, 'text', {
        get () {
          return this.tree.buffer.getTextInRange(new Range(this.startPosition, this.endPosition))
        }
      })
    }
  }

  constructor ({buffer, grammar, config, grammars}) {
    TreeSitterLanguageMode._patchSyntaxNode()
    this.id = nextId++
    this.buffer = buffer
    this.grammar = grammar
    this.config = config
    this.grammarRegistry = grammars
    this.parser = new Parser()
    this.rootLanguageLayer = new LanguageLayer(this, grammar)
    this.injectionsMarkerLayer = buffer.addMarkerLayer()

    this.rootScopeDescriptor = new ScopeDescriptor({scopes: [this.grammar.id]})
    this.emitter = new Emitter()
    this.isFoldableCache = []
    this.hasQueuedParse = false

    this.grammarForLanguageString = this.grammarForLanguageString.bind(this)
    this.emitRangeUpdate = this.emitRangeUpdate.bind(this)

    this.subscription = this.buffer.onDidChangeText(({changes}) => {
      for (let i = changes.length - 1; i >= 0; i--) {
        const {oldRange, newRange} = changes[i]
        const startRow = oldRange.start.row
        const oldEndRow = oldRange.end.row
        const newEndRow = newRange.end.row
        this.isFoldableCache.splice(
          startRow,
          oldEndRow - startRow,
          ...new Array(newEndRow - startRow)
        )
      }

      this.rootLanguageLayer.update()
    })

    this.rootLanguageLayer.update()

    // TODO: Remove this once TreeSitterLanguageMode implements its own auto-indentation system. This
    // is temporarily needed in order to delegate to the TextMateLanguageMode's auto-indent system.
    this.regexesByPattern = {}
  }

  destroy () {
    this.injectionsMarkerLayer.destroy()
    this.subscription.dispose()
    this.rootLanguageLayer = null
    this.parser = null
  }

  getLanguageId () {
    return this.grammar.id
  }

  bufferDidChange (change) {
    this.rootLanguageLayer.handleTextChange(change)
    for (const marker of this.injectionsMarkerLayer.getMarkers()) {
      marker.languageLayer.handleTextChange(change)
    }
  }

  get tree () {
    return this.rootLanguageLayer.tree
  }

  get reparsePromise () {
    return this.rootLanguageLayer.currentParsePromise
  }

  /*
  Section - Highlighting
  */

  buildHighlightIterator () {
    const layerIterators = [
      this.rootLanguageLayer.buildHighlightIterator(),
      ...this.injectionsMarkerLayer.getMarkers().map(m => m.languageLayer.buildHighlightIterator())
    ]
    return new HighlightIterator(layerIterators)
  }

  onDidChangeHighlighting (callback) {
    return this.emitter.on('did-change-highlighting', callback)
  }

  classNameForScopeId (scopeId) {
    return this.grammar.classNameForScopeId(scopeId)
  }

  /*
  Section - Commenting
  */

  commentStringsForPosition () {
    return this.grammar.commentStrings
  }

  isRowCommented () {
    return false
  }

  /*
  Section - Indentation
  */

  suggestedIndentForLineAtBufferRow (row, line, tabLength) {
    return this._suggestedIndentForLineWithScopeAtBufferRow(
      row,
      line,
      this.rootScopeDescriptor,
      tabLength
    )
  }

  suggestedIndentForBufferRow (row, tabLength, options) {
    return this._suggestedIndentForLineWithScopeAtBufferRow(
      row,
      this.buffer.lineForRow(row),
      this.rootScopeDescriptor,
      tabLength,
      options
    )
  }

  indentLevelForLine (line, tabLength = tabLength) {
    let indentLength = 0
    for (let i = 0, {length} = line; i < length; i++) {
      const char = line[i]
      if (char === '\t') {
        indentLength += tabLength - (indentLength % tabLength)
      } else if (char === ' ') {
        indentLength++
      } else {
        break
      }
    }
    return indentLength / tabLength
  }

  /*
  Section - Folding
  */

  isFoldableAtRow (row) {
    if (this.isFoldableCache[row] != null) return this.isFoldableCache[row]
    const result = this.getFoldableRangeContainingPoint(Point(row, Infinity), 0, true) != null
    this.isFoldableCache[row] = result
    return result
  }

  getFoldableRanges () {
    return this.getFoldableRangesAtIndentLevel(null)
  }

  getFoldableRangesAtIndentLevel (goalLevel) {
    let result = []
    let stack = [{node: this.tree.rootNode, level: 0}]
    while (stack.length > 0) {
      const {node, level} = stack.pop()

      const range = this.getFoldableRangeForNode(node)
      if (range) {
        if (goalLevel == null || level === goalLevel) {
          let updatedExistingRange = false
          for (let i = 0, {length} = result; i < length; i++) {
            if (result[i].start.row === range.start.row &&
                result[i].end.row === range.end.row) {
              result[i] = range
              updatedExistingRange = true
              break
            }
          }
          if (!updatedExistingRange) result.push(range)
        }
      }

      const parentStartRow = node.startPosition.row
      const parentEndRow = node.endPosition.row
      for (let children = node.namedChildren, i = 0, {length} = children; i < length; i++) {
        const child = children[i]
        const {startPosition: childStart, endPosition: childEnd} = child
        if (childEnd.row > childStart.row) {
          if (childStart.row === parentStartRow && childEnd.row === parentEndRow) {
            stack.push({node: child, level: level})
          } else {
            const childLevel = range && range.containsPoint(childStart) && range.containsPoint(childEnd)
              ? level + 1
              : level
            if (childLevel <= goalLevel || goalLevel == null) {
              stack.push({node: child, level: childLevel})
            }
          }
        }
      }
    }

    return result.sort((a, b) => a.start.row - b.start.row)
  }

  getFoldableRangeContainingPoint (point, tabLength, existenceOnly = false) {
    if (!this.tree) return null
    let node = this.tree.rootNode.descendantForPosition(this.buffer.clipPosition(point))
    while (node) {
      if (existenceOnly && node.startPosition.row < point.row) break
      if (node.endPosition.row > point.row) {
        const range = this.getFoldableRangeForNode(node, existenceOnly)
        if (range) return range
      }
      node = node.parent
    }
  }

  getFoldableRangeForNode (node, existenceOnly) {
    const {children, type: nodeType} = node
    const childCount = children.length
    let childTypes

    for (var i = 0, {length} = this.grammar.folds; i < length; i++) {
      const foldEntry = this.grammar.folds[i]

      if (foldEntry.type) {
        if (typeof foldEntry.type === 'string') {
          if (foldEntry.type !== nodeType) continue
        } else {
          if (!foldEntry.type.includes(nodeType)) continue
        }
      }

      let foldStart
      const startEntry = foldEntry.start
      if (startEntry) {
        if (startEntry.index != null) {
          const child = children[startEntry.index]
          if (!child || (startEntry.type && startEntry.type !== child.type)) continue
          foldStart = child.endPosition
        } else {
          if (!childTypes) childTypes = children.map(child => child.type)
          const index = typeof startEntry.type === 'string'
            ? childTypes.indexOf(startEntry.type)
            : childTypes.findIndex(type => startEntry.type.includes(type))
          if (index === -1) continue
          foldStart = children[index].endPosition
        }
      } else {
        foldStart = new Point(node.startPosition.row, Infinity)
      }

      let foldEnd
      const endEntry = foldEntry.end
      if (endEntry) {
        let foldEndNode
        if (endEntry.index != null) {
          const index = endEntry.index < 0 ? childCount + endEntry.index : endEntry.index
          foldEndNode = children[index]
          if (!foldEndNode || (endEntry.type && endEntry.type !== foldEndNode.type)) continue
        } else {
          if (!childTypes) childTypes = children.map(foldEndNode => foldEndNode.type)
          const index = typeof endEntry.type === 'string'
            ? childTypes.indexOf(endEntry.type)
            : childTypes.findIndex(type => endEntry.type.includes(type))
          if (index === -1) continue
          foldEndNode = children[index]
        }

        if (foldEndNode.endIndex - foldEndNode.startIndex > 1 && foldEndNode.startPosition.row > foldStart.row) {
          foldEnd = new Point(foldEndNode.startPosition.row - 1, Infinity)
        } else {
          foldEnd = foldEndNode.startPosition
          if (!pointIsGreater(foldEnd, foldStart)) continue
        }
      } else {
        const {endPosition} = node
        if (endPosition.column === 0) {
          foldEnd = Point(endPosition.row - 1, Infinity)
        } else if (childCount > 0) {
          foldEnd = endPosition
        } else {
          foldEnd = Point(endPosition.row, 0)
        }
      }

      return existenceOnly ? true : new Range(foldStart, foldEnd)
    }
  }

  /*
  Section - Syntax Tree APIs
  */

  getRangeForSyntaxNodeContainingRange (range) {
    const startIndex = this.buffer.characterIndexForPosition(range.start)
    const endIndex = this.buffer.characterIndexForPosition(range.end)
    let node = this.tree.rootNode.descendantForIndex(startIndex, endIndex - 1)
    while (node && node.startIndex === startIndex && node.endIndex === endIndex) {
      node = node.parent
    }
    if (node) return new Range(node.startPosition, node.endPosition)
  }

  bufferRangeForScopeAtPosition (position) {
    return this.getRangeForSyntaxNodeContainingRange(new Range(position, position))
  }

  /*
  Section - Backward compatibility shims
  */

  onDidTokenize (callback) { return new Disposable(() => {}) }

  tokenizedLineForRow (row) {
    return new TokenizedLine({
      openScopes: [],
      text: this.buffer.lineForRow(row),
      tags: [],
      ruleStack: [],
      lineEnding: this.buffer.lineEndingForRow(row),
      tokenIterator: null,
      grammar: this.grammar
    })
  }

  scopeDescriptorForPosition (point) {
    if (!this.tree) return this.rootScopeDescriptor

    point = Point.fromObject(point)
    let node = this.tree.rootNode.descendantForPosition(point)

    // Don't include anonymous token types like '(' because they prevent scope chains
    // from being parsed as CSS selectors by the `slick` parser. Other css selector
    // parsers like `postcss-selector-parser` do allow arbitrary quoted strings in
    // selectors.
    if (!node.isNamed) node = node.parent

    const result = []
    while (node) {
      result.push(node.type)
      node = node.parent
    }
    result.push(this.grammar.id)
    return new ScopeDescriptor({scopes: result.reverse()})
  }

  hasTokenForSelector (scopeSelector) {
    return false
  }

  getGrammar () {
    return this.grammar
  }

  /*
  Section - Private
  */

  grammarForLanguageString (languageString) {
    return this.grammarRegistry.treeSitterGrammarForLanguageString(languageString)
  }

  emitRangeUpdate (range) {
    const startRow = range.start.row
    const endRow = range.end.row
    for (let row = startRow; row < endRow; row++) {
      this.isFoldableCache[row] = undefined
    }
    this.emitter.emit('did-change-highlighting', range)
  }
}

class LanguageLayer {
  constructor (languageMode, grammar) {
    this.languageMode = languageMode
    this.grammar = grammar
    this.tree = null
    this.currentParsePromise = null
    this.patchSinceCurrentParseStarted = null
  }

  buildHighlightIterator () {
    if (this.tree) {
      return new LayerHighlightIterator(this, this.tree.walk())
    } else {
      return new NullHighlightIterator()
    }
  }

  handleTextChange ({oldRange, newRange, oldText, newText}) {
    if (this.tree) {
      this.tree.edit(this._treeEditForBufferChange(
        oldRange.start, oldRange.end, newRange.end, oldText, newText
      ))
    }

    if (this.currentParsePromise) {
      if (!this.patchSinceCurrentParseStarted) {
        this.patchSinceCurrentParseStarted = new Patch()
      }
      this.patchSinceCurrentParseStarted.splice(
        oldRange.start,
        oldRange.end,
        newRange.end,
        oldText,
        newText
      )
    }
  }

  destroy () {
    for (const marker of this.languageMode.injectionsMarkerLayer.getMarkers()) {
      if (marker.parentLanguageLayer === this) {
        marker.languageLayer.destroy()
        marker.destroy()
      }
    }
  }

  async update (containingNode) {
    if (this.currentParsePromise) return this.currentParsePromise

    this.currentParsePromise = this._performUpdate(containingNode)
    await this.currentParsePromise
    this.currentParsePromise = null

    if (this.patchSinceCurrentParseStarted) {
      const changes = this.patchSinceCurrentParseStarted.getChanges()
      for (let i = changes.length - 1; i >= 0; i--) {
        const {oldStart, oldEnd, newEnd, oldText, newText} = changes[i]
        this.tree.edit(this._treeEditForBufferChange(
          oldStart, oldEnd, newEnd, oldText, newText
        ))
      }
      this.patchSinceCurrentParseStarted = null
      this.update(containingNode)
    }
  }

  async _performUpdate (containingNode) {
    const {
      parser,
      injectionsMarkerLayer,
      grammarForLanguageString,
      emitRangeUpdate
    } = this.languageMode

    let includedRanges
    if (containingNode) {
      includedRanges = this._rangesForInjectionNode(containingNode)
      if (includedRanges.length === 0) return
    }

    parser.setLanguage(this.grammar.languageModule)
    const tree = await parser.parseTextBuffer(this.languageMode.buffer.buffer, this.tree, {
      syncOperationLimit: 1000,
      includedRanges
    })
    tree.buffer = this.languageMode.buffer

    let affectedRange
    let existingInjectionMarkers
    if (this.tree) {
      const editedRange = this.tree.getEditedRange()
      if (!editedRange) return
      affectedRange = new Range(editedRange.startPosition, editedRange.endPosition)

      const rangesWithSyntaxChanges = this.tree.getChangedRanges(tree)
      for (const range of rangesWithSyntaxChanges) {
        emitRangeUpdate(new Range(range.startPosition, range.endPosition))
      }

      if (rangesWithSyntaxChanges.length > 0) {
        affectedRange = affectedRange.union(new Range(
          rangesWithSyntaxChanges[0].startPosition,
          last(rangesWithSyntaxChanges).endPosition
        ))
      }

      existingInjectionMarkers = injectionsMarkerLayer
        .findMarkers({intersectsRange: affectedRange})
        .filter(marker => marker.parentLanguageLayer === this)
    } else {
      emitRangeUpdate(new Range(tree.rootNode.startPosition, tree.rootNode.endPosition))
      affectedRange = MAX_RANGE
      existingInjectionMarkers = []
    }

    this.tree = tree

    const markersToUpdate = new Map()
    for (const injectionPoint of this.grammar.injectionPoints) {
      const nodes = tree.rootNode.descendantsOfType(
        injectionPoint.type,
        affectedRange.start,
        affectedRange.end
      )

      for (const node of nodes) {
        const languageName = injectionPoint.language(node)
        if (!languageName) continue

        const grammar = grammarForLanguageString(languageName)
        if (!grammar) continue

        const injectionNode = injectionPoint.content(node)
        if (!injectionNode) continue

        const injectionRange = new Range(node.startPosition, node.endPosition)
        let marker = existingInjectionMarkers.find(m =>
          m.getRange().isEqual(injectionRange) &&
          m.languageLayer.grammar === grammar
        )
        if (!marker) {
          marker = injectionsMarkerLayer.markRange(injectionRange)
          marker.languageLayer = new LanguageLayer(this.languageMode, grammar)
          marker.parentLanguageLayer = this
        }

        markersToUpdate.set(marker, injectionNode)
      }
    }

    for (const marker of existingInjectionMarkers) {
      if (!markersToUpdate.has(marker)) {
        marker.languageLayer.destroy()
        emitRangeUpdate(marker.getRange())
        marker.destroy()
      }
    }

    for (const [marker, injectionNode] of markersToUpdate) {
      await marker.languageLayer.update(injectionNode)
    }
  }

  _rangesForInjectionNode (node) {
    const result = []
    let position = node.startPosition
    let index = node.startIndex

    for (const child of node.children) {
      const nextPosition = child.startPosition
      const nextIndex = child.startIndex
      if (nextIndex > index) {
        result.push({
          startIndex: index,
          endIndex: nextIndex,
          startPosition: position,
          endPosition: nextPosition
        })
      }
      position = child.endPosition
      index = child.endIndex
    }

    if (node.endIndex > index) {
      result.push({
        startIndex: index,
        endIndex: node.endIndex,
        startPosition: position,
        endPosition: node.endPosition
      })
    }

    return result
  }

  _treeEditForBufferChange (start, oldEnd, newEnd, oldText, newText) {
    const startIndex = this.languageMode.buffer.characterIndexForPosition(start)
    return {
      startIndex,
      oldEndIndex: startIndex + oldText.length,
      newEndIndex: startIndex + newText.length,
      startPosition: start,
      oldEndPosition: oldEnd,
      newEndPosition: newEnd
    }
  }
}

class HighlightIterator {
  constructor (iterators) {
    this.iterators = iterators
    this.leader = iterators[0]
  }

  seek (targetPosition) {
    const openScopes = [].concat(...this.iterators.map(it => it.seek(targetPosition)))
    this._findLeader()
    return openScopes
  }

  moveToSuccessor () {
    this.leader.moveToSuccessor()
    this._findLeader()
  }

  getPosition () {
    return this.leader.getPosition()
  }

  getCloseScopeIds () {
    return this.leader.getCloseScopeIds()
  }

  getOpenScopeIds () {
    return this.leader.getOpenScopeIds()
  }

  _findLeader () {
    let minPosition = Point.INFINITY
    for (const it of this.iterators) {
      const position = it.getPosition()
      if (pointIsLess(position, minPosition)) {
        this.leader = it
        minPosition = position
      }
    }
  }
}

class LayerHighlightIterator {
  constructor (languageLayer, treeCursor) {
    this.languageLayer = languageLayer
    this.treeCursor = treeCursor
    this.atEnd = false

    // In order to determine which selectors match its current node, the iterator maintains
    // a list of the current node's ancestors. Because the selectors can use the `:nth-child`
    // pseudo-class, each node's child index is also stored.
    this.containingNodeTypes = []
    this.containingNodeChildIndices = []
    this.containingNodeEndIndices = []

    // At any given position, the iterator exposes the list of class names that should be
    // *ended* at its current position and the list of class names that should be *started*
    // at its current position.
    this.closeTags = []
    this.openTags = []
  }

  seek (targetPosition) {
    while (this.treeCursor.gotoParent()) {}

    const containingTags = []
    const targetIndex = this.languageLayer.languageMode.buffer.characterIndexForPosition(
      targetPosition
    )

    this.done = false
    this.atEnd = true
    this.closeTags.length = 0
    this.openTags.length = 0
    this.containingNodeTypes.length = 0
    this.containingNodeChildIndices.length = 0
    this.containingNodeEndIndices.length = 0

    if (targetIndex >= this.treeCursor.endIndex) return containingTags

    let childIndex = -1
    for (;;) {
      this.containingNodeTypes.push(this.treeCursor.nodeType)
      this.containingNodeChildIndices.push(childIndex)
      this.containingNodeEndIndices.push(this.treeCursor.endIndex)

      const scopeName = this.currentScopeName()
      if (scopeName) {
        const id = this.idForScope(scopeName)
        if (this.treeCursor.startIndex < targetIndex) {
          containingTags.push(id)
        } else {
          this.atEnd = false
          this.openTags.push(id)
          while (this.treeCursor.gotoFirstChild()) {
            this.containingNodeTypes.push(this.treeCursor.nodeType)
            this.containingNodeChildIndices.push(0)
            const scopeName = this.currentScopeName()
            if (scopeName) {
              this.openTags.push(this.idForScope(scopeName))
            }
          }
          break
        }
      }

      childIndex = this.treeCursor.gotoFirstChildForIndex(targetIndex)
      if (childIndex === null) break
      if (this.treeCursor.startIndex >= targetIndex) this.atEnd = false
    }

    return containingTags
  }

  moveToSuccessor () {
    let didMove = false
    this.closeTags.length = 0
    this.openTags.length = 0

    if (this.done) return

    while (true) {
      if (this.atEnd) {
        if (this.treeCursor.gotoNextSibling()) {
          didMove = true
          this.atEnd = false
          const depth = this.containingNodeTypes.length
          this.containingNodeTypes[depth - 1] = this.treeCursor.nodeType
          this.containingNodeChildIndices[depth - 1]++
          this.containingNodeEndIndices[depth - 1] = this.treeCursor.endIndex

          while (true) {
            const {endIndex} = this.treeCursor
            const scopeName = this.currentScopeName()
            if (scopeName) {
              this.openTags.push(this.idForScope(scopeName))
            }

            if (this.treeCursor.gotoFirstChild()) {
              if ((this.closeTags.length || this.openTags.length) && this.treeCursor.endIndex > endIndex) {
                this.treeCursor.gotoParent()
                break
              }

              this.containingNodeTypes.push(this.treeCursor.nodeType)
              this.containingNodeChildIndices.push(0)
              this.containingNodeEndIndices.push(this.treeCursor.endIndex)
            } else {
              break
            }
          }
        } else if (this.treeCursor.gotoParent()) {
          this.atEnd = false
          this.containingNodeTypes.pop()
          this.containingNodeChildIndices.pop()
          this.containingNodeEndIndices.pop()
        } else {
          this.done = true
          break
        }
      } else {
        this.atEnd = true
        didMove = true

        const scopeName = this.currentScopeName()
        if (scopeName) {
          this.closeTags.push(this.idForScope(scopeName))
        }

        const endIndex = this.treeCursor.endIndex
        let depth = this.containingNodeEndIndices.length
        while (depth > 1 && this.containingNodeEndIndices[depth - 2] === endIndex) {
          this.treeCursor.gotoParent()
          this.containingNodeTypes.pop()
          this.containingNodeChildIndices.pop()
          this.containingNodeEndIndices.pop()
          --depth
          const scopeName = this.currentScopeName()
          if (scopeName) this.closeTags.push(this.idForScope(scopeName))
        }
      }

      if (didMove && (this.closeTags.length || this.openTags.length)) break
    }
  }

  getPosition () {
    if (this.done) {
      return Point.INFINITY
    } else if (this.atEnd) {
      return this.treeCursor.endPosition
    } else {
      return this.treeCursor.startPosition
    }
  }

  getCloseScopeIds () {
    return this.closeTags.slice()
  }

  getOpenScopeIds () {
    return this.openTags.slice()
  }

  // Private methods

  currentScopeName () {
    return this.languageLayer.grammar.scopeMap.get(
      this.containingNodeTypes,
      this.containingNodeChildIndices,
      this.treeCursor.nodeIsNamed
    )
  }

  idForScope (scopeName) {
    return this.languageLayer.languageMode.grammar.idForScope(scopeName)
  }
}

class NullHighlightIterator {
  seek () {}
  moveToSuccessor () {}
  getPosition () { return Point.INFINITY }
  getOpenScopeIds () { return [] }
  getCloseScopeIds () { return [] }
}

function pointIsLess (left, right) {
  return left.row < right.row || left.row === right.row && left.column < right.column
}

function pointIsGreater (left, right) {
  return left.row > right.row || left.row === right.row && left.column > right.column
}

function last (array) {
  return array[array.length - 1]
}

// TODO: Remove this once TreeSitterLanguageMode implements its own auto-indent system.
[
  '_suggestedIndentForLineWithScopeAtBufferRow',
  'suggestedIndentForEditedBufferRow',
  'increaseIndentRegexForScopeDescriptor',
  'decreaseIndentRegexForScopeDescriptor',
  'decreaseNextIndentRegexForScopeDescriptor',
  'regexForPattern'
].forEach(methodName => {
  TreeSitterLanguageMode.prototype[methodName] = TextMateLanguageMode.prototype[methodName]
})

TreeSitterLanguageMode.LanguageLayer = LanguageLayer

module.exports = TreeSitterLanguageMode
