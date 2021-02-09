const _ = require('underscore-plus');
const { CompositeDisposable, Emitter } = require('event-kit');
const { Point, Range } = require('text-buffer');
const TokenizedLine = require('./tokenized-line');
const TokenIterator = require('./token-iterator');
const ScopeDescriptor = require('./scope-descriptor');
const NullGrammar = require('./null-grammar');
const { OnigRegExp } = require('oniguruma');
const {
  toFirstMateScopeId,
  fromFirstMateScopeId
} = require('./first-mate-helpers');
const { selectorMatchesAnyScope } = require('./selectors');

const NON_WHITESPACE_REGEX = /\S/;

let nextId = 0;
const prefixedScopes = new Map();

class TextMateLanguageMode {
  constructor(params) {
    this.emitter = new Emitter();
    this.disposables = new CompositeDisposable();
    this.tokenIterator = new TokenIterator(this);
    this.regexesByPattern = {};

    this.alive = true;
    this.tokenizationStarted = false;
    this.id = params.id != null ? params.id : nextId++;
    this.buffer = params.buffer;
    this.largeFileMode = params.largeFileMode;
    this.config = params.config;
    this.largeFileMode =
      params.largeFileMode != null
        ? params.largeFileMode
        : this.buffer.buffer.getLength() >= 2 * 1024 * 1024;

    this.grammar = params.grammar || NullGrammar;
    this.rootScopeDescriptor = new ScopeDescriptor({
      scopes: [this.grammar.scopeName]
    });
    this.disposables.add(
      this.grammar.onDidUpdate(() => this.retokenizeLines())
    );
    this.retokenizeLines();
  }

  destroy() {
    if (!this.alive) return;
    this.alive = false;
    this.disposables.dispose();
    this.tokenizedLines.length = 0;
  }

  isAlive() {
    return this.alive;
  }

  isDestroyed() {
    return !this.alive;
  }

  getGrammar() {
    return this.grammar;
  }

  getLanguageId() {
    return this.grammar.scopeName;
  }

  getNonWordCharacters(position) {
    const scope = this.scopeDescriptorForPosition(position);
    return this.config.get('editor.nonWordCharacters', { scope });
  }

  /*
  Section - auto-indent
  */

  // Get the suggested indentation level for an existing line in the buffer.
  //
  // * bufferRow - A {Number} indicating the buffer row
  //
  // Returns a {Number}.
  suggestedIndentForBufferRow(bufferRow, tabLength, options) {
    const line = this.buffer.lineForRow(bufferRow);
    const tokenizedLine = this.tokenizedLineForRow(bufferRow);
    const iterator = tokenizedLine.getTokenIterator();
    iterator.next();
    const scopeDescriptor = new ScopeDescriptor({
      scopes: iterator.getScopes()
    });
    return this._suggestedIndentForLineWithScopeAtBufferRow(
      bufferRow,
      line,
      scopeDescriptor,
      tabLength,
      options
    );
  }

  // Get the suggested indentation level for a given line of text, if it were inserted at the given
  // row in the buffer.
  //
  // * bufferRow - A {Number} indicating the buffer row
  //
  // Returns a {Number}.
  suggestedIndentForLineAtBufferRow(bufferRow, line, tabLength) {
    const tokenizedLine = this.buildTokenizedLineForRowWithText(
      bufferRow,
      line
    );
    const iterator = tokenizedLine.getTokenIterator();
    iterator.next();
    const scopeDescriptor = new ScopeDescriptor({
      scopes: iterator.getScopes()
    });
    return this._suggestedIndentForLineWithScopeAtBufferRow(
      bufferRow,
      line,
      scopeDescriptor,
      tabLength
    );
  }

