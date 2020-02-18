import {TextBuffer, Range} from 'atom';

import Hunk from './hunk';
import {Unchanged, Addition, Deletion, NoNewline} from './region';

export const EXPANDED = {
  /* istanbul ignore next */
  toString() { return 'RenderStatus(expanded)'; },

  isVisible() { return true; },

  isExpandable() { return false; },
};

export const COLLAPSED = {
  /* istanbul ignore next */
  toString() { return 'RenderStatus(collapsed)'; },

  isVisible() { return false; },

  isExpandable() { return true; },
};

export const DEFERRED = {
  /* istanbul ignore next */
  toString() { return 'RenderStatus(deferred)'; },

  isVisible() { return false; },

  isExpandable() { return true; },
};

export const REMOVED = {
  /* istanbul ignore next */
  toString() { return 'RenderStatus(removed)'; },

  isVisible() { return false; },

  isExpandable() { return false; },
};

export default class Patch {
  static layerName = 'patch';

  static createNull() {
    return new NullPatch();
  }

  static createHiddenPatch(marker, renderStatus, showFn) {
    return new HiddenPatch(marker, renderStatus, showFn);
  }

  constructor({status, hunks, marker}) {
    this.status = status;
    this.hunks = hunks;
    this.marker = marker;

    this.changedLineCount = this.getHunks().reduce((acc, hunk) => acc + hunk.changedLineCount(), 0);
  }

  getStatus() {
    return this.status;
  }

  getMarker() {
    return this.marker;
  }

  getRange() {
    return this.getMarker().getRange();
  }

  getStartRange() {
    const startPoint = this.getMarker().getRange().start;
    return Range.fromObject([startPoint, startPoint]);
  }

  getHunks() {
    return this.hunks;
  }

  getChangedLineCount() {
    return this.changedLineCount;
  }

  containsRow(row) {
    return this.marker.getRange().intersectsRow(row);
  }

  destroyMarkers() {
    this.marker.destroy();
    for (const hunk of this.hunks) {
      hunk.destroyMarkers();
    }
  }

  updateMarkers(map) {
    this.marker = map.get(this.marker) || this.marker;
    for (const hunk of this.hunks) {
      hunk.updateMarkers(map);
    }
  }

  getMaxLineNumberWidth() {
    const lastHunk = this.hunks[this.hunks.length - 1];
    return lastHunk ? lastHunk.getMaxLineNumberWidth() : 0;
  }

  clone(opts = {}) {
    return new this.constructor({
      status: opts.status !== undefined ? opts.status : this.getStatus(),
      hunks: opts.hunks !== undefined ? opts.hunks : this.getHunks(),
      marker: opts.marker !== undefined ? opts.marker : this.getMarker(),
    });
  }

  /* Return the set of Markers owned by this Patch that butt up against the patch's beginning. */
  getStartingMarkers() {
    const markers = [this.marker];
    if (this.hunks.length > 0) {
      const firstHunk = this.hunks[0];
      markers.push(firstHunk.getMarker());
      if (firstHunk.getRegions().length > 0) {
        const firstRegion = firstHunk.getRegions()[0];
        markers.push(firstRegion.getMarker());
      }
    }
    return markers;
  }

  /* Return the set of Markers owned by this Patch that end at the patch's end position. */
  getEndingMarkers() {
    const markers = [this.marker];
    if (this.hunks.length > 0) {
      const lastHunk = this.hunks[this.hunks.length - 1];
      markers.push(lastHunk.getMarker());
      if (lastHunk.getRegions().length > 0) {
        const lastRegion = lastHunk.getRegions()[lastHunk.getRegions().length - 1];
        markers.push(lastRegion.getMarker());
      }
    }
    return markers;
  }

