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
exports.cssClass = "ace-kr-theme";
exports.cssText = "\
.ace-kr-theme .ace_editor {\
  border: 2px solid rgb(159, 159, 159);\
}\
\
.ace-kr-theme .ace_editor.ace_focus {\
  border: 2px solid #327fbd;\
}\
\
.ace-kr-theme .ace_gutter {\
  background: #e8e8e8;\
  color: #333;\
}\
\
.ace-kr-theme .ace_print_margin {\
  width: 1px;\
  background: #e8e8e8;\
}\
\
.ace-kr-theme .ace_scroller {\
  background-color: #0B0A09;\
}\
\
.ace-kr-theme .ace_text-layer {\
  cursor: text;\
  color: #FCFFE0;\
}\
\
.ace-kr-theme .ace_cursor {\
  border-left: 2px solid #FF9900;\
}\
\
.ace-kr-theme .ace_cursor.ace_overwrite {\
  border-left: 0px;\
  border-bottom: 1px solid #FF9900;\
}\
 \
.ace-kr-theme .ace_marker-layer .ace_selection {\
  background: rgba(170, 0, 255, 0.45);\
}\
\
.ace-kr-theme .ace_marker-layer .ace_step {\
  background: rgb(198, 219, 174);\
}\
\
.ace-kr-theme .ace_marker-layer .ace_bracket {\
  margin: -1px 0 0 -1px;\
  border: 1px solid rgba(255, 177, 111, 0.32);\
}\
\
.ace-kr-theme .ace_marker-layer .ace_active_line {\
  background: #38403D;\
}\
\
.ace-kr-theme .ace_marker-layer .ace_selected_word {\
  border: 1px solid rgba(170, 0, 255, 0.45);\
}\
       \
.ace-kr-theme .ace_invisible {\
  color: rgba(255, 177, 111, 0.32);\
}\
\
.ace-kr-theme .ace_keyword {\
  color:#949C8B;\
}\
\
.ace-kr-theme .ace_constant {\
  color:rgba(210, 117, 24, 0.76);\
}\
\
.ace-kr-theme .ace_invalid {\
  color:#F8F8F8;\
background-color:#A41300;\
}\
\
.ace-kr-theme .ace_support {\
  color:#9FC28A;\
}\
\
.ace-kr-theme .ace_fold {\
    background-color: #949C8B;\
    border-color: #FCFFE0;\
}\
\
.ace-kr-theme .ace_support.ace_function {\
  color:#85873A;\
}\
\
.ace-kr-theme .ace_string.ace_regexp {\
  color:rgba(125, 255, 192, 0.65);\
}\
\
.ace-kr-theme .ace_comment {\
  font-style:italic;\
color:#706D5B;\
}\
\
.ace-kr-theme .ace_variable {\
  color:#D1A796;\
}\
\
.ace-kr-theme .ace_variable.ace_language {\
  color:#FF80E1;\
}\
\
.ace-kr-theme .ace_meta.ace_tag {\
  color:#BABD9C;\
}\
\
.ace-kr-theme .ace_markup.ace_underline {\
    text-decoration:underline;\
}\
\
.ace-kr-theme .ace_markup.ace_list {\
  background-color:#0F0040;\
}";

var dom = require("../lib/dom");
dom.importCssString(exports.cssText, exports.cssClass);
});