  // Get the suggested indentation level for a line in the buffer on which the user is currently
  // typing. This may return a different result from {::suggestedIndentForBufferRow} in order
  // to avoid unexpected changes in indentation. It may also return undefined if no change should
  // be made.
  //
  // * bufferRow - The row {Number}
  //
  // Returns a {Number}.
  suggestedIndentForEditedBufferRow(bufferRow, tabLength) {
    const line = this.buffer.lineForRow(bufferRow);
    const currentIndentLevel = this.indentLevelForLine(line, tabLength);
    if (currentIndentLevel === 0) return;

    const scopeDescriptor = this.scopeDescriptorForPosition(
      new Point(bufferRow, 0)
    );
    const decreaseIndentRegex = this.decreaseIndentRegexForScopeDescriptor(
      scopeDescriptor
    );
    if (!decreaseIndentRegex) return;

    if (!decreaseIndentRegex.testSync(line)) return;

    const precedingRow = this.buffer.previousNonBlankRow(bufferRow);
    if (precedingRow == null) return;

    const precedingLine = this.buffer.lineForRow(precedingRow);
    let desiredIndentLevel = this.indentLevelForLine(precedingLine, tabLength);

    const increaseIndentRegex = this.increaseIndentRegexForScopeDescriptor(
      scopeDescriptor
    );
    if (increaseIndentRegex) {
      if (!increaseIndentRegex.testSync(precedingLine)) desiredIndentLevel -= 1;
    }

    const decreaseNextIndentRegex = this.decreaseNextIndentRegexForScopeDescriptor(
      scopeDescriptor
    );
    if (decreaseNextIndentRegex) {
      if (decreaseNextIndentRegex.testSync(precedingLine))
        desiredIndentLevel -= 1;
    }

    if (desiredIndentLevel < 0) return 0;
    if (desiredIndentLevel >= currentIndentLevel) return;
    return desiredIndentLevel;
  }

  _suggestedIndentForLineWithScopeAtBufferRow(
    bufferRow,
    line,
    scopeDescriptor,
    tabLength,
    options
  ) {
    const increaseIndentRegex = this.increaseIndentRegexForScopeDescriptor(
      scopeDescriptor
    );
    const decreaseIndentRegex = this.decreaseIndentRegexForScopeDescriptor(
      scopeDescriptor
    );
    const decreaseNextIndentRegex = this.decreaseNextIndentRegexForScopeDescriptor(
      scopeDescriptor
    );

    let precedingRow;
    if (!options || options.skipBlankLines !== false) {
      precedingRow = this.buffer.previousNonBlankRow(bufferRow);
      if (precedingRow == null) return 0;
    } else {
      precedingRow = bufferRow - 1;
      if (precedingRow < 0) return 0;
    }

    const precedingLine = this.buffer.lineForRow(precedingRow);
    let desiredIndentLevel = this.indentLevelForLine(precedingLine, tabLength);
    if (!increaseIndentRegex) return desiredIndentLevel;

    if (!this.isRowCommented(precedingRow)) {
      if (increaseIndentRegex && increaseIndentRegex.testSync(precedingLine))
        desiredIndentLevel += 1;
      if (
        decreaseNextIndentRegex &&
        decreaseNextIndentRegex.testSync(precedingLine)
      )
        desiredIndentLevel -= 1;
    }

    if (!this.buffer.isRowBlank(precedingRow)) {
      if (decreaseIndentRegex && decreaseIndentRegex.testSync(line))
        desiredIndentLevel -= 1;
    }

    return Math.max(desiredIndentLevel, 0);
  }

  /*
  Section - Comments
  */

  commentStringsForPosition(position) {
    const scope = this.scopeDescriptorForPosition(position);
    const commentStartEntries = this.config.getAll('editor.commentStart', {
      scope
    });
    const commentEndEntries = this.config.getAll('editor.commentEnd', {
      scope
    });
    const commentStartEntry = commentStartEntries[0];
    const commentEndEntry = commentEndEntries.find(entry => {
      return entry.scopeSelector === commentStartEntry.scopeSelector;
    });
    return {
      commentStartString: commentStartEntry && commentStartEntry.value,
      commentEndString: commentEndEntry && commentEndEntry.value
    };
  }

  /*
  Section - Syntax Highlighting
  */

  buildHighlightIterator() {
    return new TextMateHighlightIterator(this);
  }

  classNameForScopeId(id) {
    const scope = this.grammar.scopeForId(toFirstMateScopeId(id));
    if (scope) {
      let prefixedScope = prefixedScopes.get(scope);
      if (prefixedScope) {
        return prefixedScope;
      } else {
        prefixedScope = `syntax--${scope.replace(/\./g, ' syntax--')}`;
        prefixedScopes.set(scope, prefixedScope);
        return prefixedScope;
      }
    } else {
      return null;
    }
  }

