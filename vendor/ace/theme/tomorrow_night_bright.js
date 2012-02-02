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

exports.isDark = true;
exports.cssClass = "ace-tomorrow-night-bright";
exports.cssText = "\
.ace-tomorrow-night-bright .ace_editor {\
  border: 2px solid rgb(159, 159, 159);\
}\
\
.ace-tomorrow-night-bright .ace_editor.ace_focus {\
  border: 2px solid #327fbd;\
}\
\
.ace-tomorrow-night-bright .ace_gutter {\
  background: #e8e8e8;\
  color: #333;\
}\
\
.ace-tomorrow-night-bright .ace_print_margin {\
  width: 1px;\
  background: #e8e8e8;\
}\
\
.ace-tomorrow-night-bright .ace_scroller {\
  background-color: #000000;\
}\
\
.ace-tomorrow-night-bright .ace_text-layer {\
  cursor: text;\
  color: #DEDEDE;\
}\
\
.ace-tomorrow-night-bright .ace_cursor {\
  border-left: 2px solid #9F9F9F;\
}\
\
.ace-tomorrow-night-bright .ace_cursor.ace_overwrite {\
  border-left: 0px;\
  border-bottom: 1px solid #9F9F9F;\
}\
 \
.ace-tomorrow-night-bright .ace_marker-layer .ace_selection {\
  background: #424242;\
}\
\
.ace-tomorrow-night-bright .ace_marker-layer .ace_step {\
  background: rgb(198, 219, 174);\
}\
\
.ace-tomorrow-night-bright .ace_marker-layer .ace_bracket {\
  margin: -1px 0 0 -1px;\
  border: 1px solid #343434;\
}\
\
.ace-tomorrow-night-bright .ace_marker-layer .ace_active_line {\
  background: #2A2A2A;\
}\
\
.ace-tomorrow-night-bright .ace_marker-layer .ace_selected_word {\
  border: 1px solid #424242;\
}\
       \
.ace-tomorrow-night-bright .ace_invisible {\
  color: #343434;\
}\
\
.ace-tomorrow-night-bright .ace_keyword {\
  color:#C397D8;\
}\
\
.ace-tomorrow-night-bright .ace_keyword.ace_operator {\
  color:#70C0B1;\
}\
\
.ace-tomorrow-night-bright .ace_constant.ace_language {\
  color:#E78C45;\
}\
\
.ace-tomorrow-night-bright .ace_constant.ace_numeric {\
  color:#E78C45;\
}\
\
.ace-tomorrow-night-bright .ace_invalid {\
  color:#CED2CF;\
background-color:#DF5F5F;\
}\
\
.ace-tomorrow-night-bright .ace_invalid.ace_deprecated {\
  color:#CED2CF;\
background-color:#B798BF;\
}\
\
.ace-tomorrow-night-bright .ace_fold {\
    background-color: #7AA6DA;\
    border-color: #DEDEDE;\
}\
\
.ace-tomorrow-night-bright .ace_support.ace_function {\
  color:#7AA6DA;\
}\
\
.ace-tomorrow-night-bright .ace_string {\
  color:#B9CA4A;\
}\
\
.ace-tomorrow-night-bright .ace_string.ace_regexp {\
  color:#D54E53;\
}\
\
.ace-tomorrow-night-bright .ace_comment {\
  color:#969896;\
}\
\
.ace-tomorrow-night-bright .ace_variable {\
  color:#D54E53;\
}\
\
.ace-tomorrow-night-bright .ace_meta.ace_tag {\
  color:#D54E53;\
}\
\
.ace-tomorrow-night-bright .ace_entity.ace_other.ace_attribute-name {\
  color:#D54E53;\
}\
\
.ace-tomorrow-night-bright .ace_entity.ace_name.ace_function {\
  color:#7AA6DA;\
}\
\
.ace-tomorrow-night-bright .ace_markup.ace_underline {\
    text-decoration:underline;\
}\
\
.ace-tomorrow-night-bright .ace_markup.ace_heading {\
  color:#B9CA4A;\
}";

var dom = require("../lib/dom");
dom.importCssString(exports.cssText, exports.cssClass);
});
