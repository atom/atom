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

var event = require("pilot/event");

var RenderLoop = function(onRender) {
    this.onRender = onRender;
    this.pending = false;
    this.changes = 0;
};

(function() {

    this.schedule = function(change) {
        //this.onRender(change);
        //return;
        this.changes = this.changes | change;
        if (!this.pending) {
            this.pending = true;
            var _self = this;
            this.setTimeoutZero(function() {
                _self.pending = false;
                var changes = _self.changes;
                _self.changes = 0;
                _self.onRender(changes);
            })
        }
    };

    this.setTimeoutZero = window.requestAnimationFrame ||
         window.webkitRequestAnimationFrame ||
         window.mozRequestAnimationFrame ||
         window.oRequestAnimationFrame ||
         window.msRequestAnimationFrame;

    if (this.setTimeoutZero) {

        this.setTimeoutZero = this.setTimeoutZero.bind(window)
    } else if (window.postMessage) {

        this.messageName = "zero-timeout-message";

        this.setTimeoutZero = function(callback) {
            if (!this.attached) {
                var _self = this;
                event.addListener(window, "message", function(e) {
                    if (_self.callback && e.data == _self.messageName) {
                        event.stopPropagation(e);
                        _self.callback();
                    }
                });
                this.attached = true;
            }
            this.callback = callback;
            window.postMessage(this.messageName, "*");
        }

    } else {

        this.setTimeoutZero = function(callback) {
            setTimeout(callback, 0);
        }
    }

}).call(RenderLoop.prototype);

exports.RenderLoop = RenderLoop;
});
