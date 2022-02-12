const Parser = require('tree-sitter');
const { Point, Range, spliceArray } = require('text-buffer');
const { Patch } = require('superstring');
const { Emitter } = require('event-kit');
const ScopeDescriptor = require('./scope-descriptor');
const Token = require('./token');
const TokenizedLine = require('./tokenized-line');
const TextMateLanguageMode = require('./text-mate-language-mode');
const { matcherForSelector } = require('./selectors');
const TreeIndenter = require('./tree-indenter');

let nextId = 0;
const MAX_RANGE = new Range(Point.ZERO, Point.INFINITY).freeze();
const PARSER_POOL = [];
const WORD_REGEX = /\w/;

class TreeSitterLanguageMode {
  static _patchSyntaxNode() {
    if (!Parser.SyntaxNode.prototype.hasOwnProperty('range')) {
      Object.defineProperty(Parser.SyntaxNode.prototype, 'range', {
        get() {
          return rangeForNode(this);
        }
      });
    }
  }

  constructor({ buffer, grammar, config, grammars, syncTimeoutMicros }) {
    TreeSitterLanguageMode._patchSyntaxNode();
    this.id = nextId++;
    this.buffer = buffer;
    this.grammar = grammar;
    this.config = config;
    this.grammarRegistry = grammars;
    this.rootLanguageLayer = new LanguageLayer(null, this, grammar, 0);
    this.injectionsMarkerLayer = buffer.addMarkerLayer();

    if (syncTimeoutMicros != null) {
      this.syncTimeoutMicros = syncTimeoutMicros;
    }

    this.rootScopeDescriptor = new ScopeDescriptor({
      scopes: [this.grammar.scopeName]
    });
    this.emitter = new Emitter();
    this.isFoldableCache = [];
    this.hasQueuedParse = false;

    this.grammarForLanguageString = this.grammarForLanguageString.bind(this);

    this.rootLanguageLayer
      .update(null)
      .then(() => this.emitter.emit('did-tokenize'));

    // TODO: Remove this once TreeSitterLanguageMode implements its own auto-indentation system. This
    // is temporarily needed in order to delegate to the TextMateLanguageMode's auto-indent system.
    this.regexesByPattern = {};
  }

  async parseCompletePromise() {
    let done = false;
    while (!done) {
      if (this.rootLanguageLayer.currentParsePromise) {
        await this.rootLanguageLayer.currentParsePromises;
      } else {
        done = true;
        for (const marker of this.injectionsMarkerLayer.getMarkers()) {
          if (marker.languageLayer.currentParsePromise) {
            done = false;
            await marker.languageLayer.currentParsePromise;
            break;
          }
        }
      }
      await new Promise(resolve => setTimeout(resolve, 0));
    }
  }

  destroy() {
    this.injectionsMarkerLayer.destroy();
    this.rootLanguageLayer = null;
  }

  getLanguageId() {
    return this.grammar.scopeName;
  }

  bufferDidChange({ oldRange, newRange, oldText, newText }) {
    const edit = this.rootLanguageLayer._treeEditForBufferChange(
      oldRange.start,
      oldRange.end,
      newRange.end,
      oldText,
      newText
    );
    this.rootLanguageLayer.handleTextChange(edit, oldText, newText);
    for (const marker of this.injectionsMarkerLayer.getMarkers()) {
      marker.languageLayer.handleTextChange(edit, oldText, newText);
    }
  }

  bufferDidFinishTransaction({ changes }) {
    for (let i = 0, { length } = changes; i < length; i++) {
      const { oldRange, newRange } = changes[i];
      spliceArray(
        this.isFoldableCache,
        newRange.start.row,
        oldRange.end.row - oldRange.start.row,
        { length: newRange.end.row - newRange.start.row }
      );
    }
    this.rootLanguageLayer.update(null);
  }

  parse(language, oldTree, ranges) {
    const parser = PARSER_POOL.pop() || new Parser();
    parser.setLanguage(language);
    const result = parser.parseTextBuffer(this.buffer.buffer, oldTree, {
      syncTimeoutMicros: this.syncTimeoutMicros,
      includedRanges: ranges
    });

    if (result.then) {
      return result.then(tree => {
        PARSER_POOL.push(parser);
        return tree;
      });
    } else {
      PARSER_POOL.push(parser);
      return result;
    }
  }

  get tree() {
    return this.rootLanguageLayer.tree;
  }

  updateForInjection(grammar) {
    this.rootLanguageLayer.updateInjections(grammar);
  }

  /*
  Section - Highlighting
  */

  buildHighlightIterator() {
    if (!this.rootLanguageLayer) return new NullLanguageModeHighlightIterator();
    return new HighlightIterator(this);
  }

  onDidTokenize(callback) {
    return this.emitter.on('did-tokenize', callback);
  }

  onDidChangeHighlighting(callback) {
    return this.emitter.on('did-change-highlighting', callback);
  }

  classNameForScopeId(scopeId) {
    return this.grammar.classNameForScopeId(scopeId);
  }

  /*
  Section - Commenting
  */

  commentStringsForPosition(position) {
    const range =
      this.firstNonWhitespaceRange(position.row) ||
      new Range(position, position);
    const { grammar } = this.getSyntaxNodeAndGrammarContainingRange(range);
    return grammar.commentStrings;
  }

  isRowCommented(row) {
    const range = this.firstNonWhitespaceRange(row);
    if (range) {
      const firstNode = this.getSyntaxNodeContainingRange(range);
      if (firstNode) return firstNode.type.includes('comment');
    }
    return false;
  }

