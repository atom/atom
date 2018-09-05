const Parser = require('tree-sitter')
const {Point, Range, spliceArray} = require('text-buffer')
const {Patch} = require('superstring')
const {Emitter} = require('event-kit')
const ScopeDescriptor = require('./scope-descriptor')
const TokenizedLine = require('./tokenized-line')
const TextMateLanguageMode = require('./text-mate-language-mode')
const {matcherForSelector} = require('./selectors')

let nextId = 0
const MAX_RANGE = new Range(Point.ZERO, Point.INFINITY).freeze()
const PARSER_POOL = []
const WORD_REGEX = /\w/

class TreeSitterLanguageMode {
  static _patchSyntaxNode () {
    if (!Parser.SyntaxNode.prototype.hasOwnProperty('range')) {
      Object.defineProperty(Parser.SyntaxNode.prototype, 'range', {
        get () {
          return rangeForNode(this)
        }
      })
    }
  }

  constructor ({buffer, grammar, config, grammars, syncOperationLimit}) {
    TreeSitterLanguageMode._patchSyntaxNode()
    this.id = nextId++
    this.buffer = buffer
    this.grammar = grammar
    this.config = config
    this.grammarRegistry = grammars
    this.parser = new Parser()
    this.rootLanguageLayer = new LanguageLayer(this, grammar)
    this.injectionsMarkerLayer = buffer.addMarkerLayer()

    if (syncOperationLimit != null) {
      this.syncOperationLimit = syncOperationLimit
    }

    this.rootScopeDescriptor = new ScopeDescriptor({scopes: [this.grammar.scopeName]})
    this.emitter = new Emitter()
    this.isFoldableCache = []
    this.hasQueuedParse = false

    this.grammarForLanguageString = this.grammarForLanguageString.bind(this)
    this.emitRangeUpdate = this.emitRangeUpdate.bind(this)

    this.subscription = this.buffer.onDidChangeText(({changes}) => {
      for (let i = 0, {length} = changes; i < length; i++) {
        const {oldRange, newRange} = changes[i]
        spliceArray(
          this.isFoldableCache,
          newRange.start.row,
          oldRange.end.row - oldRange.start.row,
          {length: newRange.end.row - newRange.start.row}
        )
      }

      this.rootLanguageLayer.update(null)
    })

    this.rootLanguageLayer.update(null).then(() =>
      this.emitter.emit('did-tokenize')
    )

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
    return this.grammar.scopeName
  }

  bufferDidChange (change) {
    this.rootLanguageLayer.handleTextChange(change)
    for (const marker of this.injectionsMarkerLayer.getMarkers()) {
      marker.languageLayer.handleTextChange(change)
    }
  }

  parse (language, oldTree, ranges) {
    const parser = PARSER_POOL.pop() || new Parser()
    parser.setLanguage(language)
    const result = parser.parseTextBuffer(this.buffer.buffer, oldTree, {
      syncOperationLimit: this.syncOperationLimit,
      includedRanges: ranges
    })

    if (result.then) {
      return result.then(tree => {
        PARSER_POOL.push(parser)
        return tree
      })
    } else {
      PARSER_POOL.push(parser)
      return result
    }
  }

  get tree () {
    return this.rootLanguageLayer.tree
  }

  updateForInjection (grammar) {
    this.rootLanguageLayer.updateInjections(grammar)
  }

  /*
  Section - Highlighting
  */

  buildHighlightIterator () {
    if (!this.rootLanguageLayer) return new NullHighlightIterator()
    const layerIterators = [
      this.rootLanguageLayer.buildHighlightIterator(),
      ...this.injectionsMarkerLayer.getMarkers().map(m => m.languageLayer.buildHighlightIterator())
    ]
    return new HighlightIterator(this, layerIterators)
  }

