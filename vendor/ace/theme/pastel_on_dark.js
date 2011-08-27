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
 *      André Fiedler <fiedler dot andre a t gmail dot com>
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

    var dom = require("pilot/dom");

    var cssText = ".ace-pastel-on-dark .ace_editor {\
  border: 2px solid rgb(159, 159, 159);\
}\
\
.ace-pastel-on-dark .ace_editor.ace_focus {\
  border: 2px solid #327fbd;\
}\
\
.ace-pastel-on-dark .ace_gutter {\
  width: 50px;\
  background: #e8e8e8;\
  color: #333;\
  overflow : hidden;\
}\
\
.ace-pastel-on-dark .ace_gutter-layer {\
  width: 100%;\
  text-align: right;\
}\
\
.ace-pastel-on-dark .ace_gutter-layer .ace_gutter-cell {\
  padding-right: 6px;\
}\
\
.ace-pastel-on-dark .ace_print_margin {\
  width: 1px;\
  background: #e8e8e8;\
}\
\
.ace-pastel-on-dark .ace_scroller {\
  background-color: #2c2828;\
}\
\
.ace-pastel-on-dark .ace_text-layer {\
  cursor: text;\
  color: #8f938f;\
}\
\
.ace-pastel-on-dark .ace_cursor {\
  border-left: 2px solid #A7A7A7;\
}\
\
.ace-pastel-on-dark .ace_cursor.ace_overwrite {\
  border-left: 0px;\
  border-bottom: 1px solid #A7A7A7;\
}\
 \
.ace-pastel-on-dark .ace_marker-layer .ace_selection {\
  background: rgba(221, 240, 255, 0.20);\
}\
\
.ace-pastel-on-dark .ace_marker-layer .ace_step {\
  background: rgb(198, 219, 174);\
}\
\
.ace-pastel-on-dark .ace_marker-layer .ace_bracket {\
  margin: -1px 0 0 -1px;\
  border: 1px solid rgba(255, 255, 255, 0.25);\
}\
\
.ace-pastel-on-dark .ace_marker-layer .ace_active_line {\
  background: rgba(255, 255, 255, 0.031);\
}\
\
       \
.ace-pastel-on-dark .ace_invisible {\
  color: rgba(255, 255, 255, 0.25);\
}\
\
.ace-pastel-on-dark .ace_keyword {\
  color:#757ad8;\
}\
\
.ace-pastel-on-dark .ace_keyword.ace_operator {\
  color:#797878;\
}\
\
.ace-pastel-on-dark .ace_constant {\
  color:#4fb7c5;\
}\
\
.ace-pastel-on-dark .ace_constant.ace_language {\
  \
}\
\
.ace-pastel-on-dark .ace_constant.ace_library {\
  \
}\
\
.ace-pastel-on-dark .ace_constant.ace_numeric {\
  \
}\
\
.ace-pastel-on-dark .ace_invalid {\
  \
}\
\
.ace-pastel-on-dark .ace_invalid.ace_illegal {\
  color:#F8F8F8;\
background-color:rgba(86, 45, 86, 0.75);\
}\
\
.ace-pastel-on-dark .ace_invalid.ace_deprecated {\
  text-decoration:underline;\
font-style:italic;\
color:#D2A8A1;\
}\
\
.ace-pastel-on-dark .ace_support {\
  color:#9a9a9a;\
}\
\
.ace-pastel-on-dark .ace_support.ace_function {\
  color:#aeb2f8;\
}\
\
.ace-pastel-on-dark .ace_function.ace_buildin {\
  \
}\
\
.ace-pastel-on-dark .ace_string {\
  color:#66a968;\
}\
\
.ace-pastel-on-dark .ace_string.ace_regexp {\
  color:#E9C062;\
}\
\
.ace-pastel-on-dark .ace_comment {\
  color:#656865;\
}\
\
.ace-pastel-on-dark .ace_comment.ace_doc {\
  color:A6C6FF;\
}\
\
.ace-pastel-on-dark .ace_comment.ace_doc.ace_tag {\
  color:A6C6FF;\
}\
\
.ace-pastel-on-dark .ace_variable {\
  color:#bebf55;\
}\
\
.ace-pastel-on-dark .ace_variable.ace_language {\
  color:#bebf55;\
}\
\
.ace-pastel-on-dark .ace_markup.ace_underline {\
    text-decoration:underline;\
}\
\
.ace-pastel-on-dark .ace_xml_pe {\
  color:#494949;\
}";

    // import CSS once
    dom.importCssString(cssText);

    exports.cssClass = "ace-pastel-on-dark";
});
