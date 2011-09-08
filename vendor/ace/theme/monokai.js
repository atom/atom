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

    var dom = require("pilot/dom");

    var cssText = ".ace-monokai .ace_editor {\
  border: 2px solid rgb(159, 159, 159);\
}\
\
.ace-monokai .ace_editor.ace_focus {\
  border: 2px solid #327fbd;\
}\
\
.ace-monokai .ace_gutter {\
  width: 50px;\
  background: #e8e8e8;\
  color: #333;\
  overflow : hidden;\
}\
\
.ace-monokai .ace_gutter-layer {\
  width: 100%;\
  text-align: right;\
}\
\
.ace-monokai .ace_gutter-layer .ace_gutter-cell {\
  padding-right: 6px;\
}\
\
.ace-monokai .ace_print_margin {\
  width: 1px;\
  background: #e8e8e8;\
}\
\
.ace-monokai .ace_scroller {\
  background-color: #272822;\
}\
\
.ace-monokai .ace_text-layer {\
  cursor: text;\
  color: #F8F8F2;\
}\
\
.ace-monokai .ace_cursor {\
  border-left: 2px solid #F8F8F0;\
}\
\
.ace-monokai .ace_cursor.ace_overwrite {\
  border-left: 0px;\
  border-bottom: 1px solid #F8F8F0;\
}\
 \
.ace-monokai .ace_marker-layer .ace_selection {\
  background: #49483E;\
}\
\
.ace-monokai .ace_marker-layer .ace_step {\
  background: rgb(198, 219, 174);\
}\
\
.ace-monokai .ace_marker-layer .ace_bracket {\
  margin: -1px 0 0 -1px;\
  border: 1px solid #49483E;\
}\
\
.ace-monokai .ace_marker-layer .ace_active_line {\
  background: #49483E;\
}\
\
       \
.ace-monokai .ace_invisible {\
  color: #49483E;\
}\
\
.ace-monokai .ace_keyword {\
  color:#F92672;\
}\
\
.ace-monokai .ace_keyword.ace_operator {\
  \
}\
\
.ace-monokai .ace_constant {\
  \
}\
\
.ace-monokai .ace_constant.ace_language {\
  color:#AE81FF;\
}\
\
.ace-monokai .ace_constant.ace_library {\
  \
}\
\
.ace-monokai .ace_constant.ace_numeric {\
  color:#AE81FF;\
}\
\
.ace-monokai .ace_invalid {\
  color:#F8F8F0;\
background-color:#F92672;\
}\
\
.ace-monokai .ace_invalid.ace_illegal {\
  \
}\
\
.ace-monokai .ace_invalid.ace_deprecated {\
  color:#F8F8F0;\
background-color:#AE81FF;\
}\
\
.ace-monokai .ace_support {\
  \
}\
\
.ace-monokai .ace_support.ace_function {\
  color:#66D9EF;\
}\
\
.ace-monokai .ace_function.ace_buildin {\
  \
}\
\
.ace-monokai .ace_string {\
  color:#E6DB74;\
}\
\
.ace-monokai .ace_string.ace_regexp {\
  \
}\
\
.ace-monokai .ace_comment {\
  color:#75715E;\
}\
\
.ace-monokai .ace_comment.ace_doc {\
  \
}\
\
.ace-monokai .ace_comment.ace_doc.ace_tag {\
  \
}\
\
.ace-monokai .ace_variable {\
  \
}\
\
.ace-monokai .ace_variable.ace_language {\
  \
}\
\
.ace-monokai .ace_xml_pe {\
  \
}\
\
.ace-monokai .ace_meta {\
  \
}\
\
.ace-monokai .ace_meta.ace_tag {\
  \
}\
\
.ace-monokai .ace_meta.ace_tag.ace_input {\
  \
}\
\
.ace-monokai .ace_entity.ace_other.ace_attribute-name {\
  color:#A6E22E;\
}\
\
.ace-monokai .ace_entity.ace_name {\
  \
}\
\
.ace-monokai .ace_entity.ace_name.ace_function {\
  color:#A6E22E;\
}\
\
.ace-monokai .ace_markup.ace_underline {\
    text-decoration:underline;\
}\
\
.ace-monokai .ace_markup.ace_heading {\
  \
}\
\
.ace-monokai .ace_markup.ace_heading.ace_1 {\
  \
}\
\
.ace-monokai .ace_markup.ace_heading.ace_2 {\
  \
}\
\
.ace-monokai .ace_markup.ace_heading.ace_3 {\
  \
}\
\
.ace-monokai .ace_markup.ace_heading.ace_4 {\
  \
}\
\
.ace-monokai .ace_markup.ace_heading.ace_5 {\
  \
}\
\
.ace-monokai .ace_markup.ace_heading.ace_6 {\
  \
}\
\
.ace-monokai .ace_markup.ace_list {\
  \
}\
\
.ace-monokai .ace_collab.ace_user1 {\
     \
}";

    // import CSS once
    dom.importCssString(cssText);

    exports.cssClass = "ace-monokai";
});