  buildStagePatchForLines(originalBuffer, nextPatchBuffer, rowSet) {
    const originalBaseOffset = this.getMarker().getRange().start.row;
    const builder = new BufferBuilder(originalBuffer, originalBaseOffset, nextPatchBuffer);
    const hunks = [];

    let newRowDelta = 0;

    for (const hunk of this.getHunks()) {
      let atLeastOneSelectedChange = false;
      let selectedDeletionRowCount = 0;
      let noNewlineRowCount = 0;

      for (const region of hunk.getRegions()) {
        for (const {intersection, gap} of region.intersectRows(rowSet, true)) {
          region.when({
            addition: () => {
              if (gap) {
                // Unselected addition: omit from new buffer
                builder.remove(intersection);
              } else {
                // Selected addition: include in new patch
                atLeastOneSelectedChange = true;
                builder.append(intersection);
                builder.markRegion(intersection, Addition);
              }
            },
            deletion: () => {
              if (gap) {
                // Unselected deletion: convert to context row
                builder.append(intersection);
                builder.markRegion(intersection, Unchanged);
              } else {
                // Selected deletion: include in new patch
                atLeastOneSelectedChange = true;
                builder.append(intersection);
                builder.markRegion(intersection, Deletion);
                selectedDeletionRowCount += intersection.getRowCount();
              }
            },
            unchanged: () => {
              // Untouched context line: include in new patch
              builder.append(intersection);
              builder.markRegion(intersection, Unchanged);
            },
            nonewline: () => {
              builder.append(intersection);
              builder.markRegion(intersection, NoNewline);
              noNewlineRowCount += intersection.getRowCount();
            },
          });
        }
      }

      if (atLeastOneSelectedChange) {
        // Hunk contains at least one selected line

        builder.markHunkRange(hunk.getRange());
        const {regions, marker} = builder.latestHunkWasIncluded();
        const newStartRow = hunk.getNewStartRow() + newRowDelta;
        const newRowCount = marker.getRange().getRowCount() - selectedDeletionRowCount - noNewlineRowCount;

        hunks.push(new Hunk({
          oldStartRow: hunk.getOldStartRow(),
          oldRowCount: hunk.getOldRowCount(),
          newStartRow,
          newRowCount,
          sectionHeading: hunk.getSectionHeading(),
          marker,
          regions,
        }));

        newRowDelta += newRowCount - hunk.getNewRowCount();
      } else {
        newRowDelta += hunk.getOldRowCount() - hunk.getNewRowCount();

        builder.latestHunkWasDiscarded();
      }
    }

    const marker = nextPatchBuffer.markRange(
      this.constructor.layerName,
      [[0, 0], [nextPatchBuffer.getBuffer().getLastRow() - 1, Infinity]],
      {invalidate: 'never', exclusive: false},
    );

    const wholeFile = rowSet.size === this.changedLineCount;
    const status = this.getStatus() === 'deleted' && !wholeFile ? 'modified' : this.getStatus();
    return this.clone({hunks, status, marker});
  }

