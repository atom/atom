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
 *      Julian Viereck <julian.viereck@gmail.com>
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
    require("./test/mockdom");
}

define(function(require, exports, module) {
"use strict";

var Document = require("./document").Document;
var Range = require("./range").Range;
var assert = require("./test/assertions");

module.exports = {

    "test: insert text in line" : function() {
        var doc = new Document(["12", "34"]);

        var deltas = [];
        doc.on("change", function(e) { deltas.push(e.data); });

        doc.insert({row: 0, column: 1}, "juhu");
        assert.equal(doc.getValue(), ["1juhu2", "34"].join("\n"));

        var d = deltas.concat();
        doc.revertDeltas(d);
        assert.equal(doc.getValue(), ["12", "34"].join("\n"));

        doc.applyDeltas(d);
        assert.equal(doc.getValue(), ["1juhu2", "34"].join("\n"));
    },

    "test: insert new line" : function() {
        var doc = new Document(["12", "34"]);

        var deltas = [];
        doc.on("change", function(e) { deltas.push(e.data); });

        doc.insertNewLine({row: 0, column: 1});
        assert.equal(doc.getValue(), ["1", "2", "34"].join("\n"));

        var d = deltas.concat();
        doc.revertDeltas(d);
        assert.equal(doc.getValue(), ["12", "34"].join("\n"));

        doc.applyDeltas(d);
        assert.equal(doc.getValue(), ["1", "2", "34"].join("\n"));
    },

    "test: insert lines at the beginning" : function() {
        var doc = new Document(["12", "34"]);

        var deltas = [];
        doc.on("change", function(e) { deltas.push(e.data); });

        doc.insertLines(0, ["aa", "bb"]);
        assert.equal(doc.getValue(), ["aa", "bb", "12", "34"].join("\n"));

        var d = deltas.concat();
        doc.revertDeltas(d);
        assert.equal(doc.getValue(), ["12", "34"].join("\n"));

        doc.applyDeltas(d);
        assert.equal(doc.getValue(), ["aa", "bb", "12", "34"].join("\n"));
    },

    "test: insert lines at the end" : function() {
        var doc = new Document(["12", "34"]);

        var deltas = [];
        doc.on("change", function(e) { deltas.push(e.data); });

        doc.insertLines(2, ["aa", "bb"]);
        assert.equal(doc.getValue(), ["12", "34", "aa", "bb"].join("\n"));
    },

    "test: insert lines in the middle" : function() {
        var doc = new Document(["12", "34"]);

        var deltas = [];
        doc.on("change", function(e) { deltas.push(e.data); });

        doc.insertLines(1, ["aa", "bb"]);
        assert.equal(doc.getValue(), ["12", "aa", "bb", "34"].join("\n"));

        var d = deltas.concat();
        doc.revertDeltas(d);
        assert.equal(doc.getValue(), ["12", "34"].join("\n"));

        doc.applyDeltas(d);
        assert.equal(doc.getValue(), ["12", "aa", "bb", "34"].join("\n"));
    },

    "test: insert multi line string at the start" : function() {
        var doc = new Document(["12", "34"]);

        var deltas = [];
        doc.on("change", function(e) { deltas.push(e.data); });

        doc.insert({row: 0, column: 0}, "aa\nbb\ncc");
        assert.equal(doc.getValue(), ["aa", "bb", "cc12", "34"].join("\n"));

        var d = deltas.concat();
        doc.revertDeltas(d);
        assert.equal(doc.getValue(), ["12", "34"].join("\n"));

        doc.applyDeltas(d);
        assert.equal(doc.getValue(), ["aa", "bb", "cc12", "34"].join("\n"));
    },

    "test: insert multi line string at the end" : function() {
        var doc = new Document(["12", "34"]);

        var deltas = [];
        doc.on("change", function(e) { deltas.push(e.data); });

        doc.insert({row: 2, column: 0}, "aa\nbb\ncc");
        assert.equal(doc.getValue(), ["12", "34aa", "bb", "cc"].join("\n"));

        var d = deltas.concat();
        doc.revertDeltas(d);
        assert.equal(doc.getValue(), ["12", "34"].join("\n"));

        doc.applyDeltas(d);
        assert.equal(doc.getValue(), ["12", "34aa", "bb", "cc"].join("\n"));
    },

    "test: insert multi line string in the middle" : function() {
        var doc = new Document(["12", "34"]);

        var deltas = [];
        doc.on("change", function(e) { deltas.push(e.data); });

        doc.insert({row: 0, column: 1}, "aa\nbb\ncc");
        assert.equal(doc.getValue(), ["1aa", "bb", "cc2", "34"].join("\n"));

        var d = deltas.concat();
        doc.revertDeltas(d);
        assert.equal(doc.getValue(), ["12", "34"].join("\n"));

        doc.applyDeltas(d);
        assert.equal(doc.getValue(), ["1aa", "bb", "cc2", "34"].join("\n"));
    },

    "test: delete in line" : function() {
        var doc = new Document(["1234", "5678"]);

        var deltas = [];
        doc.on("change", function(e) { deltas.push(e.data); });

        doc.remove(new Range(0, 1, 0, 3));
        assert.equal(doc.getValue(), ["14", "5678"].join("\n"));

        var d = deltas.concat();
        doc.revertDeltas(d);
        assert.equal(doc.getValue(), ["1234", "5678"].join("\n"));

        doc.applyDeltas(d);
        assert.equal(doc.getValue(), ["14", "5678"].join("\n"));
    },

    "test: delete new line" : function() {
        var doc = new Document(["1234", "5678"]);

        var deltas = [];
        doc.on("change", function(e) { deltas.push(e.data); });

        doc.remove(new Range(0, 4, 1, 0));
        assert.equal(doc.getValue(), ["12345678"].join("\n"));

        var d = deltas.concat();
        doc.revertDeltas(d);
        assert.equal(doc.getValue(), ["1234", "5678"].join("\n"));

        doc.applyDeltas(d);
        assert.equal(doc.getValue(), ["12345678"].join("\n"));
    },

    "test: delete multi line range line" : function() {
        var doc = new Document(["1234", "5678", "abcd"]);

        var deltas = [];
        doc.on("change", function(e) { deltas.push(e.data); });

        doc.remove(new Range(0, 2, 2, 2));
        assert.equal(doc.getValue(), ["12cd"].join("\n"));

        var d = deltas.concat();
        doc.revertDeltas(d);
        assert.equal(doc.getValue(), ["1234", "5678", "abcd"].join("\n"));

        doc.applyDeltas(d);
        assert.equal(doc.getValue(), ["12cd"].join("\n"));
    },

    "test: delete full lines" : function() {
        var doc = new Document(["1234", "5678", "abcd"]);

        var deltas = [];
        doc.on("change", function(e) { deltas.push(e.data); });

        doc.remove(new Range(1, 0, 3, 0));
        assert.equal(doc.getValue(), ["1234", ""].join("\n"));
    },

    "test: remove lines should return the removed lines" : function() {
        var doc = new Document(["1234", "5678", "abcd"]);

        var removed = doc.removeLines(1, 2);
        assert.equal(removed.join("\n"), ["5678", "abcd"].join("\n"));
    },

    "test: should handle unix style new lines" : function() {
        var doc = new Document(["1", "2", "3"]);
        assert.equal(doc.getValue(), ["1", "2", "3"].join("\n"));
    },

    "test: should handle windows style new lines" : function() {
        var doc = new Document(["1", "2", "3"].join("\r\n"));

        doc.setNewLineMode("unix");
        assert.equal(doc.getValue(), ["1", "2", "3"].join("\n"));
    },

    "test: set new line mode to 'windows' should use '\\r\\n' as new lines": function() {
        var doc = new Document(["1", "2", "3"].join("\n"));
        doc.setNewLineMode("windows");
        assert.equal(doc.getValue(), ["1", "2", "3"].join("\r\n"));
    },

    "test: set new line mode to 'unix' should use '\\n' as new lines": function() {
        var doc = new Document(["1", "2", "3"].join("\r\n"));

        doc.setNewLineMode("unix");
        assert.equal(doc.getValue(), ["1", "2", "3"].join("\n"));
    },

    "test: set new line mode to 'auto' should detect the incoming nl type": function() {
        var doc = new Document(["1", "2", "3"].join("\n"));

        doc.setNewLineMode("auto");
        assert.equal(doc.getValue(), ["1", "2", "3"].join("\n"));

        var doc = new Document(["1", "2", "3"].join("\r\n"));

        doc.setNewLineMode("auto");
        assert.equal(doc.getValue(), ["1", "2", "3"].join("\r\n"));

        doc.replace(new Range(0, 0, 2, 1), ["4", "5", "6"].join("\n"));
        assert.equal(["4", "5", "6"].join("\n"), doc.getValue());
    },

    "test: set value": function() {
        var doc = new Document("1");
        assert.equal("1", doc.getValue());

        doc.setValue(doc.getValue());
        assert.equal("1", doc.getValue());

        var doc = new Document("1\n2");
        assert.equal("1\n2", doc.getValue());

        doc.setValue(doc.getValue());
        assert.equal("1\n2", doc.getValue());
    },

    "test: empty document has to contain one line": function() {
        var doc = new Document("");
        assert.equal(doc.$lines.length, 1);
    }
};

});

if (typeof module !== "undefined" && module === require.main) {
    require("asyncjs").test.testcase(module.exports).exec()
}