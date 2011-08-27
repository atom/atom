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
 *      Michael Schwartz <mr.pants AT gmail DOT com>
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

    var cssText = ".ace-merbivore .ace_editor {\
  border: 2px solid rgb(159, 159, 159);\
}\
\
.ace-merbivore .ace_editor.ace_focus {\
  border: 2px solid #327fbd;\
}\
\
.ace-merbivore .ace_gutter {\
  width: 50px;\
  background: #e8e8e8;\
  color: #333;\
  overflow : hidden;\
}\
\
.ace-merbivore .ace_gutter-layer {\
  width: 100%;\
  text-align: right;\
}\
\
.ace-merbivore .ace_gutter-layer .ace_gutter-cell {\
  padding-right: 6px;\
}\
\
.ace-merbivore .ace_print_margin {\
  width: 1px;\
  background: #e8e8e8;\
}\
\
.ace-merbivore .ace_scroller {\
  background-color: #161616;\
}\
\
.ace-merbivore .ace_text-layer {\
  cursor: text;\
  color: #E6E1DC;\
}\
\
.ace-merbivore .ace_cursor {\
  border-left: 2px solid #FFFFFF;\
}\
\
.ace-merbivore .ace_cursor.ace_overwrite {\
  border-left: 0px;\
  border-bottom: 1px solid #FFFFFF;\
}\
 \
.ace-merbivore .ace_marker-layer .ace_selection {\
  background: #454545;\
}\
\
.ace-merbivore .ace_marker-layer .ace_step {\
  background: rgb(198, 219, 174);\
}\
\
.ace-merbivore .ace_marker-layer .ace_bracket {\
  margin: -1px 0 0 -1px;\
  border: 1px solid #FCE94F;\
}\
\
.ace-merbivore .ace_marker-layer .ace_active_line {\
  background: #333435;\
}\
\
       \
.ace-merbivore .ace_invisible {\
  color: #404040;\
}\
\
.ace-merbivore .ace_keyword {\
  color:#FC6F09;\
}\
\
.ace-merbivore .ace_keyword.ace_operator {\
  \
}\
\
.ace-merbivore .ace_constant {\
  color:#1EDAFB;\
}\
\
.ace-merbivore .ace_constant.ace_language {\
  color:#FDC251;\
}\
\
.ace-merbivore .ace_constant.ace_library {\
  color:#8DFF0A;\
}\
\
.ace-merbivore .ace_constant.ace_numeric {\
  color:#58C554;\
}\
\
.ace-merbivore .ace_invalid {\
  color:#FFFFFF;\
background-color:#990000;\
}\
\
.ace-merbivore .ace_invalid.ace_illegal {\
  \
}\
\
.ace-merbivore .ace_invalid.ace_deprecated {\
  color:#FFFFFF;\
  background-color:#990000;\
}\
\
.ace-merbivore .ace_support {\
  \
}\
\
.ace-merbivore .ace_support.ace_function {\
  color:#FC6F09;\
}\
\
.ace-merbivore .ace_function.ace_buildin {\
  \
}\
\
.ace-merbivore .ace_string {\
  color:#8DFF0A;\
}\
\
.ace-merbivore .ace_string.ace_regexp {\
  \
}\
\
.ace-merbivore .ace_comment {\
  color:#AD2EA4;\
}\
\
.ace-merbivore .ace_comment.ace_doc {\
  \
}\
\
.ace-merbivore .ace_comment.ace_doc.ace_tag {\
  \
}\
\
.ace-merbivore .ace_variable {\
  \
}\
\
.ace-merbivore .ace_variable.ace_language {\
  \
}\
\
.ace-merbivore .ace_xml_pe {\
  \
}\
\
.ace-merbivore .ace_meta {\
  \
}\
\
.ace-merbivore .ace_meta.ace_tag {\
  color:#FC6F09;\
}\
\
.ace-merbivore .ace_meta.ace_tag.ace_input {\
  \
}\
\
.ace-merbivore .ace_entity.ace_other.ace_attribute-name {\
  color:#FFFF89;\
}\
\
.ace-merbivore .ace_markup.ace_underline {\
    text-decoration:underline;\
}\
\
.ace-merbivore .ace_markup.ace_heading {\
  \
}\
\
.ace-merbivore .ace_markup.ace_heading.ace_1 {\
  \
}\
\
.ace-merbivore .ace_markup.ace_heading.ace_2 {\
  \
}\
\
.ace-merbivore .ace_markup.ace_heading.ace_3 {\
  \
}\
\
.ace-merbivore .ace_markup.ace_heading.ace_4 {\
  \
}\
\
.ace-merbivore .ace_markup.ace_heading.ace_5 {\
  \
}\
\
.ace-merbivore .ace_markup.ace_heading.ace_6 {\
  \
}\
\
.ace-merbivore .ace_markup.ace_list {\
  \
}\
\
.ace-merbivore .ace_collab.ace_user1 {\
     \
}";

    // import CSS once
    dom.importCssString(cssText);

    exports.cssClass = "ace-merbivore";
});