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
 * The Original Code is Ajax.org Code Editor (ACE).
 *
 * The Initial Developer of the Original Code is
 * Ajax.org B.V.
 * Portions created by the Initial Developer are Copyright (C) 2010
 * the Initial Developer. All Rights Reserved.
 *
 * Contributor(s):
 *      Fabian Jakobs <fabian AT ajax DOT org>
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

if (typeof process !== "undefined") {
    require("amd-loader");
}

define(function(require, exports, module) {
"use strict";

var Range = require("./range").Range;
var EditSession = require("./edit_session").EditSession;
var assert = require("./test/assertions");

module.exports = {
    
    name: "ACE range.js",
    
    "test: create range": function() {
        var range = new Range(1,2,3,4);

        assert.equal(range.start.row, 1);
        assert.equal(range.start.column, 2);
        assert.equal(range.end.row, 3);
        assert.equal(range.end.column, 4);
    },

    "test: create from points": function() {
        var range = Range.fromPoints({row: 1, column: 2}, {row:3, column:4});

        assert.equal(range.start.row, 1);
        assert.equal(range.start.column, 2);
        assert.equal(range.end.row, 3);
        assert.equal(range.end.column, 4);
    },

    "test: clip to rows": function() {
        assert.range(new Range(0, 20, 100, 30).clipRows(10, 30), 10, 0, 31, 0);
        assert.range(new Range(0, 20, 30, 10).clipRows(10, 30), 10, 0, 30, 10);

        var range = new Range(0, 20, 3, 10);
        var range = range.clipRows(10, 30);

        assert.ok(range.isEmpty());
        assert.range(range, 10, 0, 10, 0);
    },

    "test: isEmpty": function() {
        var range = new Range(1, 2, 1, 2);
        assert.ok(range.isEmpty());

        var range = new Range(1, 2, 1, 6);
        assert.notOk(range.isEmpty());
    },

    "test: is multi line": function() {
        var range = new Range(1, 2, 1, 6);
        assert.notOk(range.isMultiLine());

        var range = new Range(1, 2, 2, 6);
        assert.ok(range.isMultiLine());
    },

    "test: clone": function() {
        var range = new Range(1, 2, 3, 4);
        var clone = range.clone();

        assert.position(clone.start, 1, 2);
        assert.position(clone.end, 3, 4);

        clone.start.column = 20;
        assert.position(range.start, 1, 2);

        clone.end.column = 20;
        assert.position(range.end, 3, 4);
    },

    "test: contains for multi line ranges": function() {
        var range = new Range(1, 10, 5, 20);

        assert.ok(range.contains(1, 10));
        assert.ok(range.contains(2, 0));
        assert.ok(range.contains(3, 100));
        assert.ok(range.contains(5, 19));
        assert.ok(range.contains(5, 20));

        assert.notOk(range.contains(1, 9));
        assert.notOk(range.contains(0, 0));
        assert.notOk(range.contains(5, 21));
    },

    "test: contains for single line ranges": function() {
        var range = new Range(1, 10, 1, 20);

        assert.ok(range.contains(1, 10));
        assert.ok(range.contains(1, 15));
        assert.ok(range.contains(1, 20));

        assert.notOk(range.contains(0, 9));
        assert.notOk(range.contains(2, 9));
        assert.notOk(range.contains(1, 9));
        assert.notOk(range.contains(1, 21));
    },

    "test: extend range": function() {
        var range = new Range(2, 10, 2, 30);

        var range = range.extend(2, 5);
        assert.range(range, 2, 5, 2, 30);

        var range = range.extend(2, 35);
        assert.range(range, 2, 5, 2, 35);

        var range = range.extend(2, 15);
        assert.range(range, 2, 5, 2, 35);

        var range = range.extend(1, 4);
        assert.range(range, 1, 4, 2, 35);

        var range = range.extend(6, 10);
        assert.range(range, 1, 4, 6, 10);
    },

    "test: collapse rows" : function() {
        var range = new Range(0, 2, 1, 2);
        assert.range(range.collapseRows(), 0, 0, 1, 0);

        var range = new Range(2, 2, 3, 1);
        assert.range(range.collapseRows(), 2, 0, 3, 0);

        var range = new Range(2, 2, 3, 0);
        assert.range(range.collapseRows(), 2, 0, 2, 0);

        var range = new Range(2, 0, 2, 0);
        assert.range(range.collapseRows(), 2, 0, 2, 0);
    },
    
    "test: to screen range" : function() {
        var session = new EditSession([
            "juhu",
            "12\t\t34",
            "ぁぁa",
            "\t\t34",
        ]);
        
        var range = new Range(0, 0, 0, 3);
        assert.range(range.toScreenRange(session), 0, 0, 0, 3);
        
        var range = new Range(1, 1, 1, 3);
        assert.range(range.toScreenRange(session), 1, 1, 1, 4);
        
        var range = new Range(2, 1, 2, 2);
        assert.range(range.toScreenRange(session), 2, 2, 2, 4);

        var range = new Range(3, 0, 3, 4);
        assert.range(range.toScreenRange(session), 3, 0, 3, 10);
    }
};

});

if (typeof module !== "undefined" && module === require.main) {
    require("asyncjs").test.testcase(module.exports).exec()
}