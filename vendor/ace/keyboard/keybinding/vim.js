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
 * The Original Code is Mozilla Skywriter.
 *
 * The Initial Developer of the Original Code is
 * Mozilla.
 * Portions created by the Initial Developer are Copyright (C) 2009
 * the Initial Developer. All Rights Reserved.
 *
 * Contributor(s):
 *   Julian Viereck (julian.viereck@gmail.com)
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

var StateHandler = require("../state_handler").StateHandler;
var matchCharacterOnly =  require("../state_handler").matchCharacterOnly;

var vimcommand = function(key, exec, then) {
    return {
        regex:  [ "([0-9]*)", key ],
        exec:   exec,
        params: [
            {
                name:     "times",
                match:    1,
                type:     "number",
                defaultValue:     1
            }
        ],
        then:   then
    }
}

var vimStates = {
    start: [
        {
            key:    "i",
            then:   "insertMode"
        },
        {
            key:    "d",
            then:   "deleteMode"
        },
        {
            key:    "a",
            exec:   "gotoright",
            then:   "insertMode"
        },
        {
            key:    "shift-i",
            exec:   "gotolinestart",
            then:   "insertMode"
        },
        {
            key:    "shift-a",
            exec:   "gotolineend",
            then:   "insertMode"
        },
        {
            key:    "shift-c",
            exec:   "removetolineend",
            then:   "insertMode"
        },
        {
            key:    "shift-r",
            exec:   "overwrite",
            then:   "replaceMode"
        },
        vimcommand("(k|up)", "golineup"),
        vimcommand("(j|down)", "golinedown"),
        vimcommand("(l|right)", "gotoright"),
        vimcommand("(h|left)", "gotoleft"),
        {
            key:    "shift-g",
            exec:   "gotoend"
        },
        vimcommand("b", "gotowordleft"),
        vimcommand("e", "gotowordright"),
        vimcommand("x", "del"),
        vimcommand("shift-x", "backspace"),
        vimcommand("shift-d", "removetolineend"),
        vimcommand("u", "undo"), // [count] on this may/may not work, depending on browser implementation...
        {
            comment:    "Catch some keyboard input to stop it here",
            match:      matchCharacterOnly
        }
    ],
    insertMode: [
        {
            key:      "esc",
            then:     "start"
        }
    ],
    replaceMode: [
        {
            key:      "esc",
            exec:     "overwrite",
            then:     "start"
        }
    ],
    deleteMode: [
        {
            key:      "d",
            exec:     "removeline",
            then:     "start"
        }
    ]
};

exports.Vim = new StateHandler(vimStates);

});
