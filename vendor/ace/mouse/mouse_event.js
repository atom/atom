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

/**
 * Custom Ace mouse event
 */
var MouseEvent = exports.MouseEvent = function(domEvent, editor) {
    this.domEvent = domEvent;
    this.editor = editor;
    
    this.pageX = event.getDocumentX(domEvent);
    this.pageY = event.getDocumentY(domEvent);
    
    this.clientX = domEvent.clientX;
    this.clientY = domEvent.clientY;

    this.$pos = null;
    this.$inSelection = null;
    
    this.propagationStopped = false;
    this.defaultPrevented = false;
};

(function() {  
    
    this.stopPropagation = function() {
        event.stopPropagation(this.domEvent);
        this.propagationStopped = true;
    };
    
    this.preventDefault = function() {
        event.preventDefault(this.domEvent);
        this.defaultPrevented = true;
    };
    
    this.stop = function() {
        this.stopPropagation();
        this.preventDefault();
    };

    /**
     * Get the document position below the mouse cursor
     * 
     * @return {Object} 'row' and 'column' of the document position
     */
    this.getDocumentPosition = function() {
        if (this.$pos)
            return this.$pos;
            
        var pageX = event.getDocumentX(this.domEvent);
        var pageY = event.getDocumentY(this.domEvent);
        this.$pos = this.editor.renderer.screenToTextCoordinates(pageX, pageY);
        this.$pos.row = Math.max(0, Math.min(this.$pos.row, this.editor.session.getLength()-1));
        return this.$pos;
    };
    
    /**
     * Check if the mouse cursor is inside of the text selection
     * 
     * @return {Boolean} whether the mouse cursor is inside of the selection
     */
    this.inSelection = function() {
        if (this.$inSelection !== null)
            return this.$inSelection;
            
        var editor = this.editor;
        
        if (editor.getReadOnly()) {
            this.$inSelection = false;
        }
        else {
            var selectionRange = editor.getSelectionRange();
            if (selectionRange.isEmpty())
                this.$inSelection = false;
            else {
                var pos = this.getDocumentPosition();
                this.$inSelection = selectionRange.contains(pos.row, pos.column);
            }
        }
        return this.$inSelection;
    };
    
    /**
     * Get the clicked mouse button
     * 
     * @return {Number} 0 for left button, 1 for middle button, 2 for right button
     */
    this.getButton = function() {
        return event.getButton(this.domEvent);
    };
    
    /**
     * @return {Boolean} whether the shift key was pressed when the event was emitted
     */
    this.getShiftKey = function() {
        return this.domEvent.shiftKey;
    };
    
    this.getAccelKey = function() {
        return this.domEvent.ctrlKey || this.domEvent.metaKey ;
    };
    
}).call(MouseEvent.prototype);

});