  /*
  Section - Indentation
  */

  suggestedIndentForLineAtBufferRow(row, line, tabLength) {
    return this._suggestedIndentForLineWithScopeAtBufferRow(
      row,
      line,
      this.rootScopeDescriptor,
      tabLength
    );
  }

  suggestedIndentForBufferRow(row, tabLength, options) {
    if (!this.treeIndenter) {
      this.treeIndenter = new TreeIndenter(this);
    }

    if (this.treeIndenter.isConfigured) {
      const indent = this.treeIndenter.suggestedIndentForBufferRow(
        row,
        tabLength,
        options
      );
      return indent;
    } else {
      return this._suggestedIndentForLineWithScopeAtBufferRow(
        row,
        this.buffer.lineForRow(row),
        this.rootScopeDescriptor,
        tabLength,
        options
      );
    }
  }

  indentLevelForLine(line, tabLength) {
    let indentLength = 0;
    for (let i = 0, { length } = line; i < length; i++) {
      const char = line[i];
      if (char === '\t') {
        indentLength += tabLength - (indentLength % tabLength);
      } else if (char === ' ') {
        indentLength++;
      } else {
        break;
      }
    }
    return indentLength / tabLength;
  }

  /*
  Section - Folding
  */

  isFoldableAtRow(row) {
    if (this.isFoldableCache[row] != null) return this.isFoldableCache[row];
    const result =
      this.getFoldableRangeContainingPoint(Point(row, Infinity), 0, true) !=
      null;
    this.isFoldableCache[row] = result;
    return result;
  }

  getFoldableRanges() {
    return this.getFoldableRangesAtIndentLevel(null);
  }

  /**
   * TODO: Make this method generate folds for nested languages (currently,
   * folds are only generated for the root language layer).
   */
  getFoldableRangesAtIndentLevel(goalLevel) {
    let result = [];
    let stack = [{ node: this.tree.rootNode, level: 0 }];
    while (stack.length > 0) {
      const { node, level } = stack.pop();

      const range = this.getFoldableRangeForNode(node, this.grammar);
      if (range) {
        if (goalLevel == null || level === goalLevel) {
          let updatedExistingRange = false;
          for (let i = 0, { length } = result; i < length; i++) {
            if (
              result[i].start.row === range.start.row &&
              result[i].end.row === range.end.row
            ) {
              result[i] = range;
              updatedExistingRange = true;
              break;
            }
          }
          if (!updatedExistingRange) result.push(range);
        }
      }

      const parentStartRow = node.startPosition.row;
      const parentEndRow = node.endPosition.row;
      for (
        let children = node.namedChildren, i = 0, { length } = children;
        i < length;
        i++
      ) {
        const child = children[i];
        const { startPosition: childStart, endPosition: childEnd } = child;
        if (childEnd.row > childStart.row) {
          if (
            childStart.row === parentStartRow &&
            childEnd.row === parentEndRow
          ) {
            stack.push({ node: child, level: level });
          } else {
            const childLevel =
              range &&
              range.containsPoint(childStart) &&
              range.containsPoint(childEnd)
                ? level + 1
                : level;
            if (childLevel <= goalLevel || goalLevel == null) {
              stack.push({ node: child, level: childLevel });
            }
          }
        }
      }
    }

    return result.sort((a, b) => a.start.row - b.start.row);
  }

  getFoldableRangeContainingPoint(point, tabLength, existenceOnly = false) {
    if (!this.tree) return null;

    let smallestRange;
    this._forEachTreeWithRange(new Range(point, point), (tree, grammar) => {
      let node = tree.rootNode.descendantForPosition(
        this.buffer.clipPosition(point)
      );
      while (node) {
        if (existenceOnly && node.startPosition.row < point.row) return;
        if (node.endPosition.row > point.row) {
          const range = this.getFoldableRangeForNode(node, grammar);
          if (range && rangeIsSmaller(range, smallestRange)) {
            smallestRange = range;
            return;
          }
        }
        node = node.parent;
      }
    });

    return existenceOnly
      ? smallestRange && smallestRange.start.row === point.row
      : smallestRange;
  }

  _forEachTreeWithRange(range, callback) {
    if (this.rootLanguageLayer.tree) {
      callback(this.rootLanguageLayer.tree, this.rootLanguageLayer.grammar);
    }

    const injectionMarkers = this.injectionsMarkerLayer.findMarkers({
      intersectsRange: range
    });

    for (const injectionMarker of injectionMarkers) {
      const { tree, grammar } = injectionMarker.languageLayer;
      if (tree) callback(tree, grammar);
    }
  }

