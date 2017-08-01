/** @babel */

import TextBuffer, {Point, Range} from 'text-buffer'
import {File, Directory} from 'pathwatcher'
import {Emitter, Disposable, CompositeDisposable} from 'event-kit'
import BufferedNodeProcess from '../src/buffered-node-process'
import BufferedProcess from '../src/buffered-process'
import GitRepository from '../src/git-repository'
import Notification from '../src/notification'
import {watchPath} from '../src/path-watcher'

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
}

// Shell integration is required by both Squirrel and Settings-View
if (process.platform === 'win32') {
  Object.defineProperty(atomExport, 'WinShell', {
    enumerable: true,
    get () {
      return require('../src/main-process/win-shell')
    }
  })
}

// The following classes can't be used from a Task handler and should therefore
// only be exported when not running as a child node process
if (process.type === 'renderer') {
  atomExport.Task = require('../src/task')
  atomExport.TextEditor = require('../src/text-editor')
}

export default atomExport
