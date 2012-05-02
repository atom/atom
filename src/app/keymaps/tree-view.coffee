window.keymap.bindKeys '.editor'
  'alt-tab': 'tree-view:focus'

window.keymap.bindKeys '.tree-view'
  'right': 'tree-view:expand-directory'
  'left': 'tree-view:collapse-directory'
  'enter': 'tree-view:open-selected-entry'
  'm': 'tree-view:move'
  'a': 'tree-view:add'
  'alt-tab': 'tree-view:unfocus'

window.keymap.bindKeys '.move-dialog .mini.editor, .add-dialog .mini.editor'
  'enter': 'tree-view:confirm'
  'escape': 'tree-view:cancel'
