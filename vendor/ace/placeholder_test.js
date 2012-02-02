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
 *      Julian Viereck <julian DOT viereck AT gmail DOT com>
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
var JavaScriptMode = require("./mode/javascript").Mode;
var PlaceHolder = require('./placeholder').PlaceHolder;
var UndoManager = require('./undomanager').UndoManager;

module.exports = {

   "test: simple at the end appending of text" : function() {
        var session = new EditSession("var a = 10;\nconsole.log(a, a);", new JavaScriptMode());
        var editor = new Editor(new MockRenderer(), session);
        
        new PlaceHolder(session, 1, {row: 0, column: 4}, [{row: 1, column: 12}, {row: 1, column: 15}]);
        
        editor.moveCursorTo(0, 5);
        editor.insert('b');
        assert.equal(session.doc.getValue(), "var ab = 10;\nconsole.log(ab, ab);");
        editor.insert('cd');
        assert.equal(session.doc.getValue(), "var abcd = 10;\nconsole.log(abcd, abcd);");
        editor.remove('left');
        editor.remove('left');
        editor.remove('left');
        assert.equal(session.doc.getValue(), "var a = 10;\nconsole.log(a, a);");
    },

    "test: inserting text outside placeholder" : function() {
        var session = new EditSession("var a = 10;\nconsole.log(a, a);\n", new JavaScriptMode());
        var editor = new Editor(new MockRenderer(), session);
        
        new PlaceHolder(session, 1, {row: 0, column: 4}, [{row: 1, column: 12}, {row: 1, column: 15}]);
        
        editor.moveCursorTo(2, 0);
        editor.insert('b');
        assert.equal(session.doc.getValue(), "var a = 10;\nconsole.log(a, a);\nb");
    },
    
   "test: insertion at the beginning" : function(next) {
        var session = new EditSession("var a = 10;\nconsole.log(a, a);", new JavaScriptMode());
        var editor = new Editor(new MockRenderer(), session);
        
        var p = new PlaceHolder(session, 1, {row: 0, column: 4}, [{row: 1, column: 12}, {row: 1, column: 15}]);
        
        editor.moveCursorTo(0, 4);
        editor.insert('$');
        assert.equal(session.doc.getValue(), "var $a = 10;\nconsole.log($a, $a);");
        editor.moveCursorTo(0, 4);
        // Have to put this in a setTimeout because the anchor is only fixed later.
        setTimeout(function() {
            editor.insert('v');
            assert.equal(session.doc.getValue(), "var v$a = 10;\nconsole.log(v$a, v$a);");
            next();
        }, 10);
    },

   "test: detaching placeholder" : function() {
        var session = new EditSession("var a = 10;\nconsole.log(a, a);", new JavaScriptMode());
        var editor = new Editor(new MockRenderer(), session);
        
        var p = new PlaceHolder(session, 1, {row: 0, column: 4}, [{row: 1, column: 12}, {row: 1, column: 15}]);
        
        editor.moveCursorTo(0, 5);
        editor.insert('b');
        assert.equal(session.doc.getValue(), "var ab = 10;\nconsole.log(ab, ab);");
        p.detach();
        editor.insert('cd');
        assert.equal(session.doc.getValue(), "var abcd = 10;\nconsole.log(ab, ab);");
    },

   "test: events" : function() {
        var session = new EditSession("var a = 10;\nconsole.log(a, a);", new JavaScriptMode());
        var editor = new Editor(new MockRenderer(), session);
        
        var p = new PlaceHolder(session, 1, {row: 0, column: 4}, [{row: 1, column: 12}, {row: 1, column: 15}]);
        var entered = false;
        var left = false;
        p.on("cursorEnter", function() {
            entered = true;
        });
        p.on("cursorLeave", function() {
            left = true;
        });
        
        editor.moveCursorTo(0, 0);
        editor.moveCursorTo(0, 4);
        p.onCursorChange(); // Have to do this by hand because moveCursorTo doesn't trigger the event
        assert.ok(entered);
        editor.moveCursorTo(1, 0);
        p.onCursorChange(); // Have to do this by hand because moveCursorTo doesn't trigger the event
        assert.ok(left);
    },
    
    "test: cancel": function(next) {
        var session = new EditSession("var a = 10;\nconsole.log(a, a);", new JavaScriptMode());
        session.setUndoManager(new UndoManager());
        var editor = new Editor(new MockRenderer(), session);
        var p = new PlaceHolder(session, 1, {row: 0, column: 4}, [{row: 1, column: 12}, {row: 1, column: 15}]);
        
        editor.moveCursorTo(0, 5);
        editor.insert('b');
        editor.insert('cd');
        editor.remove('left');
        assert.equal(session.doc.getValue(), "var abc = 10;\nconsole.log(abc, abc);");
        // Wait a little for the changes to enter the undo stack
        setTimeout(function() {
            p.cancel();
            assert.equal(session.doc.getValue(), "var a = 10;\nconsole.log(a, a);");
            next();
        }, 80);
    }
};

});

if (typeof module !== "undefined" && module === require.main) {
    require("asyncjs").test.testcase(module.exports).exec()
}