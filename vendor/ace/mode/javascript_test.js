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

var EditSession = require("../edit_session").EditSession;
var Tokenizer = require("../tokenizer").Tokenizer;
var JavaScriptMode = require("./javascript").Mode;
var assert = require("../test/assertions");

module.exports = {
    setUp : function() {    
        this.mode = new JavaScriptMode();
    },

    "test: getTokenizer() (smoke test)" : function() {
        var tokenizer = this.mode.getTokenizer();

        assert.ok(tokenizer instanceof Tokenizer);

        var tokens = tokenizer.getLineTokens("'juhu'", "start").tokens;
        assert.equal("string", tokens[0].type);
    },

    "test: toggle comment lines should prepend '//' to each line" : function() {
        var session = new EditSession(["  abc", "cde", "fg"]);

        this.mode.toggleCommentLines("start", session, 0, 1);
        assert.equal(["//  abc", "//cde", "fg"].join("\n"), session.toString());
    },

    "test: toggle comment on commented lines should remove leading '//' chars" : function() {
        var session = new EditSession(["//  abc", "//cde", "fg"]);

        this.mode.toggleCommentLines("start", session, 0, 1);
        assert.equal(["  abc", "cde", "fg"].join("\n"), session.toString());
    },

    "test: toggle comment lines twice should return the original text" : function() {
        var session = new EditSession(["  abc", "cde", "fg"]);

        this.mode.toggleCommentLines("start", session, 0, 2);
        this.mode.toggleCommentLines("start", session, 0, 2);
        assert.equal(["  abc", "cde", "fg"].join("\n"), session.toString());
    },

    "test: toggle comment on multiple lines with one commented line prepend '//' to each line" : function() {
        var session = new EditSession(["//  abc", "//cde", "fg"]);

        this.mode.toggleCommentLines("start", session, 0, 2);
        assert.equal(["////  abc", "////cde", "//fg"].join("\n"), session.toString());
    },

    "test: toggle comment on a comment line with leading white space": function() {
        var session = new EditSession(["//cde", "  //fg"]);

        this.mode.toggleCommentLines("start", session, 0, 1);
        assert.equal(["cde", "  fg"].join("\n"), session.toString());
    },

    "test: auto indent after opening brace" : function() {
        assert.equal("  ", this.mode.getNextLineIndent("start", "if () {", "  "));
    },
    
    "test: auto indent after case" : function() {
        assert.equal("  ", this.mode.getNextLineIndent("start", "case 'juhu':", "  "));
    },

    "test: no auto indent in object literal" : function() {
        assert.equal("", this.mode.getNextLineIndent("start", "{ 'juhu':", "  "));
    },

    "test: no auto indent after opening brace in multi line comment" : function() {
        assert.equal("", this.mode.getNextLineIndent("start", "/*if () {", "  "));
        assert.equal("  ", this.mode.getNextLineIndent("comment", "  abcd", "  "));
    },

    "test: no auto indent after opening brace in single line comment" : function() {
        assert.equal("", this.mode.getNextLineIndent("start", "//if () {", "  "));
        assert.equal("  ", this.mode.getNextLineIndent("start", "  //if () {", "  "));
    },

    "test: no auto indent should add to existing indent" : function() {
        assert.equal("      ", this.mode.getNextLineIndent("start", "    if () {", "  "));
        assert.equal("    ", this.mode.getNextLineIndent("start", "    cde", "  "));
        assert.equal("    ", this.mode.getNextLineIndent("regex_allowed", "function foo(items) {", "    "));
    },

    "test: special indent in doc comments" : function() {
        assert.equal(" * ", this.mode.getNextLineIndent("doc-start", "/**", " "));
        assert.equal("   * ", this.mode.getNextLineIndent("doc-start", "  /**", " "));
        assert.equal(" * ", this.mode.getNextLineIndent("doc-start", " *", " "));
        assert.equal("    * ", this.mode.getNextLineIndent("doc-start", "    *", " "));
        assert.equal("  ", this.mode.getNextLineIndent("doc-start", "  abc", " "));
    },

    "test: no indent after doc comments" : function() {
        assert.equal("", this.mode.getNextLineIndent("doc-start", "   */", "  "));
    },

    "test: trigger outdent if line is space and new text starts with closing brace" : function() {
        assert.ok(this.mode.checkOutdent("start", "   ", " }"));
        assert.ok(!this.mode.checkOutdent("start", " a  ", " }"));
        assert.ok(!this.mode.checkOutdent("start", "", "}"));
        assert.ok(!this.mode.checkOutdent("start", "   ", "a }"));
        assert.ok(!this.mode.checkOutdent("start", "   }", "}"));
    },

    "test: auto outdent should indent the line with the same indent as the line with the matching opening brace" : function() {
        var session = new EditSession(["  function foo() {", "    bla", "    }"], new JavaScriptMode());
        this.mode.autoOutdent("start", session, 2);
        assert.equal("  }", session.getLine(2));
    },

    "test: no auto outdent if no matching brace is found" : function() {
        var session = new EditSession(["  function foo()", "    bla", "    }"]);
        this.mode.autoOutdent("start", session, 2);
        assert.equal("    }", session.getLine(2));
    }
};

});

if (typeof module !== "undefined" && module === require.main) {
    require("asyncjs").test.testcase(module.exports).exec()
}