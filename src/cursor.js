const { Point, Range } = require('text-buffer');
const { Emitter } = require('event-kit');
const _ = require('underscore-plus');
const Model = require('./model');

const EmptyLineRegExp = /(\r\n[\t ]*\r\n)|(\n[\t ]*\n)/g;

// Extended: The `Cursor` class represents the little blinking line identifying
// where text can be inserted.
//
// Cursors belong to {TextEditor}s and have some metadata attached in the form
// of a {DisplayMarker}.
module.exports = class Cursor extends Model {
  // Instantiated by a {TextEditor}
  constructor(params) {
    super(params);
    this.editor = params.editor;
    this.marker = params.marker;
    this.emitter = new Emitter();
  }

  destroy() {
    this.marker.destroy();
  }

  /*
  Section: Event Subscription
  */

  // Public: Calls your `callback` when the cursor has been moved.
  //
  // * `callback` {Function}
  //   * `event` {Object}
  //     * `oldBufferPosition` {Point}
  //     * `oldScreenPosition` {Point}
  //     * `newBufferPosition` {Point}
  //     * `newScreenPosition` {Point}
  //     * `textChanged` {Boolean}
  //     * `cursor` {Cursor} that triggered the event
  //
  // Returns a {Disposable} on which `.dispose()` can be called to unsubscribe.
  onDidChangePosition(callback) {
    return this.emitter.on('did-change-position', callback);
  }

  // Public: Calls your `callback` when the cursor is destroyed
  //
  // * `callback` {Function}
  //
  // Returns a {Disposable} on which `.dispose()` can be called to unsubscribe.
  onDidDestroy(callback) {
    return this.emitter.once('did-destroy', callback);
  }

  /*
  Section: Managing Cursor Position
  */

  // Public: Moves a cursor to a given screen position.
  //
  // * `screenPosition` {Array} of two numbers: the screen row, and the screen column.
  // * `options` (optional) {Object} with the following keys:
  //   * `autoscroll` A Boolean which, if `true`, scrolls the {TextEditor} to wherever
  //     the cursor moves to.
  setScreenPosition(screenPosition, options = {}) {
    this.changePosition(options, () => {
      this.marker.setHeadScreenPosition(screenPosition, options);
    });
  }

  // Public: Returns the screen position of the cursor as a {Point}.
  getScreenPosition() {
    return this.marker.getHeadScreenPosition();
  }

  // Public: Moves a cursor to a given buffer position.
  //
  // * `bufferPosition` {Array} of two numbers: the buffer row, and the buffer column.
  // * `options` (optional) {Object} with the following keys:
  //   * `autoscroll` {Boolean} indicating whether to autoscroll to the new
  //     position. Defaults to `true` if this is the most recently added cursor,
  //     `false` otherwise.
  setBufferPosition(bufferPosition, options = {}) {
    this.changePosition(options, () => {
      this.marker.setHeadBufferPosition(bufferPosition, options);
    });
  }

  // Public: Returns the current buffer position as an Array.
  getBufferPosition() {
    return this.marker.getHeadBufferPosition();
  }

  // Public: Returns the cursor's current screen row.
  getScreenRow() {
    return this.getScreenPosition().row;
  }

  // Public: Returns the cursor's current screen column.
  getScreenColumn() {
    return this.getScreenPosition().column;
  }

  // Public: Retrieves the cursor's current buffer row.
  getBufferRow() {
    return this.getBufferPosition().row;
  }

  // Public: Returns the cursor's current buffer column.
  getBufferColumn() {
    return this.getBufferPosition().column;
  }

  // Public: Returns the cursor's current buffer row of text excluding its line
  // ending.
  getCurrentBufferLine() {
    return this.editor.lineTextForBufferRow(this.getBufferRow());
  }

  // Public: Returns whether the cursor is at the start of a line.
  isAtBeginningOfLine() {
    return this.getBufferPosition().column === 0;
  }

  // Public: Returns whether the cursor is on the line return character.
  isAtEndOfLine() {
    return this.getBufferPosition().isEqual(
      this.getCurrentLineBufferRange().end
    );
  }

  /*
  Section: Cursor Position Details
  */

  // Public: Returns the underlying {DisplayMarker} for the cursor.
  // Useful with overlay {Decoration}s.
  getMarker() {
    return this.marker;
  }

  // Public: Identifies if the cursor is surrounded by whitespace.
  //
  // "Surrounded" here means that the character directly before and after the
  // cursor are both whitespace.
  //
  // Returns a {Boolean}.
  isSurroundedByWhitespace() {
    const { row, column } = this.getBufferPosition();
    const range = [[row, column - 1], [row, column + 1]];
    return /^\s+$/.test(this.editor.getTextInBufferRange(range));
  }

  // Public: Returns whether the cursor is currently between a word and non-word
  // character. The non-word characters are defined by the
  // `editor.nonWordCharacters` config value.
  //
  // This method returns false if the character before or after the cursor is
  // whitespace.
  //
  // Returns a Boolean.
  isBetweenWordAndNonWord() {
    if (this.isAtBeginningOfLine() || this.isAtEndOfLine()) return false;

    const { row, column } = this.getBufferPosition();
    const range = [[row, column - 1], [row, column + 1]];
    const text = this.editor.getTextInBufferRange(range);
    if (/\s/.test(text[0]) || /\s/.test(text[1])) return false;

    const nonWordCharacters = this.getNonWordCharacters();
    return (
      nonWordCharacters.includes(text[0]) !==
      nonWordCharacters.includes(text[1])
    );
  }

  // Public: Returns whether this cursor is between a word's start and end.
  //
  // * `options` (optional) {Object}
  //   * `wordRegex` A {RegExp} indicating what constitutes a "word"
  //     (default: {::wordRegExp}).
  //
  // Returns a {Boolean}
  isInsideWord(options) {
    const { row, column } = this.getBufferPosition();
    const range = [[row, column], [row, Infinity]];
    const text = this.editor.getTextInBufferRange(range);
    return (
      text.search((options && options.wordRegex) || this.wordRegExp()) === 0
    );
  }

  // Public: Returns the indentation level of the current line.
  getIndentLevel() {
    if (this.editor.getSoftTabs()) {
      return this.getBufferColumn() / this.editor.getTabLength();
    } else {
      return this.getBufferColumn();
    }
  }

  // Public: Retrieves the scope descriptor for the cursor's current position.
  //
  // Returns a {ScopeDescriptor}
  getScopeDescriptor() {
    return this.editor.scopeDescriptorForBufferPosition(
      this.getBufferPosition()
    );
  }

  // Public: Retrieves the syntax tree scope descriptor for the cursor's current position.
  //
  // Returns a {ScopeDescriptor}
  getSyntaxTreeScopeDescriptor() {
    return this.editor.syntaxTreeScopeDescriptorForBufferPosition(
      this.getBufferPosition()
    );
  }

  // Public: Returns true if this cursor has no non-whitespace characters before
  // its current position.
  hasPrecedingCharactersOnLine() {
    const bufferPosition = this.getBufferPosition();
    const line = this.editor.lineTextForBufferRow(bufferPosition.row);
    const firstCharacterColumn = line.search(/\S/);

    if (firstCharacterColumn === -1) {
      return false;
    } else {
      return bufferPosition.column > firstCharacterColumn;
    }
  }

  // Public: Identifies if this cursor is the last in the {TextEditor}.
  //
  // "Last" is defined as the most recently added cursor.
  //
  // Returns a {Boolean}.
  isLastCursor() {
    return this === this.editor.getLastCursor();
  }

  /*
  Section: Moving the Cursor
  */

  // Public: Moves the cursor up one screen row.
  //
  // * `rowCount` (optional) {Number} number of rows to move (default: 1)
  // * `options` (optional) {Object} with the following keys:
  //   * `moveToEndOfSelection` if true, move to the left of the selection if a
  //     selection exists.
  moveUp(rowCount = 1, { moveToEndOfSelection } = {}) {
    let row, column;
    const range = this.marker.getScreenRange();
    if (moveToEndOfSelection && !range.isEmpty()) {
      ({ row, column } = range.start);
    } else {
      ({ row, column } = this.getScreenPosition());
    }

    if (this.goalColumn != null) column = this.goalColumn;
    this.setScreenPosition(
      { row: row - rowCount, column },
      { skipSoftWrapIndentation: true }
    );
    this.goalColumn = column;
  }

  // Public: Moves the cursor down one screen row.
  //
  // * `rowCount` (optional) {Number} number of rows to move (default: 1)
  // * `options` (optional) {Object} with the following keys:
  //   * `moveToEndOfSelection` if true, move to the left of the selection if a
  //     selection exists.
  moveDown(rowCount = 1, { moveToEndOfSelection } = {}) {
    let row, column;
    const range = this.marker.getScreenRange();
    if (moveToEndOfSelection && !range.isEmpty()) {
      ({ row, column } = range.end);
    } else {
      ({ row, column } = this.getScreenPosition());
    }

    if (this.goalColumn != null) column = this.goalColumn;
    this.setScreenPosition(
      { row: row + rowCount, column },
      { skipSoftWrapIndentation: true }
    );
    this.goalColumn = column;
  }

  // Public: Moves the cursor left one screen column.
  //
  // * `columnCount` (optional) {Number} number of columns to move (default: 1)
  // * `options` (optional) {Object} with the following keys:
  //   * `moveToEndOfSelection` if true, move to the left of the selection if a
  //     selection exists.
  moveLeft(columnCount = 1, { moveToEndOfSelection } = {}) {
    const range = this.marker.getScreenRange();
    if (moveToEndOfSelection && !range.isEmpty()) {
      this.setScreenPosition(range.start);
    } else {
      let { row, column } = this.getScreenPosition();

      while (columnCount > column && row > 0) {
        columnCount -= column;
        column = this.editor.lineLengthForScreenRow(--row);
        columnCount--; // subtract 1 for the row move
      }

      column = column - columnCount;
      this.setScreenPosition({ row, column }, { clipDirection: 'backward' });
    }
  }

  // Public: Moves the cursor right one screen column.
  //
  // * `columnCount` (optional) {Number} number of columns to move (default: 1)
  // * `options` (optional) {Object} with the following keys:
  //   * `moveToEndOfSelection` if true, move to the right of the selection if a
  //     selection exists.
  moveRight(columnCount = 1, { moveToEndOfSelection } = {}) {
    const range = this.marker.getScreenRange();
    if (moveToEndOfSelection && !range.isEmpty()) {
      this.setScreenPosition(range.end);
    } else {
      let { row, column } = this.getScreenPosition();
      const maxLines = this.editor.getScreenLineCount();
      let rowLength = this.editor.lineLengthForScreenRow(row);
      let columnsRemainingInLine = rowLength - column;

      while (columnCount > columnsRemainingInLine && row < maxLines - 1) {
        columnCount -= columnsRemainingInLine;
        columnCount--; // subtract 1 for the row move

        column = 0;
        rowLength = this.editor.lineLengthForScreenRow(++row);
        columnsRemainingInLine = rowLength;
      }

      column = column + columnCount;
      this.setScreenPosition({ row, column }, { clipDirection: 'forward' });
    }
  }

  // Public: Moves the cursor to the top of the buffer.
  moveToTop() {
    this.setBufferPosition([0, 0]);
  }

  // Public: Moves the cursor to the bottom of the buffer.
  moveToBottom() {
    const column = this.goalColumn;
    this.setBufferPosition(this.editor.getEofBufferPosition());
    this.goalColumn = column;
  }

  // Public: Moves the cursor to the beginning of the line.
  moveToBeginningOfScreenLine() {
    this.setScreenPosition([this.getScreenRow(), 0]);
  }

  // Public: Moves the cursor to the beginning of the buffer line.
  moveToBeginningOfLine() {
    this.setBufferPosition([this.getBufferRow(), 0]);
  }

  // Public: Moves the cursor to the beginning of the first character in the
  // line.
  moveToFirstCharacterOfLine() {
    let targetBufferColumn;
    const screenRow = this.getScreenRow();
    const screenLineStart = this.editor.clipScreenPosition([screenRow, 0], {
      skipSoftWrapIndentation: true
    });
    const screenLineEnd = [screenRow, Infinity];
    const screenLineBufferRange = this.editor.bufferRangeForScreenRange([
      screenLineStart,
      screenLineEnd
    ]);

    let firstCharacterColumn = null;
    this.editor.scanInBufferRange(
      /\S/,
      screenLineBufferRange,
      ({ range, stop }) => {
        firstCharacterColumn = range.start.column;
        stop();
      }
    );

    if (
      firstCharacterColumn != null &&
      firstCharacterColumn !== this.getBufferColumn()
    ) {
      targetBufferColumn = firstCharacterColumn;
    } else {
      targetBufferColumn = screenLineBufferRange.start.column;
    }

    this.setBufferPosition([
      screenLineBufferRange.start.row,
      targetBufferColumn
    ]);
  }

  // Public: Moves the cursor to the end of the line.
  moveToEndOfScreenLine() {
    this.setScreenPosition([this.getScreenRow(), Infinity]);
  }

  // Public: Moves the cursor to the end of the buffer line.
  moveToEndOfLine() {
    this.setBufferPosition([this.getBufferRow(), Infinity]);
  }

  // Public: Moves the cursor to the beginning of the word.
  moveToBeginningOfWord() {
    this.setBufferPosition(this.getBeginningOfCurrentWordBufferPosition());
  }

  // Public: Moves the cursor to the end of the word.
  moveToEndOfWord() {
    const position = this.getEndOfCurrentWordBufferPosition();
    if (position) this.setBufferPosition(position);
  }

  // Public: Moves the cursor to the beginning of the next word.
  moveToBeginningOfNextWord() {
    const position = this.getBeginningOfNextWordBufferPosition();
    if (position) this.setBufferPosition(position);
  }

  // Public: Moves the cursor to the previous word boundary.
  moveToPreviousWordBoundary() {
    const position = this.getPreviousWordBoundaryBufferPosition();
    if (position) this.setBufferPosition(position);
  }

  // Public: Moves the cursor to the next word boundary.
  moveToNextWordBoundary() {
    const position = this.getNextWordBoundaryBufferPosition();
    if (position) this.setBufferPosition(position);
  }

  // Public: Moves the cursor to the previous subword boundary.
  moveToPreviousSubwordBoundary() {
    const options = { wordRegex: this.subwordRegExp({ backwards: true }) };
    const position = this.getPreviousWordBoundaryBufferPosition(options);
    if (position) this.setBufferPosition(position);
  }

  // Public: Moves the cursor to the next subword boundary.
  moveToNextSubwordBoundary() {
    const options = { wordRegex: this.subwordRegExp() };
    const position = this.getNextWordBoundaryBufferPosition(options);
    if (position) this.setBufferPosition(position);
  }

  // Public: Moves the cursor to the beginning of the buffer line, skipping all
  // whitespace.
  skipLeadingWhitespace() {
    const position = this.getBufferPosition();
    const scanRange = this.getCurrentLineBufferRange();
    let endOfLeadingWhitespace = null;
    this.editor.scanInBufferRange(/^[ \t]*/, scanRange, ({ range }) => {
      endOfLeadingWhitespace = range.end;
    });

    if (endOfLeadingWhitespace.isGreaterThan(position))
      this.setBufferPosition(endOfLeadingWhitespace);
  }

  // Public: Moves the cursor to the beginning of the next paragraph
  moveToBeginningOfNextParagraph() {
    const position = this.getBeginningOfNextParagraphBufferPosition();
    if (position) this.setBufferPosition(position);
  }

  // Public: Moves the cursor to the beginning of the previous paragraph
  moveToBeginningOfPreviousParagraph() {
    const position = this.getBeginningOfPreviousParagraphBufferPosition();
    if (position) this.setBufferPosition(position);
  }

  /*
  Section: Local Positions and Ranges
  */

  // Public: Returns buffer position of previous word boundary. It might be on
  // the current word, or the previous word.
  //
  // * `options` (optional) {Object} with the following keys:
  //   * `wordRegex` A {RegExp} indicating what constitutes a "word"
  //      (default: {::wordRegExp})
  getPreviousWordBoundaryBufferPosition(options = {}) {
    const currentBufferPosition = this.getBufferPosition();
    const previousNonBlankRow = this.editor.buffer.previousNonBlankRow(
      currentBufferPosition.row
    );
    const scanRange = Range(
      Point(previousNonBlankRow || 0, 0),
      currentBufferPosition
    );

    const ranges = this.editor.buffer.findAllInRangeSync(
      options.wordRegex || this.wordRegExp(),
      scanRange
    );

    const range = ranges[ranges.length - 1];
    if (range) {
      if (
        range.start.row < currentBufferPosition.row &&
        currentBufferPosition.column > 0
      ) {
        return Point(currentBufferPosition.row, 0);
      } else if (currentBufferPosition.isGreaterThan(range.end)) {
        return Point.fromObject(range.end);
      } else {
        return Point.fromObject(range.start);
      }
    } else {
      return currentBufferPosition;
    }
  }

  // Public: Returns buffer position of the next word boundary. It might be on
  // the current word, or the previous word.
  //
  // * `options` (optional) {Object} with the following keys:
  //   * `wordRegex` A {RegExp} indicating what constitutes a "word"
  //      (default: {::wordRegExp})
  getNextWordBoundaryBufferPosition(options = {}) {
    const currentBufferPosition = this.getBufferPosition();
    const scanRange = Range(
      currentBufferPosition,
      this.editor.getEofBufferPosition()
    );

    const range = this.editor.buffer.findInRangeSync(
      options.wordRegex || this.wordRegExp(),
      scanRange
    );

    if (range) {
      if (range.start.row > currentBufferPosition.row) {
        return Point(range.start.row, 0);
      } else if (currentBufferPosition.isLessThan(range.start)) {
        return Point.fromObject(range.start);
      } else {
        return Point.fromObject(range.end);
      }
    } else {
      return currentBufferPosition;
    }
  }

  // Public: Retrieves the buffer position of where the current word starts.
  //
  // * `options` (optional) An {Object} with the following keys:
  //   * `wordRegex` A {RegExp} indicating what constitutes a "word"
  //     (default: {::wordRegExp}).
  //   * `includeNonWordCharacters` A {Boolean} indicating whether to include
  //     non-word characters in the default word regex.
  //     Has no effect if wordRegex is set.
  //   * `allowPrevious` A {Boolean} indicating whether the beginning of the
  //     previous word can be returned.
  //
  // Returns a {Range}.
  getBeginningOfCurrentWordBufferPosition(options = {}) {
    const allowPrevious = options.allowPrevious !== false;
    const position = this.getBufferPosition();

    const scanRange = allowPrevious
      ? new Range(new Point(position.row - 1, 0), position)
      : new Range(new Point(position.row, 0), position);

    const ranges = this.editor.buffer.findAllInRangeSync(
      options.wordRegex || this.wordRegExp(options),
      scanRange
    );

    let result;
    for (let range of ranges) {
      if (position.isLessThanOrEqual(range.start)) break;
      if (allowPrevious || position.isLessThanOrEqual(range.end))
        result = Point.fromObject(range.start);
    }

    return result || (allowPrevious ? new Point(0, 0) : position);
  }

  // Public: Retrieves the buffer position of where the current word ends.
  //
  // * `options` (optional) {Object} with the following keys:
  //   * `wordRegex` A {RegExp} indicating what constitutes a "word"
  //      (default: {::wordRegExp})
  //   * `includeNonWordCharacters` A Boolean indicating whether to include
  //     non-word characters in the default word regex. Has no effect if
  //     wordRegex is set.
  //
  // Returns a {Range}.
  getEndOfCurrentWordBufferPosition(options = {}) {
    const allowNext = options.allowNext !== false;
    const position = this.getBufferPosition();

    const scanRange = allowNext
      ? new Range(position, new Point(position.row + 2, 0))
      : new Range(position, new Point(position.row, Infinity));

    const ranges = this.editor.buffer.findAllInRangeSync(
      options.wordRegex || this.wordRegExp(options),
      scanRange
    );

    for (let range of ranges) {
      if (position.isLessThan(range.start) && !allowNext) break;
      if (position.isLessThan(range.end)) return Point.fromObject(range.end);
    }

    return allowNext ? this.editor.getEofBufferPosition() : position;
  }

  // Public: Retrieves the buffer position of where the next word starts.
  //
  // * `options` (optional) {Object}
  //   * `wordRegex` A {RegExp} indicating what constitutes a "word"
  //     (default: {::wordRegExp}).
  //
  // Returns a {Range}
  getBeginningOfNextWordBufferPosition(options = {}) {
    const currentBufferPosition = this.getBufferPosition();
    const start = this.isInsideWord(options)
      ? this.getEndOfCurrentWordBufferPosition(options)
      : currentBufferPosition;
    const scanRange = [start, this.editor.getEofBufferPosition()];

    let beginningOfNextWordPosition;
    this.editor.scanInBufferRange(
      options.wordRegex || this.wordRegExp(),
      scanRange,
      ({ range, stop }) => {
        beginningOfNextWordPosition = range.start;
        stop();
      }
    );

    return beginningOfNextWordPosition || currentBufferPosition;
  }

  // Public: Returns the buffer Range occupied by the word located under the cursor.
  //
  // * `options` (optional) {Object}
  //   * `wordRegex` A {RegExp} indicating what constitutes a "word"
  //     (default: {::wordRegExp}).
  getCurrentWordBufferRange(options = {}) {
    const position = this.getBufferPosition();
    const ranges = this.editor.buffer.findAllInRangeSync(
      options.wordRegex || this.wordRegExp(options),
      new Range(new Point(position.row, 0), new Point(position.row, Infinity))
    );
    const range = ranges.find(
      range =>
        range.end.column >= position.column &&
        range.start.column <= position.column
    );
    return range ? Range.fromObject(range) : new Range(position, position);
  }

  // Public: Returns the buffer Range for the current line.
  //
  // * `options` (optional) {Object}
  //   * `includeNewline` A {Boolean} which controls whether the Range should
  //     include the newline.
  getCurrentLineBufferRange(options) {
    return this.editor.bufferRangeForBufferRow(this.getBufferRow(), options);
  }

  // Public: Retrieves the range for the current paragraph.
  //
  // A paragraph is defined as a block of text surrounded by empty lines or comments.
  //
  // Returns a {Range}.
  getCurrentParagraphBufferRange() {
    return this.editor.rowRangeForParagraphAtBufferRow(this.getBufferRow());
  }

  // Public: Returns the characters preceding the cursor in the current word.
  getCurrentWordPrefix() {
    return this.editor.getTextInBufferRange([
      this.getBeginningOfCurrentWordBufferPosition(),
      this.getBufferPosition()
    ]);
  }

  /*
  Section: Visibility
  */

  /*
  Section: Comparing to another cursor
  */

  // Public: Compare this cursor's buffer position to another cursor's buffer position.
  //
  // See {Point::compare} for more details.
  //
  // * `otherCursor`{Cursor} to compare against
  compare(otherCursor) {
    return this.getBufferPosition().compare(otherCursor.getBufferPosition());
  }

  /*
  Section: Utilities
  */

  // Public: Deselects the current selection.
  clearSelection(options) {
    if (this.selection) this.selection.clear(options);
  }

  // Public: Get the RegExp used by the cursor to determine what a "word" is.
  //
  // * `options` (optional) {Object} with the following keys:
  //   * `includeNonWordCharacters` A {Boolean} indicating whether to include
  //     non-word characters in the regex. (default: true)
  //
  // Returns a {RegExp}.
  wordRegExp(options) {
    const nonWordCharacters = _.escapeRegExp(this.getNonWordCharacters());
    let source = `^[\t ]*$|[^\\s${nonWordCharacters}]+`;
    if (!options || options.includeNonWordCharacters !== false) {
      source += `|${`[${nonWordCharacters}]+`}`;
    }
    return new RegExp(source, 'g');
  }

  // Public: Get the RegExp used by the cursor to determine what a "subword" is.
  //
  // * `options` (optional) {Object} with the following keys:
  //   * `backwards` A {Boolean} indicating whether to look forwards or backwards
  //     for the next subword. (default: false)
  //
  // Returns a {RegExp}.
  subwordRegExp(options = {}) {
    const nonWordCharacters = this.getNonWordCharacters();
    const lowercaseLetters = 'a-z\\u00DF-\\u00F6\\u00F8-\\u00FF';
    const uppercaseLetters = 'A-Z\\u00C0-\\u00D6\\u00D8-\\u00DE';
    const snakeCamelSegment = `[${uppercaseLetters}]?[${lowercaseLetters}]+`;
    const segments = [
      '^[\t ]+',
      '[\t ]+$',
      `[${uppercaseLetters}]+(?![${lowercaseLetters}])`,
      '\\d+'
    ];
    if (options.backwards) {
      segments.push(`${snakeCamelSegment}_*`);
      segments.push(`[${_.escapeRegExp(nonWordCharacters)}]+\\s*`);
    } else {
      segments.push(`_*${snakeCamelSegment}`);
      segments.push(`\\s*[${_.escapeRegExp(nonWordCharacters)}]+`);
    }
    segments.push('_+');
    return new RegExp(segments.join('|'), 'g');
  }

  /*
  Section: Private
  */

  getNonWordCharacters() {
    return this.editor.getNonWordCharacters(this.getBufferPosition());
  }

  changePosition(options, fn) {
    this.clearSelection({ autoscroll: false });
    fn();
    this.goalColumn = null;
    const autoscroll =
      options && options.autoscroll != null
        ? options.autoscroll
        : this.isLastCursor();
    if (autoscroll) this.autoscroll();
  }

  getScreenRange() {
    const { row, column } = this.getScreenPosition();
    return new Range(new Point(row, column), new Point(row, column + 1));
  }

  autoscroll(options = {}) {
    options.clip = false;
    this.editor.scrollToScreenRange(this.getScreenRange(), options);
  }

  getBeginningOfNextParagraphBufferPosition() {
    const start = this.getBufferPosition();
    const eof = this.editor.getEofBufferPosition();
    const scanRange = [start, eof];

    const { row, column } = eof;
    let position = new Point(row, column - 1);

    this.editor.scanInBufferRange(
      EmptyLineRegExp,
      scanRange,
      ({ range, stop }) => {
        position = range.start.traverse(Point(1, 0));
        if (!position.isEqual(start)) stop();
      }
    );
    return position;
  }

  getBeginningOfPreviousParagraphBufferPosition() {
    const start = this.getBufferPosition();

    const { row, column } = start;
    const scanRange = [[row - 1, column], [0, 0]];
    let position = new Point(0, 0);
    this.editor.backwardsScanInBufferRange(
      EmptyLineRegExp,
      scanRange,
      ({ range, stop }) => {
        position = range.start.traverse(Point(1, 0));
        if (!position.isEqual(start)) stop();
      }
    );
    return position;
  }
};