  getFoldableRangeForNode(node, grammar, existenceOnly) {
    const { children } = node;
    const childCount = children.length;

    for (var i = 0, { length } = grammar.folds; i < length; i++) {
      const foldSpec = grammar.folds[i];

      if (foldSpec.matchers && !hasMatchingFoldSpec(foldSpec.matchers, node))
        continue;

      let foldStart;
      const startEntry = foldSpec.start;
      if (startEntry) {
        let foldStartNode;
        if (startEntry.index != null) {
          foldStartNode = children[startEntry.index];
          if (
            !foldStartNode ||
            (startEntry.matchers &&
              !hasMatchingFoldSpec(startEntry.matchers, foldStartNode))
          )
            continue;
        } else {
          foldStartNode = children.find(child =>
            hasMatchingFoldSpec(startEntry.matchers, child)
          );
          if (!foldStartNode) continue;
        }
        foldStart = new Point(foldStartNode.endPosition.row, Infinity);
      } else {
        foldStart = new Point(node.startPosition.row, Infinity);
      }

      let foldEnd;
      const endEntry = foldSpec.end;
      if (endEntry) {
        let foldEndNode;
        if (endEntry.index != null) {
          const index =
            endEntry.index < 0 ? childCount + endEntry.index : endEntry.index;
          foldEndNode = children[index];
          if (
            !foldEndNode ||
            (endEntry.type && endEntry.type !== foldEndNode.type)
          )
            continue;
        } else {
          foldEndNode = children.find(child =>
            hasMatchingFoldSpec(endEntry.matchers, child)
          );
          if (!foldEndNode) continue;
        }

        if (foldEndNode.startPosition.row <= foldStart.row) continue;

        foldEnd = foldEndNode.startPosition;
        if (
          this.buffer.findInRangeSync(
            WORD_REGEX,
            new Range(foldEnd, new Point(foldEnd.row, Infinity))
          )
        ) {
          foldEnd = new Point(foldEnd.row - 1, Infinity);
        }
      } else {
        const { endPosition } = node;
        if (endPosition.column === 0) {
          foldEnd = Point(endPosition.row - 1, Infinity);
        } else if (childCount > 0) {
          foldEnd = endPosition;
        } else {
          foldEnd = Point(endPosition.row, 0);
        }
      }

      return existenceOnly ? true : new Range(foldStart, foldEnd);
    }
  }

  /*
  Section - Syntax Tree APIs
  */

  getSyntaxNodeContainingRange(range, where = _ => true) {
    return this.getSyntaxNodeAndGrammarContainingRange(range, where).node;
  }

  getSyntaxNodeAndGrammarContainingRange(range, where = _ => true) {
    const startIndex = this.buffer.characterIndexForPosition(range.start);
    const endIndex = this.buffer.characterIndexForPosition(range.end);
    const searchEndIndex = Math.max(0, endIndex - 1);

    let smallestNode = null;
    let smallestNodeGrammar = this.grammar;
    this._forEachTreeWithRange(range, (tree, grammar) => {
      let node = tree.rootNode.descendantForIndex(startIndex, searchEndIndex);
      while (node) {
        if (
          nodeContainsIndices(node, startIndex, endIndex) &&
          where(node, grammar)
        ) {
          if (nodeIsSmaller(node, smallestNode)) {
            smallestNode = node;
            smallestNodeGrammar = grammar;
          }
          break;
        }
        node = node.parent;
      }
    });

    return { node: smallestNode, grammar: smallestNodeGrammar };
  }

  getRangeForSyntaxNodeContainingRange(range, where) {
    const node = this.getSyntaxNodeContainingRange(range, where);
    return node && node.range;
  }

  getSyntaxNodeAtPosition(position, where) {
    return this.getSyntaxNodeContainingRange(
      new Range(position, position),
      where
    );
  }

  bufferRangeForScopeAtPosition(selector, position) {
    const nodeCursorAdapter = new NodeCursorAdaptor();
    if (typeof selector === 'string') {
      const match = matcherForSelector(selector);
      selector = (node, grammar) => {
        const rules = grammar.scopeMap.get([node.type], [0], node.named);
        nodeCursorAdapter.node = node;
        const scopeName = applyLeafRules(rules, nodeCursorAdapter);
        if (scopeName != null) {
          return match(scopeName);
        }
      };
    }
    if (selector === null) selector = undefined;
    const node = this.getSyntaxNodeAtPosition(position, selector);
    return node && node.range;
  }

  /*
  Section - Backward compatibility shims
  */

  tokenizedLineForRow(row) {
    const lineText = this.buffer.lineForRow(row);
    const tokens = [];

    const iterator = this.buildHighlightIterator();
    let start = { row, column: 0 };
    const scopes = iterator.seek(start, row);
    while (true) {
      const end = iterator.getPosition();
      if (end.row > row) {
        end.row = row;
        end.column = lineText.length;
      }

      if (end.column > start.column) {
        tokens.push(
          new Token({
            value: lineText.substring(start.column, end.column),
            scopes: scopes.map(s => this.grammar.scopeNameForScopeId(s))
          })
        );
      }

      if (end.column < lineText.length) {
        const closeScopeCount = iterator.getCloseScopeIds().length;
        for (let i = 0; i < closeScopeCount; i++) {
          scopes.pop();
        }
        scopes.push(...iterator.getOpenScopeIds());
        start = end;
        iterator.moveToSuccessor();
      } else {
        break;
      }
    }

    return new TokenizedLine({
      openScopes: [],
      text: lineText,
      tokens,
      tags: [],
      ruleStack: [],
      lineEnding: this.buffer.lineEndingForRow(row),
      tokenIterator: null,
      grammar: this.grammar
    });
  }

