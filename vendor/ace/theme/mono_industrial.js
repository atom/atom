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
exports.cssClass = "ace-mono-industrial";
exports.cssText = "\
.ace-mono-industrial .ace_editor {\
  border: 2px solid rgb(159, 159, 159);\
}\
\
.ace-mono-industrial .ace_editor.ace_focus {\
  border: 2px solid #327fbd;\
}\
\
.ace-mono-industrial .ace_gutter {\
  background: #e8e8e8;\
  color: #333;\
}\
\
.ace-mono-industrial .ace_print_margin {\
  width: 1px;\
  background: #e8e8e8;\
}\
\
.ace-mono-industrial .ace_scroller {\
  background-color: #222C28;\
}\
\
.ace-mono-industrial .ace_text-layer {\
  cursor: text;\
  color: #FFFFFF;\
}\
\
.ace-mono-industrial .ace_cursor {\
  border-left: 2px solid #FFFFFF;\
}\
\
.ace-mono-industrial .ace_cursor.ace_overwrite {\
  border-left: 0px;\
  border-bottom: 1px solid #FFFFFF;\
}\
 \
.ace-mono-industrial .ace_marker-layer .ace_selection {\
  background: rgba(145, 153, 148, 0.40);\
}\
\
.ace-mono-industrial .ace_marker-layer .ace_step {\
  background: rgb(198, 219, 174);\
}\
\
.ace-mono-industrial .ace_marker-layer .ace_bracket {\
  margin: -1px 0 0 -1px;\
  border: 1px solid rgba(102, 108, 104, 0.50);\
}\
\
.ace-mono-industrial .ace_marker-layer .ace_active_line {\
  background: rgba(12, 13, 12, 0.25);\
}\
\
.ace-mono-industrial .ace_marker-layer .ace_selected_word {\
  border: 1px solid rgba(145, 153, 148, 0.40);\
}\
       \
.ace-mono-industrial .ace_invisible {\
  color: rgba(102, 108, 104, 0.50);\
}\
\
.ace-mono-industrial .ace_keyword {\
  color:#A39E64;\
}\
\
.ace-mono-industrial .ace_keyword.ace_operator {\
  color:#A8B3AB;\
}\
\
.ace-mono-industrial .ace_constant {\
  color:#E98800;\
}\
\
.ace-mono-industrial .ace_constant.ace_numeric {\
  color:#E98800;\
}\
\
.ace-mono-industrial .ace_invalid {\
  color:#FFFFFF;\
background-color:rgba(153, 0, 0, 0.68);\
}\
\
.ace-mono-industrial .ace_fold {\
    background-color: #A8B3AB;\
    border-color: #FFFFFF;\
}\
\
.ace-mono-industrial .ace_support.ace_function {\
  color:#588E60;\
}\
\
.ace-mono-industrial .ace_comment {\
  color:#666C68;\
background-color:#151C19;\
}\
\
.ace-mono-industrial .ace_variable.ace_language {\
  color:#648BD2;\
}\
\
.ace-mono-industrial .ace_entity.ace_other.ace_attribute-name {\
  color:#909993;\
}\
\
.ace-mono-industrial .ace_entity.ace_name {\
  color:#5778B6;\
}\
\
.ace-mono-industrial .ace_entity.ace_name.ace_function {\
  color:#A8B3AB;\
}\
\
.ace-mono-industrial .ace_markup.ace_underline {\
    text-decoration:underline;\
}";

var dom = require("../lib/dom");
dom.importCssString(exports.cssText, exports.cssClass);
});
