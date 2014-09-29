merge = (menu, item) ->
  matchingItem = findMatchingItem(menu, item)

  if matchingItem?
    if item.submenu?
      merge(matchingItem.submenu, submenuItem) for submenuItem in item.submenu
  else
    menu.push(item)

unmerge = (menu, item) ->
  if matchingItem = findMatchingItem(menu, item)
    if item.submenu?
      unmerge(matchingItem.submenu, submenuItem) for submenuItem in item.submenu

    unless matchingItem.submenu?.length > 0
      menu.splice(menu.indexOf(matchingItem), 1)

findMatchingItem = (menu, {type, label, submenu}) ->
  return if type is 'separator'
  for item in menu
    if normalizeLabel(item.label) is normalizeLabel(label) and item.submenu? is submenu?
      return item
  return

normalizeLabel = (label) ->
  return undefined unless label?

  if process.platform is 'darwin'
    label
  else
    label.replace(/\&/g, '')

module.exports = {merge, unmerge, findMatchingItem, normalizeLabel}
