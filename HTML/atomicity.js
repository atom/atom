window.onload = function() {
  var editor = ace.edit("editor");
  editor.setTheme("ace/theme/twilight");
  var JavaScriptMode = require("ace/mode/javascript").Mode;
  editor.getSession().setMode(new JavaScriptMode());
};