  getInvalidatedRanges() {
    return [];
  }

  onDidChangeHighlighting(fn) {
    return this.emitter.on('did-change-highlighting', fn);
  }

  onDidTokenize(callback) {
    return this.emitter.on('did-tokenize', callback);
  }

  getGrammarSelectionContent() {
    return this.buffer.getTextInRange([[0, 0], [10, 0]]);
  }

  updateForInjection(grammar) {
    if (!grammar.injectionSelector) return;
    for (const tokenizedLine of this.tokenizedLines) {
      if (tokenizedLine) {
        for (let token of tokenizedLine.tokens) {
          if (grammar.injectionSelector.matches(token.scopes)) {
            this.retokenizeLines();
            return;
          }
        }
      }
    }
  }

  retokenizeLines() {
    if (!this.alive) return;
    this.fullyTokenized = false;
    this.tokenizedLines = new Array(this.buffer.getLineCount());
    this.invalidRows = [];
    if (this.largeFileMode || this.grammar.name === 'Null Grammar') {
      this.markTokenizationComplete();
    } else {
      this.invalidateRow(0);
    }
  }

  startTokenizing() {
    this.tokenizationStarted = true;
    if (this.grammar.name !== 'Null Grammar' && !this.largeFileMode) {
      this.tokenizeInBackground();
    }
  }

  tokenizeInBackground() {
    if (!this.tokenizationStarted || this.pendingChunk || !this.alive) return;

    this.pendingChunk = true;
    _.defer(() => {
      this.pendingChunk = false;
      if (this.isAlive() && this.buffer.isAlive()) this.tokenizeNextChunk();
    });
  }

  tokenizeNextChunk() {
    let rowsRemaining = this.chunkSize;

    while (this.firstInvalidRow() != null && rowsRemaining > 0) {
      var endRow, filledRegion;
      const startRow = this.invalidRows.shift();
      const lastRow = this.buffer.getLastRow();
      if (startRow > lastRow) continue;

      let row = startRow;
      while (true) {
        const previousStack = this.stackForRow(row);
        this.tokenizedLines[row] = this.buildTokenizedLineForRow(
          row,
          this.stackForRow(row - 1),
          this.openScopesForRow(row)
        );
        if (--rowsRemaining === 0) {
          filledRegion = false;
          endRow = row;
          break;
        }
        if (
          row === lastRow ||
          _.isEqual(this.stackForRow(row), previousStack)
        ) {
          filledRegion = true;
          endRow = row;
          break;
        }
        row++;
      }

      this.validateRow(endRow);
      if (!filledRegion) this.invalidateRow(endRow + 1);

      this.emitter.emit(
        'did-change-highlighting',
        Range(Point(startRow, 0), Point(endRow + 1, 0))
      );
    }

    if (this.firstInvalidRow() != null) {
      this.tokenizeInBackground();
    } else {
      this.markTokenizationComplete();
    }
  }

  markTokenizationComplete() {
    if (!this.fullyTokenized) {
      this.emitter.emit('did-tokenize');
    }
    this.fullyTokenized = true;
  }

  firstInvalidRow() {
    return this.invalidRows[0];
  }

  validateRow(row) {
    while (this.invalidRows[0] <= row) this.invalidRows.shift();
  }

  invalidateRow(row) {
    this.invalidRows.push(row);
    this.invalidRows.sort((a, b) => a - b);
    this.tokenizeInBackground();
  }

  updateInvalidRows(start, end, delta) {
    this.invalidRows = this.invalidRows.map(row => {
      if (row < start) {
        return row;
      } else if (start <= row && row <= end) {
        return end + delta + 1;
      } else if (row > end) {
        return row + delta;
      }
    });
  }