  syntaxTreeScopeDescriptorForPosition(point) {
    const nodes = [];
    point = this.buffer.clipPosition(Point.fromObject(point));

    // If the position is the end of a line, get node of left character instead of newline
    // This is to match TextMate behaviour, see https://github.com/atom/atom/issues/18463
    if (
      point.column > 0 &&
      point.column === this.buffer.lineLengthForRow(point.row)
    ) {
      point = point.copy();
      point.column--;
    }

    this._forEachTreeWithRange(new Range(point, point), tree => {
      let node = tree.rootNode.descendantForPosition(point);
      while (node) {
        nodes.push(node);
        node = node.parent;
      }
    });

    // The nodes are mostly already sorted from smallest to largest,
    // but for files with multiple syntax trees (e.g. ERB), each tree's
    // nodes are separate. Sort the nodes from largest to smallest.
    nodes.reverse();
    nodes.sort(
      (a, b) => a.startIndex - b.startIndex || b.endIndex - a.endIndex
    );

    const nodeTypes = nodes.map(node => node.type);
    nodeTypes.unshift(this.grammar.scopeName);
    return new ScopeDescriptor({ scopes: nodeTypes });
  }

  scopeDescriptorForPosition(point) {
    point = this.buffer.clipPosition(Point.fromObject(point));

    // If the position is the end of a line, get scope of left character instead of newline
    // This is to match TextMate behaviour, see https://github.com/atom/atom/issues/18463
    if (
      point.column > 0 &&
      point.column === this.buffer.lineLengthForRow(point.row)
    ) {
      point = point.copy();
      point.column--;
    }

    const iterator = this.buildHighlightIterator();
    const scopes = [];
    for (const scope of iterator.seek(point, point.row + 1)) {
      scopes.push(this.grammar.scopeNameForScopeId(scope));
    }
    if (point.isEqual(iterator.getPosition())) {
      for (const scope of iterator.getOpenScopeIds()) {
        scopes.push(this.grammar.scopeNameForScopeId(scope));
      }
    }
    if (scopes.length === 0 || scopes[0] !== this.grammar.scopeName) {
      scopes.unshift(this.grammar.scopeName);
    }
    return new ScopeDescriptor({ scopes });
  }

  tokenForPosition(point) {
    const node = this.getSyntaxNodeAtPosition(point);
    const scopes = this.scopeDescriptorForPosition(point).getScopesArray();
    return new Token({ value: node.text, scopes });
  }

  getGrammar() {
    return this.grammar;
  }

  /*
  Section - Private
  */

  firstNonWhitespaceRange(row) {
    return this.buffer.findInRangeSync(
      /\S/,
      new Range(new Point(row, 0), new Point(row, Infinity))
    );
  }

  grammarForLanguageString(languageString) {
    return this.grammarRegistry.treeSitterGrammarForLanguageString(
      languageString
    );
  }

  emitRangeUpdate(range) {
    const startRow = range.start.row;
    const endRow = range.end.row;
    for (let row = startRow; row < endRow; row++) {
      this.isFoldableCache[row] = undefined;
    }
    this.emitter.emit('did-change-highlighting', range);
  }
}

class LanguageLayer {
  constructor(marker, languageMode, grammar, depth) {
    this.marker = marker;
    this.languageMode = languageMode;
    this.grammar = grammar;
    this.tree = null;
    this.currentParsePromise = null;
    this.patchSinceCurrentParseStarted = null;
    this.depth = depth;
  }

  buildHighlightIterator() {
    if (this.tree) {
      return new LayerHighlightIterator(this, this.tree.walk());
    } else {
      return new NullLayerHighlightIterator();
    }
  }

  handleTextChange(edit, oldText, newText) {
    const { startPosition, oldEndPosition, newEndPosition } = edit;

    if (this.tree) {
      this.tree.edit(edit);
      if (this.editedRange) {
        if (startPosition.isLessThan(this.editedRange.start)) {
          this.editedRange.start = startPosition;
        }
        if (oldEndPosition.isLessThan(this.editedRange.end)) {
          this.editedRange.end = newEndPosition.traverse(
            this.editedRange.end.traversalFrom(oldEndPosition)
          );
        } else {
          this.editedRange.end = newEndPosition;
        }
      } else {
        this.editedRange = new Range(startPosition, newEndPosition);
      }
    }

    if (this.patchSinceCurrentParseStarted) {
      this.patchSinceCurrentParseStarted.splice(
        startPosition,
        oldEndPosition.traversalFrom(startPosition),
        newEndPosition.traversalFrom(startPosition),
        oldText,
        newText
      );
    }
  }

  destroy() {
    this.tree = null;
    this.destroyed = true;
    this.marker.destroy();
    for (const marker of this.languageMode.injectionsMarkerLayer.getMarkers()) {
      if (marker.parentLanguageLayer === this) {
        marker.languageLayer.destroy();
      }
    }
  }

  async update(nodeRangeSet) {
    if (!this.currentParsePromise) {
      while (
        !this.destroyed &&
        (!this.tree || this.tree.rootNode.hasChanges())
      ) {
        const params = { async: false };
        this.currentParsePromise = this._performUpdate(nodeRangeSet, params);
        if (!params.async) break;
        await this.currentParsePromise;
      }
      this.currentParsePromise = null;
    }
  }

  updateInjections(grammar) {
    if (grammar.injectionRegex) {
      if (!this.currentParsePromise)
        this.currentParsePromise = Promise.resolve();
      this.currentParsePromise = this.currentParsePromise.then(async () => {
        await this._populateInjections(MAX_RANGE, null);
        this.currentParsePromise = null;
      });
    }
  }

