(function() {
  var Chrome, File, canon;
  canon = require('pilot/canon');
  Chrome = {
    openPanel: function() {
      var panel;
      panel = OSX.NSOpenPanel.openPanel;
      if (panel.runModal !== OSX.NSFileHandlingPanelOKButton) {
        return null;
      }
      return panel.filenames.lastObject;
    },
    savePanel: function() {
      var panel;
      panel = OSX.NSSavePanel.savePane;
      if (panel.runModal !== OSX.NSFileHandlingPanelOKButton) {
        return null;
      }
      return panel.filenames.lastObject;
    },
    writeToPasteboard: function(text) {
      var pb;
      pb = OSX.NSPasteboard.generalPasteboard;
      pb.declareTypes_owner([OSX.NSStringPboardType], null);
      return pb.setString_forType(text, OSX.NSStringPboardType);
    },
    bindKey: function(name, shortcut, callback) {
      return canon.addCommand({
        name: name,
        exec: callback,
        bindKey: {
          win: null,
          mac: shortcut,
          sender: 'editor'
        }
      });
    }
  };
  File = {
    read: function(path) {
      return OSX.NSString.stringWithContentsOfFile(path);
    },
    write: function(path, contents) {
      var str;
      str = OSX.NSString.stringWithString(contents);
      return str.writeToFile_atomically(path, true);
    }
  };
  this.Chrome = Chrome;
  this.File = File;
}).call(this);
