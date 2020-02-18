import {MIDDLE} from './position';
import {OURS, THEIRS, BASE} from './source';
import Side from './side';
import Banner from './banner';
import Separator from './separator';

import {ConflictParser} from './parser';
import {EditorAdapter, ChunkAdapter} from './parser/adapter';
import {NoopVisitor} from './parser/noop-visitor';

// Regular expression that matches the beginning of a potential conflict.
const CONFLICT_START_REGEX = /^<{7} ([^\r\n]+)\r?\n/g;


/*
 * Conflict parser visitor that marks each buffer range and assembles a Conflict from the
 * pieces.
 */
class ConflictVisitor {
  /*
   * editor - [TextEditor] displaying the conflicting text.
   * layer - [DisplayMarkerLayer] to created conflict markers on.
   */
  constructor(editor, layer) {
    this.editor = editor;
    this.layer = layer;

    this.ours = null;
    this.base = null;
    this.separator = null;
    this.theirs = null;
  }

  /*
   * position - [Position] one of TOP or BOTTOM.
   * bannerRow - [Integer] of the buffer row that contains our side's banner.
   * textRowStart - [Integer] of the first buffer row that contain this side's text.
   * textRowEnd - [Integer] of the first buffer row beyond the extend of this side's text.
   */
  visitOurSide(position, bannerRow, textRowStart, textRowEnd) {
    this.ours = this.markSide(position, OURS, bannerRow, textRowStart, textRowEnd);
  }

  /*
   * bannerRow - [Integer] the buffer row that contains our side's banner.
   * textRowStart - [Integer] first buffer row that contain this side's text.
   * textRowEnd - [Integer] first buffer row beyond the extend of this side's text.
   */
  visitBaseSide(bannerRow, textRowStart, textRowEnd) {
    this.base = this.markSide(MIDDLE, BASE, bannerRow, textRowStart, textRowEnd);
  }

  /*
   * sepRowStart - [Integer] buffer row that contains the "=======" separator.
   */
  visitSeparator(sepRowStart) {
    const marker = this.layer.markBufferRange([[sepRowStart, 0], [sepRowStart + 1, 0]], {
      invalidate: 'surround',
      exclusive: true,
    });
    this.separator = new Separator(this.editor, marker);
  }

  /*
   * position - [Position] alignment within the conflict marker: TOP or BOTTOM.
   * bannerRow - [Integer] the buffer row that contains our side's banner.
   * textRowStart - [Integer] first buffer row that contain this side's text.
   * textRowEnd - [Integer] first buffer row beyond the extent of this side's text.
   */
  visitTheirSide(position, bannerRow, textRowStart, textRowEnd) {
    this.theirs = this.markSide(position, THEIRS, bannerRow, textRowStart, textRowEnd);
  }

  markSide(position, source, bannerRow, textRowStart, textRowEnd) {
    const blockCol = position.when({
      top: () => 0,
      middle: () => 0,
      bottom: () => this.editor.lineTextForBufferRow(bannerRow).length,
    });
    const blockRange = [[bannerRow, blockCol], [bannerRow, blockCol]];
    const blockMarker = this.layer.markBufferRange(blockRange, {
      invalidate: 'surround',
      exclusive: true,
    });

    const description = this.sideDescription(bannerRow);
    const bannerRange = [[bannerRow, 0], [bannerRow + 1, 0]];
    const bannerMarker = this.layer.markBufferRange(bannerRange, {
      invalidate: 'surround',
      exclusive: true,
    });
    const originalBannerText = this.editor.getTextInBufferRange(bannerRange);
    const banner = new Banner(this.editor, bannerMarker, description, originalBannerText);

    const textRange = [[textRowStart, 0], [textRowEnd, 0]];
    const sideMarker = this.layer.markBufferRange(textRange, {
      invalidate: 'surround',
      exclusive: false,
    });
    const originalText = this.editor.getTextInBufferRange(textRange);

    return new Side(this.editor, sideMarker, blockMarker, source, position, banner, originalText);
  }

  /*
   * Parse the banner description for the current side from a banner row.
   *
   * bannerRow - [Integer] buffer row containing the <, |, or > marker
   */
  sideDescription(bannerRow) {
    return this.editor.lineTextForBufferRow(bannerRow).match(/^[<|>]{7} (.*)$/)[1];
  }

