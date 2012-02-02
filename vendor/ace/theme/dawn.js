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

exports.isDark = false;
exports.cssClass = "ace-dawn";
exports.cssText = "\
.ace-dawn .ace_editor {\
  border: 2px solid rgb(159, 159, 159);\
}\
\
.ace-dawn .ace_editor.ace_focus {\
  border: 2px solid #327fbd;\
}\
\
.ace-dawn .ace_gutter {\
  background: #e8e8e8;\
  color: #333;\
}\
\
.ace-dawn .ace_print_margin {\
  width: 1px;\
  background: #e8e8e8;\
}\
\
.ace-dawn .ace_scroller {\
  background-color: #F9F9F9;\
}\
\
.ace-dawn .ace_text-layer {\
  cursor: text;\
  color: #080808;\
}\
\
.ace-dawn .ace_cursor {\
  border-left: 2px solid #000000;\
}\
\
.ace-dawn .ace_cursor.ace_overwrite {\
  border-left: 0px;\
  border-bottom: 1px solid #000000;\
}\
 \
.ace-dawn .ace_marker-layer .ace_selection {\
  background: rgba(39, 95, 255, 0.30);\
}\
\
.ace-dawn .ace_marker-layer .ace_step {\
  background: rgb(198, 219, 174);\
}\
\
.ace-dawn .ace_marker-layer .ace_bracket {\
  margin: -1px 0 0 -1px;\
  border: 1px solid rgba(75, 75, 126, 0.50);\
}\
\
.ace-dawn .ace_marker-layer .ace_active_line {\
  background: rgba(36, 99, 180, 0.12);\
}\
\
.ace-dawn .ace_marker-layer .ace_selected_word {\
  border: 1px solid rgba(39, 95, 255, 0.30);\
}\
       \
.ace-dawn .ace_invisible {\
  color: rgba(75, 75, 126, 0.50);\
}\
\
.ace-dawn .ace_keyword {\
  color:#794938;\
}\
\
.ace-dawn .ace_constant {\
  color:#811F24;\
}\
\
.ace-dawn .ace_invalid.ace_illegal {\
  text-decoration:underline;\
font-style:italic;\
color:#F8F8F8;\
background-color:#B52A1D;\
}\
\
.ace-dawn .ace_invalid.ace_deprecated {\
  text-decoration:underline;\
font-style:italic;\
color:#B52A1D;\
}\
\
.ace-dawn .ace_support {\
  color:#691C97;\
}\
\
.ace-dawn .ace_fold {\
    background-color: #794938;\
    border-color: #080808;\
}\
\
.ace-dawn .ace_support.ace_function {\
  color:#693A17;\
}\
\
.ace-dawn .ace_string {\
  color:#0B6125;\
}\
\
.ace-dawn .ace_string.ace_regexp {\
  color:#CF5628;\
}\
\
.ace-dawn .ace_comment {\
  font-style:italic;\
color:#5A525F;\
}\
\
.ace-dawn .ace_variable {\
  color:#234A97;\
}\
\
.ace-dawn .ace_markup.ace_underline {\
    text-decoration:underline;\
}\
\
.ace-dawn .ace_markup.ace_heading {\
  color:#19356D;\
}\
\
.ace-dawn .ace_markup.ace_list {\
  color:#693A17;\
}";

var dom = require("../lib/dom");
dom.importCssString(exports.cssText, exports.cssClass);
});
