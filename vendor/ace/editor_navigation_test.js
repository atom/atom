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
    require("./test/mockdom");
}

define(function(require, exports, module) {
"use strict";

var EditSession = require("./edit_session").EditSession;
var Editor = require("./editor").Editor;
var MockRenderer = require("./test/mockrenderer").MockRenderer;
var assert = require("./test/assertions");

module.exports = {
    createEditSession : function(rows, cols) {
        var line = new Array(cols + 1).join("a");
        var text = new Array(rows).join(line + "\n") + line;
        return new EditSession(text);
    },

    "test: navigate to end of file should scroll the last line into view" : function() {
        var doc = this.createEditSession(200, 10);
        var editor = new Editor(new MockRenderer(), doc);

        editor.navigateFileEnd();
        var cursor = editor.getCursorPosition();

        assert.ok(editor.getFirstVisibleRow() <= cursor.row);
        assert.ok(editor.getLastVisibleRow() >= cursor.row);
    },

    "test: navigate to start of file should scroll the first row into view" : function() {
        var doc = this.createEditSession(200, 10);
        var editor = new Editor(new MockRenderer(), doc);

        editor.moveCursorTo(editor.getLastVisibleRow() + 20);
        editor.navigateFileStart();

        assert.equal(editor.getFirstVisibleRow(), 0);
    },

    "test: goto hidden line should scroll the line into the middle of the viewport" : function() {
        var editor = new Editor(new MockRenderer(), this.createEditSession(200, 5));

        editor.navigateTo(0, 0);
        editor.gotoLine(101);
        assert.position(editor.getCursorPosition(), 100, 0);
        assert.equal(editor.getFirstVisibleRow(), 90);

        editor.navigateTo(100, 0);
        editor.gotoLine(11);
        assert.position(editor.getCursorPosition(), 10, 0);
        assert.equal(editor.getFirstVisibleRow(), 0);

        editor.navigateTo(100, 0);
        editor.gotoLine(6);
        assert.position(editor.getCursorPosition(), 5, 0);
        assert.equal(0, editor.getFirstVisibleRow(), 0);

        editor.navigateTo(100, 0);
        editor.gotoLine(1);
        assert.position(editor.getCursorPosition(), 0, 0);
        assert.equal(editor.getFirstVisibleRow(), 0);

        editor.navigateTo(0, 0);
        editor.gotoLine(191);
        assert.position(editor.getCursorPosition(), 190, 0);
        assert.equal(editor.getFirstVisibleRow(), 180);

        editor.navigateTo(0, 0);
        editor.gotoLine(196);
        assert.position(editor.getCursorPosition(), 195, 0);
        assert.equal(editor.getFirstVisibleRow(), 180);
    },

    "test: goto visible line should only move the cursor and not scroll": function() {
        var editor = new Editor(new MockRenderer(), this.createEditSession(200, 5));

        editor.navigateTo(0, 0);
        editor.gotoLine(12);
        assert.position(editor.getCursorPosition(), 11, 0);
        assert.equal(editor.getFirstVisibleRow(), 0);

        editor.navigateTo(30, 0);
        editor.gotoLine(33);
        assert.position(editor.getCursorPosition(), 32, 0);
        assert.equal(editor.getFirstVisibleRow(), 30);
    },

    "test: navigate from the end of a long line down to a short line and back should maintain the curser column": function() {
        var editor = new Editor(new MockRenderer(), new EditSession(["123456", "1"]));

        editor.navigateTo(0, 6);
        assert.position(editor.getCursorPosition(), 0, 6);

        editor.navigateDown();
        assert.position(editor.getCursorPosition(), 1, 1);

        editor.navigateUp();
        assert.position(editor.getCursorPosition(), 0, 6);
    },

    "test: reset desired column on navigate left or right": function() {
        var editor = new Editor(new MockRenderer(), new EditSession(["123456", "12"]));

        editor.navigateTo(0, 6);
        assert.position(editor.getCursorPosition(), 0, 6);

        editor.navigateDown();
        assert.position(editor.getCursorPosition(), 1, 2);

        editor.navigateLeft();
        assert.position(editor.getCursorPosition(), 1, 1);

        editor.navigateUp();
        assert.position(editor.getCursorPosition(), 0, 1);
    },
    
    "test: typing text should update the desired column": function() {
        var editor = new Editor(new MockRenderer(), new EditSession(["1234", "1234567890"]));

        editor.navigateTo(0, 3);
        editor.insert("juhu");
        
        editor.navigateDown();
        assert.position(editor.getCursorPosition(), 1, 7);
    }
};

});

if (typeof module !== "undefined" && module === require.main) {
    require("asyncjs").test.testcase(module.exports).exec()
}