  conflict() {
    return new Conflict(this.ours, this.separator, this.base, this.theirs);
  }
}

export default class Conflict {
  constructor(ours, separator, base, theirs) {
    this.separator = separator;

    this.bySource = {};
    this.byPosition = {};

    [ours, base, theirs].forEach(side => {
      if (!side) {
        return;
      }

      this.bySource[side.getSource().getName()] = side;
      this.byPosition[side.getPosition().getName()] = side;
    });

    this.resolution = null;
  }

  getKey() {
    return this.getSide(OURS).getMarker().id;
  }

  isResolved() {
    return this.resolution !== null;
  }

  resolveAs(source) {
    this.resolution = this.getSide(source);
  }

  getSides() {
    return ['ours', 'base', 'theirs'].map(sourceName => this.bySource[sourceName]).filter(side => side);
  }

  getChosenSide() {
    return this.resolution;
  }

  getUnchosenSides() {
    return this.getSides().filter(side => side !== this.resolution);
  }

  getSide(source) {
    return this.bySource[source.getName()];
  }

  /*
   * Return a `Side` containing a buffer point, or `undefined` if none do.
   */
  getSideContaining(point) {
    return this.getSides().find(side => side.includesPoint(point));
  }

  /*
   * Return a `Range` that encompasses the entire Conflict region.
   */
  getRange() {
    const topRange = this.byPosition.top.getRange();
    const bottomRange = this.byPosition.bottom.getRange();
    return topRange.union(bottomRange);
  }

  /*
   * Determine whether or not a buffer position is contained within this conflict.
   */
  includesPoint(point) {
    return this.getRange().containsPoint(point);
  }

  /*
   * Return the `DisplayMarker` that immediately follows the `Side` in a given `Position`. Return `null` if no such
   * marker exists.
   */
  markerAfter(position) {
    return position.when({
      top: () => (this.byPosition.middle ? this.byPosition.middle.getBannerMarker() : this.getSeparator().getMarker()),
      middle: () => this.getSeparator().getMarker(),
      bottom: () => this.byPosition.bottom.getBannerMarker(),
    });
  }

  getSeparator() {
    return this.separator;
  }

  /*
   * Parse any conflict markers in a TextEditor's buffer and return a Conflict that contains markers corresponding to
   * each.
   *
   * editor [TextEditor] The editor to search.
   * layer [DisplayMarkerLayer] Marker layer to create markers on.
   * return [Array<Conflict>] A (possibly empty) collection of parsed Conflicts.
   */
  static allFromEditor(editor, layer, isRebase) {
    const conflicts = [];
    let lastRow = -1;

    editor.getBuffer().scan(CONFLICT_START_REGEX, m => {
      const conflictStartRow = m.range.start.row;
      if (conflictStartRow < lastRow) {
        // Match within an already-parsed conflict.
        return;
      }

      const adapter = new EditorAdapter(editor, conflictStartRow);
      const visitor = new ConflictVisitor(editor, layer);
      const parser = new ConflictParser(adapter, visitor, isRebase);

      if (parser.parse().wasSuccessful()) {
        conflicts.push(visitor.conflict());
      }

      lastRow = adapter.getCurrentRow();
    });

    return conflicts;
  }

  /*
   * Return the number of conflict markers present in a streamed file.
   */
  static countFromStream(stream, isRebase) {
    return new Promise((resolve, reject) => {
      let count = 0;
      let lastResult = null;
      let lastPartialMarker = '';

      stream.on('data', chunk => {
        const adapter = new ChunkAdapter(lastPartialMarker + chunk);
        if (!lastResult) {
          if (!adapter.advanceTo(CONFLICT_START_REGEX)) {
            lastPartialMarker = adapter.getLastPartialMarker();
            return;
          }
        }
        do {
          const parser = new ConflictParser(adapter, new NoopVisitor(), isRebase);
          const result = lastResult ? parser.continueFrom(lastResult) : parser.parse();

          if (result.wasSuccessful()) {
            count++;
          } else {
            lastResult = result;
          }
        } while (adapter.advanceTo(CONFLICT_START_REGEX));

        lastPartialMarker = adapter.getLastPartialMarker();
      });

      stream.on('error', reject);

      stream.on('end', () => resolve(count));
    });
  }
}
