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

    exports.cssText = ".ace-tomorrow .ace_editor {\
  border: 2px solid rgb(159, 159, 159);\
}\
\
.ace-tomorrow .ace_editor.ace_focus {\
  border: 2px solid #327fbd;\
}\
\
.ace-tomorrow .ace_gutter {\
  width: 50px;\
  background: #e8e8e8;\
  color: #333;\
  overflow : hidden;\
}\
\
.ace-tomorrow .ace_gutter-layer {\
  width: 100%;\
  text-align: right;\
}\
\
.ace-tomorrow .ace_gutter-layer .ace_gutter-cell {\
  padding-right: 6px;\
}\
\
.ace-tomorrow .ace_print_margin {\
  width: 1px;\
  background: #e8e8e8;\
}\
\
.ace-tomorrow .ace_scroller {\
  background-color: #FFFFFF;\
}\
\
.ace-tomorrow .ace_text-layer {\
  cursor: text;\
  color: #4D4D4C;\
}\
\
.ace-tomorrow .ace_cursor {\
  border-left: 2px solid #AEAFAD;\
}\
\
.ace-tomorrow .ace_cursor.ace_overwrite {\
  border-left: 0px;\
  border-bottom: 1px solid #AEAFAD;\
}\
 \
.ace-tomorrow .ace_marker-layer .ace_selection {\
  background: #D6D6D6;\
}\
\
.ace-tomorrow .ace_marker-layer .ace_step {\
  background: rgb(198, 219, 174);\
}\
\
.ace-tomorrow .ace_marker-layer .ace_bracket {\
  margin: -1px 0 0 -1px;\
  border: 1px solid #D1D1D1;\
}\
\
.ace-tomorrow .ace_marker-layer .ace_active_line {\
  background: #EFEFEF;\
}\
\
       \
.ace-tomorrow .ace_invisible {\
  color: #D1D1D1;\
}\
\
.ace-tomorrow .ace_keyword {\
  color:#8959A8;\
}\
\
.ace-tomorrow .ace_keyword.ace_operator {\
  color:#3E999F;\
}\
\
.ace-tomorrow .ace_constant {\
  \
}\
\
.ace-tomorrow .ace_constant.ace_language {\
  color:#F5871F;\
}\
\
.ace-tomorrow .ace_constant.ace_library {\
  \
}\
\
.ace-tomorrow .ace_constant.ace_numeric {\
  color:#F5871F;\
}\
\
.ace-tomorrow .ace_invalid {\
  color:#FFFFFF;\
background-color:#C82829;\
}\
\
.ace-tomorrow .ace_invalid.ace_illegal {\
  \
}\
\
.ace-tomorrow .ace_invalid.ace_deprecated {\
  color:#FFFFFF;\
background-color:#8959A8;\
}\
\
.ace-tomorrow .ace_support {\
  \
}\
\
.ace-tomorrow .ace_support.ace_function {\
  color:#4271AE;\
}\
\
.ace-tomorrow .ace_function.ace_buildin {\
  \
}\
\
.ace-tomorrow .ace_string {\
  color:#718C00;\
}\
\
.ace-tomorrow .ace_string.ace_regexp {\
  color:#C82829;\
}\
\
.ace-tomorrow .ace_comment {\
  color:#8E908C;\
}\
\
.ace-tomorrow .ace_comment.ace_doc {\
  \
}\
\
.ace-tomorrow .ace_comment.ace_doc.ace_tag {\
  \
}\
\
.ace-tomorrow .ace_variable {\
  color:#C82829;\
}\
\
.ace-tomorrow .ace_variable.ace_language {\
  \
}\
\
.ace-tomorrow .ace_xml_pe {\
  \
}\
\
.ace-tomorrow .ace_meta {\
  \
}\
\
.ace-tomorrow .ace_meta.ace_tag {\
  color:#C82829;\
}\
\
.ace-tomorrow .ace_meta.ace_tag.ace_input {\
  \
}\
\
.ace-tomorrow .ace_entity.ace_other.ace_attribute-name {\
  color:#C82829;\
}\
\
.ace-tomorrow .ace_entity.ace_name {\
  \
}\
\
.ace-tomorrow .ace_entity.ace_name.ace_function {\
  color:#4271AE;\
}\
\
.ace-tomorrow .ace_markup.ace_underline {\
    text-decoration:underline;\
}\
\
.ace-tomorrow .ace_markup.ace_heading {\
  color:#718C00;\
}\
\
.ace-tomorrow .ace_markup.ace_heading.ace_1 {\
  \
}\
\
.ace-tomorrow .ace_markup.ace_heading.ace_2 {\
  \
}\
\
.ace-tomorrow .ace_markup.ace_heading.ace_3 {\
  \
}\
\
.ace-tomorrow .ace_markup.ace_heading.ace_4 {\
  \
}\
\
.ace-tomorrow .ace_markup.ace_heading.ace_5 {\
  \
}\
\
.ace-tomorrow .ace_markup.ace_heading.ace_6 {\
  \
}\
\
.ace-tomorrow .ace_markup.ace_list {\
  \
}\
\
.ace-tomorrow .ace_collab.ace_user1 {\
     \
}";

    exports.cssClass = "ace-tomorrow";
});