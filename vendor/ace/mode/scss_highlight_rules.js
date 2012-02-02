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

define(function(require, exports, module) {
"use strict";

var oop = require("../lib/oop");
var lang = require("../lib/lang");
var TextHighlightRules = require("./text_highlight_rules").TextHighlightRules;

var ScssHighlightRules = function() {
    
    var properties = lang.arrayToMap( (function () {

        var browserPrefix = ("-webkit-|-moz-|-o-|-ms-|-svg-|-pie-|-khtml-").split("|");
        
        var prefixProperties = ("appearance|background-clip|background-inline-policy|background-origin|" + 
             "background-size|binding|border-bottom-colors|border-left-colors|" + 
             "border-right-colors|border-top-colors|border-end|border-end-color|" + 
             "border-end-style|border-end-width|border-image|border-start|" + 
             "border-start-color|border-start-style|border-start-width|box-align|" + 
             "box-direction|box-flex|box-flexgroup|box-ordinal-group|box-orient|" + 
             "box-pack|box-sizing|column-count|column-gap|column-width|column-rule|" + 
             "column-rule-width|column-rule-style|column-rule-color|float-edge|" + 
             "font-feature-settings|font-language-override|force-broken-image-icon|" + 
             "image-region|margin-end|margin-start|opacity|outline|outline-color|" + 
             "outline-offset|outline-radius|outline-radius-bottomleft|" + 
             "outline-radius-bottomright|outline-radius-topleft|outline-radius-topright|" + 
             "outline-style|outline-width|padding-end|padding-start|stack-sizing|" + 
             "tab-size|text-blink|text-decoration-color|text-decoration-line|" + 
             "text-decoration-style|transform|transform-origin|transition|" + 
             "transition-delay|transition-duration|transition-property|" + 
             "transition-timing-function|user-focus|user-input|user-modify|user-select|" +
             "window-shadow|border-radius").split("|");
        
        var properties = ("azimuth|background-attachment|background-color|background-image|" +
            "background-position|background-repeat|background|border-bottom-color|" +
            "border-bottom-style|border-bottom-width|border-bottom|border-collapse|" +
            "border-color|border-left-color|border-left-style|border-left-width|" +
            "border-left|border-right-color|border-right-style|border-right-width|" +
            "border-right|border-spacing|border-style|border-top-color|" +
            "border-top-style|border-top-width|border-top|border-width|border|" +
            "bottom|box-sizing|caption-side|clear|clip|color|content|counter-increment|" +
            "counter-reset|cue-after|cue-before|cue|cursor|direction|display|" +
            "elevation|empty-cells|float|font-family|font-size-adjust|font-size|" +
            "font-stretch|font-style|font-variant|font-weight|font|height|left|" +
            "letter-spacing|line-height|list-style-image|list-style-position|" +
            "list-style-type|list-style|margin-bottom|margin-left|margin-right|" +
            "margin-top|marker-offset|margin|marks|max-height|max-width|min-height|" +
            "min-width|opacity|orphans|outline-color|" +
            "outline-style|outline-width|outline|overflow|overflow-x|overflow-y|padding-bottom|" +
            "padding-left|padding-right|padding-top|padding|page-break-after|" +
            "page-break-before|page-break-inside|page|pause-after|pause-before|" +
            "pause|pitch-range|pitch|play-during|position|quotes|richness|right|" +
            "size|speak-header|speak-numeral|speak-punctuation|speech-rate|speak|" +
            "stress|table-layout|text-align|text-decoration|text-indent|" +
            "text-shadow|text-transform|top|unicode-bidi|vertical-align|" +
            "visibility|voice-family|volume|white-space|widows|width|word-spacing|" +
            "z-index").split("|");
          
        //The return array     
        var ret = [];
        
        //All prefixProperties will get the browserPrefix in
        //the begning by join the prefixProperties array with the value of browserPrefix
        for (var i=0, ln=browserPrefix.length; i<ln; i++) {
            Array.prototype.push.apply(
                ret,
                (( browserPrefix[i] + prefixProperties.join("|" + browserPrefix[i]) ).split("|"))
            );
        }
        
        //Add also prefixProperties and properties without any browser prefix
        Array.prototype.push.apply(ret, prefixProperties);
        Array.prototype.push.apply(ret, properties);
        
        return ret;
        
    })() );
    


    var functions = lang.arrayToMap(
        ("hsl|hsla|rgb|rgba|url|attr|counter|counters|abs|adjust_color|adjust_hue|" +
         "alpha|join|blue|ceil|change_color|comparable|complement|darken|desaturate|" + 
         "floor|grayscale|green|hue|if|invert|join|length|lighten|lightness|mix|" + 
         "nth|opacify|opacity|percentage|quote|red|round|saturate|saturation|" +
         "scale_color|transparentize|type_of|unit|unitless|unqoute").split("|")
    );

    var constants = lang.arrayToMap(
        ("absolute|all-scroll|always|armenian|auto|baseline|below|bidi-override|" +
        "block|bold|bolder|border-box|both|bottom|break-all|break-word|capitalize|center|" +
        "char|circle|cjk-ideographic|col-resize|collapse|content-box|crosshair|dashed|" +
        "decimal-leading-zero|decimal|default|disabled|disc|" +
        "distribute-all-lines|distribute-letter|distribute-space|" +
        "distribute|dotted|double|e-resize|ellipsis|fixed|georgian|groove|" +
        "hand|hebrew|help|hidden|hiragana-iroha|hiragana|horizontal|" +
        "ideograph-alpha|ideograph-numeric|ideograph-parenthesis|" +
        "ideograph-space|inactive|inherit|inline-block|inline|inset|inside|" +
        "inter-ideograph|inter-word|italic|justify|katakana-iroha|katakana|" +
        "keep-all|left|lighter|line-edge|line-through|line|list-item|loose|" +
        "lower-alpha|lower-greek|lower-latin|lower-roman|lowercase|lr-tb|ltr|" +
        "medium|middle|move|n-resize|ne-resize|newspaper|no-drop|no-repeat|" +
        "nw-resize|none|normal|not-allowed|nowrap|oblique|outset|outside|" +
        "overline|pointer|progress|relative|repeat-x|repeat-y|repeat|right|" +
        "ridge|row-resize|rtl|s-resize|scroll|se-resize|separate|small-caps|" +
        "solid|square|static|strict|super|sw-resize|table-footer-group|" +
        "table-header-group|tb-rl|text-bottom|text-top|text|thick|thin|top|" +
        "transparent|underline|upper-alpha|upper-latin|upper-roman|uppercase|" +
        "vertical-ideographic|vertical-text|visible|w-resize|wait|whitespace|" +
        "zero").split("|")
    );

    var colors = lang.arrayToMap(
        ("aqua|black|blue|fuchsia|gray|green|lime|maroon|navy|olive|orange|" +
        "purple|red|silver|teal|white|yellow").split("|")
    );
    
    var keywords = lang.arrayToMap(
        ("@mixin|@extend|@include|@import|@media|@debug|@warn|@if|@for|@each|@while|@else|@font-face|@-webkit-keyframes|if|and|!default|module|def|end|declare").split("|")
    )
    
    var tags = lang.arrayToMap(
        ("a|abbr|acronym|address|applet|area|article|aside|audio|b|base|basefont|bdo|" + 
         "big|blockquote|body|br|button|canvas|caption|center|cite|code|col|colgroup|" + 
         "command|datalist|dd|del|details|dfn|dir|div|dl|dt|em|embed|fieldset|" + 
         "figcaption|figure|font|footer|form|frame|frameset|h1|h2|h3|h4|h5|h6|head|" + 
         "header|hgroup|hr|html|i|iframe|img|input|ins|keygen|kbd|label|legend|li|" + 
         "link|map|mark|menu|meta|meter|nav|noframes|noscript|object|ol|optgroup|" + 
         "option|output|p|param|pre|progress|q|rp|rt|ruby|s|samp|script|section|select|" + 
         "small|source|span|strike|strong|style|sub|summary|sup|table|tbody|td|" + 
         "textarea|tfoot|th|thead|time|title|tr|tt|u|ul|var|video|wbr|xmp").split("|")
    );

    // regexp must not have capturing parentheses. Use (?:) instead.
    // regexps are ordered -> the first match is used

    var numRe = "\\-?(?:(?:[0-9]+)|(?:[0-9]*\\.[0-9]+))";

    // regexp must not have capturing parentheses. Use (?:) instead.
    // regexps are ordered -> the first match is used

    this.$rules = {
        "start" : [
            {
                token : "comment",
                regex : "\\/\\/.*$"
            },
            {
                token : "comment", // multi line comment
                merge : true,
                regex : "\\/\\*",
                next : "comment"
            }, {
                token : "string", // single line
                regex : '["](?:(?:\\\\.)|(?:[^"\\\\]))*?["]'
            }, {
                token : "string", // multi line string start
                merge : true,
                regex : '["].*\\\\$',
                next : "qqstring"
            }, {
                token : "string", // single line
                regex : "['](?:(?:\\\\.)|(?:[^'\\\\]))*?[']"
            }, {
                token : "string", // multi line string start
                merge : true,
                regex : "['].*\\\\$",
                next : "qstring"
            }, {
                token : "constant.numeric",
                regex : numRe + "(?:em|ex|px|cm|mm|in|pt|pc|deg|rad|grad|ms|s|hz|khz|%)"
            }, {
                token : "constant.numeric", // hex6 color
                regex : "#[a-f0-9]{6}"
            }, {
                token : "constant.numeric", // hex3 color
                regex : "#[a-f0-9]{3}"
            }, {
                token : "constant.numeric",
                regex : numRe
            }, {
                token : function(value) {
                    if (properties.hasOwnProperty(value.toLowerCase()))
                        return "support.type";
                    if (keywords.hasOwnProperty(value))
                        return "keyword";
                    else if (constants.hasOwnProperty(value))
                        return "constant.language";
                    else if (functions.hasOwnProperty(value))
                        return "support.function";
                    else if (colors.hasOwnProperty(value.toLowerCase()))
                        return "support.constant.color";
                    else if (tags.hasOwnProperty(value.toLowerCase()))
                        return "variable.language";
                    else
                        return "text";
                },
                regex : "\\-?[@a-z_][@a-z0-9_\\-]*"
            }, {
                token : "variable",
                regex : "[a-z_\\-$][a-z0-9_\\-$]*\\b"
            }, {
                token: "variable.language",
                regex: "#[a-z0-9-_]+"
            }, {
                token: "variable.language",
                regex: "\\.[a-z0-9-_]+"
            }, {
                token: "variable.language",
                regex: ":[a-z0-9-_]+"
            }, {
                token: "constant",
                regex: "[a-z0-9-_]+"
            }, {
                token : "keyword.operator",
                regex : "<|>|<=|>=|==|!=|-|%|#|\\+|\\$|\\+|\\*"
            }, {
                token : "paren.lparen",
                regex : "[[({]"
            }, {
                token : "paren.rparen",
                regex : "[\\])}]"
            }, {
                token : "text",
                regex : "\\s+"
            }
        ],
        "comment" : [
            {
                token : "comment", // closing comment
                regex : ".*?\\*\\/",
                next : "start"
            }, {
                token : "comment", // comment spanning whole line
                merge : true,
                regex : ".+"
            }
        ],
        "qqstring" : [
            {
                token : "string",
                regex : '(?:(?:\\\\.)|(?:[^"\\\\]))*?"',
                next : "start"
            }, {
                token : "string",
                merge : true,
                regex : '.+'
            }
        ],
        "qstring" : [
            {
                token : "string",
                regex : "(?:(?:\\\\.)|(?:[^'\\\\]))*?'",
                next : "start"
            }, {
                token : "string",
                merge : true,
                regex : '.+'
            }
        ]
    };
};

oop.inherits(ScssHighlightRules, TextHighlightRules);

exports.ScssHighlightRules = ScssHighlightRules;

});
