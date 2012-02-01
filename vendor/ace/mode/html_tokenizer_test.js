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

var HtmlMode = require("./html").Mode;
var assert = require("../test/assertions");

module.exports = {
    setUp : function() {
        this.tokenizer = new HtmlMode().getTokenizer();
    },

    "test: tokenize embedded script" : function() {
        var line = "<script a='a'>var</script>'123'";
        var tokens = this.tokenizer.getLineTokens(line, "start").tokens;

        assert.equal(12, tokens.length);
        assert.equal("meta.tag", tokens[0].type);
        assert.equal("meta.tag.script", tokens[1].type);
        assert.equal("text", tokens[2].type);
        assert.equal("entity.other.attribute-name", tokens[3].type);
        assert.equal("keyword.operator", tokens[4].type);
        assert.equal("string", tokens[5].type);
        assert.equal("meta.tag", tokens[6].type);
        assert.equal("keyword.definition", tokens[7].type);
        assert.equal("meta.tag", tokens[8].type);
        assert.equal("meta.tag.script", tokens[9].type);
        assert.equal("meta.tag", tokens[10].type);
        assert.equal("text", tokens[11].type);
    },
    
    "test: tokenize multiline attribute value with double quotes": function() {
        var line1 = this.tokenizer.getLineTokens('<a href="abc', "start");
        var t1 = line1.tokens;
        var t2 = this.tokenizer.getLineTokens('def">', line1.state).tokens;
        assert.equal(t1[t1.length-1].type, "string");
        assert.equal(t2[0].type, "string");
    },
    
    "test: tokenize multiline attribute value with single quotes": function() {
        var line1 = this.tokenizer.getLineTokens("<a href='abc", "start");
        var t1 = line1.tokens;
        var t2 = this.tokenizer.getLineTokens('def\'>', line1.state).tokens;
        assert.equal(t1[t1.length-1].type, "string");
        assert.equal(t2[0].type, "string");
    }
};

});

if (typeof module !== "undefined" && module === require.main) {
    require("asyncjs").test.testcase(module.exports).exec();
}