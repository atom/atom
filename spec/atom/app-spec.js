(function() {
  var App, fs;
  App = require('app');
  fs = require('fs');
  describe("App", function() {
    var app;
    app = null;
    beforeEach(function() {
      return app = new App();
    });
    afterEach(function() {
      var window, _i, _len, _ref;
      _ref = app.windows();
      for (_i = 0, _len = _ref.length; _i < _len; _i++) {
        window = _ref[_i];
        window.close();
      }
      return waitsFor(function() {
        return app.windows().length === 0;
      });
    });
    return describe("open", function() {
      describe("when opening a filePath", function() {
        return it("loads a buffer with filePath contents and displays it in a new window", function() {
          var filePath, newWindow;
          filePath = require.resolve('fixtures/sample.txt');
          expect(app.windows().length).toBe(0);
          app.open(filePath);
          expect(app.windows().length).toBe(1);
          newWindow = app.windows()[0];
          expect(newWindow.rootView.editor.buffer.url).toEqual(filePath);
          return expect(newWindow.rootView.editor.buffer.getText()).toEqual(fs.read(filePath));
        });
      });
      return describe("when opening a dirPath", function() {
        return it("loads an empty buffer", function() {
          var dirPath, newWindow;
          dirPath = require.resolve('fixtures');
          expect(app.windows().length).toBe(0);
          app.open(dirPath);
          expect(app.windows().length).toBe(1);
          newWindow = app.windows()[0];
          expect(newWindow.rootView.editor.buffer.url).toBeUndefined;
          return expect(newWindow.rootView.editor.buffer.getText()).toBe("");
        });
      });
    });
  });
}).call(this);
