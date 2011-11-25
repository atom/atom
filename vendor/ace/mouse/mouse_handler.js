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

var event = require("../lib/event");
var DefaultHandlers = require("./default_handlers").DefaultHandlers;
var MouseEvent = require("./mouse_event").MouseEvent;

var MouseHandler = function(editor) {
    this.editor = editor;
    
    this.defaultHandlers = new DefaultHandlers(editor);
    event.addListener(editor.container, "mousedown", function(e) {
        editor.focus();
        return event.preventDefault(e);
    });
    event.addListener(editor.container, "selectstart", function(e) {
        return event.preventDefault(e);
    });

    var mouseTarget = editor.renderer.getMouseEventTarget();
    event.addListener(mouseTarget, "mousedown", this.onMouseDown.bind(this));
    event.addListener(mouseTarget, "click", this.onMouseClick.bind(this));
    event.addListener(mouseTarget, "mousemove", this.onMouseMove.bind(this));
    event.addMultiMouseDownListener(mouseTarget, 0, 2, 500, this.onMouseDoubleClick.bind(this));
    event.addMultiMouseDownListener(mouseTarget, 0, 3, 600, this.onMouseTripleClick.bind(this));
    event.addMultiMouseDownListener(mouseTarget, 0, 4, 600, this.onMouseQuadClick.bind(this));
    event.addMouseWheelListener(editor.container, this.onMouseWheel.bind(this));
};

(function() {

    this.$scrollSpeed = 1;
    this.setScrollSpeed = function(speed) {
        this.$scrollSpeed = speed;
    };

    this.getScrollSpeed = function() {
        return this.$scrollSpeed;
    };

    this.onMouseDown = function(e) {
        this.editor._dispatchEvent("mousedown", new MouseEvent(e, this.editor));
    };

    this.onMouseClick = function(e) {
        this.editor._dispatchEvent("click", new MouseEvent(e, this.editor));
    };
    
    this.onMouseMove = function(e) {
        // optimization, because mousemove doesn't have a default handler.
        var listeners = this.editor._eventRegistry && this.editor._eventRegistry["mousemove"];
        if (!listeners || !listeners.length)
            return;

        this.editor._dispatchEvent("mousemove", new MouseEvent(e, this.editor));
    };

    this.onMouseDoubleClick = function(e) {
        this.editor._dispatchEvent("dblclick", new MouseEvent(e, this.editor));
    };

    this.onMouseTripleClick = function(e) {
        this.editor._dispatchEvent("tripleclick", new MouseEvent(e, this.editor));
    };

    this.onMouseQuadClick = function(e) {
        this.editor._dispatchEvent("quadclick", new MouseEvent(e, this.editor));
    };

    this.onMouseWheel = function(e) {
        var mouseEvent = new MouseEvent(e, this.editor);
        mouseEvent.speed = this.$scrollSpeed * 2;
        mouseEvent.wheelX = e.wheelX;
        mouseEvent.wheelY = e.wheelY;
        
        this.editor._dispatchEvent("mousewheel", mouseEvent);
    };

}).call(MouseHandler.prototype);

exports.MouseHandler = MouseHandler;
});
