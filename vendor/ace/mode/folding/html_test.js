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

if (typeof process !== "undefined")
    require("amd-loader");

define(function(require, exports, module) {
"use strict";

var HtmlMode = require("../html").Mode;
var EditSession = require("../../edit_session").EditSession;
var assert = require("../../test/assertions");

module.exports = {

    "test: fold mixed html and javascript": function() {
        var session = new EditSession([
            '<script type="text/javascript"> ',
            'function() foo {',
            '    var bar = 1;',
            '}',
            '</script>'
        ]);
        
        var mode = new HtmlMode();
        session.setMode(mode);
        session.setFoldStyle("markbeginend");
        
        assert.equal(session.getFoldWidget(0), "start");
        assert.equal(session.getFoldWidget(1), "start");
        assert.equal(session.getFoldWidget(2), "");
        assert.equal(session.getFoldWidget(3), "end");
        assert.equal(session.getFoldWidget(4), "end");
        
        assert.range(session.getFoldWidgetRange(0), 0, 8, 4, 0);
        assert.range(session.getFoldWidgetRange(4), 0, 8, 4, 0);
        
        assert.range(session.getFoldWidgetRange(1), 1, 16, 3, 0);
        assert.range(session.getFoldWidgetRange(3), 1, 16, 3, 0);
    },
    
    "test: fold mixed html and css": function() {
        var session = new EditSession([
            '<style type="text/css">',
            '    .text-layer {',
            '        font-family: Monaco, "Courier New", monospace;',
            '    }',
            '</style>'
        ]);
        
        var mode = new HtmlMode();
        session.setMode(mode);
        session.setFoldStyle("markbeginend");
        
        assert.equal(session.getFoldWidget(0), "start");
        assert.equal(session.getFoldWidget(1), "start");
        assert.equal(session.getFoldWidget(2), "");
        assert.equal(session.getFoldWidget(3), "end");
        assert.equal(session.getFoldWidget(4), "end");
        
        assert.range(session.getFoldWidgetRange(0), 0, 7, 4, 0);
        assert.range(session.getFoldWidgetRange(4), 0, 7, 4, 0);
        
        assert.range(session.getFoldWidgetRange(1), 1, 17, 3, 4);
        assert.range(session.getFoldWidgetRange(3), 1, 17, 3, 4);
    },
    
    "test: fold should skip self closing elements": function() {
        var session = new EditSession([
            '<body>',
            '<br />',
            '</body>'
        ]);
        
        var mode = new HtmlMode();
        session.setMode(mode);
        session.setFoldStyle("markbeginend");
        
        assert.equal(session.getFoldWidget(0), "start");
        assert.equal(session.getFoldWidget(1), "");
        assert.equal(session.getFoldWidget(2), "end");
        
        assert.range(session.getFoldWidgetRange(0), 0, 6, 2, 0);
        assert.range(session.getFoldWidgetRange(2), 0, 6, 2, 0);
    },
    
    "test: fold should skip void elements": function() {
        var session = new EditSession([
            '<body>',
            '<br>',
            '</body>'
        ]);
        
        var mode = new HtmlMode();
        session.setMode(mode);
        session.setFoldStyle("markbeginend");
        
        assert.equal(session.getFoldWidget(0), "start");
        assert.equal(session.getFoldWidget(1), "");
        assert.equal(session.getFoldWidget(2), "end");
        
        assert.range(session.getFoldWidgetRange(0), 0, 6, 2, 0);
        assert.range(session.getFoldWidgetRange(2), 0, 6, 2, 0);
    },
    
    "test: fold multiple unclosed elements": function() {
        var session = new EditSession([
            '<div>',
            '<p>',
            'juhu',
            '<p>',
            'kinners',
            '</div>'
        ]);
        
        var mode = new HtmlMode();
        session.setMode(mode);
        session.setFoldStyle("markbeginend");
        
        assert.equal(session.getFoldWidget(0), "start");
        assert.equal(session.getFoldWidget(1), "");
        assert.equal(session.getFoldWidget(2), "");
        assert.equal(session.getFoldWidget(3), "");
        assert.equal(session.getFoldWidget(4), "");
        assert.equal(session.getFoldWidget(5), "end");
        
        assert.range(session.getFoldWidgetRange(0), 0, 5, 5, 0);
        assert.range(session.getFoldWidgetRange(5), 0, 5, 5, 0);
    }
};

});

if (typeof module !== "undefined" && module === require.main)
    require("asyncjs").test.testcase(module.exports).exec();