  bufferDidChange(e) {
    this.changeCount = this.buffer.changeCount;

    const { oldRange, newRange } = e;
    const start = oldRange.start.row;
    const end = oldRange.end.row;
    const delta = newRange.end.row - oldRange.end.row;
    const oldLineCount = oldRange.end.row - oldRange.start.row + 1;
    const newLineCount = newRange.end.row - newRange.start.row + 1;

    this.updateInvalidRows(start, end, delta);
    const previousEndStack = this.stackForRow(end); // used in spill detection below
    if (this.largeFileMode || this.grammar.name === 'Null Grammar') {
      _.spliceWithArray(
        this.tokenizedLines,
        start,
        oldLineCount,
        new Array(newLineCount)
      );
    } else {
      const newTokenizedLines = this.buildTokenizedLinesForRows(
        start,
        end + delta,
        this.stackForRow(start - 1),
        this.openScopesForRow(start)
      );
      _.spliceWithArray(
        this.tokenizedLines,
        start,
        oldLineCount,
        newTokenizedLines
      );
      const newEndStack = this.stackForRow(end + delta);
      if (newEndStack && !_.isEqual(newEndStack, previousEndStack)) {
        this.invalidateRow(end + delta + 1);
      }
    }
  }

  bufferDidFinishTransaction() {}

  isFoldableAtRow(row) {
    return this.endRowForFoldAtRow(row, 1, true) != null;
  }

  buildTokenizedLinesForRows(
    startRow,
    endRow,
    startingStack,
    startingopenScopes
  ) {
    let ruleStack = startingStack;
    let openScopes = startingopenScopes;
    const stopTokenizingAt = startRow + this.chunkSize;
    const tokenizedLines = [];
    for (let row = startRow, end = endRow; row <= end; row++) {
      let tokenizedLine;
      if ((ruleStack || row === 0) && row < stopTokenizingAt) {
        tokenizedLine = this.buildTokenizedLineForRow(
          row,
          ruleStack,
          openScopes
        );
        ruleStack = tokenizedLine.ruleStack;
        openScopes = this.scopesFromTags(openScopes, tokenizedLine.tags);
      }
      tokenizedLines.push(tokenizedLine);
    }

    if (endRow >= stopTokenizingAt) {
      this.invalidateRow(stopTokenizingAt);
      this.tokenizeInBackground();
    }

    return tokenizedLines;
  }

  buildTokenizedLineForRow(row, ruleStack, openScopes) {
    return this.buildTokenizedLineForRowWithText(
      row,
      this.buffer.lineForRow(row),
      ruleStack,
      openScopes
    );
  }

  buildTokenizedLineForRowWithText(
    row,
    text,
    currentRuleStack = this.stackForRow(row - 1),
    openScopes = this.openScopesForRow(row)
  ) {
    const lineEnding = this.buffer.lineEndingForRow(row);
    const { tags, ruleStack } = this.grammar.tokenizeLine(
      text,
      currentRuleStack,
      row === 0,
      false
    );
    return new TokenizedLine({
      openScopes,
      text,
      tags,
      ruleStack,
      lineEnding,
      tokenIterator: this.tokenIterator,
      grammar: this.grammar
    });
  }

  tokenizedLineForRow(bufferRow) {
    if (bufferRow >= 0 && bufferRow <= this.buffer.getLastRow()) {
      const tokenizedLine = this.tokenizedLines[bufferRow];
      if (tokenizedLine) {
        return tokenizedLine;
      } else {
        const text = this.buffer.lineForRow(bufferRow);
        const lineEnding = this.buffer.lineEndingForRow(bufferRow);
        const tags = [
          this.grammar.startIdForScope(this.grammar.scopeName),
          text.length,
          this.grammar.endIdForScope(this.grammar.scopeName)
        ];
        this.tokenizedLines[bufferRow] = new TokenizedLine({
          openScopes: [],
          text,
          tags,
          lineEnding,
          tokenIterator: this.tokenIterator,
          grammar: this.grammar
        });
        return this.tokenizedLines[bufferRow];
      }
    }
  }

  tokenizedLinesForRows(startRow, endRow) {
    const result = [];
    for (let row = startRow, end = endRow; row <= end; row++) {
      result.push(this.tokenizedLineForRow(row));
    }
    return result;
  }

  stackForRow(bufferRow) {
    return (
      this.tokenizedLines[bufferRow] && this.tokenizedLines[bufferRow].ruleStack
    );
  }

