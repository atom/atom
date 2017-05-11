AtomEnvironment = require './atom-environment'
ApplicationDelegate = require './application-delegate'
Clipboard = require './clipboard'
TextEditor = require './text-editor'
TextEditorComponent = require './text-editor-component'
FileSystemBlobStore = require './file-system-blob-store'
NativeCompileCache = require './native-compile-cache'
CompileCache = require './compile-cache'
ModuleCache = require './module-cache'

if global.isGeneratingSnapshot
  require('about')
  require('archive-view')
  require('autocomplete-atom-api')
  require('autocomplete-css')
  require('autocomplete-html')
  require('autocomplete-plus')
  require('autocomplete-snippets')
  require('autoflow')
  require('autosave')
  require('background-tips')
  require('bookmarks')
  require('bracket-matcher')
  require('command-palette')
  require('deprecation-cop')
  require('dev-live-reload')
  require('encoding-selector')
  require('exception-reporting')
  require('dalek')
  require('find-and-replace')
  require('fuzzy-finder')
  require('github')
  require('git-diff')
  require('go-to-line')
  require('grammar-selector')
  require('image-view')
  require('incompatible-packages')
  require('keybinding-resolver')
  require('line-ending-selector')
  require('link')
  require('markdown-preview')
  require('metrics')
  require('notifications')
  require('open-on-github')
  require('package-generator')
  require('settings-view')
  require('snippets')
  require('spell-check')
  require('status-bar')
  require('styleguide')
  require('symbols-view')
  require('tabs')
  require('timecop')
  require('tree-view')
  require('update-package-dependencies')
  require('welcome')
  require('whitespace')
  require('wrap-guide')

clipboard = new Clipboard
TextEditor.setClipboard(clipboard)

global.atom = new AtomEnvironment({
  clipboard,
  applicationDelegate: new ApplicationDelegate,
  enablePersistence: true
})

global.atom.preloadPackages()

# Like sands through the hourglass, so are the days of our lives.
module.exports = ({blobStore}) ->
  {updateProcessEnv} = require('./update-process-env')
  path = require 'path'
  require './window'
  getWindowLoadSettings = require './get-window-load-settings'
  {ipcRenderer} = require 'electron'
  {resourcePath, devMode, env} = getWindowLoadSettings()
  require './electron-shims'

  # Add application-specific exports to module search path.
  exportsPath = path.join(resourcePath, 'exports')
  require('module').globalPaths.push(exportsPath)
  process.env.NODE_PATH = exportsPath

  # Make React faster
  process.env.NODE_ENV ?= 'production' unless devMode

  global.atom.initialize({
    window, document, blobStore,
    configDirPath: process.env.ATOM_HOME,
    env: process.env
  })

  global.atom.startEditorWindow().then ->
    # Workaround for focus getting cleared upon window creation
    windowFocused = ->
      window.removeEventListener('focus', windowFocused)
      setTimeout (-> document.querySelector('atom-workspace').focus()), 0
    window.addEventListener('focus', windowFocused)
    ipcRenderer.on('environment', (event, env) ->
      updateProcessEnv(env)
    )
