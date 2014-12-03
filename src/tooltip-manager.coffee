_ = require 'underscore-plus'
{Disposable} = require 'event-kit'
{$} = require './space-pen-extensions'

# Essential: Associates tooltips with HTML elements or selectors.
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

  # Essential: Add a tooltip to the given element.
  #
  # * `target` An `HTMLElement`
  # * `options` See http://getbootstrap.com/javascript/#tooltips for a full list
  #   of options. You can also supply the following additional options:
  #   * `title` {String} Text in the tip.
  #   * `keyBindingCommand` A {String} containing a command name. If you specify
  #     this option and a key binding exists that matches the command, it will
  #     be appended to the title or rendered alone if no title is specified.
  #   * `keyBindingTarget` An `HTMLElement` on which to look up the key binding.
  #     If this option is not supplied, the first of all matching key bindings
  #     for the given command will be rendered.
  #
  # Returns a {Disposable} on which `.dispose()` can be called to remove the
  # tooltip.
  add: (target, options) ->
    requireBootstrapTooltip()

    {keyBindingCommand, keyBindingTarget} = options

    if keyBindingCommand?
      bindings = atom.keymaps.findKeyBindings(command: keyBindingCommand, target: keyBindingTarget)
      keystroke = getKeystroke(bindings)
      if options.title? and keystroke?
        options.title += " " + getKeystroke(bindings)
      else if keystroke?
        options.title = getKeystroke(bindings)

    $target = $(target)
    $target.tooltip(_.defaults(options, @defaults))

    new Disposable -> $target.tooltip('destroy')

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
