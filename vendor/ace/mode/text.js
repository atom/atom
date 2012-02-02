/* vim:ts=4:sts=4:sw=4:
 * ***** BEGIN LICENSE BLOCK *****
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
 *      Mihai Sucan <mihai DOT sucan AT gmail DOT com>
 *      Chris Spencer <chris.ag.spencer AT googlemail DOT com>
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

var Tokenizer = require("../tokenizer").Tokenizer;
var TextHighlightRules = require("./text_highlight_rules").TextHighlightRules;
var Behaviour = require("./behaviour").Behaviour;
var unicode = require("../unicode");

var Mode = function() {
    this.$tokenizer = new Tokenizer(new TextHighlightRules().getRules());
    this.$behaviour = new Behaviour();
};

(function() {

    this.tokenRe = new RegExp("^["
        + unicode.packages.L
        + unicode.packages.Mn + unicode.packages.Mc
        + unicode.packages.Nd
        + unicode.packages.Pc + "\\$_]+", "g"
    );
    
    this.nonTokenRe = new RegExp("^(?:[^"
        + unicode.packages.L
        + unicode.packages.Mn + unicode.packages.Mc
        + unicode.packages.Nd
        + unicode.packages.Pc + "\\$_]|\s])+", "g"
    );

    this.getTokenizer = function() {
        return this.$tokenizer;
    };

    this.toggleCommentLines = function(state, doc, startRow, endRow) {
    };

    this.getNextLineIndent = function(state, line, tab) {
        return "";
    };

    this.checkOutdent = function(state, line, input) {
        return false;
    };

    this.autoOutdent = function(state, doc, row) {
    };

    this.$getIndent = function(line) {
        var match = line.match(/^(\s+)/);
        if (match) {
            return match[1];
        }

        return "";
    };
    
    this.createWorker = function(session) {
        return null;
    };

    this.highlightSelection = function(editor) {
        var session = editor.session;
        if (!session.$selectionOccurrences)
            session.$selectionOccurrences = [];

        if (session.$selectionOccurrences.length)
            this.clearSelectionHighlight(editor);

        var selection = editor.getSelectionRange();
        if (selection.isEmpty() || selection.isMultiLine())
            return;

        var startOuter = selection.start.column - 1;
        var endOuter = selection.end.column + 1;
        var line = session.getLine(selection.start.row);
        var lineCols = line.length;
        var needle = line.substring(Math.max(startOuter, 0),
                                    Math.min(endOuter, lineCols));

        // Make sure the outer characters are not part of the word.
        if ((startOuter >= 0 && /^[\w\d]/.test(needle)) ||
            (endOuter <= lineCols && /[\w\d]$/.test(needle)))
            return;

        needle = line.substring(selection.start.column, selection.end.column);
        if (!/^[\w\d]+$/.test(needle))
            return;

        var cursor = editor.getCursorPosition();

        var newOptions = {
            wrap: true,
            wholeWord: true,
            caseSensitive: true,
            needle: needle
        };

        var currentOptions = editor.$search.getOptions();
        editor.$search.set(newOptions);

        var ranges = editor.$search.findAll(session);
        ranges.forEach(function(range) {
            if (!range.contains(cursor.row, cursor.column)) {
                var marker = session.addMarker(range, "ace_selected_word", "text");
                session.$selectionOccurrences.push(marker);
            }
        });

        editor.$search.set(currentOptions);
    };

    this.clearSelectionHighlight = function(editor) {
        if (!editor.session.$selectionOccurrences)
            return;

        editor.session.$selectionOccurrences.forEach(function(marker) {
            editor.session.removeMarker(marker);
        });

        editor.session.$selectionOccurrences = [];
    };
    
    this.createModeDelegates = function (mapping) {
        if (!this.$embeds) {
            return;
        }
        this.$modes = {};
        for (var i = 0; i < this.$embeds.length; i++) {
            if (mapping[this.$embeds[i]]) {
                this.$modes[this.$embeds[i]] = new mapping[this.$embeds[i]]();
            }
        }
        
        var delegations = ['toggleCommentLines', 'getNextLineIndent', 'checkOutdent', 'autoOutdent', 'transformAction'];

        for (var i = 0; i < delegations.length; i++) {
            (function(scope) {
              var functionName = delegations[i];
              var defaultHandler = scope[functionName];
              scope[delegations[i]] = function() {
                  return this.$delegator(functionName, arguments, defaultHandler);
              }
            } (this));
        }
    }
    
    this.$delegator = function(method, args, defaultHandler) {
        var state = args[0];
        
        for (var i = 0; i < this.$embeds.length; i++) {
            if (!this.$modes[this.$embeds[i]]) continue;
            
            var split = state.split(this.$embeds[i]);
            if (!split[0] && split[1]) {
                args[0] = split[1];
                var mode = this.$modes[this.$embeds[i]];
                return mode[method].apply(mode, args);
            }
        }
        var ret = defaultHandler.apply(this, args);
        return defaultHandler ? ret : undefined;
    };
    
    this.transformAction = function(state, action, editor, session, param) {
        if (this.$behaviour) {
            var behaviours = this.$behaviour.getBehaviours();
            for (var key in behaviours) {
                if (behaviours[key][action]) {
                    var ret = behaviours[key][action].apply(this, arguments);
                    if (ret) {
                        return ret;
                    }
                }
            }
        }
    }
    
}).call(Mode.prototype);

exports.Mode = Mode;
});
