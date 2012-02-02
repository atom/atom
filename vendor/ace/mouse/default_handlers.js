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
 *      Mike de Boer <mike AT ajax DOT org>
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

var event = require("../lib/event");
var dom = require("../lib/dom");
var BrowserFocus = require("../lib/browser_focus").BrowserFocus;

var STATE_UNKNOWN = 0;
var STATE_SELECT = 1;
var STATE_DRAG = 2;

var DRAG_OFFSET = 5; // pixels

function DefaultHandlers(editor) {
    this.editor = editor;
    this.$clickSelection = null;
    this.browserFocus = new BrowserFocus();

    editor.setDefaultHandler("mousedown", this.onMouseDown.bind(this));
    editor.setDefaultHandler("dblclick", this.onDoubleClick.bind(this));
    editor.setDefaultHandler("tripleclick", this.onTripleClick.bind(this));
    editor.setDefaultHandler("quadclick", this.onQuadClick.bind(this));
    editor.setDefaultHandler("mousewheel", this.onScroll.bind(this));
}

(function() {
    
    this.onMouseDown = function(ev) {
        var inSelection = ev.inSelection();
        var pageX = ev.pageX;
        var pageY = ev.pageY;
        var pos = ev.getDocumentPosition();
        var editor = this.editor;
        var _self = this;
        
        var selectionRange = editor.getSelectionRange();
        var selectionEmpty = selectionRange.isEmpty();
        var state = STATE_UNKNOWN;
        
        // if this click caused the editor to be focused should not clear the
        // selection
        if (
            inSelection && (
                !this.browserFocus.isFocused()
                || new Date().getTime() - this.browserFocus.lastFocus < 20
                || !editor.isFocused()
            )
        ) {
            editor.focus();
            return;
        }

        var button = ev.getButton();
        if (button !== 0) {
            if (selectionEmpty) {
                editor.moveCursorToPosition(pos);
            }
            if (button == 2) {
                editor.textInput.onContextMenu({x: ev.clientX, y: ev.clientY}, selectionEmpty);
                event.capture(editor.container, function(){}, editor.textInput.onContextMenuClose);
            }
            return;
        }

        if (!inSelection) {
            // Directly pick STATE_SELECT, since the user is not clicking inside
            // a selection.
            onStartSelect(pos);
        }

        var mousePageX = pageX, mousePageY = pageY;
        var mousedownTime = (new Date()).getTime();
        var dragCursor, dragRange, dragSelectionMarker;

        var onMouseSelection = function(e) {
            mousePageX = event.getDocumentX(e);
            mousePageY = event.getDocumentY(e);
        };

        var onMouseSelectionEnd = function(e) {
            clearInterval(timerId);
            if (state == STATE_UNKNOWN)
                onStartSelect(pos);
            else if (state == STATE_DRAG)
                onMouseDragSelectionEnd(e);

            _self.$clickSelection = null;
            state = STATE_UNKNOWN;
        };

        var onMouseDragSelectionEnd = function(e) {
            dom.removeCssClass(editor.container, "ace_dragging");
            editor.session.removeMarker(dragSelectionMarker);

            if (!editor.$mouseHandler.$clickSelection) {
                if (!dragCursor) {
                    editor.moveCursorToPosition(pos);
                    editor.selection.clearSelection(pos.row, pos.column);
                }
            }

            if (!dragCursor)
                return;

            if (dragRange.contains(dragCursor.row, dragCursor.column)) {
                dragCursor = null;
                return;
            }

            editor.clearSelection();
            if (e && (e.ctrlKey || e.altKey)) {
                var session = editor.session;
                var newRange = session.insert(dragCursor, session.getTextRange(dragRange));
            } else {
                var newRange = editor.moveText(dragRange, dragCursor);
            }
            if (!newRange) {
                dragCursor = null;
                return;
            }

            editor.selection.setSelectionRange(newRange);
        };

        var onSelectionInterval = function() {
            if (state == STATE_UNKNOWN) {
                var distance = calcDistance(pageX, pageY, mousePageX, mousePageY);
                var time = (new Date()).getTime();

                if (distance > DRAG_OFFSET) {
                    state = STATE_SELECT;
                    var cursor = editor.renderer.screenToTextCoordinates(mousePageX, mousePageY);
                    cursor.row = Math.max(0, Math.min(cursor.row, editor.session.getLength()-1));
                    onStartSelect(cursor);
                }
                else if ((time - mousedownTime) > editor.getDragDelay()) {
                    state = STATE_DRAG;
                    dragRange = editor.getSelectionRange();
                    var style = editor.getSelectionStyle();
                    dragSelectionMarker = editor.session.addMarker(dragRange, "ace_selection", style);
                    editor.clearSelection();
                    dom.addCssClass(editor.container, "ace_dragging");
                }

            }

            if (state == STATE_DRAG)
                onDragSelectionInterval();
            else if (state == STATE_SELECT)
                onUpdateSelectionInterval();
        };

        function onStartSelect(pos) {
            if (ev.getShiftKey()) {
                editor.selection.selectToPosition(pos);
            }
            else {
                if (!_self.$clickSelection) {
                    editor.moveCursorToPosition(pos);
                    editor.selection.clearSelection(pos.row, pos.column);
                }
            }
            state = STATE_SELECT;
        }

        var onUpdateSelectionInterval = function() {
            var anchor;
            var cursor = editor.renderer.screenToTextCoordinates(mousePageX, mousePageY);
            cursor.row = Math.max(0, Math.min(cursor.row, editor.session.getLength()-1));

            if (_self.$clickSelection) {
                if (_self.$clickSelection.contains(cursor.row, cursor.column)) {
                    editor.selection.setSelectionRange(_self.$clickSelection);
                }
                else {
                    if (_self.$clickSelection.compare(cursor.row, cursor.column) == -1) {
                        anchor = _self.$clickSelection.end;
                    }
                    else {
                        anchor = _self.$clickSelection.start;
                    }
                    editor.selection.setSelectionAnchor(anchor.row, anchor.column);
                    editor.selection.selectToPosition(cursor);
                }
            }
            else {
                editor.selection.selectToPosition(cursor);
            }

            editor.renderer.scrollCursorIntoView();
        };

        var onDragSelectionInterval = function() {
            dragCursor = editor.renderer.screenToTextCoordinates(mousePageX, mousePageY);
            dragCursor.row = Math.max(0, Math.min(dragCursor.row, editor.session.getLength() - 1));

            editor.moveCursorToPosition(dragCursor);
        };

        event.capture(editor.container, onMouseSelection, onMouseSelectionEnd);
        var timerId = setInterval(onSelectionInterval, 20);

        return ev.preventDefault();
    };
    
    this.onDoubleClick = function(ev) {
        var pos = ev.getDocumentPosition();
        var editor = this.editor;
        
        editor.moveCursorToPosition(pos);
        editor.selection.selectWord();
        this.$clickSelection = editor.getSelectionRange();
    };
    
    this.onTripleClick = function(ev) {
        var pos = ev.getDocumentPosition();
        var editor = this.editor;
        
        editor.moveCursorToPosition(pos);
        editor.selection.selectLine();
        this.$clickSelection = editor.getSelectionRange();
    };
    
    this.onQuadClick = function(ev) {
        var editor = this.editor;
        
        editor.selectAll();
        this.$clickSelection = editor.getSelectionRange();
    };
    
    this.onScroll = function(ev) {
        var editor = this.editor;
        
        editor.renderer.scrollBy(ev.wheelX * ev.speed, ev.wheelY * ev.speed);
        if (editor.renderer.isScrollableBy(ev.wheelX * ev.speed, ev.wheelY * ev.speed))
            return ev.preventDefault();
    };
    
}).call(DefaultHandlers.prototype);

exports.DefaultHandlers = DefaultHandlers;

function calcDistance(ax, ay, bx, by) {
    return Math.sqrt(Math.pow(bx - ax, 2) + Math.pow(by - ay, 2));
}

});
