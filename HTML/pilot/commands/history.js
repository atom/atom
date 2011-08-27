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
 * The Original Code is Skywriter.
 *
 * The Initial Developer of the Original Code is
 * Mozilla.
 * Portions created by the Initial Developer are Copyright (C) 2009
 * the Initial Developer. All Rights Reserved.
 *
 * Contributor(s):
 *   Skywriter Team (skywriter@mozilla.com)
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


/**
 * CLI 'up'
 * Decrement the 'current entry' pointer
 */
var historyPreviousCommandSpec = {
    name: "historyPrevious",
    predicates: { isCommandLine: true, isKeyUp: true },
    key: "up",
    exec: function(args, request) {
        if (pointer > 0) {
            pointer--;
        }

        var display = history.requests[pointer].typed;
        env.commandLine.setInput(display);
    }
};

/**
 * CLI 'down'
 * Increment the 'current entry' pointer
 */
var historyNextCommandSpec = {
    name: "historyNext",
    predicates: { isCommandLine: true, isKeyUp: true },
    key: "down",
    exec: function(args, request) {
        if (pointer < history.requests.length) {
            pointer++;
        }

        var display = (pointer === history.requests.length)
            ? ''
            : history.requests[pointer].typed;

        env.commandLine.setInput(display);
    }
};

/**
 * 'history' command
 */
var historyCommandSpec = {
    name: "history",
    description: "Show history of the commands",
    exec: function(args, request) {
        var output = [];
        output.push('<table>');
        var count = 1;

        history.requests.forEach(function(request) {
            output.push('<tr>');
            output.push('<th>' + count + '</th>');
            output.push('<td>' + request.typed + '</td>');
            output.push('</tr>');
            count++;
        });
        output.push('</table>');

        request.done(output.join(''));
    }
};

/**
 * The pointer to the command that we show on up|down
 */
var pointer = 0;

/**
 * Reset the pointer to the latest command execution
 */
exports.addedRequestOutput = function() {
    pointer = history.requests.length;
};


});
