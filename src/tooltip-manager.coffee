_ = require 'underscore-plus'
{$} = require './space-pen-extensions'

module.exports =
class TooltipManager
  defaults:
    delay:
      show: 1000
      hide: 100
    container: 'body'
    html: true
    placement: 'auto top'
    viewportPadding: 2

  add: (target, options) ->
    requireBootstrapTooltip()

    {keyBindingCommand, keyBindingTarget} = options

    if keyBindingCommand?
      bindings = atom.keymaps.findKeyBindings(command: keyBindingCommand, target: keyBindingTarget)
      if options.title?
        options.title += " " + getKeystroke(bindings)
      else
        options.title = getKeystroke(bindings)

    if typeof target is 'string'
      options.selector = target
      target = document.body

    $(target).tooltip(_.defaults(options, @defaults))

humanizeKeystrokes = (keystroke) ->
  keystrokes = keystroke.split(' ')
  keystrokes = (_.humanizeKeystroke(stroke) for stroke in keystrokes)
  keystrokes.join(' ')

getKeystroke = (bindings) ->
  if bindings?.length
    "<span class=\"keystroke\">#{humanizeKeystrokes(bindings[0].keystrokes)}</span>"
  else

requireBootstrapTooltip = _.once ->
  atom.requireWithGlobals('bootstrap/js/tooltip', {jQuery: $})
