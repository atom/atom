define(function(require, exports, module) {
"use strict";

var oop = require("../lib/oop");
var TextMode = require("./text").Mode;
var Tokenizer = require("../tokenizer").Tokenizer;
var LatexHighlightRules = require("./latex_highlight_rules").LatexHighlightRules;
var Range = require("../range").Range;

var Mode = function()
{
    this.$tokenizer = new Tokenizer(new LatexHighlightRules().getRules());
};
oop.inherits(Mode, TextMode);

(function() {
    this.toggleCommentLines = function(state, doc, startRow, endRow) {
        // This code is adapted from ruby.js
        var outdent = true;
        
        // LaTeX comments begin with % and go to the end of the line
        var commentRegEx = /^(\s*)\%/;

        for (var i = startRow; i <= endRow; i++) {
            if (!commentRegEx.test(doc.getLine(i))) {
                outdent = false;
                break;
            }
        }

        if (outdent) {
            var deleteRange = new Range(0, 0, 0, 0);
            for (var i = startRow; i <= endRow; i++) {
                var line = doc.getLine(i);
                var m = line.match(commentRegEx);
                deleteRange.start.row = i;
                deleteRange.end.row = i;
                deleteRange.end.column = m[0].length;
                doc.replace(deleteRange, m[1]);
            }
        }
        else {
            doc.indentRows(startRow, endRow, "%");
        }
    };
    
    // There is no universally accepted way of indenting a tex document
    // so just maintain the indentation of the previous line
    this.getNextLineIndent = function(state, line, tab) {
        return this.$getIndent(line);
    };
    
}).call(Mode.prototype);

exports.Mode = Mode;

});
