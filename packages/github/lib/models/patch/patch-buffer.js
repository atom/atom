import {TextBuffer, Range, Point} from 'atom';
import {inspect} from 'util';

const LAYER_NAMES = ['unchanged', 'addition', 'deletion', 'nonewline', 'hunk', 'patch'];

export default class PatchBuffer {
  constructor() {
    this.buffer = new TextBuffer();
    this.buffer.retain();

    this.layers = LAYER_NAMES.reduce((map, layerName) => {
      map[layerName] = this.buffer.addMarkerLayer();
      return map;
    }, {});
  }

  getBuffer() {
    return this.buffer;
  }

  getInsertionPoint() {
    return this.buffer.getEndPosition();
  }

  getLayer(layerName) {
    return this.layers[layerName];
  }

  findMarkers(layerName, ...args) {
    return this.layers[layerName].findMarkers(...args);
  }

  findAllMarkers(...args) {
    return LAYER_NAMES.reduce((arr, layerName) => {
      arr.push(...this.findMarkers(layerName, ...args));
      return arr;
    }, []);
  }

  markPosition(layerName, ...args) {
    return this.layers[layerName].markPosition(...args);
  }

  markRange(layerName, ...args) {
    return this.layers[layerName].markRange(...args);
  }

  clearAllLayers() {
    for (const layerName of LAYER_NAMES) {
      this.layers[layerName].clear();
    }
  }

  createInserterAt(insertionPoint) {
    return new Inserter(this, Point.fromObject(insertionPoint));
  }

  createInserterAtEnd() {
    return this.createInserterAt(this.getInsertionPoint());
  }

  createSubBuffer(rangeLike, options = {}) {
    const opts = {
      exclude: new Set(),
      ...options,
    };

    const range = Range.fromObject(rangeLike);
    const baseOffset = range.start.negate();
    const includedMarkersByLayer = LAYER_NAMES.reduce((map, layerName) => {
      map[layerName] = this.layers[layerName]
        .findMarkers({intersectsRange: range})
        .filter(m => !opts.exclude.has(m));
      return map;
    }, {});
    const markerMap = new Map();

    const subBuffer = new PatchBuffer();
    subBuffer.getBuffer().setText(this.buffer.getTextInRange(range));

    for (const layerName of LAYER_NAMES) {
      for (const oldMarker of includedMarkersByLayer[layerName]) {
        const oldRange = oldMarker.getRange();

        const clippedStart = oldRange.start.isLessThanOrEqual(range.start) ? range.start : oldRange.start;
        const clippedEnd = oldRange.end.isGreaterThanOrEqual(range.end) ? range.end : oldRange.end;

        // Exclude non-empty markers that intersect *only* at the range start or end
        if (clippedStart.isEqual(clippedEnd) && !oldRange.start.isEqual(oldRange.end)) {
          continue;
        }

        const startOffset = clippedStart.row === range.start.row ? baseOffset : [baseOffset.row, 0];
        const endOffset = clippedEnd.row === range.start.row ? baseOffset : [baseOffset.row, 0];

        const newMarker = subBuffer.markRange(
          layerName,
          [clippedStart.translate(startOffset), clippedEnd.translate(endOffset)],
          oldMarker.getProperties(),
        );
        markerMap.set(oldMarker, newMarker);
      }
    }

    return {patchBuffer: subBuffer, markerMap};
  }

  extractPatchBuffer(rangeLike, options = {}) {
    const {patchBuffer: subBuffer, markerMap} = this.createSubBuffer(rangeLike, options);

    for (const oldMarker of markerMap.keys()) {
      oldMarker.destroy();
    }

    this.buffer.setTextInRange(rangeLike, '');
    return {patchBuffer: subBuffer, markerMap};
  }

  deleteLastNewline() {
    if (this.buffer.getLastLine() === '') {
      this.buffer.deleteRow(this.buffer.getLastRow());
    }

    return this;
  }

  adopt(original) {
    this.clearAllLayers();
    this.buffer.setText(original.getBuffer().getText());

    const markerMap = new Map();
    for (const layerName of LAYER_NAMES) {
      for (const originalMarker of original.getLayer(layerName).getMarkers()) {
        const newMarker = this.markRange(layerName, originalMarker.getRange(), originalMarker.getProperties());
        markerMap.set(originalMarker, newMarker);
      }
    }
    return markerMap;
  }