  openScopesForRow(bufferRow) {
    const precedingLine = this.tokenizedLines[bufferRow - 1];
    if (precedingLine) {
      return this.scopesFromTags(precedingLine.openScopes, precedingLine.tags);
    } else {
      return [];
    }
  }

  scopesFromTags(startingScopes, tags) {
    const scopes = startingScopes.slice();
    for (const tag of tags) {
      if (tag < 0) {
        if (tag % 2 === -1) {
          scopes.push(tag);
        } else {
          const matchingStartTag = tag + 1;
          while (true) {
            if (scopes.pop() === matchingStartTag) break;
            if (scopes.length === 0) {
              break;
            }
          }
        }
      }
    }
    return scopes;
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

  scopeDescriptorForPosition(position) {
    let scopes;
    const { row, column } = this.buffer.clipPosition(
      Point.fromObject(position)
    );

    const iterator = this.tokenizedLineForRow(row).getTokenIterator();
    while (iterator.next()) {
      if (iterator.getBufferEnd() > column) {
        scopes = iterator.getScopes();
        break;
      }
    }

    // rebuild scope of last token if we iterated off the end
    if (!scopes) {
      scopes = iterator.getScopes();
      scopes.push(...iterator.getScopeEnds().reverse());
    }

    return new ScopeDescriptor({ scopes });
  }

  tokenForPosition(position) {
    const { row, column } = Point.fromObject(position);
    return this.tokenizedLineForRow(row).tokenAtBufferColumn(column);
  }

  tokenStartPositionForPosition(position) {
    let { row, column } = Point.fromObject(position);
    column = this.tokenizedLineForRow(row).tokenStartColumnForBufferColumn(
      column
    );
    return new Point(row, column);
  }

  bufferRangeForScopeAtPosition(selector, position) {
    let endColumn, tag, tokenIndex;
    position = Point.fromObject(position);

    const { openScopes, tags } = this.tokenizedLineForRow(position.row);
    const scopes = openScopes.map(tag => this.grammar.scopeForId(tag));

    let startColumn = 0;
    for (tokenIndex = 0; tokenIndex < tags.length; tokenIndex++) {
      tag = tags[tokenIndex];
      if (tag < 0) {
        if (tag % 2 === -1) {
          scopes.push(this.grammar.scopeForId(tag));
        } else {
          scopes.pop();
        }
      } else {
        endColumn = startColumn + tag;
        if (endColumn >= position.column) {
          break;
        } else {
          startColumn = endColumn;
        }
      }
    }

    if (!selectorMatchesAnyScope(selector, scopes)) return;

    const startScopes = scopes.slice();
    for (
      let startTokenIndex = tokenIndex - 1;
      startTokenIndex >= 0;
      startTokenIndex--
    ) {
      tag = tags[startTokenIndex];
      if (tag < 0) {
        if (tag % 2 === -1) {
          startScopes.pop();
        } else {
          startScopes.push(this.grammar.scopeForId(tag));
        }
      } else {
        if (!selectorMatchesAnyScope(selector, startScopes)) {
          break;
        }
        startColumn -= tag;
      }
    }

    const endScopes = scopes.slice();
    for (
      let endTokenIndex = tokenIndex + 1, end = tags.length;
      endTokenIndex < end;
      endTokenIndex++
    ) {
      tag = tags[endTokenIndex];
      if (tag < 0) {
        if (tag % 2 === -1) {
          endScopes.push(this.grammar.scopeForId(tag));
        } else {
          endScopes.pop();
        }
      } else {
        if (!selectorMatchesAnyScope(selector, endScopes)) {
          break;
        }
        endColumn += tag;
      }
    }

    return new Range(
      new Point(position.row, startColumn),
      new Point(position.row, endColumn)
    );
  }

  isRowCommented(row) {
    return this.tokenizedLines[row] && this.tokenizedLines[row].isComment();
  }

  getFoldableRangeContainingPoint(point, tabLength) {
    if (point.column >= this.buffer.lineLengthForRow(point.row)) {
      const endRow = this.endRowForFoldAtRow(point.row, tabLength);
      if (endRow != null) {
        return Range(Point(point.row, Infinity), Point(endRow, Infinity));
      }
    }

    for (let row = point.row - 1; row >= 0; row--) {
      const endRow = this.endRowForFoldAtRow(row, tabLength);
      if (endRow != null && endRow >= point.row) {
        return Range(Point(row, Infinity), Point(endRow, Infinity));
      }
    }
    return null;
  }

  getFoldableRangesAtIndentLevel(indentLevel, tabLength) {
    const result = [];
    let row = 0;
    const lineCount = this.buffer.getLineCount();
    while (row < lineCount) {
      if (
        this.indentLevelForLine(this.buffer.lineForRow(row), tabLength) ===
        indentLevel
      ) {
        const endRow = this.endRowForFoldAtRow(row, tabLength);
        if (endRow != null) {
          result.push(Range(Point(row, Infinity), Point(endRow, Infinity)));
          row = endRow + 1;
          continue;
        }
      }
      row++;
    }
    return result;
  }

  getFoldableRanges(tabLength) {
    const result = [];
    let row = 0;
    const lineCount = this.buffer.getLineCount();
    while (row < lineCount) {
      const endRow = this.endRowForFoldAtRow(row, tabLength);
      if (endRow != null) {
        result.push(Range(Point(row, Infinity), Point(endRow, Infinity)));
      }
      row++;
    }
    return result;
  }

  endRowForFoldAtRow(row, tabLength, existenceOnly = false) {
    if (this.isRowCommented(row)) {
      return this.endRowForCommentFoldAtRow(row, existenceOnly);
    } else {
      return this.endRowForCodeFoldAtRow(row, tabLength, existenceOnly);
    }
  }

  endRowForCommentFoldAtRow(row, existenceOnly) {
    if (this.isRowCommented(row - 1)) return;

    let endRow;
    for (
      let nextRow = row + 1, end = this.buffer.getLineCount();
      nextRow < end;
      nextRow++
    ) {
      if (!this.isRowCommented(nextRow)) break;
      endRow = nextRow;
      if (existenceOnly) break;
    }

    return endRow;
  }

  endRowForCodeFoldAtRow(row, tabLength, existenceOnly) {
    let foldEndRow;
    const line = this.buffer.lineForRow(row);
    if (!NON_WHITESPACE_REGEX.test(line)) return;
    const startIndentLevel = this.indentLevelForLine(line, tabLength);
    const scopeDescriptor = this.scopeDescriptorForPosition([row, 0]);
    const foldEndRegex = this.foldEndRegexForScopeDescriptor(scopeDescriptor);
    for (
      let nextRow = row + 1, end = this.buffer.getLineCount();
      nextRow < end;
      nextRow++
    ) {
      const line = this.buffer.lineForRow(nextRow);
      if (!NON_WHITESPACE_REGEX.test(line)) continue;
      const indentation = this.indentLevelForLine(line, tabLength);
      if (indentation < startIndentLevel) {
        break;
      } else if (indentation === startIndentLevel) {
        if (foldEndRegex && foldEndRegex.searchSync(line)) foldEndRow = nextRow;
        break;
      }
      foldEndRow = nextRow;
      if (existenceOnly) break;
    }
    return foldEndRow;
  }

  increaseIndentRegexForScopeDescriptor(scope) {
    return this.regexForPattern(
      this.config.get('editor.increaseIndentPattern', { scope })
    );
  }

  decreaseIndentRegexForScopeDescriptor(scope) {
    return this.regexForPattern(
      this.config.get('editor.decreaseIndentPattern', { scope })
    );
  }

  decreaseNextIndentRegexForScopeDescriptor(scope) {
    return this.regexForPattern(
      this.config.get('editor.decreaseNextIndentPattern', { scope })
    );
  }

  foldEndRegexForScopeDescriptor(scope) {
    return this.regexForPattern(
      this.config.get('editor.foldEndPattern', { scope })
    );
  }

  regexForPattern(pattern) {
    if (pattern) {
      if (!this.regexesByPattern[pattern]) {
        this.regexesByPattern[pattern] = new OnigRegExp(pattern);
      }
      return this.regexesByPattern[pattern];
    }
  }

  logLines(start = 0, end = this.buffer.getLastRow()) {
    for (let row = start; row <= end; row++) {
      const line = this.tokenizedLines[row].text;
      console.log(row, line, line.length);
    }
  }
}

TextMateLanguageMode.prototype.chunkSize = 50;

class TextMateHighlightIterator {
  constructor(languageMode) {
    this.languageMode = languageMode;
    this.openScopeIds = null;
    this.closeScopeIds = null;
  }

