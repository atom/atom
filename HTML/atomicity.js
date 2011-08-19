(function() {
  var JavaScriptMode, bindKey, canon, editor;
  console.log = OSX.NSLog;
  editor = ace.edit("editor");
  editor.setTheme("ace/theme/twilight");
  JavaScriptMode = require("ace/mode/javascript").Mode;
  editor.getSession().setMode(new JavaScriptMode());
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
    var file, panel;
    panel = OSX.NSOpenPanel.openPanel;
    if (panel.runModal !== OSX.NSFileHandlingPanelOKButton) {
      return null;
    }
    if (file = panel.filenames.lastObject) {
      return env.editor.getSession().setValue(OSX.NSString.stringWithContentsOfFile(file));
    }
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
