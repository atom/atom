path = require 'path'

_ = require 'underscore-plus'
ipc = require 'ipc'
CSON = require 'season'
fs = require 'fs-plus'

# Public: Provides a registry for menu items that you'd like to appear in the
# application menu.
#
# An instance of this class is always available as the `atom.menu` global.
module.exports =
class MenuManager
  constructor: ({@resourcePath}) ->
    @pendingUpdateOperation = null
    @template = []
    atom.keymaps.on 'bundled-keymaps-loaded', => @loadPlatformItems()
    atom.packages.on 'activated', => @sortPackagesMenu()

  # Public: Adds the given items to the application menu.
  #
  # ## Examples
  # ```coffee
  #   atom.menu.add [
  #     {
  #       label: 'Hello'
  #       submenu : [{label: 'World!', command: 'hello:world'}]
  #     }
  #   ]
  # ```
  #
  # * `items` An {Array} of menu item {Object}s containing the keys:
  #   * `label` The {String} menu label.
  #   * `submenu` An optional {Array} of sub menu items.
  #   * `command` An optional {String} command to trigger when the item is
  #               clicked.
  add: (items) ->
    @merge(@template, item) for item in items
    @update()
    undefined

  # Should the binding for the given selector be included in the menu
  # commands.
  #
  # * `selector` A {String} selector to check.
  #
  # Returns a {Boolean}, true to include the selector, false otherwise.
  includeSelector: (selector) ->
    try
      return true if document.body.webkitMatchesSelector(selector)
    catch error
      # Selector isn't valid
      return false

    # Simulate an .editor element attached to a .workspace element attached to
    # a body element that has the same classes as the current body element.
    unless @testEditor?
      testBody = document.createElement('body')
      testBody.classList.add(@classesForElement(document.body)...)

      testWorkspace = document.createElement('div')
      workspaceClasses = @classesForElement(document.body.querySelector('.workspace'))
      workspaceClasses = ['workspace'] if workspaceClasses.length is 0
      testWorkspace.classList.add(workspaceClasses...)

      testBody.appendChild(testWorkspace)

      @testEditor = document.createElement('div')
      @testEditor.classList.add('editor')
      testWorkspace.appendChild(@testEditor)

    element = @testEditor
    while element
      return true if element.webkitMatchesSelector(selector)
      element = element.parentElement

    false

  # Public: Refreshes the currently visible menu.
  update: ->
    clearImmediate(@pendingUpdateOperation) if @pendingUpdateOperation?
    @pendingUpdateOperation = setImmediate =>
      keystrokesByCommand = {}
      for binding in atom.keymaps.getKeyBindings() when @includeSelector(binding.selector)
        keystrokesByCommand[binding.command] ?= []
        keystrokesByCommand[binding.command].unshift binding.keystrokes
      @sendToBrowserProcess(@template, keystrokesByCommand)

  loadPlatformItems: ->
    menusDirPath = path.join(@resourcePath, 'menus')
    platformMenuPath = fs.resolve(menusDirPath, process.platform, ['cson', 'json'])
    {menu} = CSON.readFileSync(platformMenuPath)
    @add(menu)

  # Merges an item in a submenu aware way such that new items are always
  # appended to the bottom of existing menus where possible.
  merge: (menu, item) ->
    item = _.deepClone(item)

    if item.submenu? and match = _.find(menu, ({label, submenu}) => submenu? and label and @normalizeLabel(label) is @normalizeLabel(item.label))
      @merge(match.submenu, i) for i in item.submenu
    else
      menu.push(item) unless _.find(menu, ({label}) => label and @normalizeLabel(label) is @normalizeLabel(item.label))

  # OSX can't handle displaying accelerators for multiple keystrokes.
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

  sendToBrowserProcess: (template, keystrokesByCommand) ->
    keystrokesByCommand = @filterMultipleKeystroke(keystrokesByCommand)
    ipc.send 'update-application-menu', template, keystrokesByCommand

  normalizeLabel: (label) ->
    return undefined unless label?

    if process.platform is 'darwin'
      label
    else
      label.replace(/\&/g, '')

  # Get an {Array} of {String} classes for the given element.
  classesForElement: (element) ->
    element?.classList.toString().split(' ') ? []

  sortPackagesMenu: ->
    packagesMenu = @template.find ({label}) => @normalizeLabel(label) is 'Packages'
    return unless packagesMenu?.submenu?

    packagesMenu.submenu.sort (item1, item2) =>
      if item1.label and item2.label
        @normalizeLabel(item1.label).localeCompare(@normalizeLabel(item2.label))
      else
        0
    @update()
