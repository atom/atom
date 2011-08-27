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
 *      Satoshi Murakami <murky.satyr AT gmail DOT com>
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

    require("pilot/oop").inherits(CoffeeHighlightRules,
            require("ace/mode/text_highlight_rules").TextHighlightRules);

    function CoffeeHighlightRules() {
        var identifier = "[$A-Za-z_\\x7f-\\uffff][$\\w\\x7f-\\uffff]*";
        var keywordend = "(?![$\\w]|\\s*:)";
        var stringfill = {
            token : "string",
            merge : true,
            regex : ".+"
        };
        
        this.$rules = {
            start : [
                {
                    token : "identifier",
                    regex : "(?:@|(?:\\.|::)\\s*)" + identifier
                }, {
                    token : "keyword",
                    regex : "(?:t(?:h(?:is|row|en)|ry|ypeof)|s(?:uper|witch)|return|b(?:reak|y)|c(?:ontinue|atch|lass)|i(?:n(?:stanceof)?|s(?:nt)?|f)|e(?:lse|xtends)|f(?:or (?:own)?|inally|unction)|wh(?:ile|en)|n(?:ew|ot?)|d(?:e(?:lete|bugger)|o)|loop|o(?:ff?|[rn])|un(?:less|til)|and|yes)"
                            + keywordend
                }, {
                    token : "constant.language",
                    regex : "(?:true|false|null|undefined)" + keywordend
                }, {
                    token : "invalid.illegal",
                    regex : "(?:c(?:ase|onst)|default|function|v(?:ar|oid)|with|e(?:num|xport)|i(?:mplements|nterface)|let|p(?:ackage|r(?:ivate|otected)|ublic)|static|yield|__(?:hasProp|extends|slice|bind|indexOf))"
                            + keywordend
                }, {
                    token : "language.support.class",
                    regex : "(?:Array|Boolean|Date|Function|Number|Object|R(?:e(?:gExp|ferenceError)|angeError)|S(?:tring|yntaxError)|E(?:rror|valError)|TypeError|URIError)"
                            + keywordend
                }, {
                    token : "language.support.function",
                    regex : "(?:Math|JSON|is(?:NaN|Finite)|parse(?:Int|Float)|encodeURI(?:Component)?|decodeURI(?:Component)?)"
                            + keywordend
                }, {
                    token : "identifier",
                    regex : identifier
                }, {
                    token : "constant.numeric",
                    regex : "(?:0x[\\da-fA-F]+|(?:\\d+(?:\\.\\d+)?|\\.\\d+)(?:[eE][+-]?\\d+)?)"
                }, {
                    token : "string",
                    merge : true,
                    regex : "'''",
                    next : "qdoc"
                }, {
                    token : "string",
                    merge : true,
                    regex : '"""',
                    next : "qqdoc"
                }, {
                    token : "string",
                    merge : true,
                    regex : "'",
                    next : "qstring"
                }, {
                    token : "string",
                    merge : true,
                    regex : '"',
                    next : "qqstring"
                }, {
                    token : "string",
                    merge : true,
                    regex : "`",
                    next : "js"
                }, {
                    token : "string.regex",
                    merge : true,
                    regex : "///",
                    next : "heregex"
                }, {
                    token : "string.regex",
                    regex : "/(?!\\s)[^[/\\n\\\\]*(?: (?:\\\\.|\\[[^\\]\\n\\\\]*(?:\\\\.[^\\]\\n\\\\]*)*\\])[^[/\\n\\\\]*)*/[imgy]{0,4}(?!\\w)"
                }, {
                    token : "comment",
                    merge : true,
                    regex : "###(?!#)",
                    next : "comment"
                }, {
                    token : "comment",
                    regex : "#.*"
                }, {
                    token : "lparen",
                    regex : "[({[]"
                }, {
                    token : "rparen",
                    regex : "[\\]})]"
                }, {
                    token : "keyword.operator",
                    regex : "\\S+"
                }, {
                    token : "text",
                    regex : "\\s+"
                }],
            
            qdoc : [{
                token : "string",
                regex : ".*?'''",
                next : "start"
            }, stringfill],
            
            qqdoc : [{
                token : "string",
                regex : '.*?"""',
                next : "start"
            }, stringfill],
            
            qstring : [{
                token : "string",
                regex : "[^\\\\']*(?:\\\\.[^\\\\']*)*'",
                next : "start"
            }, stringfill],
            
            qqstring : [{
                token : "string",
                regex : '[^\\\\"]*(?:\\\\.[^\\\\"]*)*"',
                next : "start"
            }, stringfill],
            
            js : [{
                token : "string",
                merge : true,
                regex : "[^\\\\`]*(?:\\\\.[^\\\\`]*)*`",
                next : "start"
            }, stringfill],
            
            heregex : [{
                token : "string.regex",
                regex : '.*?///[imgy]{0,4}',
                next : "start"
            }, {
                token : "comment.regex",
                regex : "\\s+(?:#.*)?"
            }, {
                token : "string.regex",
                merge : true,
                regex : "\\S+"
            }],
            
            comment : [{
                token : "comment",
                regex : '.*?###',
                next : "start"
            }, {
                token : "comment",
                merge : true,
                regex : ".+"
            }]
        };
    }

    exports.CoffeeHighlightRules = CoffeeHighlightRules;
});
