path = require 'path'

_ = require 'underscore-plus'
ipc = require 'ipc'
CSON = require 'season'
fs = require 'fs-plus'

# Public: Provides a registry for menu items that you'd like to appear in the
# application menu.
#
# Should be accessed via `atom.menu`.
module.exports =
class MenuManager
  pendingUpdateOperation: null

  # Private:
  constructor: ({@resourcePath}) ->
    @template = []
    atom.keymap.on 'bundled-keymaps-loaded', => @loadPlatformItems()

  # Public: Adds the given item definition to the existing template.
  #
  # * item:
  #   An object which describes a menu item as defined by
  #   https://github.com/atom/atom-shell/blob/master/docs/api/browser/menu.md
  #
  # Returns nothing.
  add: (items) ->
    @merge(@template, item) for item in items
    @update()

  # Private: Should the binding for the given selector be included in the menu
  # commands.
  #
  # * selector: A String selector to check.
  #
  # Returns true to include the selector, false otherwise.
  includeSelector: (selector) ->
    return true if document.body.webkitMatchesSelector(selector)

    # Simulate an .editor element attached to a body element that has the same
    # classes as the current body element.
    unless @testEditor?
      @testEditor = document.createElement('div')
      @testEditor.classList.add('editor')
      testBody = document.createElement('body')
      testBody.classList.add(document.body.classList.toString().split(' ')...)
      testBody.appendChild(@testEditor)

    @testEditor.webkitMatchesSelector(selector)

  # Public: Refreshes the currently visible menu.
  update: ->
    clearImmediate(@pendingUpdateOperation) if @pendingUpdateOperation?
    @pendingUpdateOperation = setImmediate =>
      keystrokesByCommand = {}
      for binding in atom.keymap.getKeyBindings() when @includeSelector(binding.selector)
        keystrokesByCommand[binding.command] ?= []
        keystrokesByCommand[binding.command].push binding.keystroke
      @sendToBrowserProcess(@template, keystrokesByCommand)

  # Private:
  loadPlatformItems: ->
    menusDirPath = path.join(@resourcePath, 'menus')
    platformMenuPath = fs.resolve(menusDirPath, process.platform, ['cson', 'json'])
    {menu} = CSON.readFileSync(platformMenuPath)
    @add(menu)

  # Private: Merges an item in a submenu aware way such that new items are always
  # appended to the bottom of existing menus where possible.
  merge: (menu, item) ->
    item = _.deepClone(item)

    if item.submenu? and match = _.find(menu, (i) => i.submenu? and @normalizeLabel(i.label) == @normalizeLabel(item.label))
      @merge(match.submenu, i) for i in item.submenu
    else
      menu.push(item) unless _.find(menu, (i) => @normalizeLabel(i.label) == @normalizeLabel(item.label))

  # Private: OSX can't handle displaying accelerators for multiple keystrokes.
  # If they are sent across, it will stop processing accelerators for the rest
  # of the menu items.
  filterMultipleKeystroke: (keystrokesByCommand) ->
    filtered = {}
    for key, bindings of keystrokesByCommand
      for binding in bindings
        continue if binding.indexOf(' ') != -1

        filtered[key] ?= []
        filtered[key].push(binding)
    filtered

  # Private:
  sendToBrowserProcess: (template, keystrokesByCommand) ->
    keystrokesByCommand = @filterMultipleKeystroke(keystrokesByCommand)
    ipc.sendChannel 'update-application-menu', template, keystrokesByCommand

  # Private:
  normalizeLabel: (label) ->
    return undefined unless label?

    if process.platform is 'win32'
      label.replace(/\&/g, '')
    else
      label
