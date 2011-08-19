(function() {
  var JavaScriptMode, editor, filename, save, saveAs;
  console.log = OSX.NSLog;
  editor = ace.edit("editor");
  editor.setTheme("ace/theme/twilight");
  JavaScriptMode = require("ace/mode/javascript").Mode;
  editor.getSession().setMode(new JavaScriptMode);
  editor.getSession().setUseSoftTabs(true);
  editor.getSession().setTabSize(2);
  filename = null;
  save = function() {
    return File.write(filename, editor.getSession().getValue());
  };
  saveAs = function() {
    var file;
    if (file = Chrome.savePanel()) {
      filename = file;
      App.window.title = _.last(filename.split('/'));
      return save();
    }
  };
  Chrome.bindKey('open', 'Command-O', function(env, args, request) {
    var code, file;
    if (file = Chrome.openPanel()) {
      filename = file;
      App.window.title = _.last(filename.split('/'));
      code = File.read(file);
      return env.editor.getSession().setValue(code);
    }
  });
  Chrome.bindKey('saveAs', 'Command-Shift-S', function(env, args, request) {
    return saveAs();
  });
  Chrome.bindKey('save', 'Command-S', function(env, args, request) {
    if (filename) {
      return save();
    } else {
      return saveAs();
    }
  });
  Chrome.bindKey('copy', 'Command-C', function(env, args, request) {
    var text;
    text = editor.getSession().doc.getTextRange(editor.getSelectionRange());
    return Chrome.writeToPasteboard(text);
  });
  Chrome.bindKey('eval', 'Command-R', function(env, args, request) {
    return eval(env.editor.getSession().getValue());
  });
  Chrome.bindKey('togglecomment', 'Command-/', function(env) {
    return env.editor.toggleCommentLines();
  });
  Chrome.bindKey('fullscreen', 'Command-Return', function(env) {
    return OSX.NSLog('coming soon');
  });
}).call(this);
