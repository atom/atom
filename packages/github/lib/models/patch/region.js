import {Range} from 'atom';

class Region {
  constructor(marker) {
    this.marker = marker;
  }

  getMarker() {
    return this.marker;
  }

  getRange() {
    return this.marker.getRange();
  }

  getStartBufferRow() {
    return this.getRange().start.row;
  }

  getEndBufferRow() {
    return this.getRange().end.row;
  }

  includesBufferRow(row) {
    return this.getRange().intersectsRow(row);
  }

  /*
   * intersectRows breaks a Region into runs of rows that are included in
   * rowSet and rows that are not. For example:
   *  @this Region        row 10-20
   *  @param rowSet       row 11, 12, 13, 17, 19
   *  @param includeGaps  true (whether the result will include gaps or not)
   *  @return an array of regions like this:
   *    (10, gap = true) (11, 12, 13, gap = false) (14, 15, 16, gap = true)
   *    (17, gap = false) (18, gap = true) (19, gap = false) (20, gap = true)
   */
  intersectRows(rowSet, includeGaps) {
    const intersections = [];
    let withinIntersection = false;

    let currentRow = this.getRange().start.row;
    let nextStartRow = currentRow;

    const finishRowRange = isGap => {
      if (isGap && !includeGaps) {
        nextStartRow = currentRow;
        return;
      }

      if (currentRow <= this.getRange().start.row) {
        return;
      }

      intersections.push({
        intersection: Range.fromObject([[nextStartRow, 0], [currentRow - 1, Infinity]]),
        gap: isGap,
      });

      nextStartRow = currentRow;
    };

    while (currentRow <= this.getRange().end.row) {
      if (rowSet.has(currentRow) && !withinIntersection) {
        // One row past the end of a gap. Start of intersecting row range.
        finishRowRange(true);
        withinIntersection = true;
      } else if (!rowSet.has(currentRow) && withinIntersection) {
        // One row past the end of intersecting row range. Start of the next gap.
        finishRowRange(false);
        withinIntersection = false;
      }

      currentRow++;
    }

    finishRowRange(!withinIntersection);
    return intersections;
  }

  isAddition() {
    return false;
  }

  isDeletion() {
    return false;
  }

  isUnchanged() {
    return false;
  }

  isNoNewline() {
    return false;
  }

  getBufferRows() {
    return this.getRange().getRows();
  }

  bufferRowCount() {
    return this.getRange().getRowCount();
  }

  when(callbacks) {
    const callback = callbacks[this.constructor.name.toLowerCase()] || callbacks.default || (() => undefined);
    return callback();
  }

  updateMarkers(map) {
    this.marker = map.get(this.marker) || this.marker;
  }

  destroyMarkers() {
    this.marker.destroy();
  }

  toStringIn(buffer) {
    const raw = buffer.getTextInRange(this.getRange());
    return this.constructor.origin + raw.replace(/\r?\n/g, '$&' + this.constructor.origin) +
      buffer.lineEndingForRow(this.getRange().end.row);
  }

  /*
   * Construct a String containing internal diagnostic information.
   */
  /* istanbul ignore next */
  inspect(opts = {}) {
    const options = {
      indent: 0,
      ...opts,
    };

    let indentation = '';
    for (let i = 0; i < options.indent; i++) {
      indentation += ' ';
    }

    let inspectString = `${indentation}(${this.constructor.name} marker=${this.marker.id})`;
    if (this.marker.isDestroyed()) {
      inspectString += ' [destroyed]';
    }
    if (!this.marker.isValid()) {
      inspectString += ' [invalid]';
    }
    return inspectString + '\n';
  }

  isChange() {
    return true;
  }
}

export class Addition extends Region {
  static origin = '+';

  static layerName = 'addition';

  isAddition() {
    return true;
  }

  invertIn(nextBuffer) {
    return new Deletion(nextBuffer.markRange(this.getRange()));
  }
}

export class Deletion extends Region {
  static origin = '-';

  static layerName = 'deletion';

  isDeletion() {
    return true;
  }

  invertIn(nextBuffer) {
    return new Addition(nextBuffer.markRange(this.getRange()));
  }
}

export class Unchanged extends Region {
  static origin = ' ';

  static layerName = 'unchanged';

  isUnchanged() {
    return true;
  }

  isChange() {
    return false;
  }

  invertIn(nextBuffer) {
    return new Unchanged(nextBuffer.markRange(this.getRange()));
  }
}

export class NoNewline extends Region {
  static origin = '\\';

  static layerName = 'nonewline';

  isNoNewline() {
    return true;
  }

  isChange() {
    return false;
  }

  invertIn(nextBuffer) {
    return new NoNewline(nextBuffer.markRange(this.getRange()));
  }
}