  async _performUpdate(nodeRangeSet, params) {
    let includedRanges = null;
    if (nodeRangeSet) {
      includedRanges = nodeRangeSet.getRanges(this.languageMode.buffer);
      if (includedRanges.length === 0) {
        const range = this.marker.getRange();
        this.destroy();
        this.languageMode.emitRangeUpdate(range);
        return;
      }
    }

    let affectedRange = this.editedRange;
    this.editedRange = null;

    this.patchSinceCurrentParseStarted = new Patch();
    let tree = this.languageMode.parse(
      this.grammar.languageModule,
      this.tree,
      includedRanges
    );
    if (tree.then) {
      params.async = true;
      tree = await tree;
    }

    const changes = this.patchSinceCurrentParseStarted.getChanges();
    this.patchSinceCurrentParseStarted = null;
    for (const {
      oldStart,
      newStart,
      oldEnd,
      newEnd,
      oldText,
      newText
    } of changes) {
      const newExtent = Point.fromObject(newEnd).traversalFrom(newStart);
      tree.edit(
        this._treeEditForBufferChange(
          newStart,
          oldEnd,
          Point.fromObject(oldStart).traverse(newExtent),
          oldText,
          newText
        )
      );
    }

    if (this.tree) {
      const rangesWithSyntaxChanges = this.tree.getChangedRanges(tree);
      this.tree = tree;

      if (rangesWithSyntaxChanges.length > 0) {
        for (const range of rangesWithSyntaxChanges) {
          this.languageMode.emitRangeUpdate(rangeForNode(range));
        }

        const combinedRangeWithSyntaxChange = new Range(
          rangesWithSyntaxChanges[0].startPosition,
          last(rangesWithSyntaxChanges).endPosition
        );

        if (affectedRange) {
          this.languageMode.emitRangeUpdate(affectedRange);
          affectedRange = affectedRange.union(combinedRangeWithSyntaxChange);
        } else {
          affectedRange = combinedRangeWithSyntaxChange;
        }
      }
    } else {
      this.tree = tree;
      this.languageMode.emitRangeUpdate(rangeForNode(tree.rootNode));
      if (includedRanges) {
        affectedRange = new Range(
          includedRanges[0].startPosition,
          last(includedRanges).endPosition
        );
      } else {
        affectedRange = MAX_RANGE;
      }
    }

    if (affectedRange) {
      const injectionPromise = this._populateInjections(
        affectedRange,
        nodeRangeSet
      );
      if (injectionPromise) {
        params.async = true;
        return injectionPromise;
      }
    }
  }

  _populateInjections(range, nodeRangeSet) {
    const existingInjectionMarkers = this.languageMode.injectionsMarkerLayer
      .findMarkers({ intersectsRange: range })
      .filter(marker => marker.parentLanguageLayer === this);

    if (existingInjectionMarkers.length > 0) {
      range = range.union(
        new Range(
          existingInjectionMarkers[0].getRange().start,
          last(existingInjectionMarkers).getRange().end
        )
      );
    }

    const markersToUpdate = new Map();
    const nodes = this.tree.rootNode.descendantsOfType(
      Object.keys(this.grammar.injectionPointsByType),
      range.start,
      range.end
    );

    let existingInjectionMarkerIndex = 0;
    for (const node of nodes) {
      for (const injectionPoint of this.grammar.injectionPointsByType[
        node.type
      ]) {
        const languageName = injectionPoint.language(node);
        if (!languageName) continue;

        const grammar = this.languageMode.grammarForLanguageString(
          languageName
        );
        if (!grammar) continue;

        const contentNodes = injectionPoint.content(node);
        if (!contentNodes) continue;

        const injectionNodes = [].concat(contentNodes);
        if (!injectionNodes.length) continue;

        const injectionRange = rangeForNode(node);

        let marker;
        for (
          let i = existingInjectionMarkerIndex,
            n = existingInjectionMarkers.length;
          i < n;
          i++
        ) {
          const existingMarker = existingInjectionMarkers[i];
          const comparison = existingMarker.getRange().compare(injectionRange);
          if (comparison > 0) {
            break;
          } else if (comparison === 0) {
            existingInjectionMarkerIndex = i;
            if (existingMarker.languageLayer.grammar === grammar) {
              marker = existingMarker;
              break;
            }
          } else {
            existingInjectionMarkerIndex = i;
          }
        }

        if (!marker) {
          marker = this.languageMode.injectionsMarkerLayer.markRange(
            injectionRange
          );
          marker.languageLayer = new LanguageLayer(
            marker,
            this.languageMode,
            grammar,
            this.depth + 1
          );
          marker.parentLanguageLayer = this;
        }

        markersToUpdate.set(
          marker,
          new NodeRangeSet(
            nodeRangeSet,
            injectionNodes,
            injectionPoint.newlinesBetween,
            injectionPoint.includeChildren
          )
        );
      }
    }

    for (const marker of existingInjectionMarkers) {
      if (!markersToUpdate.has(marker)) {
        this.languageMode.emitRangeUpdate(marker.getRange());
        marker.languageLayer.destroy();
      }
    }

    if (markersToUpdate.size > 0) {
      const promises = [];
      for (const [marker, nodeRangeSet] of markersToUpdate) {
        promises.push(marker.languageLayer.update(nodeRangeSet));
      }
      return Promise.all(promises);
    }
  }

  _treeEditForBufferChange(start, oldEnd, newEnd, oldText, newText) {
    const startIndex = this.languageMode.buffer.characterIndexForPosition(
      start
    );
    return {
      startIndex,
      oldEndIndex: startIndex + oldText.length,
      newEndIndex: startIndex + newText.length,
      startPosition: start,
      oldEndPosition: oldEnd,
      newEndPosition: newEnd
    };
  }
}

class HighlightIterator {
  constructor(languageMode) {
    this.languageMode = languageMode;
    this.iterators = null;
  }

