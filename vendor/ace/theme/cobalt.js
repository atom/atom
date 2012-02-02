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
exports.cssClass = "ace-cobalt";
exports.cssText = "\
.ace-cobalt .ace_editor {\
  border: 2px solid rgb(159, 159, 159);\
}\
\
.ace-cobalt .ace_editor.ace_focus {\
  border: 2px solid #327fbd;\
}\
\
.ace-cobalt .ace_gutter {\
  background: #e8e8e8;\
  color: #333;\
}\
\
.ace-cobalt .ace_print_margin {\
  width: 1px;\
  background: #e8e8e8;\
}\
\
.ace-cobalt .ace_scroller {\
  background-color: #002240;\
}\
\
.ace-cobalt .ace_text-layer {\
  cursor: text;\
  color: #FFFFFF;\
}\
\
.ace-cobalt .ace_cursor {\
  border-left: 2px solid #FFFFFF;\
}\
\
.ace-cobalt .ace_cursor.ace_overwrite {\
  border-left: 0px;\
  border-bottom: 1px solid #FFFFFF;\
}\
 \
.ace-cobalt .ace_marker-layer .ace_selection {\
  background: rgba(179, 101, 57, 0.75);\
}\
\
.ace-cobalt .ace_marker-layer .ace_step {\
  background: rgb(198, 219, 174);\
}\
\
.ace-cobalt .ace_marker-layer .ace_bracket {\
  margin: -1px 0 0 -1px;\
  border: 1px solid rgba(255, 255, 255, 0.15);\
}\
\
.ace-cobalt .ace_marker-layer .ace_active_line {\
  background: rgba(0, 0, 0, 0.35);\
}\
\
.ace-cobalt .ace_marker-layer .ace_selected_word {\
  border: 1px solid rgba(179, 101, 57, 0.75);\
}\
       \
.ace-cobalt .ace_invisible {\
  color: rgba(255, 255, 255, 0.15);\
}\
\
.ace-cobalt .ace_keyword {\
  color:#FF9D00;\
}\
\
.ace-cobalt .ace_constant {\
  color:#FF628C;\
}\
\
.ace-cobalt .ace_invalid {\
  color:#F8F8F8;\
background-color:#800F00;\
}\
\
.ace-cobalt .ace_support {\
  color:#80FFBB;\
}\
\
.ace-cobalt .ace_fold {\
    background-color: #FF9D00;\
    border-color: #FFFFFF;\
}\
\
.ace-cobalt .ace_support.ace_function {\
  color:#FFB054;\
}\
\
.ace-cobalt .ace_string.ace_regexp {\
  color:#80FFC2;\
}\
\
.ace-cobalt .ace_comment {\
  font-style:italic;\
color:#0088FF;\
}\
\
.ace-cobalt .ace_variable {\
  color:#CCCCCC;\
}\
\
.ace-cobalt .ace_variable.ace_language {\
  color:#FF80E1;\
}\
\
.ace-cobalt .ace_meta.ace_tag {\
  color:#9EFFFF;\
}\
\
.ace-cobalt .ace_markup.ace_underline {\
    text-decoration:underline;\
}\
\
.ace-cobalt .ace_markup.ace_heading {\
  color:#C8E4FD;\
background-color:#001221;\
}\
\
.ace-cobalt .ace_markup.ace_list {\
  background-color:#130D26;\
}";

var dom = require("../lib/dom");
dom.importCssString(exports.cssText, exports.cssClass);
});
