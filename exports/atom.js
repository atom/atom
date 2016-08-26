/** @babel */

import TextBuffer, {Point, Range} from 'text-buffer'
import {File, Directory} from 'pathwatcher'
import {Emitter, Disposable, CompositeDisposable} from 'event-kit'
import Grim from 'grim'
import dedent from 'dedent'
import BufferedNodeProcess from '../src/buffered-node-process'
import BufferedProcess from '../src/buffered-process'
import GitRepository from '../src/git-repository'
import Notification from '../src/notification'

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
  CompositeDisposable
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
if (!process.env.ATOM_SHELL_INTERNAL_RUN_AS_NODE) {
  atomExport.Task = require('../src/task')

  const TextEditor = (params) => {
    return atom.workspace.buildTextEditor(params)
  }

  TextEditor.prototype = require('../src/text-editor').prototype

  Object.defineProperty(atomExport, 'TextEditor', {
    enumerable: true,
    get () {
      Grim.deprecate(dedent`
        The \`TextEditor\` constructor is no longer public.

        To construct a text editor, use \`atom.workspace.buildTextEditor()\`.
        To check if an object is a text editor, use \`atom.workspace.isTextEditor(object)\`.
      `)
      return TextEditor
    }
  })
}

export default atomExport