  onDidTokenize (callback) {
    return this.emitter.on('did-tokenize', callback)
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

  isRowCommented (row) {
    const firstNonWhitespaceRange = this.buffer.findInRangeSync(
      /\S/,
      new Range(new Point(row, 0), new Point(row, Infinity))
    )
    if (firstNonWhitespaceRange) {
      const firstNode = this.getSyntaxNodeContainingRange(firstNonWhitespaceRange)
      if (firstNode) return firstNode.type.includes('comment')
    }
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

  /**
   * TODO: Make this method generate folds for nested languages (currently,
   * folds are only generated for the root language layer).
   */
  getFoldableRangesAtIndentLevel (goalLevel) {
    let result = []
    let stack = [{node: this.tree.rootNode, level: 0}]
    while (stack.length > 0) {
      const {node, level} = stack.pop()

      const range = this.getFoldableRangeForNode(node, this.grammar)
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

    let smallestRange
    this._forEachTreeWithRange(new Range(point, point), (tree, grammar) => {
      let node = tree.rootNode.descendantForPosition(this.buffer.clipPosition(point))
      while (node) {
        if (existenceOnly && node.startPosition.row < point.row) return
        if (node.endPosition.row > point.row) {
          const range = this.getFoldableRangeForNode(node, grammar)
          if (range && rangeIsSmaller(range, smallestRange)) {
            smallestRange = range
            return
          }
        }
        node = node.parent
      }
    })

    return existenceOnly
      ? smallestRange && smallestRange.start.row === point.row
      : smallestRange
  }

  _forEachTreeWithRange (range, callback) {
    if (this.rootLanguageLayer.tree) {
      callback(this.rootLanguageLayer.tree, this.rootLanguageLayer.grammar)
    }

    const injectionMarkers = this.injectionsMarkerLayer.findMarkers({
      intersectsRange: range
    })

    for (const injectionMarker of injectionMarkers) {
      const {tree, grammar} = injectionMarker.languageLayer
      if (tree) callback(tree, grammar)
    }
  }

  getFoldableRangeForNode (node, grammar, existenceOnly) {
    const {children} = node
    const childCount = children.length

    for (var i = 0, {length} = grammar.folds; i < length; i++) {
      const foldSpec = grammar.folds[i]

      if (foldSpec.matchers && !hasMatchingFoldSpec(foldSpec.matchers, node)) continue

      let foldStart
      const startEntry = foldSpec.start
      if (startEntry) {
        let foldStartNode
        if (startEntry.index != null) {
          foldStartNode = children[startEntry.index]
          if (!foldStartNode || startEntry.matchers && !hasMatchingFoldSpec(startEntry.matchers, foldStartNode)) continue
        } else {
          foldStartNode = children.find(child => hasMatchingFoldSpec(startEntry.matchers, child))
          if (!foldStartNode) continue
        }
        foldStart = new Point(foldStartNode.endPosition.row, Infinity)
      } else {
        foldStart = new Point(node.startPosition.row, Infinity)
      }

      let foldEnd
      const endEntry = foldSpec.end
      if (endEntry) {
        let foldEndNode
        if (endEntry.index != null) {
          const index = endEntry.index < 0 ? childCount + endEntry.index : endEntry.index
          foldEndNode = children[index]
          if (!foldEndNode || (endEntry.type && endEntry.type !== foldEndNode.type)) continue
        } else {
          foldEndNode = children.find(child => hasMatchingFoldSpec(endEntry.matchers, child))
          if (!foldEndNode) continue
        }

        if (foldEndNode.startPosition.row <= foldStart.row) continue

        foldEnd = foldEndNode.startPosition
        if (this.buffer.findInRangeSync(
          WORD_REGEX, new Range(foldEnd, new Point(foldEnd.row, Infinity))
        )) {
          foldEnd = new Point(foldEnd.row - 1, Infinity)
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

  getSyntaxNodeContainingRange (range, where = _ => true) {
    const startIndex = this.buffer.characterIndexForPosition(range.start)
    const endIndex = this.buffer.characterIndexForPosition(range.end)
    const searchEndIndex = Math.max(0, endIndex - 1)

    let smallestNode
    this._forEachTreeWithRange(range, tree => {
      let node = tree.rootNode.descendantForIndex(startIndex, searchEndIndex)
      while (node) {
        if (nodeContainsIndices(node, startIndex, endIndex) && where(node)) {
          if (nodeIsSmaller(node, smallestNode)) smallestNode = node
          break
        }
        node = node.parent
      }
    })

    return smallestNode
  }

  getRangeForSyntaxNodeContainingRange (range, where) {
    const node = this.getSyntaxNodeContainingRange(range, where)
    return node && node.range
  }

  getSyntaxNodeAtPosition (position, where) {
    return this.getSyntaxNodeContainingRange(new Range(position, position), where)
  }

  bufferRangeForScopeAtPosition (selector, position) {
    if (typeof selector === 'string') {
      const match = matcherForSelector(selector)
      selector = ({type}) => match(type)
    }
    if (selector === null) selector = undefined
    const node = this.getSyntaxNodeAtPosition(position, selector)
    return node && node.range
  }

  /*
  Section - Backward compatibility shims
  */

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
    const iterator = this.buildHighlightIterator()
    const scopes = []
    for (const scope of iterator.seek(point)) {
      scopes.push(this.grammar.scopeNameForScopeId(scope, false))
    }
    for (const scope of iterator.getOpenScopeIds()) {
      scopes.push(this.grammar.scopeNameForScopeId(scope, false))
    }
    if (scopes.length === 0 || scopes[0] !== this.grammar.scopeName) {
      scopes.unshift(this.grammar.scopeName)
    }
    return new ScopeDescriptor({scopes})
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
  constructor (languageMode, grammar, contentChildTypes) {
    this.languageMode = languageMode
    this.grammar = grammar
    this.tree = null
    this.currentParsePromise = null
    this.patchSinceCurrentParseStarted = null
    this.contentChildTypes = contentChildTypes
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

      if (this.editedRange) {
        if (newRange.start.isLessThan(this.editedRange.start)) {
          this.editedRange.start = newRange.start
        }
        if (oldRange.end.isLessThan(this.editedRange.end)) {
          this.editedRange.end = newRange.end.traverse(this.editedRange.end.traversalFrom(oldRange.end))
        } else {
          this.editedRange.end = newRange.end
        }
      } else {
        this.editedRange = newRange.copy()
      }
    }

    if (this.patchSinceCurrentParseStarted) {
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

  async update (nodeRangeSet) {
    if (!this.currentParsePromise) {
      do {
        const params = {async: false}
        this.currentParsePromise = this._performUpdate(nodeRangeSet, params)
        if (!params.async) break
        await this.currentParsePromise
      } while (this.tree && this.tree.rootNode.hasChanges())
      this.currentParsePromise = null
    }
  }

  updateInjections (grammar) {
    if (grammar.injectionRegex) {
      if (!this.currentParsePromise) this.currentParsePromise = Promise.resolve()
      this.currentParsePromise = this.currentParsePromise.then(async () => {
        await this._populateInjections(MAX_RANGE, null)
        this.currentParsePromise = null
      })
    }
  }

  async _performUpdate (nodeRangeSet, params) {
    let includedRanges = null
    if (nodeRangeSet) {
      includedRanges = nodeRangeSet.getRanges()
      if (includedRanges.length === 0) {
        this.tree = null
        return
      }
    }

    let affectedRange = this.editedRange
    this.editedRange = null

    this.patchSinceCurrentParseStarted = new Patch()
    let tree = this.languageMode.parse(
      this.grammar.languageModule,
      this.tree,
      includedRanges
    )
    if (tree.then) {
      params.async = true
      tree = await tree
    }
    tree.buffer = this.languageMode.buffer

    const changes = this.patchSinceCurrentParseStarted.getChanges()
    this.patchSinceCurrentParseStarted = null
    for (let i = changes.length - 1; i >= 0; i--) {
      const {oldStart, oldEnd, newEnd, oldText, newText} = changes[i]
      tree.edit(this._treeEditForBufferChange(
        oldStart, oldEnd, newEnd, oldText, newText
      ))
    }

    if (this.tree) {
      const rangesWithSyntaxChanges = this.tree.getChangedRanges(tree)
      this.tree = tree

      if (!affectedRange) return
      if (rangesWithSyntaxChanges.length > 0) {
        for (const range of rangesWithSyntaxChanges) {
          this.languageMode.emitRangeUpdate(rangeForNode(range))
        }

        affectedRange = affectedRange.union(new Range(
          rangesWithSyntaxChanges[0].startPosition,
          last(rangesWithSyntaxChanges).endPosition
        ))
      } else {
        this.languageMode.emitRangeUpdate(affectedRange)
      }
    } else {
      this.tree = tree
      this.languageMode.emitRangeUpdate(rangeForNode(tree.rootNode))
      if (includedRanges) {
        affectedRange = new Range(includedRanges[0].startPosition, last(includedRanges).endPosition)
      } else {
        affectedRange = MAX_RANGE
      }
    }

    const injectionPromise = this._populateInjections(affectedRange, nodeRangeSet)
    if (injectionPromise) {
      params.async = true
      return injectionPromise
    }
  }

  _populateInjections (range, nodeRangeSet) {
    const {injectionsMarkerLayer, grammarForLanguageString} = this.languageMode

    const existingInjectionMarkers = injectionsMarkerLayer
      .findMarkers({intersectsRange: range})
      .filter(marker => marker.parentLanguageLayer === this)

    if (existingInjectionMarkers.length > 0) {
      range = range.union(new Range(
        existingInjectionMarkers[0].getRange().start,
        last(existingInjectionMarkers).getRange().end
      ))
    }

    const markersToUpdate = new Map()
    for (const injectionPoint of this.grammar.injectionPoints) {
      const nodes = this.tree.rootNode.descendantsOfType(
        injectionPoint.type,
        range.start,
        range.end
      )

      for (const node of nodes) {
        const languageName = injectionPoint.language(node)
        if (!languageName) continue

        const grammar = grammarForLanguageString(languageName)
        if (!grammar) continue

        const contentNodes = injectionPoint.content(node)
        if (!contentNodes) continue

        const injectionNodes = [].concat(contentNodes)
        if (!injectionNodes.length) continue

        const injectionRange = rangeForNode(node)
        let marker = existingInjectionMarkers.find(m =>
          m.getRange().isEqual(injectionRange) &&
          m.languageLayer.grammar === grammar
        )
        if (!marker) {
          marker = injectionsMarkerLayer.markRange(injectionRange)
          marker.languageLayer = new LanguageLayer(this.languageMode, grammar, injectionPoint.contentChildTypes)
          marker.parentLanguageLayer = this
        }

        markersToUpdate.set(marker, new NodeRangeSet(nodeRangeSet, injectionNodes))
      }
    }

    for (const marker of existingInjectionMarkers) {
      if (!markersToUpdate.has(marker)) {
        marker.languageLayer.destroy()
        this.languageMode.emitRangeUpdate(marker.getRange())
        marker.destroy()
      }
    }

    if (markersToUpdate.size > 0) {
      this.lastUpdateWasAsync = true
      const promises = []
      for (const [marker, nodeRangeSet] of markersToUpdate) {
        promises.push(marker.languageLayer.update(nodeRangeSet))
      }
      return Promise.all(promises)
    }
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
  constructor (languageMode, iterators) {
    this.languageMode = languageMode
    this.iterators = iterators.sort((a, b) => b.getIndex() - a.getIndex())
  }

  seek (targetPosition) {
    const containingTags = []
    const containingTagStartIndices = []
    const targetIndex = this.languageMode.buffer.characterIndexForPosition(targetPosition)
    for (let i = this.iterators.length - 1; i >= 0; i--) {
      this.iterators[i].seek(targetIndex, containingTags, containingTagStartIndices)
    }
    this.iterators.sort((a, b) => b.getIndex() - a.getIndex())
    return containingTags
  }

  moveToSuccessor () {
    const lastIndex = this.iterators.length - 1
    const leader = this.iterators[lastIndex]
    leader.moveToSuccessor()
    const leaderCharIndex = leader.getIndex()
    let i = lastIndex
    while (i > 0 && this.iterators[i - 1].getIndex() < leaderCharIndex) i--
    if (i < lastIndex) this.iterators.splice(i, 0, this.iterators.pop())
  }

  getPosition () {
    return last(this.iterators).getPosition()
  }

  getCloseScopeIds () {
    return last(this.iterators).getCloseScopeIds()
  }

  getOpenScopeIds () {
    return last(this.iterators).getOpenScopeIds()
  }

  logState () {
    const iterator = last(this.iterators)
    if (iterator.treeCursor) {
      console.log(
        iterator.getPosition(),
        iterator.treeCursor.nodeType,
        new Range(
          iterator.languageLayer.tree.rootNode.startPosition,
          iterator.languageLayer.tree.rootNode.endPosition
        ).toString()
      )
      console.log('close', iterator.closeTags.map(id => this.shortClassNameForScopeId(id)))
      console.log('open', iterator.openTags.map(id => this.shortClassNameForScopeId(id)))
    }
  }

  shortClassNameForScopeId (id) {
    return this.languageMode.classNameForScopeId(id).replace(/syntax--/g, '')
  }
}

class LayerHighlightIterator {
  constructor (languageLayer, treeCursor) {
    this.languageLayer = languageLayer

    // The iterator is always positioned at either the start or the end of some node
    // in the syntax tree.
    this.atEnd = false
    this.treeCursor = treeCursor

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

  seek (targetIndex, containingTags, containingTagStartIndices) {
    while (this.treeCursor.gotoParent()) {}

    this.done = false
    this.atEnd = true
    this.closeTags.length = 0
    this.openTags.length = 0
    this.containingNodeTypes.length = 0
    this.containingNodeChildIndices.length = 0
    this.containingNodeEndIndices.length = 0

    const containingTagEndIndices = []

    if (targetIndex >= this.treeCursor.endIndex) {
      this.done = true
      return
    }

    let childIndex = -1
    for (;;) {
      this.containingNodeTypes.push(this.treeCursor.nodeType)
      this.containingNodeChildIndices.push(childIndex)
      this.containingNodeEndIndices.push(this.treeCursor.endIndex)

      const scopeId = this._currentScopeId()
      if (scopeId) {
        if (this.treeCursor.startIndex < targetIndex) {
          insertContainingTag(
            scopeId, this.treeCursor.startIndex,
            containingTags, containingTagStartIndices
          )
          containingTagEndIndices.push(this.treeCursor.endIndex)
        } else {
          this.atEnd = false
          this.openTags.push(scopeId)
          this._moveDown()
          break
        }
      }

      childIndex = this.treeCursor.gotoFirstChildForIndex(targetIndex)
      if (childIndex === null) break
      if (this.treeCursor.startIndex >= targetIndex) this.atEnd = false
    }

    if (this.atEnd) {
      const currentIndex = this.treeCursor.endIndex
      for (let i = 0, {length} = containingTags; i < length; i++) {
        if (containingTagEndIndices[i] === currentIndex) {
          this.closeTags.push(containingTags[i])
        }
      }
    }

    return containingTags
  }

  moveToSuccessor () {
    this.closeTags.length = 0
    this.openTags.length = 0

    while (!this.done && !this.closeTags.length && !this.openTags.length) {
      if (this.atEnd) {
        if (this._moveRight()) {
          const scopeId = this._currentScopeId()
          if (scopeId) this.openTags.push(scopeId)
          this.atEnd = false
          this._moveDown()
        } else if (this._moveUp(true)) {
          this.atEnd = true
        } else {
          this.done = true
        }
      } else if (!this._moveDown()) {
        const scopeId = this._currentScopeId()
        if (scopeId) this.closeTags.push(scopeId)
        this.atEnd = true
        this._moveUp(false)
      }
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

  getIndex () {
    if (this.done) {
      return Infinity
    } else if (this.atEnd) {
      return this.treeCursor.endIndex
    } else {
      return this.treeCursor.startIndex
    }
  }

  getCloseScopeIds () {
    return this.closeTags.slice()
  }

  getOpenScopeIds () {
    return this.openTags.slice()
  }

  // Private methods
  _moveUp (atLastChild) {
    let result = false
    const {endIndex} = this.treeCursor
    let depth = this.containingNodeEndIndices.length

    // The iterator should not move up until it has visited all of the children of this node.
    while (depth > 1 && (atLastChild || this.containingNodeEndIndices[depth - 2] === endIndex)) {
      atLastChild = false
      result = true
      this.treeCursor.gotoParent()
      this.containingNodeTypes.pop()
      this.containingNodeChildIndices.pop()
      this.containingNodeEndIndices.pop()
      --depth
      const scopeId = this._currentScopeId()
      if (scopeId) this.closeTags.push(scopeId)
    }
    return result
  }

  _moveDown () {
    let result = false
    const {startIndex} = this.treeCursor

    // Once the iterator has found a scope boundary, it needs to stay at the same
    // position, so it should not move down if the first child node starts later than the
    // current node.
    while (this.treeCursor.gotoFirstChild()) {
      if ((this.closeTags.length || this.openTags.length) &&
          this.treeCursor.startIndex > startIndex) {
        this.treeCursor.gotoParent()
        break
      }

      result = true
      this.containingNodeTypes.push(this.treeCursor.nodeType)
      this.containingNodeChildIndices.push(0)
      this.containingNodeEndIndices.push(this.treeCursor.endIndex)

      const scopeId = this._currentScopeId()
      if (scopeId) this.openTags.push(scopeId)
    }

    return result
  }

  _moveRight () {
    if (this.treeCursor.gotoNextSibling()) {
      const depth = this.containingNodeTypes.length
      this.containingNodeTypes[depth - 1] = this.treeCursor.nodeType
      this.containingNodeChildIndices[depth - 1]++
      this.containingNodeEndIndices[depth - 1] = this.treeCursor.endIndex
      return true
    }
  }

  _currentScopeId () {
    const rules = this.languageLayer.grammar.scopeMap.get(
      this.containingNodeTypes,
      this.containingNodeChildIndices,
      this.treeCursor.nodeIsNamed
    )
    const scopes = applyLeafRules(rules, this.treeCursor)
    if (scopes) {
      return this.languageLayer.languageMode.grammar.idForScope(scopes)
    }
  }
}

const applyLeafRules = (rules, cursor) => {
  if (!rules || typeof rules === 'string') return rules
  if (Array.isArray(rules)) {
    for (let i = 0, {length} = rules; i !== length; ++i) {
      const result = applyLeafRules(rules[i], cursor)
      if (result) return result
    }
    return undefined
  }
  if (typeof rules === 'object') {
    if (rules.exact) {
      return cursor.nodeText === rules.exact
        ? applyLeafRules(rules.scopes, cursor)
        : undefined
    }
    if (rules.match) {
      return rules.match.test(cursor.nodeText)
        ? applyLeafRules(rules.scopes, cursor)
        : undefined
    }
  }
}

class NullHighlightIterator {
  seek () { return [] }
  moveToSuccessor () {}
  getIndex () { return Infinity }
  getPosition () { return Point.INFINITY }
  getOpenScopeIds () { return [] }
  getCloseScopeIds () { return [] }
}

class NodeRangeSet {
  constructor (previous, nodes) {
    this.previous = previous
    this.nodes = nodes
  }

  getRanges () {
    const previousRanges = this.previous && this.previous.getRanges()
    const result = []

    for (const node of this.nodes) {
      let position = node.startPosition
      let index = node.startIndex

      for (const child of node.children) {
        const nextPosition = child.startPosition
        const nextIndex = child.startIndex
        if (nextIndex > index) {
          this._pushRange(previousRanges, result, {
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
        this._pushRange(previousRanges, result, {
          startIndex: index,
          endIndex: node.endIndex,
          startPosition: position,
          endPosition: node.endPosition
        })
      }
    }

    return result
  }

  _pushRange (previousRanges, newRanges, newRange) {
    if (!previousRanges) {
      newRanges.push(newRange)
      return
    }

    for (const previousRange of previousRanges) {
      if (previousRange.endIndex <= newRange.startIndex) continue
      if (previousRange.startIndex >= newRange.endIndex) break
      newRanges.push({
        startIndex: Math.max(previousRange.startIndex, newRange.startIndex),
        endIndex: Math.min(previousRange.endIndex, newRange.endIndex),
        startPosition: Point.max(previousRange.startPosition, newRange.startPosition),
        endPosition: Point.min(previousRange.endPosition, newRange.endPosition)
      })
    }
  }
}

function insertContainingTag (tag, index, tags, indices) {
  const i = indices.findIndex(existingIndex => existingIndex > index)
  if (i === -1) {
    tags.push(tag)
    indices.push(index)
  } else {
    tags.splice(i, 0, tag)
    indices.splice(i, 0, index)
  }
}

// Return true iff `mouse` is smaller than `house`. Only correct if
// mouse and house overlap.
//
// * `mouse` {Range}
// * `house` {Range}
function rangeIsSmaller (mouse, house) {
  if (!house) return true
  const mvec = vecFromRange(mouse)
  const hvec = vecFromRange(house)
  return Point.min(mvec, hvec) === mvec
}

function vecFromRange ({start, end}) {
  return end.translate(start.negate())
}

function rangeForNode (node) {
  return new Range(node.startPosition, node.endPosition)
}

function nodeContainsIndices (node, start, end) {
  if (node.startIndex < start) return node.endIndex >= end
  if (node.startIndex === start) return node.endIndex > end
  return false
}

function nodeIsSmaller (left, right) {
  if (!left) return false
  if (!right) return true
  return left.endIndex - left.startIndex < right.endIndex - right.startIndex
}

function last (array) {
  return array[array.length - 1]
}

function hasMatchingFoldSpec (specs, node) {
  return specs.some(({type, named}) => type === node.type && named === node.isNamed)
}

// TODO: Remove this once TreeSitterLanguageMode implements its own auto-indent system.
[
  '_suggestedIndentForLineWithScopeAtBufferRow',
  'suggestedIndentForEditedBufferRow',
  'increaseIndentRegexForScopeDescriptor',
  'decreaseIndentRegexForScopeDescriptor',
  'decreaseNextIndentRegexForScopeDescriptor',
  'regexForPattern',
  'getNonWordCharacters'
].forEach(methodName => {
  TreeSitterLanguageMode.prototype[methodName] = TextMateLanguageMode.prototype[methodName]
})

TreeSitterLanguageMode.LanguageLayer = LanguageLayer
TreeSitterLanguageMode.prototype.syncOperationLimit = 1000

module.exports = TreeSitterLanguageMode