  seek(position) {
    this.openScopeIds = [];
    this.closeScopeIds = [];
    this.tagIndex = null;

    const currentLine = this.languageMode.tokenizedLineForRow(position.row);
    this.currentLineTags = currentLine.tags;
    this.currentLineLength = currentLine.text.length;
    const containingScopeIds = currentLine.openScopes.map(id =>
      fromFirstMateScopeId(id)
    );

    let currentColumn = 0;
    for (let index = 0; index < this.currentLineTags.length; index++) {
      const tag = this.currentLineTags[index];
      if (tag >= 0) {
        if (currentColumn >= position.column) {
          this.tagIndex = index;
          break;
        } else {
          currentColumn += tag;
          while (this.closeScopeIds.length > 0) {
            this.closeScopeIds.shift();
            containingScopeIds.pop();
          }
          while (this.openScopeIds.length > 0) {
            const openTag = this.openScopeIds.shift();
            containingScopeIds.push(openTag);
          }
        }
      } else {
        const scopeId = fromFirstMateScopeId(tag);
        if ((tag & 1) === 0) {
          if (this.openScopeIds.length > 0) {
            if (currentColumn >= position.column) {
              this.tagIndex = index;
              break;
            } else {
              while (this.closeScopeIds.length > 0) {
                this.closeScopeIds.shift();
                containingScopeIds.pop();
              }
              while (this.openScopeIds.length > 0) {
                const openTag = this.openScopeIds.shift();
                containingScopeIds.push(openTag);
              }
            }
          }
          this.closeScopeIds.push(scopeId);
        } else {
          this.openScopeIds.push(scopeId);
        }
      }
    }

    if (this.tagIndex == null) {
      this.tagIndex = this.currentLineTags.length;
    }
    this.position = Point(
      position.row,
      Math.min(this.currentLineLength, currentColumn)
    );
    return containingScopeIds;
  }

