const TextBuffer = require('text-buffer');
const { Point, Range } = TextBuffer;
const { File, Directory } = require('pathwatcher');
const { Emitter, Disposable, CompositeDisposable } = require('event-kit');
const BufferedNodeProcess = require('../src/buffered-node-process');
const BufferedProcess = require('../src/buffered-process');
const GitRepository = require('../src/git-repository');
const Notification = require('../src/notification');
const { watchPath } = require('../src/path-watcher');

const atomExport = {
  BufferedNodeProcess,
  BufferedProcess,
  GitRepository,
  Notification,
  TextBuffer,
  Point,
  Range,
  File,
  Directory,
  Emitter,
  Disposable,
  CompositeDisposable,
  watchPath
};

// Shell integration is required by both Squirrel and Settings-View
if (process.platform === 'win32') {
  Object.defineProperty(atomExport, 'WinShell', {
    enumerable: true,
    get() {
      return require('../src/main-process/win-shell');
    }
  });
}

// The following classes can't be used from a Task handler and should therefore
// only be exported when not running as a child node process
if (process.type === 'renderer') {
  atomExport.Task = require('../src/task');
  atomExport.TextEditor = require('../src/text-editor');
}

module.exports = atomExport;
