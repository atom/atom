_ = require 'underscore-plus'
{Disposable, CompositeDisposable} = require 'event-kit'
Tooltip = null

# Essential: Associates tooltips with HTML elements.
#
# You can get the `TooltipManager` via `atom.tooltips`.
#
# ## Examples
#
# The essence of displaying a tooltip
#
# ```coffee
# # display it
# disposable = atom.tooltips.add(div, {title: 'This is a tooltip'})
#
# # remove it
# disposable.dispose()
# ```
#
# In practice there are usually multiple tooltips. So we add them to a
# CompositeDisposable
#
# ```coffee
# {CompositeDisposable} = require 'atom'
# subscriptions = new CompositeDisposable
#
# div1 = document.createElement('div')
# div2 = document.createElement('div')
# subscriptions.add atom.tooltips.add(div1, {title: 'This is a tooltip'})
# subscriptions.add atom.tooltips.add(div2, {title: 'Another tooltip'})
#
# # remove them all
# subscriptions.dispose()
# ```
#
# You can display a key binding in the tooltip as well with the
# `keyBindingCommand` option.
#
# ```coffee
# disposable = atom.tooltips.add @caseOptionButton,
#   title: "Match Case"
#   keyBindingCommand: 'find-and-replace:toggle-case-option'
#   keyBindingTarget: @findEditor.element
# ```
module.exports =
class TooltipManager
  defaults:
    trigger: 'hover'
    container: 'body'
    html: true
    placement: 'auto top'
    viewportPadding: 2

  hoverDefaults:
    {delay: {show: 1000, hide: 100}}

  constructor: ({@keymapManager, @viewRegistry}) ->

  # Essential: Add a tooltip to the given element.
  #
  # * `target` An `HTMLElement`
  # * `options` An object with one or more of the following options:
  #   * `title` A {String} or {Function} to use for the text in the tip. If
  #     a function is passed, `this` will be set to the `target` element. This
  #     option is mutually exclusive with the `item` option.
  #   * `html` A {Boolean} affecting the interpetation of the `title` option.
  #     If `true` (the default), the `title` string will be interpreted as HTML.
  #     Otherwise it will be interpreted as plain text.
  #   * `item` A view (object with an `.element` property) or a DOM element
  #     containing custom content for the tooltip. This option is mutually
  #     exclusive with the `title` option.
  #   * `class` A {String} with a class to apply to the tooltip element to
  #     enable custom styling.
  #   * `placement` A {String} or {Function} returning a string to indicate
  #     the position of the tooltip relative to `element`. Can be `'top'`,
  #     `'bottom'`, `'left'`, `'right'`, or `'auto'`. When `'auto'` is
  #     specified, it will dynamically reorient the tooltip. For example, if
  #     placement is `'auto left'`, the tooltip will display to the left when
  #     possible, otherwise it will display right.
  #     When a function is used to determine the placement, it is called with
  #     the tooltip DOM node as its first argument and the triggering element
  #     DOM node as its second. The `this` context is set to the tooltip
  #     instance.
  #   * `trigger` A {String} indicating how the tooltip should be displayed.
  #     Choose from one of the following options:
  #       * `'hover'` Show the tooltip when the mouse hovers over the element.
  #         This is the default.
  #       * `'click'` Show the tooltip when the element is clicked. The tooltip
  #         will be hidden after clicking the element again or anywhere else
  #         outside of the tooltip itself.
  #       * `'focus'` Show the tooltip when the element is focused.
  #       * `'manual'` Show the tooltip immediately and only hide it when the
  #         returned disposable is disposed.
  #   * `delay` An object specifying the show and hide delay in milliseconds.
  #     Defaults to `{show: 1000, hide: 100}` if the `trigger` is `hover` and
  #     otherwise defaults to `0` for both values.
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
    if target.jquery
      disposable = new CompositeDisposable
      disposable.add @add(element, options) for element in target
      return disposable

    Tooltip ?= require './tooltip'

    {keyBindingCommand, keyBindingTarget} = options

    if keyBindingCommand?
      bindings = @keymapManager.findKeyBindings(command: keyBindingCommand, target: keyBindingTarget)
      keystroke = getKeystroke(bindings)
      if options.title? and keystroke?
        options.title += " " + getKeystroke(bindings)
      else if keystroke?
        options.title = getKeystroke(bindings)

    options = _.defaults(options, @defaults)
    if options.trigger is 'hover'
      options = _.defaults(options, @hoverDefaults)

    tooltip = new Tooltip(target, options, @viewRegistry)

    hideTooltip = ->
      tooltip.leave(currentTarget: target)
      tooltip.hide()

    window.addEventListener('resize', hideTooltip)

    disposable = new Disposable ->
      window.removeEventListener('resize', hideTooltip)
      hideTooltip()
      tooltip.destroy()

    disposable

humanizeKeystrokes = (keystroke) ->
  keystrokes = keystroke.split(' ')
  keystrokes = (_.humanizeKeystroke(stroke) for stroke in keystrokes)
  keystrokes.join(' ')

getKeystroke = (bindings) ->
  if bindings?.length
    "<span class=\"keystroke\">#{humanizeKeystrokes(bindings[0].keystrokes)}</span>"
