_ = require 'underscore-plus'

merge = (menu, item) ->
  matchingItemIndex = findMatchingItemIndex(menu, item)
  matchingItem = menu[matchingItemIndex] unless matchingItemIndex is - 1

  if matchingItem?
    if item.submenu?
      merge(matchingItem.submenu, submenuItem) for submenuItem in item.submenu
    else
      menu[matchingItemIndex] = item
  else
    menu.push(item)

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
  item = _.pick(item, 'type', 'label', 'command', 'submenu', 'commandOptions')
  if item.submenu?
    item.submenu = item.submenu.map (submenuItem) -> cloneMenuItem(submenuItem)
  item

module.exports = {merge, unmerge, normalizeLabel, cloneMenuItem}
