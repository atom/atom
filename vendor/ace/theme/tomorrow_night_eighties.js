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
exports.cssClass = "ace-tomorrow-night-eighties";
exports.cssText = "\
.ace-tomorrow-night-eighties .ace_editor {\
  border: 2px solid rgb(159, 159, 159);\
}\
\
.ace-tomorrow-night-eighties .ace_editor.ace_focus {\
  border: 2px solid #327fbd;\
}\
\
.ace-tomorrow-night-eighties .ace_gutter {\
  background: #e8e8e8;\
  color: #333;\
}\
\
.ace-tomorrow-night-eighties .ace_print_margin {\
  width: 1px;\
  background: #e8e8e8;\
}\
\
.ace-tomorrow-night-eighties .ace_scroller {\
  background-color: #2D2D2D;\
}\
\
.ace-tomorrow-night-eighties .ace_text-layer {\
  cursor: text;\
  color: #CCCCCC;\
}\
\
.ace-tomorrow-night-eighties .ace_cursor {\
  border-left: 2px solid #CCCCCC;\
}\
\
.ace-tomorrow-night-eighties .ace_cursor.ace_overwrite {\
  border-left: 0px;\
  border-bottom: 1px solid #CCCCCC;\
}\
 \
.ace-tomorrow-night-eighties .ace_marker-layer .ace_selection {\
  background: #515151;\
}\
\
.ace-tomorrow-night-eighties .ace_marker-layer .ace_step {\
  background: rgb(198, 219, 174);\
}\
\
.ace-tomorrow-night-eighties .ace_marker-layer .ace_bracket {\
  margin: -1px 0 0 -1px;\
  border: 1px solid #6A6A6A;\
}\
\
.ace-tomorrow-night-eighties .ace_marker-layer .ace_active_line {\
  background: #393939;\
}\
\
.ace-tomorrow-night-eighties .ace_marker-layer .ace_selected_word {\
  border: 1px solid #515151;\
}\
       \
.ace-tomorrow-night-eighties .ace_invisible {\
  color: #6A6A6A;\
}\
\
.ace-tomorrow-night-eighties .ace_keyword {\
  color:#CC99CC;\
}\
\
.ace-tomorrow-night-eighties .ace_keyword.ace_operator {\
  color:#66CCCC;\
}\
\
.ace-tomorrow-night-eighties .ace_constant.ace_language {\
  color:#F99157;\
}\
\
.ace-tomorrow-night-eighties .ace_constant.ace_numeric {\
  color:#F99157;\
}\
\
.ace-tomorrow-night-eighties .ace_invalid {\
  color:#CDCDCD;\
background-color:#F2777A;\
}\
\
.ace-tomorrow-night-eighties .ace_invalid.ace_deprecated {\
  color:#CDCDCD;\
background-color:#CC99CC;\
}\
\
.ace-tomorrow-night-eighties .ace_fold {\
    background-color: #6699CC;\
    border-color: #CCCCCC;\
}\
\
.ace-tomorrow-night-eighties .ace_support.ace_function {\
  color:#6699CC;\
}\
\
.ace-tomorrow-night-eighties .ace_string {\
  color:#99CC99;\
}\
\
.ace-tomorrow-night-eighties .ace_comment {\
  color:#999999;\
}\
\
.ace-tomorrow-night-eighties .ace_variable {\
  color:#F2777A;\
}\
\
.ace-tomorrow-night-eighties .ace_meta.ace_tag {\
  color:#F2777A;\
}\
\
.ace-tomorrow-night-eighties .ace_entity.ace_other.ace_attribute-name {\
  color:#F2777A;\
}\
\
.ace-tomorrow-night-eighties .ace_entity.ace_name.ace_function {\
  color:#6699CC;\
}\
\
.ace-tomorrow-night-eighties .ace_markup.ace_underline {\
    text-decoration:underline;\
}\
\
.ace-tomorrow-night-eighties .ace_markup.ace_heading {\
  color:#99CC99;\
}";

var dom = require("../lib/dom");
dom.importCssString(exports.cssText, exports.cssClass);
});
