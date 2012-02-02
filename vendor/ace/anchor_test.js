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

var Document = require("./document").Document;
var Anchor = require("./anchor").Anchor;
var Range = require("./range").Range;
var assert = require("./test/assertions");

module.exports = {

    "test create anchor" : function() {
        var doc = new Document("juhu");
        var anchor = new Anchor(doc, 0, 0);
        
        assert.position(anchor.getPosition(), 0, 0);
        assert.equal(anchor.getDocument(), doc);
    },
    
    "test insert text in same row before cursor should move anchor column": function() {
        var doc = new Document("juhu\nkinners");
        var anchor = new Anchor(doc, 1, 4);
        
        doc.insert({row: 1, column: 1}, "123");
        assert.position(anchor.getPosition(), 1, 7);
    },
    
    "test insert lines before cursor should move anchor row": function() {
        var doc = new Document("juhu\nkinners");
        var anchor = new Anchor(doc, 1, 4);
        
        doc.insertLines(1, ["123", "456"]);
        assert.position(anchor.getPosition(), 3, 4);    
    },
    
    "test insert new line before cursor should move anchor column": function() {
        var doc = new Document("juhu\nkinners");
        var anchor = new Anchor(doc, 1, 4);
        
        doc.insertNewLine({row: 0, column: 0});
        assert.position(anchor.getPosition(), 2, 4);    
    },
    
    "test insert new line in anchor line before anchor should move anchor column and row": function() {
        var doc = new Document("juhu\nkinners");
        var anchor = new Anchor(doc, 1, 4);
        
        doc.insertNewLine({row: 1, column: 2});
        assert.position(anchor.getPosition(), 2, 2);
    },
    
    "test delete text in anchor line before anchor should move anchor column": function() {
        var doc = new Document("juhu\nkinners");
        var anchor = new Anchor(doc, 1, 4);
        
        doc.remove(new Range(1, 1, 1, 3));
        assert.position(anchor.getPosition(), 1, 2);
    },
    
    "test remove range which contains the anchor should move the anchor to the start of the range": function() {
        var doc = new Document("juhu\nkinners");
        var anchor = new Anchor(doc, 0, 3);
        
        doc.remove(new Range(0, 1, 1, 3));
        assert.position(anchor.getPosition(), 0, 1);
    },
    
    "test delete character before the anchor should have no effect": function() {
        var doc = new Document("juhu\nkinners");
        var anchor = new Anchor(doc, 1, 4);
        
        doc.remove(new Range(1, 4, 1, 5));
        assert.position(anchor.getPosition(), 1, 4);
    },
    
    "test delete lines in anchor line before anchor should move anchor row": function() {
        var doc = new Document("juhu\n1\n2\nkinners");
        var anchor = new Anchor(doc, 3, 4);
        
        doc.removeLines(1, 2);
        assert.position(anchor.getPosition(), 1, 4);
    },
    
    "test remove new line before the cursor": function() {
        var doc = new Document("juhu\nkinners");
        var anchor = new Anchor(doc, 1, 4);
        
        doc.removeNewLine(0);
        assert.position(anchor.getPosition(), 0, 8);
    },
    
    "test delete range which contains the anchor should move anchor to the end of the range": function() {
        var doc = new Document("juhu\nkinners");
        var anchor = new Anchor(doc, 1, 4);
        
        doc.remove(new Range(0, 2, 1, 2));
        assert.position(anchor.getPosition(), 0, 4);
    },
    
    "test delete line which contains the anchor should move anchor to the end of the range": function() {
        var doc = new Document("juhu\nkinners\n123");
        var anchor = new Anchor(doc, 1, 5);
        
        doc.removeLines(1, 1);
        assert.position(anchor.getPosition(), 1, 0);
    },
    
    "test remove after the anchor should have no effect": function() {
        var doc = new Document("juhu\nkinners\n123");
        var anchor = new Anchor(doc, 1, 2);
        
        doc.remove(new Range(1, 4, 2, 2));
        assert.position(anchor.getPosition(), 1, 2);
    },
    
    "test anchor changes triggered by document changes should emit change event": function(next) {
        var doc = new Document("juhu\nkinners\n123");
        var anchor = new Anchor(doc, 1, 5);
        
        anchor.on("change", function(e) {
            assert.position(anchor.getPosition(), 0, 0);
            next();
        });
        
        doc.remove(new Range(0, 0, 2, 1));
    },
    
    "test only fire change event if position changes": function() {
        var doc = new Document("juhu\nkinners\n123");
        var anchor = new Anchor(doc, 1, 5);
        
        anchor.on("change", function(e) {
            assert.fail();
        });
        
        doc.remove(new Range(2, 0, 2, 1));
    }
};

});

if (typeof module !== "undefined" && module === require.main) {
    require("asyncjs").test.testcase(module.exports).exec()
}