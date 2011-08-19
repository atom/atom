(function() {
  var JavaScriptMode, bindKey, canon, editor, filename, save, saveAs;
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
  canon = require('pilot/canon');
  bindKey = function(name, shortcut, callback) {
    return canon.addCommand({
      name: name,
      exec: callback,
      bindKey: {
        win: null,
        mac: shortcut,
        sender: 'editor'
      }
    });
  };
  bindKey('open', 'Command-O', function(env, args, request) {
    var code, file;
    if (file = Chrome.openPanel()) {
      filename = file;
      App.window.title = _.last(filename.split('/'));
      code = File.read(file);
      return env.editor.getSession().setValue(code);
    }
  });
  bindKey('saveAs', 'Command-Shift-S', function(env, args, request) {
    return saveAs();
  });
  bindKey('save', 'Command-S', function(env, args, request) {
    if (filename) {
      return save();
    } else {
      return saveAs();
    }
  });
  bindKey('copy', 'Command-C', function(env, args, request) {
    var text;
    text = editor.getSession().doc.getTextRange(editor.getSelectionRange());
    return Chrome.writeToPasteboard(text);
  });
  bindKey('eval', 'Command-R', function(env, args, request) {
    return eval(env.editor.getSession().getValue());
  });
  bindKey('togglecomment', 'Command-/', function(env) {
    return env.editor.toggleCommentLines();
  });
  bindKey('fullscreen', 'Command-Return', function(env) {
    return OSX.NSLog('coming soon');
  });
}).call(this);
