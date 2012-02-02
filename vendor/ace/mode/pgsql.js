/* ***** BEGIN LICENSE BLOCK *****
* The Original Code is Ajax.org Code Editor (ACE).
*
* Contributor(s):
*      Jonathan Camile <jonathan.camile AT gmail DOT com>
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

define(function(require, exports, module) {

    var oop = require("ace/lib/oop");
    var TextMode = require("ace/mode/text").Mode;
    var Tokenizer = require("ace/tokenizer").Tokenizer;
    var PgsqlHighlightRules = require("ace/mode/pgsql_highlight_rules").PgsqlHighlightRules;
    var Range = require("ace/range").Range;
    // var EditSession = require("ace/edit_session").EditSession;

    var Mode = function() {
        this.$tokenizer = new Tokenizer(new PgsqlHighlightRules().getRules());
    };
    oop.inherits(Mode, TextMode);

    (function() {

        this.toggleCommentLines = function(state, doc, startRow, endRow) {
            var outdent = true;
            // var outentedRows = [];
            var re = /^(\s*)--/;

            for (var i=startRow; i<= endRow; i++) {
                if (!re.test(doc.getLine(i))) {
                    outdent = false;
                    break;
                }
            }

            if (outdent) {
                var deleteRange = new Range(0, 0, 0, 0);
                for (var i=startRow; i<= endRow; i++)
                {
                    var line = doc.getLine(i);
                    var m = line.match(re);
                    deleteRange.start.row = i;
                    deleteRange.end.row = i;
                    deleteRange.end.column = m[0].length;
                    doc.replace(deleteRange, m[1]);
                }
            }
            else {
                doc.indentRows(startRow, endRow, "--");
            }
        };


        this.getNextLineIndent = function(state, line, tab) { 
            if (state == "start" || state == "keyword.statementEnd") {
                return "";
            } else {
                return this.$getIndent(line); // Keep whatever indent the previous line has
            }
        }

    }).call(Mode.prototype);

    exports.Mode = Mode;
});
