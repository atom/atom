/* ***** BEGIN LICENSE BLOCK *****
 * Version: MPL 1.1/GPL 2.0/LGPL 2.1
 *
 * The contents of this file are subject to the Mozilla Public License Version
 * 1.1 (the "License"); you may not use this file except in compliance with
 * the License. You may obtain a copy of the License at
 * http://www.mozilla.org/MPL/
 *
 * Software distributed under the License is distributed on an "AS IS" basis,
 * WITHOUT WARRANTY OF ANY KIND, either express or implied. See the License
 * for the specific language governing rights and limitations under the
 * License.
 *
 * The Original Code is Mozilla Skywriter.
 *
 * The Initial Developer of the Original Code is
 * Mozilla.
 * Portions created by the Initial Developer are Copyright (C) 2009
 * the Initial Developer. All Rights Reserved.
 *
 * Contributor(s):
 *   Patrick Walton (pwalton@mozilla.com)
 *
 * Alternatively, the contents of this file may be used under the terms of
 * either the GNU General Public License Version 2 or later (the "GPL"), or
 * the GNU Lesser General Public License Version 2.1 or later (the "LGPL"),
 * in which case the provisions of the GPL or the LGPL are applicable instead
 * of those above. If you wish to allow use of your version of this file only
 * under the terms of either the GPL or the LGPL, and not to allow others to
 * use your version of this file under the terms of the MPL, indicate your
 * decision by deleting the provisions above and replace them with the notice
 * and other provisions required by the GPL or the LGPL. If you do not delete
 * the provisions above, a recipient may use your version of this file under
 * the terms of any one of the MPL, the GPL or the LGPL.
 *
 * ***** END LICENSE BLOCK ***** */

define(function(require, exports, module) {

var util = require("util/util");

/**
 * Returns the result of adding the two positions.
 */
exports.addPositions = function(a, b) {
    return { row: a.row + b.row, col: a.col + b.col };
};

/** Returns a copy of the given range. */
exports.cloneRange = function(range) {
    var oldStart = range.start, oldEnd = range.end;
    var newStart = { row: oldStart.row, col: oldStart.col };
    var newEnd = { row: oldEnd.row, col: oldEnd.col };
    return { start: newStart, end: newEnd };
};

/**
 * Given two positions a and b, returns a negative number if a < b, 0 if a = b,
 * or a positive number if a > b.
 */
exports.comparePositions = function(positionA, positionB) {
    var rowDiff = positionA.row - positionB.row;
    return rowDiff === 0 ? positionA.col - positionB.col : rowDiff;
};

/**
 * Returns true if the two ranges are equal and false otherwise.
 */
exports.equal = function(rangeA, rangeB) {
    return (exports.comparePositions(rangeA.start, rangeB.start) === 0 &&
                exports.comparePositions(rangeA.end, rangeB.end) === 0);
};

exports.extendRange = function(range, delta) {
    var end = range.end;
    return {
        start: range.start,
        end:   {
            row: end.row + delta.row,
            col: end.col + delta.col
        }
    };
};

/**
 * Given two sets of ranges, returns the ranges of characters that exist in one
 * of the sets but not both.
 */
exports.intersectRangeSets = function(setA, setB) {
    var stackA = util.clone(setA), stackB = util.clone(setB);
    var result = [];
    while (stackA.length > 0 && stackB.length > 0) {
        var rangeA = stackA.shift(), rangeB = stackB.shift();
        var startDiff = exports.comparePositions(rangeA.start, rangeB.start);
        var endDiff = exports.comparePositions(rangeA.end, rangeB.end);

        if (exports.comparePositions(rangeA.end, rangeB.start) < 0) {
            // A is completely before B
            result.push(rangeA);
            stackB.unshift(rangeB);
        } else if (exports.comparePositions(rangeB.end, rangeA.start) < 0) {
            // B is completely before A
            result.push(rangeB);
            stackA.unshift(rangeA);
        } else if (startDiff < 0) {     // A starts before B
            result.push({ start: rangeA.start, end: rangeB.start });
            stackA.unshift({ start: rangeB.start, end: rangeA.end });
            stackB.unshift(rangeB);
        } else if (startDiff === 0) {   // A and B start at the same place
            if (endDiff < 0) {          // A ends before B
                stackB.unshift({ start: rangeA.end, end: rangeB.end });
            } else if (endDiff > 0) {   // A ends after B
                stackA.unshift({ start: rangeB.end, end: rangeA.end });
            }
        } else if (startDiff > 0) {     // A starts after B
            result.push({ start: rangeB.start, end: rangeA.start });
            stackA.unshift(rangeA);
            stackB.unshift({ start: rangeA.start, end: rangeB.end });
        }
    }
    return result.concat(stackA, stackB);
};

exports.isZeroLength = function(range) {
    return range.start.row === range.end.row &&
        range.start.col === range.end.col;
};

/**
 * Returns the greater of the two positions.
 */
exports.maxPosition = function(a, b) {
    return exports.comparePositions(a, b) > 0 ? a : b;
};

/**
 * Converts a range with swapped 'end' and 'start' values into one with the
 * values in the correct order.
 *
 * TODO: Unit test.
 */
exports.normalizeRange = function(range) {
    return this.comparePositions(range.start, range.end) < 0 ? range :
        { start: range.end, end: range.start };
};

/**
 * Returns a single range that spans the entire given set of ranges.
 */
exports.rangeSetBoundaries = function(rangeSet) {
    return {
        start:  rangeSet[0].start,
        end:    rangeSet[rangeSet.length - 1].end
    };
};

exports.toString = function(range) {
    var start = range.start, end = range.end;
    return '[ ' + start.row + ', ' + start.col + ' ' + end.row + ',' + + end.col +' ]';
};

/**
 * Returns the union of the two ranges.
 */
exports.unionRanges = function(a, b) {
    return {
        start:  a.start.row < b.start.row ||
            (a.start.row === b.start.row && a.start.col < b.start.col) ?
            a.start : b.start,
        end:    a.end.row > b.end.row ||
            (a.end.row === b.end.row && a.end.col > b.end.col) ?
            a.end : b.end
    };
};

exports.isPosition = function(pos) {
    return !util.none(pos) && !util.none(pos.row) && !util.none(pos.col);
};

exports.isRange = function(range) {
    return (!util.none(range) && exports.isPosition(range.start) &&
                                                exports.isPosition(range.end));
};

});