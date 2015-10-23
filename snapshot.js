// We won't have access to es_natives.js here, so this means we have to provide
// them ourselves. The best way we can overcome this is to avoid using such
// functions wherever possible.
//Object.prototype.toString = function() {
//  return "[object " + typeof this + "]";
//};

var snapshotGlobal = {};
var cachedFunctions = {
  "./helpers": (function (exports, require, module, __filename, __dirname, process, global) { (function() {
  var SpliceArrayChunkSize,
    __slice = [].slice;

  SpliceArrayChunkSize = 100000;

  module.exports = {
    spliceArray: function(originalArray, start, length, insertedArray) {
      var chunk, chunkEnd, chunkStart, removedValues, _i, _ref;
      if (insertedArray == null) {
        insertedArray = [];
      }
      if (insertedArray.length < SpliceArrayChunkSize) {
        return originalArray.splice.apply(originalArray, [start, length].concat(__slice.call(insertedArray)));
      } else {
        removedValues = originalArray.splice(start, length);
        for (chunkStart = _i = 0, _ref = insertedArray.length; SpliceArrayChunkSize > 0 ? _i <= _ref : _i >= _ref; chunkStart = _i += SpliceArrayChunkSize) {
          chunkEnd = chunkStart + SpliceArrayChunkSize;
          chunk = insertedArray.slice(chunkStart, chunkEnd);
          originalArray.splice.apply(originalArray, [start + chunkStart, 0].concat(__slice.call(chunk)));
        }
        return removedValues;
      }
    },
    newlineRegex: /\r\n|\n|\r/g
  };

}).call(this);

}),
  "./range": (function (exports, require, module, __filename, __dirname, process, global) { (function() {
  var Grim, Point, Range, newlineRegex,
    __slice = [].slice;

  Grim = require('grim');

  Point = require('./point');

  newlineRegex = require('./helpers').newlineRegex;

  module.exports = Range = (function() {

    /*
    Section: Properties
     */
    Range.prototype.start = null;

    Range.prototype.end = null;


    /*
    Section: Construction
     */

    Range.fromObject = function(object, copy) {
      if (Array.isArray(object)) {
        return new this(object[0], object[1]);
      } else if (object instanceof this) {
        if (copy) {
          return object.copy();
        } else {
          return object;
        }
      } else {
        return new this(object.start, object.end);
      }
    };

    Range.fromText = function() {
      var args, endPoint, lastIndex, lines, startPoint, text;
      args = 1 <= arguments.length ? __slice.call(arguments, 0) : [];
      if (args.length > 1) {
        startPoint = Point.fromObject(args.shift());
      } else {
        startPoint = new Point(0, 0);
      }
      text = args.shift();
      endPoint = startPoint.copy();
      lines = text.split(newlineRegex);
      if (lines.length > 1) {
        lastIndex = lines.length - 1;
        endPoint.row += lastIndex;
        endPoint.column = lines[lastIndex].length;
      } else {
        endPoint.column += lines[0].length;
      }
      return new this(startPoint, endPoint);
    };

    Range.fromPointWithDelta = function(startPoint, rowDelta, columnDelta) {
      var endPoint;
      startPoint = Point.fromObject(startPoint);
      endPoint = new Point(startPoint.row + rowDelta, startPoint.column + columnDelta);
      return new this(startPoint, endPoint);
    };


    /*
    Section: Serialization and Deserialization
     */

    Range.deserialize = function(array) {
      if (Array.isArray(array)) {
        return new this(array[0], array[1]);
      } else {
        return new this();
      }
    };


    /*
    Section: Construction
     */

    function Range(pointA, pointB) {
      if (pointA == null) {
        pointA = new Point(0, 0);
      }
      if (pointB == null) {
        pointB = new Point(0, 0);
      }
      if (!(this instanceof Range)) {
        return new Range(pointA, pointB);
      }
      pointA = Point.fromObject(pointA);
      pointB = Point.fromObject(pointB);
      if (pointA.isLessThanOrEqual(pointB)) {
        this.start = pointA;
        this.end = pointB;
      } else {
        this.start = pointB;
        this.end = pointA;
      }
    }

    Range.prototype.copy = function() {
      return new this.constructor(this.start.copy(), this.end.copy());
    };

    Range.prototype.negate = function() {
      return new this.constructor(this.start.negate(), this.end.negate());
    };


    /*
    Section: Serialization and Deserialization
     */

    Range.prototype.serialize = function() {
      return [this.start.serialize(), this.end.serialize()];
    };


    /*
    Section: Range Details
     */

    Range.prototype.isEmpty = function() {
      return this.start.isEqual(this.end);
    };

    Range.prototype.isSingleLine = function() {
      return this.start.row === this.end.row;
    };

    Range.prototype.getRowCount = function() {
      return this.end.row - this.start.row + 1;
    };

    Range.prototype.getRows = function() {
      var _i, _ref, _ref1, _results;
      return (function() {
        _results = [];
        for (var _i = _ref = this.start.row, _ref1 = this.end.row; _ref <= _ref1 ? _i <= _ref1 : _i >= _ref1; _ref <= _ref1 ? _i++ : _i--){ _results.push(_i); }
        return _results;
      }).apply(this);
    };


    /*
    Section: Operations
     */

    Range.prototype.freeze = function() {
      this.start.freeze();
      this.end.freeze();
      return Object.freeze(this);
    };

    Range.prototype.union = function(otherRange) {
      var end, start;
      start = this.start.isLessThan(otherRange.start) ? this.start : otherRange.start;
      end = this.end.isGreaterThan(otherRange.end) ? this.end : otherRange.end;
      return new this.constructor(start, end);
    };

    Range.prototype.translate = function(startDelta, endDelta) {
      if (endDelta == null) {
        endDelta = startDelta;
      }
      return new this.constructor(this.start.translate(startDelta), this.end.translate(endDelta));
    };

    Range.prototype.traverse = function(delta) {
      return new this.constructor(this.start.traverse(delta), this.end.traverse(delta));
    };


    /*
    Section: Comparison
     */

    Range.prototype.compare = function(other) {
      var value;
      other = this.constructor.fromObject(other);
      if (value = this.start.compare(other.start)) {
        return value;
      } else {
        return other.end.compare(this.end);
      }
    };

    Range.prototype.isEqual = function(other) {
      if (other == null) {
        return false;
      }
      other = this.constructor.fromObject(other);
      return other.start.isEqual(this.start) && other.end.isEqual(this.end);
    };

    Range.prototype.coversSameRows = function(other) {
      return this.start.row === other.start.row && this.end.row === other.end.row;
    };

    Range.prototype.intersectsWith = function(otherRange, exclusive) {
      if (exclusive) {
        return !(this.end.isLessThanOrEqual(otherRange.start) || this.start.isGreaterThanOrEqual(otherRange.end));
      } else {
        return !(this.end.isLessThan(otherRange.start) || this.start.isGreaterThan(otherRange.end));
      }
    };

    Range.prototype.containsRange = function(otherRange, exclusive) {
      var end, start, _ref;
      _ref = this.constructor.fromObject(otherRange), start = _ref.start, end = _ref.end;
      return this.containsPoint(start, exclusive) && this.containsPoint(end, exclusive);
    };

    Range.prototype.containsPoint = function(point, exclusive) {
      if (Grim.includeDeprecatedAPIs && (exclusive != null) && typeof exclusive === 'object') {
        Grim.deprecate("The second param is no longer an object, it's a boolean argument named `exclusive`.");
        exclusive = exclusive.exclusive;
      }
      point = Point.fromObject(point);
      if (exclusive) {
        return point.isGreaterThan(this.start) && point.isLessThan(this.end);
      } else {
        return point.isGreaterThanOrEqual(this.start) && point.isLessThanOrEqual(this.end);
      }
    };

    Range.prototype.intersectsRow = function(row) {
      return (this.start.row <= row && row <= this.end.row);
    };

    Range.prototype.intersectsRowRange = function(startRow, endRow) {
      var _ref;
      if (startRow > endRow) {
        _ref = [endRow, startRow], startRow = _ref[0], endRow = _ref[1];
      }
      return this.end.row >= startRow && endRow >= this.start.row;
    };

    Range.prototype.getExtent = function() {
      return this.end.traversalFrom(this.start);
    };


    /*
    Section: Conversion
     */

    Range.prototype.toDelta = function() {
      var columns, rows;
      rows = this.end.row - this.start.row;
      if (rows === 0) {
        columns = this.end.column - this.start.column;
      } else {
        columns = this.end.column;
      }
      return new Point(rows, columns);
    };

    Range.prototype.toString = function() {
      return "[" + this.start + " - " + this.end + "]";
    };

    return Range;

  })();

  if (Grim.includeDeprecatedAPIs) {
    Range.prototype.add = function(delta) {
      Grim.deprecate("Use Range::traverse instead");
      return this.traverse(delta);
    };
  }

}).call(this);

}),
  "./point": (function (exports, require, module, __filename, __dirname, process, global) { (function() {
  var Point, deprecate, includeDeprecatedAPIs, isNumber, _ref;

  _ref = require('grim'), includeDeprecatedAPIs = _ref.includeDeprecatedAPIs, deprecate = _ref.deprecate;

  module.exports = Point = (function() {

    /*
    Section: Properties
     */
    Point.prototype.row = null;

    Point.prototype.column = null;


    /*
    Section: Construction
     */

    Point.fromObject = function(object, copy) {
      var column, row;
      if (object instanceof Point) {
        if (copy) {
          return object.copy();
        } else {
          return object;
        }
      } else {
        if (Array.isArray(object)) {
          row = object[0], column = object[1];
        } else {
          row = object.row, column = object.column;
        }
        return new Point(row, column);
      }
    };


    /*
    Section: Comparison
     */

    Point.min = function(point1, point2) {
      point1 = this.fromObject(point1);
      point2 = this.fromObject(point2);
      if (point1.isLessThanOrEqual(point2)) {
        return point1;
      } else {
        return point2;
      }
    };

    Point.max = function(point1, point2) {
      point1 = Point.fromObject(point1);
      point2 = Point.fromObject(point2);
      if (point1.compare(point2) >= 0) {
        return point1;
      } else {
        return point2;
      }
    };

    Point.assertValid = function(point) {
      if (!(isNumber(point.row) && isNumber(point.column))) {
        throw new TypeError("Invalid Point: " + point);
      }
    };

    Point.ZERO = Object.freeze(new Point(0, 0));

    Point.INFINITY = Object.freeze(new Point(Infinity, Infinity));


    /*
    Section: Construction
     */

    function Point(row, column) {
      if (row == null) {
        row = 0;
      }
      if (column == null) {
        column = 0;
      }
      if (!(this instanceof Point)) {
        return new Point(row, column);
      }
      this.row = row;
      this.column = column;
    }

    Point.prototype.copy = function() {
      return new Point(this.row, this.column);
    };

    Point.prototype.negate = function() {
      return new Point(-this.row, -this.column);
    };


    /*
    Section: Operations
     */

    Point.prototype.freeze = function() {
      return Object.freeze(this);
    };

    Point.prototype.translate = function(other) {
      var column, row, _ref1;
      _ref1 = Point.fromObject(other), row = _ref1.row, column = _ref1.column;
      return new Point(this.row + row, this.column + column);
    };

    Point.prototype.traverse = function(other) {
      var column, row;
      other = Point.fromObject(other);
      row = this.row + other.row;
      if (other.row === 0) {
        column = this.column + other.column;
      } else {
        column = other.column;
      }
      return new Point(row, column);
    };

    Point.prototype.traversalFrom = function(other) {
      other = Point.fromObject(other);
      if (this.row === other.row) {
        if (this.column === Infinity && other.column === Infinity) {
          return new Point(0, 0);
        } else {
          return new Point(0, this.column - other.column);
        }
      } else {
        return new Point(this.row - other.row, this.column);
      }
    };

    Point.prototype.splitAt = function(column) {
      var rightColumn;
      if (this.row === 0) {
        rightColumn = this.column - column;
      } else {
        rightColumn = this.column;
      }
      return [new Point(0, column), new Point(this.row, rightColumn)];
    };


    /*
    Section: Comparison
     */

    Point.prototype.compare = function(other) {
      other = Point.fromObject(other);
      if (this.row > other.row) {
        return 1;
      } else if (this.row < other.row) {
        return -1;
      } else {
        if (this.column > other.column) {
          return 1;
        } else if (this.column < other.column) {
          return -1;
        } else {
          return 0;
        }
      }
    };

    Point.prototype.isEqual = function(other) {
      if (!other) {
        return false;
      }
      other = Point.fromObject(other);
      return this.row === other.row && this.column === other.column;
    };

    Point.prototype.isLessThan = function(other) {
      return this.compare(other) < 0;
    };

    Point.prototype.isLessThanOrEqual = function(other) {
      return this.compare(other) <= 0;
    };

    Point.prototype.isGreaterThan = function(other) {
      return this.compare(other) > 0;
    };

    Point.prototype.isGreaterThanOrEqual = function(other) {
      return this.compare(other) >= 0;
    };

    Point.prototype.isZero = function() {
      return this.row === 0 && this.column === 0;
    };

    Point.prototype.isPositive = function() {
      if (this.row > 0) {
        return true;
      } else if (this.row < 0) {
        return false;
      } else {
        return this.column > 0;
      }
    };

    Point.prototype.isNegative = function() {
      if (this.row < 0) {
        return true;
      } else if (this.row > 0) {
        return false;
      } else {
        return this.column < 0;
      }
    };


    /*
    Section: Conversion
     */

    Point.prototype.toArray = function() {
      return [this.row, this.column];
    };

    Point.prototype.serialize = function() {
      return this.toArray();
    };

    Point.prototype.toString = function() {
      return "(" + this.row + ", " + this.column + ")";
    };

    return Point;

  })();

  if (includeDeprecatedAPIs) {
    Point.prototype.add = function(other) {
      deprecate("Use Point::traverse instead");
      return this.traverse(other);
    };
  }

  isNumber = function(value) {
    return (typeof value === 'number') && (!Number.isNaN(value));
  };

}).call(this);

}),
  "./marker": (function (exports, require, module, __filename, __dirname, process, global) { (function() {
  var Delegator, Emitter, EmitterMixin, Grim, Marker, OptionKeys, Point, Range, extend, isEqual, omit, pick, size, _ref,
    __slice = [].slice;

  _ref = require('underscore-plus'), extend = _ref.extend, isEqual = _ref.isEqual, omit = _ref.omit, pick = _ref.pick, size = _ref.size;
  //
  Emitter = require('event-kit').Emitter;
  //
  Grim = require('grim');
  //
  Delegator = require('delegato');
  //
  Point = require('./point');
  //
  Range = require('./range');
  //
  OptionKeys = new Set(['reversed', 'tailed', 'invalidate', 'persistent', 'maintainHistory']);

  module.exports = Marker = (function() {
    Delegator.includeInto(Marker);

    Marker.extractParams = function(inputParams) {
      var key, outputParams, _i, _len, _ref1;
      outputParams = {};
      if (inputParams != null) {
        if (Grim.includeDeprecatedAPIs) {
          this.handleDeprecatedParams(inputParams);
        }
        _ref1 = Object.keys(inputParams);
        for (_i = 0, _len = _ref1.length; _i < _len; _i++) {
          key = _ref1[_i];
          if (OptionKeys.has(key)) {
            outputParams[key] = inputParams[key];
          } else {
            if (outputParams.properties == null) {
              outputParams.properties = {};
            }
            outputParams.properties[key] = inputParams[key];
          }
        }
      }
      return outputParams;
    };

    // Marker.delegatesMethods('containsPoint', 'containsRange', 'intersectsRow', {
    //   toMethod: 'getRange'
    // });

    function Marker(id, store, range, params) {
      this.id = id;
      this.store = store;
      this.tailed = params.tailed, this.reversed = params.reversed, this.valid = params.valid, this.invalidate = params.invalidate, this.persistent = params.persistent, this.properties = params.properties, this.maintainHistory = params.maintainHistory;
      this.emitter = new Emitter;
      if (this.tailed == null) {
        this.tailed = true;
      }
      if (this.reversed == null) {
        this.reversed = false;
      }
      if (this.valid == null) {
        this.valid = true;
      }
      if (this.invalidate == null) {
        this.invalidate = 'overlap';
      }
      if (this.persistent == null) {
        this.persistent = true;
      }
      if (this.maintainHistory == null) {
        this.maintainHistory = false;
      }
      if (this.properties == null) {
        this.properties = {};
      }
      this.hasChangeObservers = false;
      this.rangeWhenDestroyed = null;
      Object.freeze(this.properties);
      this.store.setMarkerHasTail(this.id, this.tailed);
    }


    /*
    Section: Event Subscription
     */

    Marker.prototype.onDidDestroy = function(callback) {
      return this.emitter.on('did-destroy', callback);
    };

    Marker.prototype.onDidChange = function(callback) {
      if (!this.hasChangeObservers) {
        this.previousEventState = this.getSnapshot(this.getRange());
        this.hasChangeObservers = true;
      }
      return this.emitter.on('did-change', callback);
    };

    Marker.prototype.getRange = function() {
      var _ref1;
      return (_ref1 = this.rangeWhenDestroyed) != null ? _ref1 : this.store.getMarkerRange(this.id);
    };

    Marker.prototype.setRange = function(range, properties) {
      var params;
      params = this.extractParams(properties);
      params.tailed = true;
      params.range = Range.fromObject(range, true);
      return this.update(this.getRange(), params);
    };

    Marker.prototype.getHeadPosition = function() {
      if (this.reversed) {
        return this.getStartPosition();
      } else {
        return this.getEndPosition();
      }
    };

    Marker.prototype.setHeadPosition = function(position, properties) {
      var oldRange, params;
      position = Point.fromObject(position);
      params = this.extractParams(properties);
      oldRange = this.getRange();
      if (this.hasTail()) {
        if (this.isReversed()) {
          if (position.isLessThan(oldRange.end)) {
            params.range = new Range(position, oldRange.end);
          } else {
            params.reversed = false;
            params.range = new Range(oldRange.end, position);
          }
        } else {
          if (position.isLessThan(oldRange.start)) {
            params.reversed = true;
            params.range = new Range(position, oldRange.start);
          } else {
            params.range = new Range(oldRange.start, position);
          }
        }
      } else {
        params.range = new Range(position, position);
      }
      return this.update(oldRange, params);
    };

    Marker.prototype.getTailPosition = function() {
      if (this.reversed) {
        return this.getEndPosition();
      } else {
        return this.getStartPosition();
      }
    };

    Marker.prototype.setTailPosition = function(position, properties) {
      var oldRange, params;
      position = Point.fromObject(position);
      params = this.extractParams(properties);
      params.tailed = true;
      oldRange = this.getRange();
      if (this.reversed) {
        if (position.isLessThan(oldRange.start)) {
          params.reversed = false;
          params.range = new Range(position, oldRange.start);
        } else {
          params.range = new Range(oldRange.start, position);
        }
      } else {
        if (position.isLessThan(oldRange.end)) {
          params.range = new Range(position, oldRange.end);
        } else {
          params.reversed = true;
          params.range = new Range(oldRange.end, position);
        }
      }
      return this.update(oldRange, params);
    };

    Marker.prototype.getStartPosition = function() {
      var _ref1, _ref2;
      return (_ref1 = (_ref2 = this.rangeWhenDestroyed) != null ? _ref2.start : void 0) != null ? _ref1 : this.store.getMarkerStartPosition(this.id);
    };

    Marker.prototype.getEndPosition = function() {
      var _ref1, _ref2;
      return (_ref1 = (_ref2 = this.rangeWhenDestroyed) != null ? _ref2.end : void 0) != null ? _ref1 : this.store.getMarkerEndPosition(this.id);
    };

    Marker.prototype.clearTail = function(properties) {
      var headPosition, params;
      params = this.extractParams(properties);
      params.tailed = false;
      headPosition = this.getHeadPosition();
      params.range = new Range(headPosition, headPosition);
      return this.update(this.getRange(), params);
    };

    Marker.prototype.plantTail = function(properties) {
      var params;
      params = this.extractParams(properties);
      if (!this.hasTail()) {
        params.tailed = true;
        params.range = new Range(this.getHeadPosition(), this.getHeadPosition());
      }
      return this.update(this.getRange(), params);
    };

    Marker.prototype.isReversed = function() {
      return this.tailed && this.reversed;
    };

    Marker.prototype.hasTail = function() {
      return this.tailed;
    };

    Marker.prototype.isValid = function() {
      return !this.isDestroyed() && this.valid;
    };

    Marker.prototype.isDestroyed = function() {
      return this.rangeWhenDestroyed != null;
    };

    Marker.prototype.isEqual = function(other) {
      return this.invalidate === other.invalidate && this.tailed === other.tailed && this.persistent === other.persistent && this.maintainHistory === other.maintainHistory && this.reversed === other.reversed && isEqual(this.properties, other.properties) && this.getRange().isEqual(other.getRange());
    };

    Marker.prototype.getInvalidationStrategy = function() {
      return this.invalidate;
    };

    Marker.prototype.getProperties = function() {
      return this.properties;
    };

    Marker.prototype.setProperties = function(properties) {
      return this.update(this.getRange(), {
        properties: extend({}, this.properties, properties)
      });
    };

    Marker.prototype.copy = function(options) {
      var snapshot;
      if (options == null) {
        options = {};
      }
      snapshot = this.getSnapshot(null);
      options = Marker.extractParams(options);
      return this.store.createMarker(this.getRange(), extend({}, snapshot, options, {
        properties: extend({}, snapshot.properties, options.properties)
      }));
    };

    Marker.prototype.destroy = function() {
      this.rangeWhenDestroyed = this.getRange();
      this.store.destroyMarker(this.id);
      this.emitter.emit('did-destroy');
      if (Grim.includeDeprecatedAPIs) {
        return this.emit('destroyed');
      }
    };

    Marker.prototype.extractParams = function(params) {
      params = this.constructor.extractParams(params);
      if (params.properties != null) {
        params.properties = extend({}, this.properties, params.properties);
      }
      return params;
    };

    Marker.prototype.compare = function(other) {
      return this.getRange().compare(other.getRange());
    };

    Marker.prototype.matchesParams = function(params) {
      var key, _i, _len, _ref1;
      _ref1 = Object.keys(params);
      for (_i = 0, _len = _ref1.length; _i < _len; _i++) {
        key = _ref1[_i];
        if (!this.matchesParam(key, params[key])) {
          return false;
        }
      }
      return true;
    };

    Marker.prototype.matchesParam = function(key, value) {
      switch (key) {
        case 'startPosition':
          return this.getStartPosition().isEqual(value);
        case 'endPosition':
          return this.getEndPosition().isEqual(value);
        case 'containsPoint':
        case 'containsPosition':
          return this.containsPoint(value);
        case 'containsRange':
          return this.containsRange(value);
        case 'startRow':
          return this.getStartPosition().row === value;
        case 'endRow':
          return this.getEndPosition().row === value;
        case 'intersectsRow':
          return this.intersectsRow(value);
        case 'invalidate':
        case 'reversed':
        case 'tailed':
        case 'persistent':
        case 'maintainHistory':
          return isEqual(this[key], value);
        default:
          return isEqual(this.properties[key], value);
      }
    };

    Marker.prototype.update = function(oldRange, _arg, textChanged) {
      var properties, propertiesChanged, range, reversed, tailed, updated, valid;
      range = _arg.range, reversed = _arg.reversed, tailed = _arg.tailed, valid = _arg.valid, properties = _arg.properties;
      if (textChanged == null) {
        textChanged = false;
      }
      if (this.isDestroyed()) {
        return;
      }
      updated = propertiesChanged = false;
      if ((range != null) && !range.isEqual(oldRange)) {
        this.store.setMarkerRange(this.id, range);
        updated = true;
      }
      if ((reversed != null) && reversed !== this.reversed) {
        this.reversed = reversed;
        updated = true;
      }
      if ((tailed != null) && tailed !== this.tailed) {
        this.tailed = tailed;
        this.store.setMarkerHasTail(this.id, this.tailed);
        updated = true;
      }
      if ((valid != null) && valid !== this.valid) {
        this.valid = valid;
        updated = true;
      }
      if ((properties != null) && !isEqual(properties, this.properties)) {
        this.properties = Object.freeze(properties);
        propertiesChanged = true;
        updated = true;
      }
      this.emitChangeEvent(range != null ? range : oldRange, textChanged, propertiesChanged);
      if (updated && !textChanged) {
        this.store.markerUpdated();
      }
      return updated;
    };

    Marker.prototype.getSnapshot = function(range) {
      return Object.freeze({
        range: range,
        properties: this.properties,
        reversed: this.reversed,
        tailed: this.tailed,
        valid: this.valid,
        invalidate: this.invalidate,
        maintainHistory: this.maintainHistory
      });
    };

    Marker.prototype.toString = function() {
      return "[Marker " + this.id + ", " + (this.getRange()) + "]";
    };


    /*
    Section: Private
     */

    Marker.prototype.emitChangeEvent = function(currentRange, textChanged, propertiesChanged) {
      var newHeadPosition, newState, newTailPosition, oldHeadPosition, oldState, oldTailPosition;
      if (!this.hasChangeObservers) {
        return;
      }
      oldState = this.previousEventState;
      if (currentRange == null) {
        currentRange = this.getRange();
      }
      if (!(propertiesChanged || oldState.valid !== this.valid || oldState.tailed !== this.tailed || oldState.reversed !== this.reversed || oldState.range.compare(currentRange) !== 0)) {
        return false;
      }
      newState = this.previousEventState = this.getSnapshot(currentRange);
      if (oldState.reversed) {
        oldHeadPosition = oldState.range.start;
        oldTailPosition = oldState.range.end;
      } else {
        oldHeadPosition = oldState.range.end;
        oldTailPosition = oldState.range.start;
      }
      if (newState.reversed) {
        newHeadPosition = newState.range.start;
        newTailPosition = newState.range.end;
      } else {
        newHeadPosition = newState.range.end;
        newTailPosition = newState.range.start;
      }
      this.emitter.emit("did-change", {
        wasValid: oldState.valid,
        isValid: newState.valid,
        hadTail: oldState.tailed,
        hasTail: newState.tailed,
        oldProperties: oldState.properties,
        newProperties: newState.properties,
        oldHeadPosition: oldHeadPosition,
        newHeadPosition: newHeadPosition,
        oldTailPosition: oldTailPosition,
        newTailPosition: newTailPosition,
        textChanged: textChanged
      });
      return true;
    };

    return Marker;

  })();

  // if (Grim.includeDeprecatedAPIs) {
  //   EmitterMixin = require('emissary').Emitter;
  //   EmitterMixin.includeInto(Marker);
  //   Marker.prototype.on = function(eventName) {
  //     switch (eventName) {
  //       case 'changed':
  //         Grim.deprecate("Use Marker::onDidChange instead");
  //         break;
  //       case 'destroyed':
  //         Grim.deprecate("Use Marker::onDidDestroy instead");
  //         break;
  //       default:
  //         Grim.deprecate("Marker::on is deprecated. Use event subscription methods instead.");
  //     }
  //     return EmitterMixin.prototype.on.apply(this, arguments);
  //   };
  //   Marker.prototype.matchesAttributes = function() {
  //     var args;
  //     args = 1 <= arguments.length ? __slice.call(arguments, 0) : [];
  //     Grim.deprecate("Use Marker::matchesParams instead.");
  //     return this.matchesParams.apply(this, args);
  //   };
  //   Marker.prototype.getAttributes = function() {
  //     Grim.deprecate("Use Marker::getProperties instead.");
  //     return this.getProperties();
  //   };
  //   Marker.prototype.setAttributes = function() {
  //     var args;
  //     args = 1 <= arguments.length ? __slice.call(arguments, 0) : [];
  //     Grim.deprecate("Use Marker::setProperties instead.");
  //     return this.setProperties.apply(this, args);
  //   };
  //   Marker.handleDeprecatedParams = function(params) {
  //     if (params.isReversed != null) {
  //       Grim.deprecate("The option `isReversed` is deprecated, use `reversed` instead");
  //       params.reversed = params.isReversed;
  //       delete params.isReversed;
  //     }
  //     if (params.hasTail != null) {
  //       Grim.deprecate("The option `hasTail` is deprecated, use `tailed` instead");
  //       params.tailed = params.hasTail;
  //       delete params.hasTail;
  //     }
  //     if (params.persist != null) {
  //       Grim.deprecate("The option `persist` is deprecated, use `persistent` instead");
  //       params.persistent = params.persist;
  //       delete params.persist;
  //     }
  //     if (params.invalidation) {
  //       Grim.deprecate("The option `invalidation` is deprecated, use `invalidate` instead");
  //       params.invalidate = params.invalidation;
  //       return delete params.invalidation;
  //     }
  //   };
  // }

}).call(this);

}),
  "mixto": (function (exports, require, module, __filename, __dirname, process, global) { (function() {
  var ExcludedClassProperties, ExcludedPrototypeProperties, Mixin, name;

  module.exports = Mixin = (function() {
    Mixin.includeInto = function(constructor) {
      var name, value, _ref;
      this.extend(constructor.prototype);
      for (name in this) {
        value = this[name];
        if (ExcludedClassProperties.indexOf(name) === -1) {
          if (!constructor.hasOwnProperty(name)) {
            constructor[name] = value;
          }
        }
      }
      return (_ref = this.included) != null ? _ref.call(constructor) : void 0;
    };

    Mixin.extend = function(object) {
      var name, _i, _len, _ref, _ref1;
      _ref = Object.getOwnPropertyNames(this.prototype);
      for (_i = 0, _len = _ref.length; _i < _len; _i++) {
        name = _ref[_i];
        if (ExcludedPrototypeProperties.indexOf(name) === -1) {
          if (!object.hasOwnProperty(name)) {
            object[name] = this.prototype[name];
          }
        }
      }
      return (_ref1 = this.prototype.extended) != null ? _ref1.call(object) : void 0;
    };

    function Mixin() {
      if (typeof this.extended === "function") {
        this.extended();
      }
    }

    return Mixin;

  })();

  ExcludedClassProperties = ['__super__'];

  for (name in Mixin) {
    ExcludedClassProperties.push(name);
  }

  ExcludedPrototypeProperties = ['constructor', 'extended'];

}).call(this);

}),
  "delegato": (function (exports, require, module, __filename, __dirname, process, global) { (function() {
  var Delegator, Mixin, _ref,
    __extends = function(child, parent) { for (var key in parent) { if (parent.hasOwnProperty(key)) child[key] = parent[key]; } function ctor() { this.constructor = child; } ctor.prototype = parent.prototype; child.prototype = new ctor(); child.__super__ = parent.prototype; return child; },
    __slice = [].slice;

  Mixin = require('mixto');

  module.exports = Delegator = (function(_super) {
    __extends(Delegator, _super);

    function Delegator() {
      _ref = Delegator.__super__.constructor.apply(this, arguments);
      return _ref;
    }

    Delegator.delegatesProperties = function() {
      var propertyName, propertyNames, toMethod, toProperty, _arg, _i, _j, _len, _results,
        _this = this;
      propertyNames = 2 <= arguments.length ? __slice.call(arguments, 0, _i = arguments.length - 1) : (_i = 0, []), _arg = arguments[_i++];
      toProperty = _arg.toProperty, toMethod = _arg.toMethod;
      _results = [];
      for (_j = 0, _len = propertyNames.length; _j < _len; _j++) {
        propertyName = propertyNames[_j];
        _results.push((function(propertyName) {
          return Object.defineProperty(_this.prototype, propertyName, (function() {
            if (toProperty != null) {
              return {
                get: function() {
                  return this[toProperty][propertyName];
                },
                set: function(value) {
                  return this[toProperty][propertyName] = value;
                }
              };
            } else if (toMethod != null) {
              return {
                get: function() {
                  return this[toMethod]()[propertyName];
                },
                set: function(value) {
                  return this[toMethod]()[propertyName] = value;
                }
              };
            } else {
              throw new Error("No delegation target specified");
            }
          })());
        })(propertyName));
      }
      return _results;
    };

    Delegator.delegatesMethods = function() {
      var methodName, methodNames, toMethod, toProperty, _arg, _i, _j, _len, _results,
        _this = this;
      methodNames = 2 <= arguments.length ? __slice.call(arguments, 0, _i = arguments.length - 1) : (_i = 0, []), _arg = arguments[_i++];
      toProperty = _arg.toProperty, toMethod = _arg.toMethod;
      _results = [];
      for (_j = 0, _len = methodNames.length; _j < _len; _j++) {
        methodName = methodNames[_j];
        _results.push((function(methodName) {
          if (toProperty != null) {
            return _this.prototype[methodName] = function() {
              var args, _ref1;
              args = 1 <= arguments.length ? __slice.call(arguments, 0) : [];
              return (_ref1 = this[toProperty])[methodName].apply(_ref1, args);
            };
          } else if (toMethod != null) {
            return _this.prototype[methodName] = function() {
              var args, _ref1;
              args = 1 <= arguments.length ? __slice.call(arguments, 0) : [];
              return (_ref1 = this[toMethod]())[methodName].apply(_ref1, args);
            };
          } else {
            throw new Error("No delegation target specified");
          }
        })(methodName));
      }
      return _results;
    };

    Delegator.delegatesProperty = function() {
      var args;
      args = 1 <= arguments.length ? __slice.call(arguments, 0) : [];
      return this.delegatesProperties.apply(this, args);
    };

    Delegator.delegatesMethod = function() {
      var args;
      args = 1 <= arguments.length ? __slice.call(arguments, 0) : [];
      return this.delegatesMethods.apply(this, args);
    };

    return Delegator;

  })(Mixin);

}).call(this);

}),
  "underscore": (function (exports, require, module, __filename, __dirname, process, global) { //     Underscore.js 1.6.0
//     http://underscorejs.org
//     (c) 2009-2014 Jeremy Ashkenas, DocumentCloud and Investigative Reporters & Editors
//     Underscore may be freely distributed under the MIT license.

(function() {

  // Baseline setup
  // --------------

  // Establish the root object, `window` in the browser, or `exports` on the server.
  var root = this;

  // Save the previous value of the `_` variable.
  var previousUnderscore = root._;

  // Establish the object that gets returned to break out of a loop iteration.
  var breaker = {};

  // Save bytes in the minified (but not gzipped) version:
  var ArrayProto = Array.prototype, ObjProto = Object.prototype, FuncProto = Function.prototype;

  // Create quick reference variables for speed access to core prototypes.
  var
    push             = ArrayProto.push,
    slice            = ArrayProto.slice,
    concat           = ArrayProto.concat;

  // All **ECMAScript 5** native function implementations that we hope to use
  // are declared here.
  var
    nativeForEach      = ArrayProto.forEach,
    nativeMap          = ArrayProto.map,
    nativeReduce       = ArrayProto.reduce,
    nativeReduceRight  = ArrayProto.reduceRight,
    nativeFilter       = ArrayProto.filter,
    nativeEvery        = ArrayProto.every,
    nativeSome         = ArrayProto.some,
    nativeIndexOf      = ArrayProto.indexOf,
    nativeLastIndexOf  = ArrayProto.lastIndexOf,
    nativeIsArray      = Array.isArray,
    nativeKeys         = Object.keys,
    nativeBind         = FuncProto.bind;

  // Create a safe reference to the Underscore object for use below.
  var _ = function(obj) {
    if (obj instanceof _) return obj;
    if (!(this instanceof _)) return new _(obj);
    this._wrapped = obj;
  };

  // Export the Underscore object for **Node.js**, with
  // backwards-compatibility for the old `require()` API. If we're in
  // the browser, add `_` as a global object via a string identifier,
  // for Closure Compiler "advanced" mode.
  if (typeof exports !== 'undefined') {
    if (typeof module !== 'undefined' && module.exports) {
      exports = module.exports = _;
    }
    exports._ = _;
  } else {
    root._ = _;
  }

  // Current version.
  _.VERSION = '1.6.0';

  // Collection Functions
  // --------------------

  // The cornerstone, an `each` implementation, aka `forEach`.
  // Handles objects with the built-in `forEach`, arrays, and raw objects.
  // Delegates to **ECMAScript 5**'s native `forEach` if available.
  var each = _.each = _.forEach = function(obj, iterator, context) {
    if (obj == null) return obj;
    if (nativeForEach && obj.forEach === nativeForEach) {
      obj.forEach(iterator, context);
    } else if (obj.length === +obj.length) {
      for (var i = 0, length = obj.length; i < length; i++) {
        if (iterator.call(context, obj[i], i, obj) === breaker) return;
      }
    } else {
      var keys = _.keys(obj);
      for (var i = 0, length = keys.length; i < length; i++) {
        if (iterator.call(context, obj[keys[i]], keys[i], obj) === breaker) return;
      }
    }
    return obj;
  };

  // Return the results of applying the iterator to each element.
  // Delegates to **ECMAScript 5**'s native `map` if available.
  _.map = _.collect = function(obj, iterator, context) {
    var results = [];
    if (obj == null) return results;
    if (nativeMap && obj.map === nativeMap) return obj.map(iterator, context);
    each(obj, function(value, index, list) {
      results.push(iterator.call(context, value, index, list));
    });
    return results;
  };

  var reduceError = 'Reduce of empty array with no initial value';

  // **Reduce** builds up a single result from a list of values, aka `inject`,
  // or `foldl`. Delegates to **ECMAScript 5**'s native `reduce` if available.
  _.reduce = _.foldl = _.inject = function(obj, iterator, memo, context) {
    var initial = arguments.length > 2;
    if (obj == null) obj = [];
    if (nativeReduce && obj.reduce === nativeReduce) {
      if (context) iterator = _.bind(iterator, context);
      return initial ? obj.reduce(iterator, memo) : obj.reduce(iterator);
    }
    each(obj, function(value, index, list) {
      if (!initial) {
        memo = value;
        initial = true;
      } else {
        memo = iterator.call(context, memo, value, index, list);
      }
    });
    if (!initial) throw new TypeError(reduceError);
    return memo;
  };

  // The right-associative version of reduce, also known as `foldr`.
  // Delegates to **ECMAScript 5**'s native `reduceRight` if available.
  _.reduceRight = _.foldr = function(obj, iterator, memo, context) {
    var initial = arguments.length > 2;
    if (obj == null) obj = [];
    if (nativeReduceRight && obj.reduceRight === nativeReduceRight) {
      if (context) iterator = _.bind(iterator, context);
      return initial ? obj.reduceRight(iterator, memo) : obj.reduceRight(iterator);
    }
    var length = obj.length;
    if (length !== +length) {
      var keys = _.keys(obj);
      length = keys.length;
    }
    each(obj, function(value, index, list) {
      index = keys ? keys[--length] : --length;
      if (!initial) {
        memo = obj[index];
        initial = true;
      } else {
        memo = iterator.call(context, memo, obj[index], index, list);
      }
    });
    if (!initial) throw new TypeError(reduceError);
    return memo;
  };

  // Return the first value which passes a truth test. Aliased as `detect`.
  _.find = _.detect = function(obj, predicate, context) {
    var result;
    any(obj, function(value, index, list) {
      if (predicate.call(context, value, index, list)) {
        result = value;
        return true;
      }
    });
    return result;
  };

  // Return all the elements that pass a truth test.
  // Delegates to **ECMAScript 5**'s native `filter` if available.
  // Aliased as `select`.
  _.filter = _.select = function(obj, predicate, context) {
    var results = [];
    if (obj == null) return results;
    if (nativeFilter && obj.filter === nativeFilter) return obj.filter(predicate, context);
    each(obj, function(value, index, list) {
      if (predicate.call(context, value, index, list)) results.push(value);
    });
    return results;
  };

  // Return all the elements for which a truth test fails.
  _.reject = function(obj, predicate, context) {
    return _.filter(obj, function(value, index, list) {
      return !predicate.call(context, value, index, list);
    }, context);
  };

  // Determine whether all of the elements match a truth test.
  // Delegates to **ECMAScript 5**'s native `every` if available.
  // Aliased as `all`.
  _.every = _.all = function(obj, predicate, context) {
    predicate || (predicate = _.identity);
    var result = true;
    if (obj == null) return result;
    if (nativeEvery && obj.every === nativeEvery) return obj.every(predicate, context);
    each(obj, function(value, index, list) {
      if (!(result = result && predicate.call(context, value, index, list))) return breaker;
    });
    return !!result;
  };

  // Determine if at least one element in the object matches a truth test.
  // Delegates to **ECMAScript 5**'s native `some` if available.
  // Aliased as `any`.
  var any = _.some = _.any = function(obj, predicate, context) {
    predicate || (predicate = _.identity);
    var result = false;
    if (obj == null) return result;
    if (nativeSome && obj.some === nativeSome) return obj.some(predicate, context);
    each(obj, function(value, index, list) {
      if (result || (result = predicate.call(context, value, index, list))) return breaker;
    });
    return !!result;
  };

  // Determine if the array or object contains a given value (using `===`).
  // Aliased as `include`.
  _.contains = _.include = function(obj, target) {
    if (obj == null) return false;
    if (nativeIndexOf && obj.indexOf === nativeIndexOf) return obj.indexOf(target) != -1;
    return any(obj, function(value) {
      return value === target;
    });
  };

  // Invoke a method (with arguments) on every item in a collection.
  _.invoke = function(obj, method) {
    var args = slice.call(arguments, 2);
    var isFunc = _.isFunction(method);
    return _.map(obj, function(value) {
      return (isFunc ? method : value[method]).apply(value, args);
    });
  };

  // Convenience version of a common use case of `map`: fetching a property.
  _.pluck = function(obj, key) {
    return _.map(obj, _.property(key));
  };

  // Convenience version of a common use case of `filter`: selecting only objects
  // containing specific `key:value` pairs.
  _.where = function(obj, attrs) {
    return _.filter(obj, _.matches(attrs));
  };

  // Convenience version of a common use case of `find`: getting the first object
  // containing specific `key:value` pairs.
  _.findWhere = function(obj, attrs) {
    return _.find(obj, _.matches(attrs));
  };

  // Return the maximum element or (element-based computation).
  // Can't optimize arrays of integers longer than 65,535 elements.
  // See [WebKit Bug 80797](https://bugs.webkit.org/show_bug.cgi?id=80797)
  _.max = function(obj, iterator, context) {
    if (!iterator && _.isArray(obj) && obj[0] === +obj[0] && obj.length < 65535) {
      return Math.max.apply(Math, obj);
    }
    var result = -Infinity, lastComputed = -Infinity;
    each(obj, function(value, index, list) {
      var computed = iterator ? iterator.call(context, value, index, list) : value;
      if (computed > lastComputed) {
        result = value;
        lastComputed = computed;
      }
    });
    return result;
  };

  // Return the minimum element (or element-based computation).
  _.min = function(obj, iterator, context) {
    if (!iterator && _.isArray(obj) && obj[0] === +obj[0] && obj.length < 65535) {
      return Math.min.apply(Math, obj);
    }
    var result = Infinity, lastComputed = Infinity;
    each(obj, function(value, index, list) {
      var computed = iterator ? iterator.call(context, value, index, list) : value;
      if (computed < lastComputed) {
        result = value;
        lastComputed = computed;
      }
    });
    return result;
  };

  // Shuffle an array, using the modern version of the
  // [Fisher-Yates shuffle](http://en.wikipedia.org/wiki/Fisher–Yates_shuffle).
  _.shuffle = function(obj) {
    var rand;
    var index = 0;
    var shuffled = [];
    each(obj, function(value) {
      rand = _.random(index++);
      shuffled[index - 1] = shuffled[rand];
      shuffled[rand] = value;
    });
    return shuffled;
  };

  // Sample **n** random values from a collection.
  // If **n** is not specified, returns a single random element.
  // The internal `guard` argument allows it to work with `map`.
  _.sample = function(obj, n, guard) {
    if (n == null || guard) {
      if (obj.length !== +obj.length) obj = _.values(obj);
      return obj[_.random(obj.length - 1)];
    }
    return _.shuffle(obj).slice(0, Math.max(0, n));
  };

  // An internal function to generate lookup iterators.
  var lookupIterator = function(value) {
    if (value == null) return _.identity;
    if (_.isFunction(value)) return value;
    return _.property(value);
  };

  // Sort the object's values by a criterion produced by an iterator.
  _.sortBy = function(obj, iterator, context) {
    iterator = lookupIterator(iterator);
    return _.pluck(_.map(obj, function(value, index, list) {
      return {
        value: value,
        index: index,
        criteria: iterator.call(context, value, index, list)
      };
    }).sort(function(left, right) {
      var a = left.criteria;
      var b = right.criteria;
      if (a !== b) {
        if (a > b || a === void 0) return 1;
        if (a < b || b === void 0) return -1;
      }
      return left.index - right.index;
    }), 'value');
  };

  // An internal function used for aggregate "group by" operations.
  var group = function(behavior) {
    return function(obj, iterator, context) {
      var result = {};
      iterator = lookupIterator(iterator);
      each(obj, function(value, index) {
        var key = iterator.call(context, value, index, obj);
        behavior(result, key, value);
      });
      return result;
    };
  };

  // Groups the object's values by a criterion. Pass either a string attribute
  // to group by, or a function that returns the criterion.
  _.groupBy = group(function(result, key, value) {
    _.has(result, key) ? result[key].push(value) : result[key] = [value];
  });

  // Indexes the object's values by a criterion, similar to `groupBy`, but for
  // when you know that your index values will be unique.
  _.indexBy = group(function(result, key, value) {
    result[key] = value;
  });

  // Counts instances of an object that group by a certain criterion. Pass
  // either a string attribute to count by, or a function that returns the
  // criterion.
  _.countBy = group(function(result, key) {
    _.has(result, key) ? result[key]++ : result[key] = 1;
  });

  // Use a comparator function to figure out the smallest index at which
  // an object should be inserted so as to maintain order. Uses binary search.
  _.sortedIndex = function(array, obj, iterator, context) {
    iterator = lookupIterator(iterator);
    var value = iterator.call(context, obj);
    var low = 0, high = array.length;
    while (low < high) {
      var mid = (low + high) >>> 1;
      iterator.call(context, array[mid]) < value ? low = mid + 1 : high = mid;
    }
    return low;
  };

  // Safely create a real, live array from anything iterable.
  _.toArray = function(obj) {
    if (!obj) return [];
    if (_.isArray(obj)) return slice.call(obj);
    if (obj.length === +obj.length) return _.map(obj, _.identity);
    return _.values(obj);
  };

  // Return the number of elements in an object.
  _.size = function(obj) {
    if (obj == null) return 0;
    return (obj.length === +obj.length) ? obj.length : _.keys(obj).length;
  };

  // Array Functions
  // ---------------

  // Get the first element of an array. Passing **n** will return the first N
  // values in the array. Aliased as `head` and `take`. The **guard** check
  // allows it to work with `_.map`.
  _.first = _.head = _.take = function(array, n, guard) {
    if (array == null) return void 0;
    if ((n == null) || guard) return array[0];
    if (n < 0) return [];
    return slice.call(array, 0, n);
  };

  // Returns everything but the last entry of the array. Especially useful on
  // the arguments object. Passing **n** will return all the values in
  // the array, excluding the last N. The **guard** check allows it to work with
  // `_.map`.
  _.initial = function(array, n, guard) {
    return slice.call(array, 0, array.length - ((n == null) || guard ? 1 : n));
  };

  // Get the last element of an array. Passing **n** will return the last N
  // values in the array. The **guard** check allows it to work with `_.map`.
  _.last = function(array, n, guard) {
    if (array == null) return void 0;
    if ((n == null) || guard) return array[array.length - 1];
    return slice.call(array, Math.max(array.length - n, 0));
  };

  // Returns everything but the first entry of the array. Aliased as `tail` and `drop`.
  // Especially useful on the arguments object. Passing an **n** will return
  // the rest N values in the array. The **guard**
  // check allows it to work with `_.map`.
  _.rest = _.tail = _.drop = function(array, n, guard) {
    return slice.call(array, (n == null) || guard ? 1 : n);
  };

  // Trim out all falsy values from an array.
  _.compact = function(array) {
    return _.filter(array, _.identity);
  };

  // Internal implementation of a recursive `flatten` function.
  var flatten = function(input, shallow, output) {
    if (shallow && _.every(input, _.isArray)) {
      return concat.apply(output, input);
    }
    each(input, function(value) {
      if (_.isArray(value) || _.isArguments(value)) {
        shallow ? push.apply(output, value) : flatten(value, shallow, output);
      } else {
        output.push(value);
      }
    });
    return output;
  };

  // Flatten out an array, either recursively (by default), or just one level.
  _.flatten = function(array, shallow) {
    return flatten(array, shallow, []);
  };

  // Return a version of the array that does not contain the specified value(s).
  _.without = function(array) {
    return _.difference(array, slice.call(arguments, 1));
  };

  // Split an array into two arrays: one whose elements all satisfy the given
  // predicate, and one whose elements all do not satisfy the predicate.
  _.partition = function(array, predicate) {
    var pass = [], fail = [];
    each(array, function(elem) {
      (predicate(elem) ? pass : fail).push(elem);
    });
    return [pass, fail];
  };

  // Produce a duplicate-free version of the array. If the array has already
  // been sorted, you have the option of using a faster algorithm.
  // Aliased as `unique`.
  _.uniq = _.unique = function(array, isSorted, iterator, context) {
    if (_.isFunction(isSorted)) {
      context = iterator;
      iterator = isSorted;
      isSorted = false;
    }
    var initial = iterator ? _.map(array, iterator, context) : array;
    var results = [];
    var seen = [];
    each(initial, function(value, index) {
      if (isSorted ? (!index || seen[seen.length - 1] !== value) : !_.contains(seen, value)) {
        seen.push(value);
        results.push(array[index]);
      }
    });
    return results;
  };

  // Produce an array that contains the union: each distinct element from all of
  // the passed-in arrays.
  _.union = function() {
    return _.uniq(_.flatten(arguments, true));
  };

  // Produce an array that contains every item shared between all the
  // passed-in arrays.
  _.intersection = function(array) {
    var rest = slice.call(arguments, 1);
    return _.filter(_.uniq(array), function(item) {
      return _.every(rest, function(other) {
        return _.contains(other, item);
      });
    });
  };

  // Take the difference between one array and a number of other arrays.
  // Only the elements present in just the first array will remain.
  _.difference = function(array) {
    var rest = concat.apply(ArrayProto, slice.call(arguments, 1));
    return _.filter(array, function(value){ return !_.contains(rest, value); });
  };

  // Zip together multiple lists into a single array -- elements that share
  // an index go together.
  _.zip = function() {
    var length = _.max(_.pluck(arguments, 'length').concat(0));
    var results = new Array(length);
    for (var i = 0; i < length; i++) {
      results[i] = _.pluck(arguments, '' + i);
    }
    return results;
  };

  // Converts lists into objects. Pass either a single array of `[key, value]`
  // pairs, or two parallel arrays of the same length -- one of keys, and one of
  // the corresponding values.
  _.object = function(list, values) {
    if (list == null) return {};
    var result = {};
    for (var i = 0, length = list.length; i < length; i++) {
      if (values) {
        result[list[i]] = values[i];
      } else {
        result[list[i][0]] = list[i][1];
      }
    }
    return result;
  };

  // If the browser doesn't supply us with indexOf (I'm looking at you, **MSIE**),
  // we need this function. Return the position of the first occurrence of an
  // item in an array, or -1 if the item is not included in the array.
  // Delegates to **ECMAScript 5**'s native `indexOf` if available.
  // If the array is large and already in sort order, pass `true`
  // for **isSorted** to use binary search.
  _.indexOf = function(array, item, isSorted) {
    if (array == null) return -1;
    var i = 0, length = array.length;
    if (isSorted) {
      if (typeof isSorted == 'number') {
        i = (isSorted < 0 ? Math.max(0, length + isSorted) : isSorted);
      } else {
        i = _.sortedIndex(array, item);
        return array[i] === item ? i : -1;
      }
    }
    if (nativeIndexOf && array.indexOf === nativeIndexOf) return array.indexOf(item, isSorted);
    for (; i < length; i++) if (array[i] === item) return i;
    return -1;
  };

  // Delegates to **ECMAScript 5**'s native `lastIndexOf` if available.
  _.lastIndexOf = function(array, item, from) {
    if (array == null) return -1;
    var hasIndex = from != null;
    if (nativeLastIndexOf && array.lastIndexOf === nativeLastIndexOf) {
      return hasIndex ? array.lastIndexOf(item, from) : array.lastIndexOf(item);
    }
    var i = (hasIndex ? from : array.length);
    while (i--) if (array[i] === item) return i;
    return -1;
  };

  // Generate an integer Array containing an arithmetic progression. A port of
  // the native Python `range()` function. See
  // [the Python documentation](http://docs.python.org/library/functions.html#range).
  _.range = function(start, stop, step) {
    if (arguments.length <= 1) {
      stop = start || 0;
      start = 0;
    }
    step = arguments[2] || 1;

    var length = Math.max(Math.ceil((stop - start) / step), 0);
    var idx = 0;
    var range = new Array(length);

    while(idx < length) {
      range[idx++] = start;
      start += step;
    }

    return range;
  };

  // Function (ahem) Functions
  // ------------------

  // Reusable constructor function for prototype setting.
  var ctor = function(){};

  // Create a function bound to a given object (assigning `this`, and arguments,
  // optionally). Delegates to **ECMAScript 5**'s native `Function.bind` if
  // available.
  _.bind = function(func, context) {
    var args, bound;
    if (nativeBind && func.bind === nativeBind) return nativeBind.apply(func, slice.call(arguments, 1));
    if (!_.isFunction(func)) throw new TypeError;
    args = slice.call(arguments, 2);
    return bound = function() {
      if (!(this instanceof bound)) return func.apply(context, args.concat(slice.call(arguments)));
      ctor.prototype = func.prototype;
      var self = new ctor;
      ctor.prototype = null;
      var result = func.apply(self, args.concat(slice.call(arguments)));
      if (Object(result) === result) return result;
      return self;
    };
  };

  // Partially apply a function by creating a version that has had some of its
  // arguments pre-filled, without changing its dynamic `this` context. _ acts
  // as a placeholder, allowing any combination of arguments to be pre-filled.
  _.partial = function(func) {
    var boundArgs = slice.call(arguments, 1);
    return function() {
      var position = 0;
      var args = boundArgs.slice();
      for (var i = 0, length = args.length; i < length; i++) {
        if (args[i] === _) args[i] = arguments[position++];
      }
      while (position < arguments.length) args.push(arguments[position++]);
      return func.apply(this, args);
    };
  };

  // Bind a number of an object's methods to that object. Remaining arguments
  // are the method names to be bound. Useful for ensuring that all callbacks
  // defined on an object belong to it.
  _.bindAll = function(obj) {
    var funcs = slice.call(arguments, 1);
    if (funcs.length === 0) throw new Error('bindAll must be passed function names');
    each(funcs, function(f) { obj[f] = _.bind(obj[f], obj); });
    return obj;
  };

  // Memoize an expensive function by storing its results.
  _.memoize = function(func, hasher) {
    var memo = {};
    hasher || (hasher = _.identity);
    return function() {
      var key = hasher.apply(this, arguments);
      return _.has(memo, key) ? memo[key] : (memo[key] = func.apply(this, arguments));
    };
  };

  // Delays a function for the given number of milliseconds, and then calls
  // it with the arguments supplied.
  _.delay = function(func, wait) {
    var args = slice.call(arguments, 2);
    return setTimeout(function(){ return func.apply(null, args); }, wait);
  };

  // Defers a function, scheduling it to run after the current call stack has
  // cleared.
  _.defer = function(func) {
    return _.delay.apply(_, [func, 1].concat(slice.call(arguments, 1)));
  };

  // Returns a function, that, when invoked, will only be triggered at most once
  // during a given window of time. Normally, the throttled function will run
  // as much as it can, without ever going more than once per `wait` duration;
  // but if you'd like to disable the execution on the leading edge, pass
  // `{leading: false}`. To disable execution on the trailing edge, ditto.
  _.throttle = function(func, wait, options) {
    var context, args, result;
    var timeout = null;
    var previous = 0;
    options || (options = {});
    var later = function() {
      previous = options.leading === false ? 0 : _.now();
      timeout = null;
      result = func.apply(context, args);
      context = args = null;
    };
    return function() {
      var now = _.now();
      if (!previous && options.leading === false) previous = now;
      var remaining = wait - (now - previous);
      context = this;
      args = arguments;
      if (remaining <= 0) {
        clearTimeout(timeout);
        timeout = null;
        previous = now;
        result = func.apply(context, args);
        context = args = null;
      } else if (!timeout && options.trailing !== false) {
        timeout = setTimeout(later, remaining);
      }
      return result;
    };
  };

  // Returns a function, that, as long as it continues to be invoked, will not
  // be triggered. The function will be called after it stops being called for
  // N milliseconds. If `immediate` is passed, trigger the function on the
  // leading edge, instead of the trailing.
  _.debounce = function(func, wait, immediate) {
    var timeout, args, context, timestamp, result;

    var later = function() {
      var last = _.now() - timestamp;
      if (last < wait) {
        timeout = setTimeout(later, wait - last);
      } else {
        timeout = null;
        if (!immediate) {
          result = func.apply(context, args);
          context = args = null;
        }
      }
    };

    return function() {
      context = this;
      args = arguments;
      timestamp = _.now();
      var callNow = immediate && !timeout;
      if (!timeout) {
        timeout = setTimeout(later, wait);
      }
      if (callNow) {
        result = func.apply(context, args);
        context = args = null;
      }

      return result;
    };
  };

  // Returns a function that will be executed at most one time, no matter how
  // often you call it. Useful for lazy initialization.
  _.once = function(func) {
    var ran = false, memo;
    return function() {
      if (ran) return memo;
      ran = true;
      memo = func.apply(this, arguments);
      func = null;
      return memo;
    };
  };

  // Returns the first function passed as an argument to the second,
  // allowing you to adjust arguments, run code before and after, and
  // conditionally execute the original function.
  _.wrap = function(func, wrapper) {
    return _.partial(wrapper, func);
  };

  // Returns a function that is the composition of a list of functions, each
  // consuming the return value of the function that follows.
  _.compose = function() {
    var funcs = arguments;
    return function() {
      var args = arguments;
      for (var i = funcs.length - 1; i >= 0; i--) {
        args = [funcs[i].apply(this, args)];
      }
      return args[0];
    };
  };

  // Returns a function that will only be executed after being called N times.
  _.after = function(times, func) {
    return function() {
      if (--times < 1) {
        return func.apply(this, arguments);
      }
    };
  };

  // Object Functions
  // ----------------

  // Retrieve the names of an object's properties.
  // Delegates to **ECMAScript 5**'s native `Object.keys`
  _.keys = function(obj) {
    if (!_.isObject(obj)) return [];
    if (nativeKeys) return nativeKeys(obj);
    var keys = [];
    for (var key in obj) if (_.has(obj, key)) keys.push(key);
    return keys;
  };

  // Retrieve the values of an object's properties.
  _.values = function(obj) {
    var keys = _.keys(obj);
    var length = keys.length;
    var values = new Array(length);
    for (var i = 0; i < length; i++) {
      values[i] = obj[keys[i]];
    }
    return values;
  };

  // Convert an object into a list of `[key, value]` pairs.
  _.pairs = function(obj) {
    var keys = _.keys(obj);
    var length = keys.length;
    var pairs = new Array(length);
    for (var i = 0; i < length; i++) {
      pairs[i] = [keys[i], obj[keys[i]]];
    }
    return pairs;
  };

  // Invert the keys and values of an object. The values must be serializable.
  _.invert = function(obj) {
    var result = {};
    var keys = _.keys(obj);
    for (var i = 0, length = keys.length; i < length; i++) {
      result[obj[keys[i]]] = keys[i];
    }
    return result;
  };

  // Return a sorted list of the function names available on the object.
  // Aliased as `methods`
  _.functions = _.methods = function(obj) {
    var names = [];
    for (var key in obj) {
      if (_.isFunction(obj[key])) names.push(key);
    }
    return names.sort();
  };

  // Extend a given object with all the properties in passed-in object(s).
  _.extend = function(obj) {
    each(slice.call(arguments, 1), function(source) {
      if (source) {
        for (var prop in source) {
          obj[prop] = source[prop];
        }
      }
    });
    return obj;
  };

  // Return a copy of the object only containing the whitelisted properties.
  _.pick = function(obj) {
    var copy = {};
    var keys = concat.apply(ArrayProto, slice.call(arguments, 1));
    each(keys, function(key) {
      if (key in obj) copy[key] = obj[key];
    });
    return copy;
  };

   // Return a copy of the object without the blacklisted properties.
  _.omit = function(obj) {
    var copy = {};
    var keys = concat.apply(ArrayProto, slice.call(arguments, 1));
    for (var key in obj) {
      if (!_.contains(keys, key)) copy[key] = obj[key];
    }
    return copy;
  };

  // Fill in a given object with default properties.
  _.defaults = function(obj) {
    each(slice.call(arguments, 1), function(source) {
      if (source) {
        for (var prop in source) {
          if (obj[prop] === void 0) obj[prop] = source[prop];
        }
      }
    });
    return obj;
  };

  // Create a (shallow-cloned) duplicate of an object.
  _.clone = function(obj) {
    if (!_.isObject(obj)) return obj;
    return _.isArray(obj) ? obj.slice() : _.extend({}, obj);
  };

  // Invokes interceptor with the obj, and then returns obj.
  // The primary purpose of this method is to "tap into" a method chain, in
  // order to perform operations on intermediate results within the chain.
  _.tap = function(obj, interceptor) {
    interceptor(obj);
    return obj;
  };

  // Internal recursive comparison function for `isEqual`.
  var eq = function(a, b, aStack, bStack) {
    // Identical objects are equal. `0 === -0`, but they aren't identical.
    // See the [Harmony `egal` proposal](http://wiki.ecmascript.org/doku.php?id=harmony:egal).
    if (a === b) return a !== 0 || 1 / a == 1 / b;
    // A strict comparison is necessary because `null == undefined`.
    if (a == null || b == null) return a === b;
    // Unwrap any wrapped objects.
    if (a instanceof _) a = a._wrapped;
    if (b instanceof _) b = b._wrapped;
    // Compare `[[Class]]` names.
    var className = a.toString();
    if (className != b.toString()) return false;
    switch (className) {
      // Strings, numbers, dates, and booleans are compared by value.
      case '[object String]':
        // Primitives and their corresponding object wrappers are equivalent; thus, `"5"` is
        // equivalent to `new String("5")`.
        return a == String(b);
      case '[object Number]':
        // `NaN`s are equivalent, but non-reflexive. An `egal` comparison is performed for
        // other numeric values.
        return a != +a ? b != +b : (a == 0 ? 1 / a == 1 / b : a == +b);
      case '[object Date]':
      case '[object Boolean]':
        // Coerce dates and booleans to numeric primitive values. Dates are compared by their
        // millisecond representations. Note that invalid dates with millisecond representations
        // of `NaN` are not equivalent.
        return +a == +b;
      // RegExps are compared by their source patterns and flags.
      case '[object RegExp]':
        return a.source == b.source &&
               a.global == b.global &&
               a.multiline == b.multiline &&
               a.ignoreCase == b.ignoreCase;
    }
    if (typeof a != 'object' || typeof b != 'object') return false;
    // Assume equality for cyclic structures. The algorithm for detecting cyclic
    // structures is adapted from ES 5.1 section 15.12.3, abstract operation `JO`.
    var length = aStack.length;
    while (length--) {
      // Linear search. Performance is inversely proportional to the number of
      // unique nested structures.
      if (aStack[length] == a) return bStack[length] == b;
    }
    // Objects with different constructors are not equivalent, but `Object`s
    // from different frames are.
    var aCtor = a.constructor, bCtor = b.constructor;
    if (aCtor !== bCtor && !(_.isFunction(aCtor) && (aCtor instanceof aCtor) &&
                             _.isFunction(bCtor) && (bCtor instanceof bCtor))
                        && ('constructor' in a && 'constructor' in b)) {
      return false;
    }
    // Add the first object to the stack of traversed objects.
    aStack.push(a);
    bStack.push(b);
    var size = 0, result = true;
    // Recursively compare objects and arrays.
    if (className == '[object Array]') {
      // Compare array lengths to determine if a deep comparison is necessary.
      size = a.length;
      result = size == b.length;
      if (result) {
        // Deep compare the contents, ignoring non-numeric properties.
        while (size--) {
          if (!(result = eq(a[size], b[size], aStack, bStack))) break;
        }
      }
    } else {
      // Deep compare objects.
      for (var key in a) {
        if (_.has(a, key)) {
          // Count the expected number of properties.
          size++;
          // Deep compare each member.
          if (!(result = _.has(b, key) && eq(a[key], b[key], aStack, bStack))) break;
        }
      }
      // Ensure that both objects contain the same number of properties.
      if (result) {
        for (key in b) {
          if (_.has(b, key) && !(size--)) break;
        }
        result = !size;
      }
    }
    // Remove the first object from the stack of traversed objects.
    aStack.pop();
    bStack.pop();
    return result;
  };

  // Perform a deep comparison to check if two objects are equal.
  _.isEqual = function(a, b) {
    return eq(a, b, [], []);
  };

  // Is a given array, string, or object empty?
  // An "empty" object has no enumerable own-properties.
  _.isEmpty = function(obj) {
    if (obj == null) return true;
    if (_.isArray(obj) || _.isString(obj)) return obj.length === 0;
    for (var key in obj) if (_.has(obj, key)) return false;
    return true;
  };

  // Is a given value a DOM element?
  _.isElement = function(obj) {
    return !!(obj && obj.nodeType === 1);
  };

  // Is a given value an array?
  // Delegates to ECMA5's native Array.isArray
  _.isArray = nativeIsArray || function(obj) {
    return obj.toString() == '[object Array]';
  };

  // Is a given variable an object?
  _.isObject = function(obj) {
    return obj === Object(obj);
  };

  // Add some isType methods: isArguments, isFunction, isString, isNumber, isDate, isRegExp.
  each(['Arguments', 'Function', 'String', 'Number', 'Date', 'RegExp'], function(name) {
    _['is' + name] = function(obj) {
      return obj.toString() == '[object ' + name + ']';
    };
  });

  // Define a fallback version of the method in browsers (ahem, IE), where
  // there isn't any inspectable "Arguments" type.
  // if (!_.isArguments(arguments)) {
  //   _.isArguments = function(obj) {
  //     return !!(obj && _.has(obj, 'callee'));
  //   };
  // }

  // Optimize `isFunction` if appropriate.
  if (typeof (/./) !== 'function') {
    _.isFunction = function(obj) {
      return typeof obj === 'function';
    };
  }

  // Is a given object a finite number?
  _.isFinite = function(obj) {
    return isFinite(obj) && !isNaN(parseFloat(obj));
  };

  // Is the given value `NaN`? (NaN is the only number which does not equal itself).
  _.isNaN = function(obj) {
    return _.isNumber(obj) && obj != +obj;
  };

  // Is a given value a boolean?
  _.isBoolean = function(obj) {
    return obj === true || obj === false || obj.toString() == '[object Boolean]';
  };

  // Is a given value equal to null?
  _.isNull = function(obj) {
    return obj === null;
  };

  // Is a given variable undefined?
  _.isUndefined = function(obj) {
    return obj === void 0;
  };

  // Shortcut function for checking if an object has a given property directly
  // on itself (in other words, not on a prototype).
  _.has = function(obj, key) {
    return obj.hasOwnProperty(key);
  };

  // Utility Functions
  // -----------------

  // Run Underscore.js in *noConflict* mode, returning the `_` variable to its
  // previous owner. Returns a reference to the Underscore object.
  _.noConflict = function() {
    root._ = previousUnderscore;
    return this;
  };

  // Keep the identity function around for default iterators.
  _.identity = function(value) {
    return value;
  };

  _.constant = function(value) {
    return function () {
      return value;
    };
  };

  _.property = function(key) {
    return function(obj) {
      return obj[key];
    };
  };

  // Returns a predicate for checking whether an object has a given set of `key:value` pairs.
  _.matches = function(attrs) {
    return function(obj) {
      if (obj === attrs) return true; //avoid comparing an object to itself.
      for (var key in attrs) {
        if (attrs[key] !== obj[key])
          return false;
      }
      return true;
    }
  };

  // Run a function **n** times.
  _.times = function(n, iterator, context) {
    var accum = Array(Math.max(0, n));
    for (var i = 0; i < n; i++) accum[i] = iterator.call(context, i);
    return accum;
  };

  // Return a random integer between min and max (inclusive).
  _.random = function(min, max) {
    if (max == null) {
      max = min;
      min = 0;
    }
    return min + Math.floor(Math.random() * (max - min + 1));
  };

  // A (possibly faster) way to get the current timestamp as an integer.
  _.now = Date.now || function() { return new Date().getTime(); };

  // List of HTML entities for escaping.
  var entityMap = {
    escape: {
      '&': '&amp;',
      '<': '&lt;',
      '>': '&gt;',
      '"': '&quot;',
      "'": '&#x27;'
    }
  };
  entityMap.unescape = _.invert(entityMap.escape);

  // Regexes containing the keys and values listed immediately above.
  var entityRegexes = {
    escape:   new RegExp('[' + _.keys(entityMap.escape).join('') + ']', 'g'),
    unescape: new RegExp('(' + _.keys(entityMap.unescape).join('|') + ')', 'g')
  };

  // Functions for escaping and unescaping strings to/from HTML interpolation.
  _.each(['escape', 'unescape'], function(method) {
    _[method] = function(string) {
      if (string == null) return '';
      return ('' + string).replace(entityRegexes[method], function(match) {
        return entityMap[method][match];
      });
    };
  });

  // If the value of the named `property` is a function then invoke it with the
  // `object` as context; otherwise, return it.
  _.result = function(object, property) {
    if (object == null) return void 0;
    var value = object[property];
    return _.isFunction(value) ? value.call(object) : value;
  };

  // Add your own custom functions to the Underscore object.
  _.mixin = function(obj) {
    each(_.functions(obj), function(name) {
      var func = _[name] = obj[name];
      _.prototype[name] = function() {
        var args = [this._wrapped];
        push.apply(args, arguments);
        return result.call(this, func.apply(_, args));
      };
    });
  };

  // Generate a unique integer id (unique within the entire client session).
  // Useful for temporary DOM ids.
  var idCounter = 0;
  _.uniqueId = function(prefix) {
    var id = ++idCounter + '';
    return prefix ? prefix + id : id;
  };

  // By default, Underscore uses ERB-style template delimiters, change the
  // following template settings to use alternative delimiters.
  _.templateSettings = {
    evaluate    : /<%([\s\S]+?)%>/g,
    interpolate : /<%=([\s\S]+?)%>/g,
    escape      : /<%-([\s\S]+?)%>/g
  };

  // When customizing `templateSettings`, if you don't want to define an
  // interpolation, evaluation or escaping regex, we need one that is
  // guaranteed not to match.
  var noMatch = /(.)^/;

  // Certain characters need to be escaped so that they can be put into a
  // string literal.
  var escapes = {
    "'":      "'",
    '\\':     '\\',
    '\r':     'r',
    '\n':     'n',
    '\t':     't',
    '\u2028': 'u2028',
    '\u2029': 'u2029'
  };

  var escaper = /\\|'|\r|\n|\t|\u2028|\u2029/g;

  // JavaScript micro-templating, similar to John Resig's implementation.
  // Underscore templating handles arbitrary delimiters, preserves whitespace,
  // and correctly escapes quotes within interpolated code.
  _.template = function(text, data, settings) {
    var render;
    settings = _.defaults({}, settings, _.templateSettings);

    // Combine delimiters into one regular expression via alternation.
    var matcher = new RegExp([
      (settings.escape || noMatch).source,
      (settings.interpolate || noMatch).source,
      (settings.evaluate || noMatch).source
    ].join('|') + '|$', 'g');

    // Compile the template source, escaping string literals appropriately.
    var index = 0;
    var source = "__p+='";
    text.replace(matcher, function(match, escape, interpolate, evaluate, offset) {
      source += text.slice(index, offset)
        .replace(escaper, function(match) { return '\\' + escapes[match]; });

      if (escape) {
        source += "'+\n((__t=(" + escape + "))==null?'':_.escape(__t))+\n'";
      }
      if (interpolate) {
        source += "'+\n((__t=(" + interpolate + "))==null?'':__t)+\n'";
      }
      if (evaluate) {
        source += "';\n" + evaluate + "\n__p+='";
      }
      index = offset + match.length;
      return match;
    });
    source += "';\n";

    // If a variable is not specified, place data values in local scope.
    if (!settings.variable) source = 'with(obj||{}){\n' + source + '}\n';

    source = "var __t,__p='',__j=Array.prototype.join," +
      "print=function(){__p+=__j.call(arguments,'');};\n" +
      source + "return __p;\n";

    try {
      render = new Function(settings.variable || 'obj', '_', source);
    } catch (e) {
      e.source = source;
      throw e;
    }

    if (data) return render(data, _);
    var template = function(data) {
      return render.call(this, data, _);
    };

    // Provide the compiled function source as a convenience for precompilation.
    template.source = 'function(' + (settings.variable || 'obj') + '){\n' + source + '}';

    return template;
  };

  // Add a "chain" function, which will delegate to the wrapper.
  _.chain = function(obj) {
    return _(obj).chain();
  };

  // OOP
  // ---------------
  // If Underscore is called as a function, it returns a wrapped object that
  // can be used OO-style. This wrapper holds altered versions of all the
  // underscore functions. Wrapped objects may be chained.

  // Helper function to continue chaining intermediate results.
  var result = function(obj) {
    return this._chain ? _(obj).chain() : obj;
  };

  // Add all of the Underscore functions to the wrapper object.
  _.mixin(_);

  // Add all mutator Array functions to the wrapper.
  each(['pop', 'push', 'reverse', 'shift', 'sort', 'splice', 'unshift'], function(name) {
    var method = ArrayProto[name];
    _.prototype[name] = function() {
      var obj = this._wrapped;
      method.apply(obj, arguments);
      if ((name == 'shift' || name == 'splice') && obj.length === 0) delete obj[0];
      return result.call(this, obj);
    };
  });

  // Add all accessor Array functions to the wrapper.
  each(['concat', 'join', 'slice'], function(name) {
    var method = ArrayProto[name];
    _.prototype[name] = function() {
      return result.call(this, method.apply(this._wrapped, arguments));
    };
  });

  _.extend(_.prototype, {

    // Start chaining a wrapped Underscore object.
    chain: function() {
      this._chain = true;
      return this;
    },

    // Extracts the result from a wrapped and chained object.
    value: function() {
      return this._wrapped;
    }

  });

  // AMD registration happens at the end for compatibility with AMD loaders
  // that may not enforce next-turn semantics on modules. Even though general
  // practice for AMD registration is to be anonymous, underscore registers
  // as a named module because, like jQuery, it is a base library that is
  // popular enough to be bundled in a third party lib, but not be part of
  // an AMD load request. Those cases could generate an error when an
  // anonymous define() is called outside of a loader request.
  if (typeof define === 'function' && define.amd) {
    define('underscore', [], function() {
      return _;
    });
  }
}).call(this);

}),
  "underscore-plus": (function (exports, require, module, __filename, __dirname, process, global) { (function() {
  var isEqual, isPlainObject, macModifierKeyMap, nonMacModifierKeyMap, plus, shiftKeyMap, splitKeyPath, _,
    __slice = [].slice;

  _ = require('underscore');

  macModifierKeyMap = {
    cmd: '\u2318',
    ctrl: '\u2303',
    alt: '\u2325',
    option: '\u2325',
    shift: '\u21e7',
    enter: '\u23ce',
    left: '\u2190',
    right: '\u2192',
    up: '\u2191',
    down: '\u2193'
  };

  nonMacModifierKeyMap = {
    cmd: 'Cmd',
    ctrl: 'Ctrl',
    alt: 'Alt',
    option: 'Alt',
    shift: 'Shift',
    enter: 'Enter',
    left: 'Left',
    right: 'Right',
    up: 'Up',
    down: 'Down'
  };

  shiftKeyMap = {
    '~': '`',
    '_': '-',
    '+': '=',
    '|': '\\',
    '{': '[',
    '}': ']',
    ':': ';',
    '"': '\'',
    '<': ',',
    '>': '.',
    '?': '/'
  };

  splitKeyPath = function(keyPath) {
    var char, i, keyPathArray, startIndex, _i, _len;
    startIndex = 0;
    keyPathArray = [];
    if (keyPath == null) {
      return keyPathArray;
    }
    for (i = _i = 0, _len = keyPath.length; _i < _len; i = ++_i) {
      char = keyPath[i];
      if (char === '.' && (i === 0 || keyPath[i - 1] !== '\\')) {
        keyPathArray.push(keyPath.substring(startIndex, i));
        startIndex = i + 1;
      }
    }
    keyPathArray.push(keyPath.substr(startIndex, keyPath.length));
    return keyPathArray;
  };

  isPlainObject = function(value) {
    return _.isObject(value) && !_.isArray(value);
  };

  plus = {
    adviseBefore: function(object, methodName, advice) {
      var original;
      original = object[methodName];
      return object[methodName] = function() {
        var args;
        args = 1 <= arguments.length ? __slice.call(arguments, 0) : [];
        if (advice.apply(this, args) !== false) {
          return original.apply(this, args);
        }
      };
    },
    camelize: function(string) {
      if (string) {
        return string.replace(/[_-]+(\w)/g, function(m) {
          return m[1].toUpperCase();
        });
      } else {
        return '';
      }
    },
    capitalize: function(word) {
      if (!word) {
        return '';
      }
      if (word.toLowerCase() === 'github') {
        return 'GitHub';
      } else {
        return word[0].toUpperCase() + word.slice(1);
      }
    },
    compactObject: function(object) {
      var key, newObject, value;
      newObject = {};
      for (key in object) {
        value = object[key];
        if (value != null) {
          newObject[key] = value;
        }
      }
      return newObject;
    },
    dasherize: function(string) {
      if (!string) {
        return '';
      }
      string = string[0].toLowerCase() + string.slice(1);
      return string.replace(/([A-Z])|(_)/g, function(m, letter) {
        if (letter) {
          return "-" + letter.toLowerCase();
        } else {
          return "-";
        }
      });
    },
    deepClone: function(object) {
      if (_.isArray(object)) {
        return object.map(function(value) {
          return plus.deepClone(value);
        });
      } else if (_.isObject(object) && !_.isFunction(object)) {
        return plus.mapObject(object, (function(_this) {
          return function(key, value) {
            return [key, plus.deepClone(value)];
          };
        })(this));
      } else {
        return object;
      }
    },
    deepExtend: function(target) {
      var i, key, object, result, _i, _len, _ref;
      result = target;
      i = 0;
      while (++i < arguments.length) {
        object = arguments[i];
        if (isPlainObject(result) && isPlainObject(object)) {
          _ref = Object.keys(object);
          for (_i = 0, _len = _ref.length; _i < _len; _i++) {
            key = _ref[_i];
            result[key] = plus.deepExtend(result[key], object[key]);
          }
        } else {
          result = plus.deepClone(object);
        }
      }
      return result;
    },
    deepContains: function(array, target) {
      var object, _i, _len;
      if (array == null) {
        return false;
      }
      for (_i = 0, _len = array.length; _i < _len; _i++) {
        object = array[_i];
        if (_.isEqual(object, target)) {
          return true;
        }
      }
      return false;
    },
    endsWith: function(string, suffix) {
      if (suffix == null) {
        suffix = '';
      }
      if (string) {
        return string.indexOf(suffix, string.length - suffix.length) !== -1;
      } else {
        return false;
      }
    },
    escapeAttribute: function(string) {
      if (string) {
        return string.replace(/"/g, '&quot;').replace(/\n/g, '').replace(/\\/g, '-');
      } else {
        return '';
      }
    },
    escapeRegExp: function(string) {
      if (string) {
        return string.replace(/[-\/\\^$*+?.()|[\]{}]/g, '\\$&');
      } else {
        return '';
      }
    },
    humanizeEventName: function(eventName, eventDoc) {
      var event, namespace, namespaceDoc, _ref;
      _ref = eventName.split(':'), namespace = _ref[0], event = _ref[1];
      if (event == null) {
        return plus.undasherize(namespace);
      }
      namespaceDoc = plus.undasherize(namespace);
      if (eventDoc == null) {
        eventDoc = plus.undasherize(event);
      }
      return "" + namespaceDoc + ": " + eventDoc;
    },
    humanizeKey: function(key, platform) {
      var modifierKeyMap;
      if (platform == null) {
        platform = process.platform;
      }
      if (!key) {
        return key;
      }
      modifierKeyMap = platform === 'darwin' ? macModifierKeyMap : nonMacModifierKeyMap;
      if (modifierKeyMap[key]) {
        return modifierKeyMap[key];
      } else if (key.length === 1 && (shiftKeyMap[key] != null)) {
        return [modifierKeyMap.shift, shiftKeyMap[key]];
      } else if (key.length === 1 && key === key.toUpperCase() && key.toUpperCase() !== key.toLowerCase()) {
        return [modifierKeyMap.shift, key.toUpperCase()];
      } else if (key.length === 1 || /f[0-9]{1,2}/.test(key)) {
        return key.toUpperCase();
      } else {
        if (platform === 'darwin') {
          return key;
        } else {
          return plus.capitalize(key);
        }
      }
    },
    humanizeKeystroke: function(keystroke, platform) {
      var humanizedKeystrokes, index, key, keys, keystrokes, splitKeystroke, _i, _j, _len, _len1;
      if (platform == null) {
        platform = process.platform;
      }
      if (!keystroke) {
        return keystroke;
      }
      keystrokes = keystroke.split(' ');
      humanizedKeystrokes = [];
      for (_i = 0, _len = keystrokes.length; _i < _len; _i++) {
        keystroke = keystrokes[_i];
        keys = [];
        splitKeystroke = keystroke.split('-');
        for (index = _j = 0, _len1 = splitKeystroke.length; _j < _len1; index = ++_j) {
          key = splitKeystroke[index];
          if (key === '' && splitKeystroke[index - 1] === '') {
            key = '-';
          }
          if (key) {
            keys.push(plus.humanizeKey(key, platform));
          }
        }
        keys = _.uniq(_.flatten(keys));
        if (platform === 'darwin') {
          keys = keys.join('');
        } else {
          keys = keys.join('+');
        }
        humanizedKeystrokes.push(keys);
      }
      return humanizedKeystrokes.join(' ');
    },
    isSubset: function(potentialSubset, potentialSuperset) {
      return _.every(potentialSubset, function(element) {
        return _.include(potentialSuperset, element);
      });
    },
    losslessInvert: function(hash) {
      var inverted, key, value;
      inverted = {};
      for (key in hash) {
        value = hash[key];
        if (inverted[value] == null) {
          inverted[value] = [];
        }
        inverted[value].push(key);
      }
      return inverted;
    },
    mapObject: function(object, iterator) {
      var key, newObject, value, _i, _len, _ref, _ref1;
      newObject = {};
      _ref = Object.keys(object);
      for (_i = 0, _len = _ref.length; _i < _len; _i++) {
        key = _ref[_i];
        _ref1 = iterator(key, object[key]), key = _ref1[0], value = _ref1[1];
        newObject[key] = value;
      }
      return newObject;
    },
    multiplyString: function(string, n) {
      var finalString, i;
      finalString = "";
      i = 0;
      while (i < n) {
        finalString += string;
        i++;
      }
      return finalString;
    },
    pluralize: function(count, singular, plural) {
      if (count == null) {
        count = 0;
      }
      if (plural == null) {
        plural = singular + 's';
      }
      if (count === 1) {
        return "" + count + " " + singular;
      } else {
        return "" + count + " " + plural;
      }
    },
    remove: function(array, element) {
      var index;
      index = array.indexOf(element);
      if (index >= 0) {
        array.splice(index, 1);
      }
      return array;
    },
    setValueForKeyPath: function(object, keyPath, value) {
      var key, keys;
      keys = splitKeyPath(keyPath);
      while (keys.length > 1) {
        key = keys.shift();
        if (object[key] == null) {
          object[key] = {};
        }
        object = object[key];
      }
      if (value != null) {
        return object[keys.shift()] = value;
      } else {
        return delete object[keys.shift()];
      }
    },
    hasKeyPath: function(object, keyPath) {
      var key, keys, _i, _len;
      keys = splitKeyPath(keyPath);
      for (_i = 0, _len = keys.length; _i < _len; _i++) {
        key = keys[_i];
        if (!object.hasOwnProperty(key)) {
          return false;
        }
        object = object[key];
      }
      return true;
    },
    spliceWithArray: function(originalArray, start, length, insertedArray, chunkSize) {
      var chunkStart, _i, _ref, _results;
      if (chunkSize == null) {
        chunkSize = 100000;
      }
      if (insertedArray.length < chunkSize) {
        return originalArray.splice.apply(originalArray, [start, length].concat(__slice.call(insertedArray)));
      } else {
        originalArray.splice(start, length);
        _results = [];
        for (chunkStart = _i = 0, _ref = insertedArray.length; chunkSize > 0 ? _i <= _ref : _i >= _ref; chunkStart = _i += chunkSize) {
          _results.push(originalArray.splice.apply(originalArray, [start + chunkStart, 0].concat(__slice.call(insertedArray.slice(chunkStart, chunkStart + chunkSize)))));
        }
        return _results;
      }
    },
    sum: function(array) {
      var elt, sum, _i, _len;
      sum = 0;
      for (_i = 0, _len = array.length; _i < _len; _i++) {
        elt = array[_i];
        sum += elt;
      }
      return sum;
    },
    uncamelcase: function(string) {
      var result;
      if (!string) {
        return '';
      }
      result = string.replace(/([A-Z])|_+/g, function(match, letter) {
        if (letter == null) {
          letter = '';
        }
        return " " + letter;
      });
      return plus.capitalize(result.trim());
    },
    undasherize: function(string) {
      if (string) {
        return string.split('-').map(plus.capitalize).join(' ');
      } else {
        return '';
      }
    },
    underscore: function(string) {
      if (!string) {
        return '';
      }
      string = string[0].toLowerCase() + string.slice(1);
      return string.replace(/([A-Z])|-+/g, function(match, letter) {
        if (letter == null) {
          letter = '';
        }
        return "_" + (letter.toLowerCase());
      });
    },
    valueForKeyPath: function(object, keyPath) {
      var key, keys, _i, _len;
      keys = splitKeyPath(keyPath);
      for (_i = 0, _len = keys.length; _i < _len; _i++) {
        key = keys[_i];
        object = object[key];
        if (object == null) {
          return;
        }
      }
      return object;
    },
    isEqual: function(a, b, aStack, bStack) {
      if (_.isArray(aStack) && _.isArray(bStack)) {
        return isEqual(a, b, aStack, bStack);
      } else {
        return isEqual(a, b);
      }
    },
    isEqualForProperties: function() {
      var a, b, properties, property, _i, _len;
      a = arguments[0], b = arguments[1], properties = 3 <= arguments.length ? __slice.call(arguments, 2) : [];
      for (_i = 0, _len = properties.length; _i < _len; _i++) {
        property = properties[_i];
        if (!_.isEqual(a[property], b[property])) {
          return false;
        }
      }
      return true;
    }
  };

  isEqual = function(a, b, aStack, bStack) {
    var aCtor, aCtorValid, aElement, aKeyCount, aValue, bCtor, bCtorValid, bKeyCount, bValue, equal, i, key, stackIndex, _i, _len;
    if (aStack == null) {
      aStack = [];
    }
    if (bStack == null) {
      bStack = [];
    }
    if (a === b) {
      return _.isEqual(a, b);
    }
    if (_.isFunction(a) || _.isFunction(b)) {
      return _.isEqual(a, b);
    }
    stackIndex = aStack.length;
    while (stackIndex--) {
      if (aStack[stackIndex] === a) {
        return bStack[stackIndex] === b;
      }
    }
    aStack.push(a);
    bStack.push(b);
    equal = false;
    if (_.isFunction(a != null ? a.isEqual : void 0)) {
      equal = a.isEqual(b, aStack, bStack);
    } else if (_.isFunction(b != null ? b.isEqual : void 0)) {
      equal = b.isEqual(a, bStack, aStack);
    } else if (_.isArray(a) && _.isArray(b) && a.length === b.length) {
      equal = true;
      for (i = _i = 0, _len = a.length; _i < _len; i = ++_i) {
        aElement = a[i];
        if (!isEqual(aElement, b[i], aStack, bStack)) {
          equal = false;
          break;
        }
      }
    } else if (_.isRegExp(a) && _.isRegExp(b)) {
      equal = _.isEqual(a, b);
    } else if (_.isElement(a) && _.isElement(b)) {
      equal = a === b;
    } else if (_.isObject(a) && _.isObject(b)) {
      aCtor = a.constructor;
      bCtor = b.constructor;
      aCtorValid = _.isFunction(aCtor) && aCtor instanceof aCtor;
      bCtorValid = _.isFunction(bCtor) && bCtor instanceof bCtor;
      if (aCtor !== bCtor && !(aCtorValid && bCtorValid)) {
        equal = false;
      } else {
        aKeyCount = 0;
        equal = true;
        for (key in a) {
          aValue = a[key];
          if (!_.has(a, key)) {
            continue;
          }
          aKeyCount++;
          if (!(_.has(b, key) && isEqual(aValue, b[key], aStack, bStack))) {
            equal = false;
            break;
          }
        }
        if (equal) {
          bKeyCount = 0;
          for (key in b) {
            bValue = b[key];
            if (_.has(b, key)) {
              bKeyCount++;
            }
          }
          equal = aKeyCount === bKeyCount;
        }
      }
    } else {
      equal = _.isEqual(a, b);
    }
    aStack.pop();
    bStack.pop();
    return equal;
  };

  module.exports = _.extend({}, _, plus);

}).call(this);

}),
  "./deprecation": (function (exports, require, module, __filename, __dirname, process, global) {
     (function() {
    var Deprecation, SourceMapCache;

    SourceMapCache = {};

    module.exports = Deprecation = (function() {
      Deprecation.getFunctionNameFromCallsite = function(callsite) {};

      Deprecation.deserialize = function(_arg) {
        var deprecation, fileName, lineNumber, message, stack, stacks, _i, _len;
        message = _arg.message, fileName = _arg.fileName, lineNumber = _arg.lineNumber, stacks = _arg.stacks;
        deprecation = new Deprecation(message, fileName, lineNumber);
        for (_i = 0, _len = stacks.length; _i < _len; _i++) {
          stack = stacks[_i];
          deprecation.addStack(stack, stack.metadata);
        }
        return deprecation;
      };

      function Deprecation(message, fileName, lineNumber) {
        this.message = message;
        this.fileName = fileName;
        this.lineNumber = lineNumber;
        this.callCount = 0;
        this.stackCount = 0;
        this.stacks = {};
        this.stackCallCounts = {};
      }

      Deprecation.prototype.getFunctionNameFromCallsite = function(callsite) {
        var _ref, _ref1, _ref2;
        if (callsite.functionName != null) {
          return callsite.functionName;
        }
        if (callsite.isToplevel()) {
          return (_ref = callsite.getFunctionName()) != null ? _ref : '<unknown>';
        } else {
          if (callsite.isConstructor()) {
            return "new " + (callsite.getFunctionName());
          } else if (callsite.getMethodName() && !callsite.getFunctionName()) {
            return callsite.getMethodName();
          } else {
            return "" + (callsite.getTypeName()) + "." + ((_ref1 = (_ref2 = callsite.getMethodName()) != null ? _ref2 : callsite.getFunctionName()) != null ? _ref1 : '<anonymous>');
          }
        }
      };

      Deprecation.prototype.getLocationFromCallsite = function(callsite) {
        var column, fileName, line;
        if (callsite.location != null) {
          return callsite.location;
        }
        if (callsite.isNative()) {
          return "native";
        } else if (callsite.isEval()) {
          return "eval at " + (this.getLocationFromCallsite(callsite.getEvalOrigin()));
        } else {
          fileName = callsite.getFileName();
          line = callsite.getLineNumber();
          column = callsite.getColumnNumber();
          return "" + fileName + ":" + line + ":" + column;
        }
      };

      Deprecation.prototype.getFileNameFromCallSite = function(callsite) {
        var _ref;
        return (_ref = callsite.fileName) != null ? _ref : callsite.getFileName();
      };

      Deprecation.prototype.getOriginName = function() {
        return this.originName;
      };

      Deprecation.prototype.getMessage = function() {
        return this.message;
      };

      Deprecation.prototype.getStacks = function() {
        var location, parsedStack, parsedStacks, stack, _ref;
        parsedStacks = [];
        _ref = this.stacks;
        for (location in _ref) {
          stack = _ref[location];
          parsedStack = this.parseStack(stack);
          parsedStack.callCount = this.stackCallCounts[location];
          parsedStack.metadata = stack.metadata;
          parsedStacks.push(parsedStack);
        }
        return parsedStacks;
      };

      Deprecation.prototype.getStackCount = function() {
        return this.stackCount;
      };

      Deprecation.prototype.getCallCount = function() {
        return this.callCount;
      };

      Deprecation.prototype.addStack = function(stack, metadata) {
        var callerLocation, _base, _base1;
        if (this.originName == null) {
          this.originName = this.getFunctionNameFromCallsite(stack[0]);
        }
        if (this.fileName == null) {
          this.fileName = this.getFileNameFromCallSite(stack[0]);
        }
        if (this.lineNumber == null) {
          this.lineNumber = typeof (_base = stack[0]).getLineNumber === "function" ? _base.getLineNumber() : void 0;
        }
        this.callCount++;
        stack.metadata = metadata;
        callerLocation = this.getLocationFromCallsite(stack[1]);
        if (this.stacks[callerLocation] == null) {
          this.stacks[callerLocation] = stack;
          this.stackCount++;
        }
        if ((_base1 = this.stackCallCounts)[callerLocation] == null) {
          _base1[callerLocation] = 0;
        }
        return this.stackCallCounts[callerLocation]++;
      };

      Deprecation.prototype.parseStack = function(stack) {
        return stack.map((function(_this) {
          return function(callsite) {
            return {
              functionName: _this.getFunctionNameFromCallsite(callsite),
              location: _this.getLocationFromCallsite(callsite),
              fileName: _this.getFileNameFromCallSite(callsite)
            };
          };
        })(this));
      };

      Deprecation.prototype.serialize = function() {
        return {
          message: this.getMessage(),
          lineNumber: this.lineNumber,
          fileName: this.fileName,
          stacks: this.getStacks()
        };
      };

      return Deprecation;

    })();

  }).call(this);

}),
  "grim": (function (exports, require, module, __filename, __dirname, process, global) { (function() {
    var Deprecation, Emitter, getRawStack, grim;

    Deprecation = require('./deprecation');

    if (global.__grim__ == null) {
      Emitter = require('event-kit').Emitter;
      grim = global.__grim__ = {
        deprecations: {},
        emitter: new Emitter,
        includeDeprecatedAPIs: true,
        getDeprecations: function() {
          var deprecation, deprecations, deprecationsByLineNumber, deprecationsByPackage, fileName, lineNumber, packageName, _ref;
          deprecations = [];
          _ref = grim.deprecations;
          for (fileName in _ref) {
            deprecationsByLineNumber = _ref[fileName];
            for (lineNumber in deprecationsByLineNumber) {
              deprecationsByPackage = deprecationsByLineNumber[lineNumber];
              for (packageName in deprecationsByPackage) {
                deprecation = deprecationsByPackage[packageName];
                deprecations.push(deprecation);
              }
            }
          }
          return deprecations;
        },
        getDeprecationsLength: function() {
          return this.getDeprecations().length;
        },
        clearDeprecations: function() {
          grim.deprecations = {};
        },
        logDeprecations: function() {
          var deprecation, deprecations, _i, _len;
          deprecations = this.getDeprecations();
          deprecations.sort(function(a, b) {
            return b.getCallCount() - a.getCallCount();
          });
          console.warn("\nCalls to deprecated functions\n-----------------------------");
          for (_i = 0, _len = deprecations.length; _i < _len; _i++) {
            deprecation = deprecations[_i];
            console.warn("(" + (deprecation.getCallCount()) + ") " + (deprecation.getOriginName()) + " : " + (deprecation.getMessage()), deprecation);
          }
        },
        deprecate: function(message, metadata) {
          var deprecation, deprecationSite, error, fileName, lineNumber, originalStackTraceLimit, packageName, stack, _base, _base1, _base2, _ref, _ref1;
          originalStackTraceLimit = Error.stackTraceLimit;
          Error.stackTraceLimit = 7;
          error = new Error;
          Error.captureStackTrace(error);
          Error.stackTraceLimit = originalStackTraceLimit;
          stack = (_ref = typeof error.getRawStack === "function" ? error.getRawStack() : void 0) != null ? _ref : getRawStack(error);
          stack = stack.slice(1);
          deprecationSite = stack[0];
          fileName = deprecationSite.getFileName();
          lineNumber = deprecationSite.getLineNumber();
          packageName = (_ref1 = metadata != null ? metadata.packageName : void 0) != null ? _ref1 : "";
          if ((_base = grim.deprecations)[fileName] == null) {
            _base[fileName] = {};
          }
          if ((_base1 = grim.deprecations[fileName])[lineNumber] == null) {
            _base1[lineNumber] = {};
          }
          if ((_base2 = grim.deprecations[fileName][lineNumber])[packageName] == null) {
            _base2[packageName] = new Deprecation(message);
          }
          deprecation = grim.deprecations[fileName][lineNumber][packageName];
          deprecation.addStack(stack, metadata);
          this.emitter.emit("updated", deprecation);
        },
        addSerializedDeprecation: function(serializedDeprecation) {
          var deprecation, fileName, lineNumber, message, packageName, stack, stacks, _base, _base1, _base2, _i, _len, _ref, _ref1, _ref2;
          deprecation = Deprecation.deserialize(serializedDeprecation);
          message = deprecation.getMessage();
          fileName = deprecation.fileName, lineNumber = deprecation.lineNumber;
          stacks = deprecation.getStacks();
          packageName = (_ref = (_ref1 = stacks[0]) != null ? (_ref2 = _ref1.metadata) != null ? _ref2.packageName : void 0 : void 0) != null ? _ref : "";
          if ((_base = grim.deprecations)[fileName] == null) {
            _base[fileName] = {};
          }
          if ((_base1 = grim.deprecations[fileName])[lineNumber] == null) {
            _base1[lineNumber] = {};
          }
          if ((_base2 = grim.deprecations[fileName][lineNumber])[packageName] == null) {
            _base2[packageName] = new Deprecation(message, fileName, lineNumber);
          }
          deprecation = grim.deprecations[fileName][lineNumber][packageName];
          for (_i = 0, _len = stacks.length; _i < _len; _i++) {
            stack = stacks[_i];
            deprecation.addStack(stack, stack.metadata);
          }
          this.emitter.emit("updated", deprecation);
        },
        on: function(eventName, callback) {
          return this.emitter.on(eventName, callback);
        }
      };
    }

    getRawStack = function(error) {
      var originalPrepareStackTrace, result;
      originalPrepareStackTrace = Error.prepareStackTrace;
      Error.prepareStackTrace = function(error, stack) {
        return stack;
      };
      result = error.stack;
      Error.prepareStackTrace = originalPrepareStackTrace;
      return result;
    };

    module.exports = global.__grim__;

  }).call(this);

}),
  "./emitter": function (exports, require, module, __filename, __dirname) {
    (function() {
      var Disposable, Emitter;

      Disposable = require('./disposable');

      module.exports = Emitter = (function() {
        Emitter.prototype.disposed = false;


        /*
        Section: Construction and Destruction
         */

        function Emitter() {
          this.clear();
        }

        Emitter.prototype.clear = function() {
          return this.handlersByEventName = {};
        };

        Emitter.prototype.dispose = function() {
          this.handlersByEventName = null;
          return this.disposed = true;
        };


        /*
        Section: Event Subscription
         */

        Emitter.prototype.on = function(eventName, handler, unshift) {
          var currentHandlers;
          if (unshift == null) {
            unshift = false;
          }
          if (this.disposed) {
            throw new Error("Emitter has been disposed");
          }
          if (typeof handler !== 'function') {
            throw new Error("Handler must be a function");
          }
          if (currentHandlers = this.handlersByEventName[eventName]) {
            if (unshift) {
              this.handlersByEventName[eventName] = [handler].concat(currentHandlers);
            } else {
              this.handlersByEventName[eventName] = currentHandlers.concat(handler);
            }
          } else {
            this.handlersByEventName[eventName] = [handler];
          }
          return new Disposable(this.off.bind(this, eventName, handler));
        };

        Emitter.prototype.preempt = function(eventName, handler) {
          return this.on(eventName, handler, true);
        };

        Emitter.prototype.off = function(eventName, handlerToRemove) {
          var handler, newHandlers, oldHandlers, _i, _len;
          if (this.disposed) {
            return;
          }
          if (oldHandlers = this.handlersByEventName[eventName]) {
            newHandlers = [];
            for (_i = 0, _len = oldHandlers.length; _i < _len; _i++) {
              handler = oldHandlers[_i];
              if (handler !== handlerToRemove) {
                newHandlers.push(handler);
              }
            }
            this.handlersByEventName[eventName] = newHandlers;
          }
        };


        /*
        Section: Event Emission
         */

        Emitter.prototype.emit = function(eventName, value) {
          var handler, handlers, _i, _len, _ref;
          if (handlers = (_ref = this.handlersByEventName) != null ? _ref[eventName] : void 0) {
            for (_i = 0, _len = handlers.length; _i < _len; _i++) {
              handler = handlers[_i];
              handler(value);
            }
          }
        };

        return Emitter;

      })();

    }).call(this);
  },
  "./disposable": function (exports, require, module, __filename, __dirname) {
    (function() {
      var Disposable;

      module.exports = Disposable = (function() {
        Disposable.prototype.disposed = false;

        Disposable.isDisposable = function(object) {
          return typeof (object != null ? object.dispose : void 0) === "function";
        };


        /*
        Section: Construction and Destruction
         */

        function Disposable(disposalAction) {
          this.disposalAction = disposalAction;
        }

        Disposable.prototype.dispose = function() {
          if (!this.disposed) {
            this.disposed = true;
            if (typeof this.disposalAction === "function") {
              this.disposalAction();
            }
            this.disposalAction = null;
          }
        };

        return Disposable;

      })();

    }).call(this);

  },
  "./composite-disposable": function (exports, require, module, __filename, __dirname) {
    (function() {
      var CompositeDisposable;

      module.exports = CompositeDisposable = (function() {
        CompositeDisposable.prototype.disposed = false;


        /*
        Section: Construction and Destruction
         */

        function CompositeDisposable() {
          var disposable, _i, _len;
          this.disposables = new Set;
          for (_i = 0, _len = arguments.length; _i < _len; _i++) {
            disposable = arguments[_i];
            this.add(disposable);
          }
        }

        CompositeDisposable.prototype.dispose = function() {
          if (!this.disposed) {
            this.disposed = true;
            this.disposables.forEach(function(disposable) {
              return disposable.dispose();
            });
            this.disposables = null;
          }
        };


        /*
        Section: Managing Disposables
         */

        CompositeDisposable.prototype.add = function() {
          var disposable, _i, _len;
          if (!this.disposed) {
            for (_i = 0, _len = arguments.length; _i < _len; _i++) {
              disposable = arguments[_i];
              this.disposables.add(disposable);
            }
          }
        };

        CompositeDisposable.prototype.remove = function(disposable) {
          if (!this.disposed) {
            this.disposables["delete"](disposable);
          }
        };

        CompositeDisposable.prototype.clear = function() {
          if (!this.disposed) {
            this.disposables.clear();
          }
        };

        return CompositeDisposable;

      })();

    }).call(this);
  },
  "event-kit": function (exports, require, module, __filename, __dirname) {
    (function() {
      exports.Emitter = require('./emitter');

      exports.Disposable = require('./disposable');

      exports.CompositeDisposable = require('./composite-disposable');
    }).call(this);
  },
  "atom-environment": function (exports, require, module, __filename, __dirname) {
    exports.DeserializerManager = require('./deserializer-manager');
    exports.Grim = require('grim');
    // ViewRegistry = require('./view-registry')
    // NotificationManager = require('./notification-manager')
  },
  "./deserializer-manager": function (exports, require, module, __filename, __dirname) { (function() {
      var DeserializerManager, Disposable,
        __slice = [].slice;

      Disposable = require('event-kit').Disposable;

      module.exports = DeserializerManager = (function() {
        function DeserializerManager(atomEnvironment) {
          this.atomEnvironment = atomEnvironment;
          this.deserializers = {};
        }

        DeserializerManager.prototype.add = function() {
          var deserializer, deserializers, _i, _len;
          deserializers = 1 <= arguments.length ? __slice.call(arguments, 0) : [];
          for (_i = 0, _len = deserializers.length; _i < _len; _i++) {
            deserializer = deserializers[_i];
            this.deserializers[deserializer.name] = deserializer;
          }
          return new Disposable((function(_this) {
            return function() {
              var _j, _len1;
              for (_j = 0, _len1 = deserializers.length; _j < _len1; _j++) {
                deserializer = deserializers[_j];
                delete _this.deserializers[deserializer.name];
              }
            };
          })(this));
        };

        DeserializerManager.prototype.deserialize = function(state) {
          var deserializer, stateVersion, _ref;
          if (state == null) {
            return;
          }
          if (deserializer = this.get(state)) {
            stateVersion = (_ref = typeof state.get === "function" ? state.get('version') : void 0) != null ? _ref : state.version;
            if ((deserializer.version != null) && deserializer.version !== stateVersion) {
              return;
            }
            return deserializer.deserialize(state, this.atomEnvironment);
          } else {
            return console.warn("No deserializer found for", state);
          }
        };

        DeserializerManager.prototype.get = function(state) {
          var name, _ref;
          if (state == null) {
            return;
          }
          name = (_ref = typeof state.get === "function" ? state.get('deserializer') : void 0) != null ? _ref : state.deserializer;
          return this.deserializers[name];
        };

        DeserializerManager.prototype.clear = function() {
          return this.deserializers = {};
        };

        return DeserializerManager;

      })();

    }).call(this);
  }
};

function SnapshotModule(id, parent) {
  this.id = id;
  this.exports = {};
  this.parent = parent;
  if (parent && parent.children) {
    parent.children.push(this);
  }

  this.filename = null;
  this.loaded = false;
  this.children = [];
}

SnapshotModule._resolveFilename = function (request, parent) {
  // this should expand the filename into a full path, so that we can directly
  // fetch it from the cache.
  return request;
}

SnapshotModule._load = function(request, parent) {
  var filename = SnapshotModule._resolveFilename(request, parent);
  var snapshotModule = new SnapshotModule(filename, parent);
  snapshotModule.load(filename);
  return snapshotModule.exports;
};

// Given a file name, pass it to the proper extension handler.
SnapshotModule.prototype.load = function(filename) {
  this.filename = filename;
  this._compile(filename);
  this.loaded = true;
};

// Loads a module at the given file path. Returns that module's
// `exports` property.
SnapshotModule.prototype.require = function(path) {
  return SnapshotModule._load(path, this);
};

SnapshotModule.prototype._compile = function(filename) {
  var self = this;

  function require(path) {
    return self.require(path);
  }

  require.resolve = function(request) {
    return SnapshotModule._resolveFilename(request, self);
  };
  // var dirname = cachedFunctions[filename].dirname;
  var dirname = "";
  // we need to make sure to not use process/global inside the code we run on the snapshot.
  // here we may probably shim it and re-assign it later, when node has loaded.
  var args = [self.exports, require, self, filename, dirname, null, snapshotGlobal];
  return cachedFunctions[filename].apply(self.exports, args);
};

var snapshot = new SnapshotModule("snapshot", null);
var __AtomEnvironment__ = snapshot.require("atom-environment");