  seek(targetPosition, endRow) {
    const injectionMarkers = this.languageMode.injectionsMarkerLayer.findMarkers(
      {
        intersectsRange: new Range(targetPosition, new Point(endRow + 1, 0))
      }
    );

    const containingTags = [];
    const containingTagStartIndices = [];
    const targetIndex = this.languageMode.buffer.characterIndexForPosition(
      targetPosition
    );

    this.iterators = [];
    const iterator = this.languageMode.rootLanguageLayer.buildHighlightIterator();
    if (iterator.seek(targetIndex, containingTags, containingTagStartIndices)) {
      this.iterators.push(iterator);
    }

    // Populate the iterators array with all of the iterators whose syntax
    // trees span the given position.
    for (const marker of injectionMarkers) {
      const iterator = marker.languageLayer.buildHighlightIterator();
      if (
        iterator.seek(targetIndex, containingTags, containingTagStartIndices)
      ) {
        this.iterators.push(iterator);
      }
    }

    // Sort the iterators so that the last one in the array is the earliest
    // in the document, and represents the current position.
    this.iterators.sort((a, b) => b.compare(a));
    this.detectCoveredScope();

    return containingTags;
  }

  moveToSuccessor() {
    // Advance the earliest layer iterator to its next scope boundary.
    let leader = last(this.iterators);

    // Maintain the sorting of the iterators by their position in the document.
    if (leader.moveToSuccessor()) {
      const leaderIndex = this.iterators.length - 1;
      let i = leaderIndex;
      while (i > 0 && this.iterators[i - 1].compare(leader) < 0) i--;
      if (i < leaderIndex) {
        this.iterators.splice(i, 0, this.iterators.pop());
      }
    } else {
      // If the layer iterator was at the end of its syntax tree, then remove
      // it from the array.
      this.iterators.pop();
    }

    this.detectCoveredScope();
  }

  // Detect whether or not another more deeply-nested language layer has a
  // scope boundary at this same position. If so, the current language layer's
  // scope boundary should not be reported.
  detectCoveredScope() {
    const layerCount = this.iterators.length;
    if (layerCount > 1) {
      const first = this.iterators[layerCount - 1];
      const next = this.iterators[layerCount - 2];
      if (
        next.offset === first.offset &&
        next.atEnd === first.atEnd &&
        next.depth > first.depth &&
        !next.isAtInjectionBoundary()
      ) {
        this.currentScopeIsCovered = true;
        return;
      }
    }
    this.currentScopeIsCovered = false;
  }

  getPosition() {
    const iterator = last(this.iterators);
    if (iterator) {
      return iterator.getPosition();
    } else {
      return Point.INFINITY;
    }
  }

  getCloseScopeIds() {
    const iterator = last(this.iterators);
    if (iterator && !this.currentScopeIsCovered) {
      return iterator.getCloseScopeIds();
    }
    return [];
  }

  getOpenScopeIds() {
    const iterator = last(this.iterators);
    if (iterator && !this.currentScopeIsCovered) {
      return iterator.getOpenScopeIds();
    }
    return [];
  }

  logState() {
    const iterator = last(this.iterators);
    if (iterator && iterator.treeCursor) {
      console.log(
        iterator.getPosition(),
        iterator.treeCursor.nodeType,
        `depth=${iterator.languageLayer.depth}`,
        new Range(
          iterator.languageLayer.tree.rootNode.startPosition,
          iterator.languageLayer.tree.rootNode.endPosition
        ).toString()
      );
      if (this.currentScopeIsCovered) {
        console.log('covered');
      } else {
        console.log(
          'close',
          iterator.closeTags.map(id =>
            this.languageMode.grammar.scopeNameForScopeId(id)
          )
        );
        console.log(
          'open',
          iterator.openTags.map(id =>
            this.languageMode.grammar.scopeNameForScopeId(id)
          )
        );
      }
    }
  }
}

class LayerHighlightIterator {
  constructor(languageLayer, treeCursor) {
    this.languageLayer = languageLayer;
    this.depth = this.languageLayer.depth;

    // The iterator is always positioned at either the start or the end of some node
    // in the syntax tree.
    this.atEnd = false;
    this.treeCursor = treeCursor;
    this.offset = 0;

    // In order to determine which selectors match its current node, the iterator maintains
    // a list of the current node's ancestors. Because the selectors can use the `:nth-child`
    // pseudo-class, each node's child index is also stored.
    this.containingNodeTypes = [];
    this.containingNodeChildIndices = [];
    this.containingNodeEndIndices = [];

    // At any given position, the iterator exposes the list of class names that should be
    // *ended* at its current position and the list of class names that should be *started*
    // at its current position.
    this.closeTags = [];
    this.openTags = [];
  }

