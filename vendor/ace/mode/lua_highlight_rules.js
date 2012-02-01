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
*      Colin Gourlay <colin DOT j DOT gourlay AT gmail DOT com>
*      Lee Gao
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

var LuaHighlightRules = function() {

    var keywords = lang.arrayToMap(
        ("break|do|else|elseif|end|for|function|if|in|local|repeat|"+
         "return|then|until|while|or|and|not").split("|")
    );

    var builtinConstants = lang.arrayToMap(
        ("true|false|nil|_G|_VERSION").split("|")
    );

    var builtinFunctions = lang.arrayToMap(
        ("string|xpcall|package|tostring|print|os|unpack|require|"+
        "getfenv|setmetatable|next|assert|tonumber|io|rawequal|"+
        "collectgarbage|getmetatable|module|rawset|math|debug|"+
        "pcall|table|newproxy|type|coroutine|_G|select|gcinfo|"+
        "pairs|rawget|loadstring|ipairs|_VERSION|dofile|setfenv|"+
        "load|error|loadfile|"+

        "sub|upper|len|gfind|rep|find|match|char|dump|gmatch|"+
        "reverse|byte|format|gsub|lower|preload|loadlib|loaded|"+
        "loaders|cpath|config|path|seeall|exit|setlocale|date|"+
        "getenv|difftime|remove|time|clock|tmpname|rename|execute|"+
        "lines|write|close|flush|open|output|type|read|stderr|"+
        "stdin|input|stdout|popen|tmpfile|log|max|acos|huge|"+
        "ldexp|pi|cos|tanh|pow|deg|tan|cosh|sinh|random|randomseed|"+
        "frexp|ceil|floor|rad|abs|sqrt|modf|asin|min|mod|fmod|log10|"+
        "atan2|exp|sin|atan|getupvalue|debug|sethook|getmetatable|"+
        "gethook|setmetatable|setlocal|traceback|setfenv|getinfo|"+
        "setupvalue|getlocal|getregistry|getfenv|setn|insert|getn|"+
        "foreachi|maxn|foreach|concat|sort|remove|resume|yield|"+
        "status|wrap|create|running").split("|")
    );
    
    var stdLibaries = lang.arrayToMap(
        ("string|package|os|io|math|debug|table|coroutine").split("|")
    );
    
    var metatableMethods = lang.arrayToMap(
        ("__add|__sub|__mod|__unm|__concat|__lt|__index|__call|__gc|__metatable|"+
         "__mul|__div|__pow|__len|__eq|__le|__newindex|__tostring|__mode|__tonumber").split("|")
    );

    var futureReserved = lang.arrayToMap(
        ("").split("|")
    );
    
    var deprecatedIn5152 = lang.arrayToMap(
        ("setn|foreach|foreachi|gcinfo|log10|maxn").split("|")
    );

    var strPre = "";

    var decimalInteger = "(?:(?:[1-9]\\d*)|(?:0))";
    var hexInteger = "(?:0[xX][\\dA-Fa-f]+)";
    var integer = "(?:" + decimalInteger + "|" + hexInteger + ")";

    var fraction = "(?:\\.\\d+)";
    var intPart = "(?:\\d+)";
    var pointFloat = "(?:(?:" + intPart + "?" + fraction + ")|(?:" + intPart + "\\.))";
    var floatNumber = "(?:" + pointFloat + ")";
    
    var comment_stack = [];
    
    this.$rules = {
        "start" : 

		
        // bracketed comments
        [{
            token : "comment",           // --[[ comment
            regex : strPre + '\\-\\-\\[\\[.*\\]\\]'
        }, {
            token : "comment",           // --[=[ comment
            regex : strPre + '\\-\\-\\[\\=\\[.*\\]\\=\\]'
        }, {
            token : "comment",           // --[==[ comment
            regex : strPre + '\\-\\-\\[\\={2}\\[.*\\]\\={2}\\]'
        }, {
            token : "comment",           // --[===[ comment
            regex : strPre + '\\-\\-\\[\\={3}\\[.*\\]\\={3}\\]'
        }, {
            token : "comment",           // --[====[ comment
            regex : strPre + '\\-\\-\\[\\={4}\\[.*\\]\\={4}\\]'
        }, {
            token : "comment",           // --[====+[ comment
            regex : strPre + '\\-\\-\\[\\={5}\\=*\\[.*\\]\\={5}\\=*\\]'
        },
		
		// multiline bracketed comments
		{
            token : "comment",           // --[[ comment
            regex : strPre + '\\-\\-\\[\\[.*$',
            merge : true,
            next  : "qcomment"
        }, {
            token : "comment",           // --[=[ comment
            regex : strPre + '\\-\\-\\[\\=\\[.*$',
            merge : true,
            next  : "qcomment1"
        }, {
            token : "comment",           // --[==[ comment
            regex : strPre + '\\-\\-\\[\\={2}\\[.*$',
            merge : true,
            next  : "qcomment2"
        }, {
            token : "comment",           // --[===[ comment
            regex : strPre + '\\-\\-\\[\\={3}\\[.*$',
            merge : true,
            next  : "qcomment3"
        }, {
            token : "comment",           // --[====[ comment
            regex : strPre + '\\-\\-\\[\\={4}\\[.*$',
            merge : true,
            next  : "qcomment4"
        }, {
            token : function(value){     // --[====+[ comment
                // WARNING: EXTREMELY SLOW, but this is the only way to circumvent the
                // limits imposed by the current automaton.
                // I've never personally seen any practical code where 5 or more '='s are
                // used for string or commenting, so this will rarely be invoked.
                var pattern = /\-\-\[(\=+)\[/, match;
                // you can never be too paranoid ;)
                if ((match = pattern.exec(value)) != null && (match = match[1]) != undefined)
                    comment_stack.push(match.length);
                
                return "comment";
            },
            regex : strPre + '\\-\\-\\[\\={5}\\=*\\[.*$',
            merge : true,
            next  : "qcomment5"
        },
        
        // single line comments
        {
            token : "comment",
            regex : "\\-\\-.*$"
        }, 
        
        // bracketed strings
		{
            token : "string",           // [[ string
            regex : strPre + '\\[\\[.*\\]\\]'
        }, {
            token : "string",           // [=[ string
            regex : strPre + '\\[\\=\\[.*\\]\\=\\]'
        }, {
            token : "string",           // [==[ string
            regex : strPre + '\\[\\={2}\\[.*\\]\\={2}\\]'
        }, {
            token : "string",           // [===[ string
            regex : strPre + '\\[\\={3}\\[.*\\]\\={3}\\]'
        }, {
            token : "string",           // [====[ string
            regex : strPre + '\\[\\={4}\\[.*\\]\\={4}\\]'
        }, {
            token : "string",           // [====+[ string
            regex : strPre + '\\[\\={5}\\=*\\[.*\\]\\={5}\\=*\\]'
        },
		
		// multiline bracketed strings
        {
            token : "string",           // [[ string
            regex : strPre + '\\[\\[.*$',
            merge : true,
            next  : "qstring"
        }, {
            token : "string",           // [=[ string
            regex : strPre + '\\[\\=\\[.*$',
            merge : true,
            next  : "qstring1"
        }, {
            token : "string",           // [==[ string
            regex : strPre + '\\[\\={2}\\[.*$',
            merge : true,
            next  : "qstring2"
        }, {
            token : "string",           // [===[ string
            regex : strPre + '\\[\\={3}\\[.*$',
            merge : true,
            next  : "qstring3"
        }, {
            token : "string",           // [====[ string
            regex : strPre + '\\[\\={4}\\[.*$',
            merge : true,
            next  : "qstring4"
        }, {
            token : function(value){     // --[====+[ string
                // WARNING: EXTREMELY SLOW, see above.
                var pattern = /\[(\=+)\[/, match;
                if ((match = pattern.exec(value)) != null && (match = match[1]) != undefined)
                    comment_stack.push(match.length);
                
                return "string";
            },
            regex : strPre + '\\[\\={5}\\=*\\[.*$',
            merge : true,
            next  : "qstring5"
        }, 
        
        {
            token : "string",           // " string
            regex : strPre + '"(?:[^\\\\]|\\\\.)*?"'
        }, {
            token : "string",           // ' string
            regex : strPre + "'(?:[^\\\\]|\\\\.)*?'"
        }, {
            token : "constant.numeric", // float
            regex : floatNumber
        }, {
            token : "constant.numeric", // integer
            regex : integer + "\\b"
        }, {
            token : function(value) {
                if (keywords.hasOwnProperty(value))
                    return "keyword";
                else if (builtinConstants.hasOwnProperty(value))
                    return "constant.language";
                else if (futureReserved.hasOwnProperty(value))
                    return "invalid.illegal";
                else if (stdLibaries.hasOwnProperty(value))
                    return "constant.library";
                else if (deprecatedIn5152.hasOwnProperty(value))
                    return "invalid.deprecated";
                else if (builtinFunctions.hasOwnProperty(value))
                    return "support.function";
                else if (metatableMethods.hasOwnProperty(value))
                    return "support.function";
                else
                    return "identifier";
            },
            regex : "[a-zA-Z_$][a-zA-Z0-9_$]*\\b"
        }, {
            token : "keyword.operator",
            regex : "\\+|\\-|\\*|\\/|%|\\#|\\^|~|<|>|<=|=>|==|~=|=|\\:|\\.\\.\\.|\\.\\."
        }, {
            token : "paren.lparen",
            regex : "[\\[\\(\\{]"
        }, {
            token : "paren.rparen",
            regex : "[\\]\\)\\}]"
        }, {
            token : "text",
            regex : "\\s+"
        } ],
        
        "qcomment": [ {
            token : "comment",
            regex : "(?:[^\\\\]|\\\\.)*?\\]\\]",
            next  : "start"
        }, {
            token : "comment",
            merge : true,
            regex : '.+'
        } ],
        "qcomment1": [ {
            token : "comment",
            regex : "(?:[^\\\\]|\\\\.)*?\\]\\=\\]",
            next  : "start"
        }, {
            token : "comment",
            merge : true,
            regex : '.+'
        } ],
        "qcomment2": [ {
            token : "comment",
            regex : "(?:[^\\\\]|\\\\.)*?\\]\\={2}\\]",
            next  : "start"
        }, {
            token : "comment",
            merge : true,
            regex : '.+'
        } ],
        "qcomment3": [ {
            token : "comment",
            regex : "(?:[^\\\\]|\\\\.)*?\\]\\={3}\\]",
            next  : "start"
        }, {
            token : "comment",
            merge : true,
            regex : '.+'
        } ],
        "qcomment4": [ {
            token : "comment",
            regex : "(?:[^\\\\]|\\\\.)*?\\]\\={4}\\]",
            next  : "start"
        }, {
            token : "comment",
            merge : true,
            regex : '.+'
        } ],
        "qcomment5": [ {
            token : function(value){ 
                // very hackish, mutates the qcomment5 field on the fly.
                var pattern = /\](\=+)\]/, rule = this.rules.qcomment5[0], match;
                rule.next = "start";
                if ((match = pattern.exec(value)) != null && (match = match[1]) != undefined){
                    var found = match.length, expected;
                    if ((expected = comment_stack.pop()) != found){
                        comment_stack.push(expected);
                        rule.next = "qcomment5";
                    }
                }
                
                return "comment";
            },
            regex : "(?:[^\\\\]|\\\\.)*?\\]\\={5}\\=*\\]",
            next  : "start"
        }, {
            token : "comment",
            merge : true,
            regex : '.+'
        } ],
        
        "qstring": [ {
            token : "string",
            regex : "(?:[^\\\\]|\\\\.)*?\\]\\]",
            next  : "start"
        }, {
            token : "string",
            merge : true,
            regex : '.+'
        } ],
        "qstring1": [ {
            token : "string",
            regex : "(?:[^\\\\]|\\\\.)*?\\]\\=\\]",
            next  : "start"
        }, {
            token : "string",
            merge : true,
            regex : '.+'
        } ],
        "qstring2": [ {
            token : "string",
            regex : "(?:[^\\\\]|\\\\.)*?\\]\\={2}\\]",
            next  : "start"
        }, {
            token : "string",
            merge : true,
            regex : '.+'
        } ],
        "qstring3": [ {
            token : "string",
            regex : "(?:[^\\\\]|\\\\.)*?\\]\\={3}\\]",
            next  : "start"
        }, {
            token : "string",
            merge : true,
            regex : '.+'
        } ],
        "qstring4": [ {
            token : "string",
            regex : "(?:[^\\\\]|\\\\.)*?\\]\\={4}\\]",
            next  : "start"
        }, {
            token : "string",
            merge : true,
            regex : '.+'
        } ],
        "qstring5": [ {
            token : function(value){ 
                // very hackish, mutates the qstring5 field on the fly.
                var pattern = /\](\=+)\]/, rule = this.rules.qstring5[0], match;
                rule.next = "start";
                if ((match = pattern.exec(value)) != null && (match = match[1]) != undefined){
                    var found = match.length, expected;
                    if ((expected = comment_stack.pop()) != found){
                        comment_stack.push(expected);
                        rule.next = "qstring5";
                    }
                }
                
                return "string";
            },
            regex : "(?:[^\\\\]|\\\\.)*?\\]\\={5}\\=*\\]",
            next  : "start"
        }, {
            token : "string",
            merge : true,
            regex : '.+'
        } ]
        
    };

}

oop.inherits(LuaHighlightRules, TextHighlightRules);

exports.LuaHighlightRules = LuaHighlightRules;
});
