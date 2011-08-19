(function() {
  var CoffeeMode, JavaScriptMode, editor, filename, open, save, saveAs, setMode;
  console.log = OSX.NSLog;
  editor = ace.edit("editor");
  editor.setTheme("ace/theme/twilight");
  JavaScriptMode = require("ace/mode/javascript").Mode;
  CoffeeMode = require("ace/mode/coffee").Mode;
  editor.getSession().setMode(new JavaScriptMode);
  editor.getSession().setUseSoftTabs(true);
  editor.getSession().setTabSize(2);
  filename = null;
  save = function() {
    File.write(filename, editor.getSession().getValue());
    return setMode();
  };
  open = function() {
    App.window.title = _.last(filename.split('/'));
    editor.getSession().setValue(File.read(filename));
    return setMode();
  };
  setMode = function() {
    if (/\.js$/.test(filename)) {
      return editor.getSession().setMode(new JavaScriptMode);
    } else if (/\.coffee$/.test(filename)) {
      return editor.getSession().setMode(new CoffeeMode);
    }
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
    var file;
    if (file = Chrome.openPanel()) {
      filename = file;
      return open();
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
  Chrome.bindKey('moveforward', 'Alt-F', function(env) {
    return env.editor.navigateWordRight();
  });
  Chrome.bindKey('moveback', 'Alt-B', function(env) {
    return env.editor.navigateWordLeft();
  });
  Chrome.bindKey('deleteword', 'Alt-D', function(env) {
    return env.editor.removeWordRight();
  });
  Chrome.bindKey('selectwordright', 'Alt-B', function(env) {
    return env.editor.navigateWordLeft();
  });
  Chrome.bindKey('fullscreen', 'Command-Return', function(env) {
    return OSX.NSLog('coming soon');
  });
  Chrome.bindKey('consolelog', 'Ctrl-L', function(env) {
    env.editor.insert('console.log ""');
    return env.editor.navigateLeft();
  });
}).call(this);