  seek(targetIndex, containingTags, containingTagStartIndices) {
    while (this.treeCursor.gotoParent()) {}

    this.atEnd = true;
    this.closeTags.length = 0;
    this.openTags.length = 0;
    this.containingNodeTypes.length = 0;
    this.containingNodeChildIndices.length = 0;
    this.containingNodeEndIndices.length = 0;

    const containingTagEndIndices = [];

    if (targetIndex >= this.treeCursor.endIndex) {
      return false;
    }

    let childIndex = -1;
    for (;;) {
      this.containingNodeTypes.push(this.treeCursor.nodeType);
      this.containingNodeChildIndices.push(childIndex);
      this.containingNodeEndIndices.push(this.treeCursor.endIndex);

      const scopeId = this._currentScopeId();
      if (scopeId) {
        if (this.treeCursor.startIndex < targetIndex) {
          insertContainingTag(
            scopeId,
            this.treeCursor.startIndex,
            containingTags,
            containingTagStartIndices
          );
          containingTagEndIndices.push(this.treeCursor.endIndex);
        } else {
          this.atEnd = false;
          this.openTags.push(scopeId);
          this._moveDown();
          break;
        }
      }

      childIndex = this.treeCursor.gotoFirstChildForIndex(targetIndex);
      if (childIndex === null) break;
      if (this.treeCursor.startIndex >= targetIndex) this.atEnd = false;
    }

    if (this.atEnd) {
      this.offset = this.treeCursor.endIndex;
      for (let i = 0, { length } = containingTags; i < length; i++) {
        if (containingTagEndIndices[i] === this.offset) {
          this.closeTags.push(containingTags[i]);
        }
      }
    } else {
      this.offset = this.treeCursor.startIndex;
    }

    return true;
  }

  moveToSuccessor() {
    this.closeTags.length = 0;
    this.openTags.length = 0;

    while (!this.closeTags.length && !this.openTags.length) {
      if (this.atEnd) {
        if (this._moveRight()) {
          const scopeId = this._currentScopeId();
          if (scopeId) this.openTags.push(scopeId);
          this.atEnd = false;
          this._moveDown();
        } else if (this._moveUp(true)) {
          this.atEnd = true;
        } else {
          return false;
        }
      } else if (!this._moveDown()) {
        const scopeId = this._currentScopeId();
        if (scopeId) this.closeTags.push(scopeId);
        this.atEnd = true;
        this._moveUp(false);
      }
    }

    if (this.atEnd) {
      this.offset = this.treeCursor.endIndex;
    } else {
      this.offset = this.treeCursor.startIndex;
    }

    return true;
  }

  getPosition() {
    if (this.atEnd) {
      return this.treeCursor.endPosition;
    } else {
      return this.treeCursor.startPosition;
    }
  }

  compare(other) {
    const result = this.offset - other.offset;
    if (result !== 0) return result;
    if (this.atEnd && !other.atEnd) return -1;
    if (other.atEnd && !this.atEnd) return 1;
    return this.languageLayer.depth - other.languageLayer.depth;
  }

  getCloseScopeIds() {
    return this.closeTags.slice();
  }

  getOpenScopeIds() {
    return this.openTags.slice();
  }

  isAtInjectionBoundary() {
    return this.containingNodeTypes.length === 1;
  }

  // Private methods

  _moveUp(atLastChild) {
    let result = false;
    const { endIndex } = this.treeCursor;
    let depth = this.containingNodeEndIndices.length;

    // The iterator should not move up until it has visited all of the children of this node.
    while (
      depth > 1 &&
      (atLastChild || this.containingNodeEndIndices[depth - 2] === endIndex)
    ) {
      atLastChild = false;
      result = true;
      this.treeCursor.gotoParent();
      this.containingNodeTypes.pop();
      this.containingNodeChildIndices.pop();
      this.containingNodeEndIndices.pop();
      --depth;
      const scopeId = this._currentScopeId();
      if (scopeId) this.closeTags.push(scopeId);
    }
    return result;
  }

  _moveDown() {
    let result = false;
    const { startIndex } = this.treeCursor;

    // Once the iterator has found a scope boundary, it needs to stay at the same
    // position, so it should not move down if the first child node starts later than the
    // current node.
    while (this.treeCursor.gotoFirstChild()) {
      if (
        (this.closeTags.length || this.openTags.length) &&
        this.treeCursor.startIndex > startIndex
      ) {
        this.treeCursor.gotoParent();
        break;
      }

      result = true;
      this.containingNodeTypes.push(this.treeCursor.nodeType);
      this.containingNodeChildIndices.push(0);
      this.containingNodeEndIndices.push(this.treeCursor.endIndex);

      const scopeId = this._currentScopeId();
      if (scopeId) this.openTags.push(scopeId);
    }

    return result;
  }

  _moveRight() {
    if (this.treeCursor.gotoNextSibling()) {
      const depth = this.containingNodeTypes.length;
      this.containingNodeTypes[depth - 1] = this.treeCursor.nodeType;
      this.containingNodeChildIndices[depth - 1]++;
      this.containingNodeEndIndices[depth - 1] = this.treeCursor.endIndex;
      return true;
    }
  }

  _currentScopeId() {
    const value = this.languageLayer.grammar.scopeMap.get(
      this.containingNodeTypes,
      this.containingNodeChildIndices,
      this.treeCursor.nodeIsNamed
    );
    const scopeName = applyLeafRules(value, this.treeCursor);
    const node = this.treeCursor.currentNode;
    if (!node.childCount) {
      return this.languageLayer.languageMode.grammar.idForScope(
        scopeName,
        node.text
      );
    } else if (scopeName) {
      return this.languageLayer.languageMode.grammar.idForScope(scopeName);
    }
  }
}

const applyLeafRules = (rules, cursor) => {
  if (!rules || typeof rules === 'string') return rules;
  if (Array.isArray(rules)) {
    for (let i = 0, { length } = rules; i !== length; ++i) {
      const result = applyLeafRules(rules[i], cursor);
      if (result) return result;
    }
    return undefined;
  }
  if (typeof rules === 'object') {
    if (rules.exact) {
      return cursor.nodeText === rules.exact
        ? applyLeafRules(rules.scopes, cursor)
        : undefined;
    }
    if (rules.match) {
      return rules.match.test(cursor.nodeText)
        ? applyLeafRules(rules.scopes, cursor)
        : undefined;
    }
  }
};

