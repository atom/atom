_ = require 'underscore-plus'

ItemSpecificities = new WeakMap

merge = (menu, item, itemSpecificity=Infinity) ->
  item = cloneMenuItem(item)
  ItemSpecificities.set(item, itemSpecificity) if itemSpecificity
  matchingItemIndex = findMatchingItemIndex(menu, item)
  matchingItem = menu[matchingItemIndex] unless matchingItemIndex is - 1

  if matchingItem?
    if item.submenu?
      merge(matchingItem.submenu, submenuItem, itemSpecificity) for submenuItem in item.submenu
    else if itemSpecificity
      unless itemSpecificity < ItemSpecificities.get(matchingItem)
        menu[matchingItemIndex] = item
  else unless item.type is 'separator' and _.last(menu)?.type is 'separator'
    menu.push(item)

  return

unmerge = (menu, item) ->
  matchingItemIndex = findMatchingItemIndex(menu, item)
  matchingItem = menu[matchingItemIndex] unless matchingItemIndex is - 1

  if matchingItem?
    if item.submenu?
      unmerge(matchingItem.submenu, submenuItem) for submenuItem in item.submenu

    unless matchingItem.submenu?.length > 0
      menu.splice(matchingItemIndex, 1)

findMatchingItemIndex = (menu, {type, label, submenu}) ->
  return -1 if type is 'separator'
  for item, index in menu
    if normalizeLabel(item.label) is normalizeLabel(label) and item.submenu? is submenu?
      return index
  -1

normalizeLabel = (label) ->
  return undefined unless label?

  if process.platform is 'darwin'
    label
  else
    label.replace(/\&/g, '')

cloneMenuItem = (item) ->
  item = _.pick(item, 'type', 'label', 'enabled', 'visible', 'command', 'submenu', 'commandDetail', 'role', 'accelerator')
  if item.submenu?
    item.submenu = item.submenu.map (submenuItem) -> cloneMenuItem(submenuItem)
  item

# Determine the Electron accelerator for a given Atom keystroke.
#
# keystroke - The keystroke.
#
# Returns a String containing the keystroke in a format that can be interpreted
#   by Electron to provide nice icons where available.
acceleratorForKeystroke = (keystroke) ->
  return null unless keystroke
  modifiers = keystroke.split(/-(?=.)/)
  key = modifiers.pop().toUpperCase().replace('+', 'Plus')

  modifiers = modifiers.map (modifier) ->
    modifier.replace(/shift/ig, "Shift")
    .replace(/cmd/ig, "Command")
    .replace(/ctrl/ig, "Ctrl")
    .replace(/alt/ig, "Alt")

  keys = modifiers.concat([key])
  keys.join("+")

module.exports = {merge, unmerge, normalizeLabel, cloneMenuItem, acceleratorForKeystroke}