  /* istanbul ignore next */
  inspect(opts = {}) {
    /* istanbul ignore next */
    const options = {
      layerNames: LAYER_NAMES,
      ...opts,
    };

    let inspectString = '';

    const increasingMarkers = [];
    for (const layerName of options.layerNames) {
      for (const marker of this.findMarkers(layerName, {})) {
        increasingMarkers.push({layerName, point: marker.getRange().start, start: true, id: marker.id});
        increasingMarkers.push({layerName, point: marker.getRange().end, end: true, id: marker.id});
      }
    }
    increasingMarkers.sort((a, b) => {
      const cmp = a.point.compare(b.point);
      if (cmp !== 0) {
        return cmp;
      } else if (a.start && b.start) {
        return 0;
      } else if (a.start && !b.start) {
        return -1;
      } else if (!a.start && b.start) {
        return 1;
      } else {
        return 0;
      }
    });

    let inspectPoint = Point.fromObject([0, 0]);
    for (const marker of increasingMarkers) {
      if (!marker.point.isEqual(inspectPoint)) {
        inspectString += inspect(this.buffer.getTextInRange([inspectPoint, marker.point])) + '\n';
      }

      if (marker.start) {
        inspectString += `  start ${marker.layerName}@${marker.id}\n`;
      } else if (marker.end) {
        inspectString += `  end ${marker.layerName}@${marker.id}\n`;
      }

      inspectPoint = marker.point;
    }

    return inspectString;
  }
}

class Inserter {
  constructor(patchBuffer, insertionPoint) {
    const clipped = patchBuffer.getBuffer().clipPosition(insertionPoint);

    this.patchBuffer = patchBuffer;
    this.startPoint = clipped.copy();
    this.insertionPoint = clipped.copy();
    this.markerBlueprints = [];
    this.markerMapCallbacks = [];

    this.markersBefore = new Set();
    this.markersAfter = new Set();
  }

  keepBefore(markers) {
    for (const marker of markers) {
      if (marker.getRange().end.isEqual(this.startPoint)) {
        this.markersBefore.add(marker);
      }
    }
    return this;
  }

  keepAfter(markers) {
    for (const marker of markers) {
      if (marker.getRange().start.isEqual(this.startPoint)) {
        this.markersAfter.add(marker);
      }
    }
    return this;
  }

  markWhile(layerName, block, markerOpts) {
    const start = this.insertionPoint.copy();
    block();
    const end = this.insertionPoint.copy();
    this.markerBlueprints.push({layerName, range: new Range(start, end), markerOpts});
    return this;
  }

  insert(text) {
    const insertedRange = this.patchBuffer.getBuffer().insert(this.insertionPoint, text);
    this.insertionPoint = insertedRange.end;
    return this;
  }

  insertMarked(text, layerName, markerOpts) {
    return this.markWhile(layerName, () => this.insert(text), markerOpts);
  }

  insertPatchBuffer(subPatchBuffer, opts) {
    const baseOffset = this.insertionPoint.copy();
    this.insert(subPatchBuffer.getBuffer().getText());

    const subMarkerMap = new Map();
    for (const layerName of LAYER_NAMES) {
      for (const oldMarker of subPatchBuffer.findMarkers(layerName, {})) {
        const startOffset = oldMarker.getRange().start.row === 0 ? baseOffset : [baseOffset.row, 0];
        const endOffset = oldMarker.getRange().end.row === 0 ? baseOffset : [baseOffset.row, 0];

        const range = oldMarker.getRange().translate(startOffset, endOffset);
        const markerOpts = {
          ...oldMarker.getProperties(),
          callback: newMarker => { subMarkerMap.set(oldMarker, newMarker); },
        };
        this.markerBlueprints.push({layerName, range, markerOpts});
      }
    }

    this.markerMapCallbacks.push({markerMap: subMarkerMap, callback: opts.callback});

    return this;
  }

  apply() {
    for (const {layerName, range, markerOpts} of this.markerBlueprints) {
      const callback = markerOpts.callback;
      delete markerOpts.callback;

      const marker = this.patchBuffer.markRange(layerName, range, markerOpts);
      if (callback) {
        callback(marker);
      }
    }

    for (const {markerMap, callback} of this.markerMapCallbacks) {
      callback(markerMap);
    }

    for (const beforeMarker of this.markersBefore) {
      const isEmpty = beforeMarker.getRange().isEmpty();

      if (!beforeMarker.isReversed()) {
        beforeMarker.setHeadPosition(this.startPoint);
        if (isEmpty) {
          beforeMarker.setTailPosition(this.startPoint);
        }
      } else {
        beforeMarker.setTailPosition(this.startPoint);
        if (isEmpty) {
          beforeMarker.setHeadPosition(this.startPoint);
        }
      }
    }

    for (const afterMarker of this.markersAfter) {
      const isEmpty = afterMarker.getRange().isEmpty();

      if (!afterMarker.isReversed()) {
        afterMarker.setTailPosition(this.insertionPoint);
        if (isEmpty) {
          afterMarker.setHeadPosition(this.insertionPoint);
        }
      } else {
        afterMarker.setHeadPosition(this.insertionPoint);
        if (isEmpty) {
          afterMarker.setTailPosition(this.insertionPoint);
        }
      }
    }
  }
}