class NodeCursorAdaptor {
  get nodeText() {
    return this.node.text;
  }
}

class NullLanguageModeHighlightIterator {
  seek() {
    return [];
  }
  compare() {
    return 1;
  }
  moveToSuccessor() {}
  getPosition() {
    return Point.INFINITY;
  }
  getOpenScopeIds() {
    return [];
  }
  getCloseScopeIds() {
    return [];
  }
}

class NullLayerHighlightIterator {
  seek() {
    return null;
  }
  compare() {
    return 1;
  }
  moveToSuccessor() {}
  getPosition() {
    return Point.INFINITY;
  }
  getOpenScopeIds() {
    return [];
  }
  getCloseScopeIds() {
    return [];
  }
}

class NodeRangeSet {
  constructor(previous, nodes, newlinesBetween, includeChildren) {
    this.previous = previous;
    this.nodes = nodes;
    this.newlinesBetween = newlinesBetween;
    this.includeChildren = includeChildren;
  }

  getRanges(buffer) {
    const previousRanges = this.previous && this.previous.getRanges(buffer);
    const result = [];

    for (const node of this.nodes) {
      let position = node.startPosition;
      let index = node.startIndex;

      if (!this.includeChildren) {
        for (const child of node.children) {
          const nextIndex = child.startIndex;
          if (nextIndex > index) {
            this._pushRange(buffer, previousRanges, result, {
              startIndex: index,
              endIndex: nextIndex,
              startPosition: position,
              endPosition: child.startPosition
            });
          }
          position = child.endPosition;
          index = child.endIndex;
        }
      }

      if (node.endIndex > index) {
        this._pushRange(buffer, previousRanges, result, {
          startIndex: index,
          endIndex: node.endIndex,
          startPosition: position,
          endPosition: node.endPosition
        });
      }
    }

    return result;
  }

  _pushRange(buffer, previousRanges, newRanges, newRange) {
    if (!previousRanges) {
      if (this.newlinesBetween) {
        const { startIndex, startPosition } = newRange;
        this._ensureNewline(buffer, newRanges, startIndex, startPosition);
      }
      newRanges.push(newRange);
      return;
    }

    for (const previousRange of previousRanges) {
      if (previousRange.endIndex <= newRange.startIndex) continue;
      if (previousRange.startIndex >= newRange.endIndex) break;
      const startIndex = Math.max(
        previousRange.startIndex,
        newRange.startIndex
      );
      const endIndex = Math.min(previousRange.endIndex, newRange.endIndex);
      const startPosition = Point.max(
        previousRange.startPosition,
        newRange.startPosition
      );
      const endPosition = Point.min(
        previousRange.endPosition,
        newRange.endPosition
      );
      if (this.newlinesBetween) {
        this._ensureNewline(buffer, newRanges, startIndex, startPosition);
      }
      newRanges.push({ startIndex, endIndex, startPosition, endPosition });
    }
  }

  // For injection points with `newlinesBetween` enabled, ensure that a
  // newline is included between each disjoint range.
  _ensureNewline(buffer, newRanges, startIndex, startPosition) {
    const lastRange = newRanges[newRanges.length - 1];
    if (lastRange && lastRange.endPosition.row < startPosition.row) {
      newRanges.push({
        startPosition: new Point(
          startPosition.row - 1,
          buffer.lineLengthForRow(startPosition.row - 1)
        ),
        endPosition: new Point(startPosition.row, 0),
        startIndex: startIndex - startPosition.column - 1,
        endIndex: startIndex - startPosition.column
      });
    }
  }
}

function insertContainingTag(tag, index, tags, indices) {
  const i = indices.findIndex(existingIndex => existingIndex > index);
  if (i === -1) {
    tags.push(tag);
    indices.push(index);
  } else {
    tags.splice(i, 0, tag);
    indices.splice(i, 0, index);
  }
}

// Return true iff `mouse` is smaller than `house`. Only correct if
// mouse and house overlap.
//
// * `mouse` {Range}
// * `house` {Range}
function rangeIsSmaller(mouse, house) {
  if (!house) return true;
  const mvec = vecFromRange(mouse);
  const hvec = vecFromRange(house);
  return Point.min(mvec, hvec) === mvec;
}

function vecFromRange({ start, end }) {
  return end.translate(start.negate());
}

function rangeForNode(node) {
  return new Range(node.startPosition, node.endPosition);
}

function nodeContainsIndices(node, start, end) {
  if (node.startIndex < start) return node.endIndex >= end;
  if (node.startIndex === start) return node.endIndex > end;
  return false;
}

function nodeIsSmaller(left, right) {
  if (!left) return false;
  if (!right) return true;
  return left.endIndex - left.startIndex < right.endIndex - right.startIndex;
}

function last(array) {
  return array[array.length - 1];
}

function hasMatchingFoldSpec(specs, node) {
  return specs.some(
    ({ type, named }) => type === node.type && named === node.isNamed
  );
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
  TreeSitterLanguageMode.prototype[methodName] =
    TextMateLanguageMode.prototype[methodName];
});

TreeSitterLanguageMode.LanguageLayer = LanguageLayer;
TreeSitterLanguageMode.prototype.syncTimeoutMicros = 1000;

module.exports = TreeSitterLanguageMode;