  moveToSuccessor() {
    this.openScopeIds = [];
    this.closeScopeIds = [];
    while (true) {
      if (this.tagIndex === this.currentLineTags.length) {
        if (this.isAtTagBoundary()) {
          break;
        } else if (!this.moveToNextLine()) {
          return false;
        }
      } else {
        const tag = this.currentLineTags[this.tagIndex];
        if (tag >= 0) {
          if (this.isAtTagBoundary()) {
            break;
          } else {
            this.position = Point(
              this.position.row,
              Math.min(
                this.currentLineLength,
                this.position.column + this.currentLineTags[this.tagIndex]
              )
            );
          }
        } else {
          const scopeId = fromFirstMateScopeId(tag);
          if ((tag & 1) === 0) {
            if (this.openScopeIds.length > 0) {
              break;
            } else {
              this.closeScopeIds.push(scopeId);
            }
          } else {
            this.openScopeIds.push(scopeId);
          }
        }
        this.tagIndex++;
      }
    }
    return true;
  }

  getPosition() {
    return this.position;
  }

  getCloseScopeIds() {
    return this.closeScopeIds.slice();
  }

  getOpenScopeIds() {
    return this.openScopeIds.slice();
  }

  moveToNextLine() {
    this.position = Point(this.position.row + 1, 0);
    const tokenizedLine = this.languageMode.tokenizedLineForRow(
      this.position.row
    );
    if (tokenizedLine == null) {
      return false;
    } else {
      this.currentLineTags = tokenizedLine.tags;
      this.currentLineLength = tokenizedLine.text.length;
      this.tagIndex = 0;
      return true;
    }
  }

  isAtTagBoundary() {
    return this.closeScopeIds.length > 0 || this.openScopeIds.length > 0;
  }
}

TextMateLanguageMode.TextMateHighlightIterator = TextMateHighlightIterator;
module.exports = TextMateLanguageMode;
