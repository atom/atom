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

var EditSession = require("./edit_session").EditSession;
var JavaScriptMode = require("./mode/javascript").Mode;
var TokenIterator = require("./token_iterator").TokenIterator;
var assert = require("./test/assertions");

module.exports = {
    "test: token iterator initialization in JavaScript document" : function() {
        var lines = [
            "function foo(items) {",
            "    for (var i=0; i<items.length; i++) {",
            "        alert(items[i] + \"juhu\");",
            "    } // Real Tab.",
            "}"
        ];
        var session = new EditSession(lines.join("\n"), new JavaScriptMode());      

        var iterator = new TokenIterator(session, 0, 0);
        assert.equal(iterator.getCurrentToken().value, "function");
        assert.equal(iterator.getCurrentTokenRow(), 0);
        assert.equal(iterator.getCurrentTokenColumn(), 0);
        
        iterator.stepForward();
        assert.equal(iterator.getCurrentToken().value, " ");
        assert.equal(iterator.getCurrentTokenRow(), 0);
        assert.equal(iterator.getCurrentTokenColumn(), 8);      

        var iterator = new TokenIterator(session, 0, 4);
        assert.equal(iterator.getCurrentToken().value, "function");
        assert.equal(iterator.getCurrentTokenRow(), 0);
        assert.equal(iterator.getCurrentTokenColumn(), 0);

        iterator.stepForward();
        assert.equal(iterator.getCurrentToken().value, " ");
        assert.equal(iterator.getCurrentTokenRow(), 0);
        assert.equal(iterator.getCurrentTokenColumn(), 8);      

        var iterator = new TokenIterator(session, 2, 18);
        assert.equal(iterator.getCurrentToken().value, "items");
        assert.equal(iterator.getCurrentTokenRow(), 2);
        assert.equal(iterator.getCurrentTokenColumn(), 14);

        iterator.stepForward();
        assert.equal(iterator.getCurrentToken().value, "[");
        assert.equal(iterator.getCurrentTokenRow(), 2);
        assert.equal(iterator.getCurrentTokenColumn(), 19);     
        
        var iterator = new TokenIterator(session, 4, 0);
        assert.equal(iterator.getCurrentToken().value, "}");
        assert.equal(iterator.getCurrentTokenRow(), 4);
        assert.equal(iterator.getCurrentTokenColumn(), 0);

        iterator.stepBackward();
        assert.equal(iterator.getCurrentToken().value, "// Real Tab.");
        assert.equal(iterator.getCurrentTokenRow(), 3);
        assert.equal(iterator.getCurrentTokenColumn(), 6);      
       
        var iterator = new TokenIterator(session, 5, 0);
        assert.equal(iterator.getCurrentToken(), null);
    },
 
    "test: token iterator initialization in text document" : function() {
        var lines = [
            "Lorem ipsum dolor sit amet, consectetur adipisicing elit,", 
            "sed do eiusmod tempor incididunt ut labore et dolore magna",
            "aliqua. Ut enim ad minim veniam, quis nostrud exercitation", 
            "ullamco laboris nisi ut aliquip ex ea commodo consequat."
        ];
        var session = new EditSession(lines.join("\n"));
        
        var iterator = new TokenIterator(session, 0, 0);
        assert.equal(iterator.getCurrentToken().value, lines[0]);
        assert.equal(iterator.getCurrentTokenRow(), 0);
        assert.equal(iterator.getCurrentTokenColumn(), 0);

        var iterator = new TokenIterator(session, 0, 4);
        assert.equal(iterator.getCurrentToken().value, lines[0]);
        assert.equal(iterator.getCurrentTokenRow(), 0);
        assert.equal(iterator.getCurrentTokenColumn(), 0);

        var iterator = new TokenIterator(session, 2, 18);
        assert.equal(iterator.getCurrentToken().value, lines[2]);
        assert.equal(iterator.getCurrentTokenRow(), 2);
        assert.equal(iterator.getCurrentTokenColumn(), 0);
        
        var iterator = new TokenIterator(session, 3, lines[3].length-1);
        assert.equal(iterator.getCurrentToken().value, lines[3]);
        assert.equal(iterator.getCurrentTokenRow(), 3);
        assert.equal(iterator.getCurrentTokenColumn(), 0);
       
        var iterator = new TokenIterator(session, 4, 0);
        assert.equal(iterator.getCurrentToken(), null);
    }, 
    
    "test: token iterator step forward in JavaScript document" : function() {
        var lines = [
            "function foo(items) {",
            "    for (var i=0; i<items.length; i++) {",
            "        alert(items[i] + \"juhu\");",
            "    } // Real Tab.",
            "}"
        ];
        var session = new EditSession(lines.join("\n"), new JavaScriptMode());      
    
        var rows = session.getTokens(0, lines.length-1);
        var tokens = [];    
        for (var i = 0; i < rows.length; i++)
            tokens = tokens.concat(rows[i].tokens);

        var iterator = new TokenIterator(session, 0, 0);
        for (var i = 1; i < tokens.length; i++)
            assert.equal(iterator.stepForward(), tokens[i]);
        assert.equal(iterator.stepForward(), null);
        assert.equal(iterator.getCurrentToken(), null);
    },
    
    "test: token iterator step backward in JavaScript document" : function() {
        var lines = [
            "function foo(items) {",
            "     for (var i=0; i<items.length; i++) {",
            "         alert(items[i] + \"juhu\");",
            "     } // Real Tab.",
            "}"
        ];
        var session = new EditSession(lines.join("\n"), new JavaScriptMode());      

        var rows = session.getTokens(0, lines.length-1);
        var tokens = [];    
        for (var i = 0; i < rows.length; i++)
            tokens = tokens.concat(rows[i].tokens);
    
        var iterator = new TokenIterator(session, 4, 0);
        for (var i = tokens.length-2; i >= 0; i--)
            assert.equal(iterator.stepBackward(), tokens[i]);
        assert.equal(iterator.stepBackward(), null);
        assert.equal(iterator.getCurrentToken(), null);
    },

    "test: token iterator reports correct row and column" : function() {
        var lines = [
            "function foo(items) {",
            "    for (var i=0; i<items.length; i++) {",
            "        alert(items[i] + \"juhu\");",
            "    } // Real Tab.",
            "}"
        ];
        var session = new EditSession(lines.join("\n"), new JavaScriptMode());      

        var iterator = new TokenIterator(session, 0, 0);
        
        iterator.stepForward();
        iterator.stepForward();
        
        assert.equal(iterator.getCurrentToken().value, "foo");
        assert.equal(iterator.getCurrentTokenRow(), 0);
        assert.equal(iterator.getCurrentTokenColumn(), 9);

        iterator.stepForward();
        iterator.stepForward();
        iterator.stepForward();
        iterator.stepForward();
        iterator.stepForward();
        iterator.stepForward();
        iterator.stepForward();

        assert.equal(iterator.getCurrentToken().value, "for");
        assert.equal(iterator.getCurrentTokenRow(), 1);
        assert.equal(iterator.getCurrentTokenColumn(), 4);
    },
};

});

if (typeof module !== "undefined" && module === require.main) {
    require("asyncjs").test.testcase(module.exports).exec()
}