  buildUnstagePatchForLines(originalBuffer, nextPatchBuffer, rowSet) {
    const originalBaseOffset = this.getMarker().getRange().start.row;
    const builder = new BufferBuilder(originalBuffer, originalBaseOffset, nextPatchBuffer);
    const hunks = [];
    let newRowDelta = 0;

    for (const hunk of this.getHunks()) {
      let atLeastOneSelectedChange = false;
      let contextRowCount = 0;
      let additionRowCount = 0;
      let deletionRowCount = 0;

      for (const region of hunk.getRegions()) {
        for (const {intersection, gap} of region.intersectRows(rowSet, true)) {
          region.when({
            addition: () => {
              if (gap) {
                // Unselected addition: become a context line.
                builder.append(intersection);
                builder.markRegion(intersection, Unchanged);
                contextRowCount += intersection.getRowCount();
              } else {
                // Selected addition: become a deletion.
                atLeastOneSelectedChange = true;
                builder.append(intersection);
                builder.markRegion(intersection, Deletion);
                deletionRowCount += intersection.getRowCount();
              }
            },
            deletion: () => {
              if (gap) {
                // Non-selected deletion: omit from new buffer.
                builder.remove(intersection);
              } else {
                // Selected deletion: becomes an addition
                atLeastOneSelectedChange = true;
                builder.append(intersection);
                builder.markRegion(intersection, Addition);
                additionRowCount += intersection.getRowCount();
              }
            },
            unchanged: () => {
              // Untouched context line: include in new patch.
              builder.append(intersection);
              builder.markRegion(intersection, Unchanged);
              contextRowCount += intersection.getRowCount();
            },
            nonewline: () => {
              // Nonewline marker: include in new patch.
              builder.append(intersection);
              builder.markRegion(intersection, NoNewline);
            },
          });
        }
      }

      if (atLeastOneSelectedChange) {
        // Hunk contains at least one selected line

        builder.markHunkRange(hunk.getRange());
        const {marker, regions} = builder.latestHunkWasIncluded();
        hunks.push(new Hunk({
          oldStartRow: hunk.getNewStartRow(),
          oldRowCount: contextRowCount + deletionRowCount,
          newStartRow: hunk.getNewStartRow() + newRowDelta,
          newRowCount: contextRowCount + additionRowCount,
          sectionHeading: hunk.getSectionHeading(),
          marker,
          regions,
        }));
      } else {
        builder.latestHunkWasDiscarded();
      }

      // (contextRowCount + additionRowCount) - (contextRowCount + deletionRowCount)
      newRowDelta += additionRowCount - deletionRowCount;
    }

    const wholeFile = rowSet.size === this.changedLineCount;
    let status = this.getStatus();
    if (this.getStatus() === 'added') {
      status = wholeFile ? 'deleted' : 'modified';
    } else if (this.getStatus() === 'deleted') {
      status = 'added';
    }

    const marker = nextPatchBuffer.markRange(
      this.constructor.layerName,
      [[0, 0], [nextPatchBuffer.getBuffer().getLastRow(), Infinity]],
      {invalidate: 'never', exclusive: false},
    );

    return this.clone({hunks, status, marker});
  }

  getFirstChangeRange() {
    const firstHunk = this.getHunks()[0];
    if (!firstHunk) {
      return Range.fromObject([[0, 0], [0, 0]]);
    }

    const firstChange = firstHunk.getChanges()[0];
    if (!firstChange) {
      return Range.fromObject([[0, 0], [0, 0]]);
    }

    const firstRow = firstChange.getStartBufferRow();
    return Range.fromObject([[firstRow, 0], [firstRow, Infinity]]);
  }

  toStringIn(buffer) {
    return this.getHunks().reduce((str, hunk) => str + hunk.toStringIn(buffer), '');
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

    let inspectString = `${indentation}(Patch marker=${this.marker.id}`;
    if (this.marker.isDestroyed()) {
      inspectString += ' [destroyed]';
    }
    if (!this.marker.isValid()) {
      inspectString += ' [invalid]';
    }
    inspectString += '\n';
    for (const hunk of this.hunks) {
      inspectString += hunk.inspect({indent: options.indent + 2});
    }
    inspectString += `${indentation})\n`;
    return inspectString;
  }

  isPresent() {
    return true;
  }

  getRenderStatus() {
    return EXPANDED;
  }
}

class HiddenPatch extends Patch {
  constructor(marker, renderStatus, showFn) {
    super({status: null, hunks: [], marker});

    this.renderStatus = renderStatus;
    this.show = showFn;
  }

  getInsertionPoint() {
    return this.getRange().end;
  }

  getRenderStatus() {
    return this.renderStatus;
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

    return `${indentation}(HiddenPatch marker=${this.marker.id})\n`;
  }
}

class NullPatch {
  constructor() {
    const buffer = new TextBuffer();
    this.marker = buffer.markRange([[0, 0], [0, 0]]);
  }

  getStatus() {
    return null;
  }

  getMarker() {
    return this.marker;
  }

  getRange() {
    return this.getMarker().getRange();
  }

  getStartRange() {
    return Range.fromObject([[0, 0], [0, 0]]);
  }

  getHunks() {
    return [];
  }

  getChangedLineCount() {
    return 0;
  }

  containsRow() {
    return false;
  }

  getMaxLineNumberWidth() {
    return 0;
  }

