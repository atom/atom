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
var Text = require("./mode/text").Mode;
var JavaScriptMode = require("./mode/javascript").Mode;
var CssMode = require("./mode/css").Mode;
var HtmlMode = require("./mode/html").Mode;
var MockRenderer = require("./test/mockrenderer").MockRenderer;
var assert = require("./test/assertions");

module.exports = {

    setUp : function(next) {
        this.session1 = new EditSession(["abc", "def"]);
        this.session2 = new EditSession(["ghi", "jkl"]);
        
        
        this.editor = new Editor(new MockRenderer());
        next();
    },

    "test: change document" : function() {
        this.editor.setSession(this.session1);
        assert.equal(this.editor.getSession(), this.session1);

        this.editor.setSession(this.session2);
        assert.equal(this.editor.getSession(), this.session2);
    },

    "test: only changes to the new document should have effect" : function() {
        var called = false;
        this.editor.onDocumentChange = function() {
            called = true;
        };

        this.editor.setSession(this.session1);
        this.editor.setSession(this.session2);

        this.session1.duplicateLines(0, 0);
        assert.notOk(called);

        this.session2.duplicateLines(0, 0);
        assert.ok(called);
    },

    "test: should use cursor of new document" : function() {
        this.session1.getSelection().moveCursorTo(0, 1);
        this.session2.getSelection().moveCursorTo(1, 0);

        this.editor.setSession(this.session1);
        assert.position(this.editor.getCursorPosition(), 0, 1);

        this.editor.setSession(this.session2);
        assert.position(this.editor.getCursorPosition(), 1, 0);
    },

    "test: only changing the cursor of the new doc should not have an effect" : function() {
        this.editor.onCursorChange = function() {
            called = true;
        };

        this.editor.setSession(this.session1);
        this.editor.setSession(this.session2);
        assert.position(this.editor.getCursorPosition(), 0, 0);

        var called = false;
        this.session1.getSelection().moveCursorTo(0, 1);
        assert.position(this.editor.getCursorPosition(), 0, 0);
        assert.notOk(called);

        this.session2.getSelection().moveCursorTo(1, 1);
        assert.position(this.editor.getCursorPosition(), 1, 1);
        assert.ok(called);
    },

    "test: should use selection of new document" : function() {
        this.session1.getSelection().selectTo(0, 1);
        this.session2.getSelection().selectTo(1, 0);

        this.editor.setSession(this.session1);
        assert.position(this.editor.getSelection().getSelectionLead(), 0, 1);

        this.editor.setSession(this.session2);
        assert.position(this.editor.getSelection().getSelectionLead(), 1, 0);
    },

    "test: only changing the selection of the new doc should not have an effect" : function() {
        this.editor.onSelectionChange = function() {
            called = true;
        };

        this.editor.setSession(this.session1);
        this.editor.setSession(this.session2);
        assert.position(this.editor.getSelection().getSelectionLead(), 0, 0);

        var called = false;
        this.session1.getSelection().selectTo(0, 1);
        assert.position(this.editor.getSelection().getSelectionLead(), 0, 0);
        assert.notOk(called);

        this.session2.getSelection().selectTo(1, 1);
        assert.position(this.editor.getSelection().getSelectionLead(), 1, 1);
        assert.ok(called);
    },

    "test: should use mode of new document" : function() {
        this.editor.onChangeMode = function() {
            called = true;
        };
        this.editor.setSession(this.session1);
        this.editor.setSession(this.session2);

        var called = false;
        this.session1.setMode(new Text());
        assert.notOk(called);

        this.session2.setMode(new JavaScriptMode());
        assert.ok(called);
    },
    
    "test: should use stop worker of old document" : function(next) {
        var self = this;
        
        // 1. Open an editor and set the session to CssMode
        self.editor.setSession(self.session1);
        self.session1.setMode(new CssMode());
        
        // 2. Add a line or two of valid CSS.
        self.session1.setValue("DIV { color: red; }");
        
        // 3. Clear the session value.
        self.session1.setValue("");
        
        // 4. Set the session to HtmlMode
        self.session1.setMode(new HtmlMode());

        // 5. Try to type valid HTML
        self.session1.insert({row: 0, column: 0}, "<html></html>");
        
        setTimeout(function() {
            assert.equal(Object.keys(self.session1.getAnnotations()).length, 0);
            next();
        }, 600);
    }
};

});

if (typeof module !== "undefined" && module === require.main) {
    require("asyncjs").test.testcase(module.exports).exec()
}