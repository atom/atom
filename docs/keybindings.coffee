# Keybinding ideas
# ----------------
# Are ctrl-v and ctrl-V different?
# Nested commands? Use timeout?
# Optional Regex, is that fucking crazy?
# Command/Control/Option or cmd/ctrl/alt
# How should we deal with scope?

keymap:
  # Take some method found in the keymap scope?
  'cmd-c': 'copyText'

  # Take a block
  'cmd-v': -> paste.someText()

  # Can take a regex
  # * how would this work with timeouts
  # * how can this not look so hackish
  # * do we even need this?
  'cmd-/(\d+)/': (number) ->
    window.switchTo(parseInt(number))

  # Nested commands
  'cmd-ctrl-r':
    'r': -> run.something()
    't': -> test.something()

  # Switch modes? I don't like this syntax
  'mode(normal):esc':
    'j': 'moveDown'
    'k': 'moveUp'
    'a': ->
      goto.endOfLine()
      keybindingMode('normal')
  'mode(insert):i':
    'delete': 'delete'