  clone(opts = {}) {
    if (
      opts.status === undefined &&
      opts.hunks === undefined &&
      opts.marker === undefined &&
      opts.renderStatus === undefined
    ) {
      return this;
    } else {
      return new Patch({
        status: opts.status !== undefined ? opts.status : this.getStatus(),
        hunks: opts.hunks !== undefined ? opts.hunks : this.getHunks(),
        marker: opts.marker !== undefined ? opts.marker : this.getMarker(),
        renderStatus: opts.renderStatus !== undefined ? opts.renderStatus : this.getRenderStatus(),
      });
    }
  }

  getStartingMarkers() {
    return [];
  }

  getEndingMarkers() {
    return [];
  }

  buildStagePatchForLines() {
    return this;
  }

  buildUnstagePatchForLines() {
    return this;
  }

  getFirstChangeRange() {
    return Range.fromObject([[0, 0], [0, 0]]);
  }

  updateMarkers() {}

  toStringIn() {
    return '';
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

    return `${indentation}(NullPatch)\n`;
  }

  isPresent() {
    return false;
  }

  getRenderStatus() {
    return EXPANDED;
  }
}

class BufferBuilder {
  constructor(original, originalBaseOffset, nextPatchBuffer) {
    this.originalBuffer = original;
    this.nextPatchBuffer = nextPatchBuffer;

    // The ranges provided to builder methods are expected to be valid within the original buffer. Account for
    // the position of the Patch within its original TextBuffer, and any existing content already on the next
    // TextBuffer.
    this.offset = this.nextPatchBuffer.getBuffer().getLastRow() - originalBaseOffset;

    this.hunkBufferText = '';
    this.hunkRowCount = 0;
    this.hunkStartOffset = this.offset;
    this.hunkRegions = [];
    this.hunkRange = null;

    this.lastOffset = 0;
  }

  append(range) {
    this.hunkBufferText += this.originalBuffer.getTextInRange(range) + '\n';
    this.hunkRowCount += range.getRowCount();
  }

  remove(range) {
    this.offset -= range.getRowCount();
  }

  markRegion(range, RegionKind) {
    const finalRange = this.offset !== 0
      ? range.translate([this.offset, 0], [this.offset, 0])
      : range;

    // Collapse consecutive ranges of the same RegionKind into one continuous region.
    const lastRegion = this.hunkRegions[this.hunkRegions.length - 1];
    if (lastRegion && lastRegion.RegionKind === RegionKind && finalRange.start.row - lastRegion.range.end.row === 1) {
      lastRegion.range.end = finalRange.end;
    } else {
      this.hunkRegions.push({RegionKind, range: finalRange});
    }
  }

  markHunkRange(range) {
    let finalRange = range;
    if (this.hunkStartOffset !== 0 || this.offset !== 0) {
      finalRange = finalRange.translate([this.hunkStartOffset, 0], [this.offset, 0]);
    }
    this.hunkRange = finalRange;
  }

  latestHunkWasIncluded() {
    this.nextPatchBuffer.buffer.append(this.hunkBufferText, {normalizeLineEndings: false});

    const regions = this.hunkRegions.map(({RegionKind, range}) => {
      const regionMarker = this.nextPatchBuffer.markRange(
        RegionKind.layerName,
        range,
        {invalidate: 'never', exclusive: false},
      );
      return new RegionKind(regionMarker);
    });

    const marker = this.nextPatchBuffer.markRange('hunk', this.hunkRange, {invalidate: 'never', exclusive: false});

    this.hunkBufferText = '';
    this.hunkRowCount = 0;
    this.hunkStartOffset = this.offset;
    this.hunkRegions = [];
    this.hunkRange = null;

    return {regions, marker};
  }

  latestHunkWasDiscarded() {
    this.offset -= this.hunkRowCount;

    this.hunkBufferText = '';
    this.hunkRowCount = 0;
    this.hunkStartOffset = this.offset;
    this.hunkRegions = [];
    this.hunkRange = null;

    return {regions: [], marker: null};
  }
}
