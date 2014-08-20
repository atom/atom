{View} = require './space-pen-extensions'

# Public: Represents a view that scrolls.
#
# Subclasses must call `super` if overriding the `initialize` method or else
# the following events won't be handled by the ScrollView.
#
# ## Events
#   * `core:move-up` Scrolls the view up
#   * `core:move-down` Scrolls the view down
#   * `core:page-up`   Scrolls the view up by the height of the page
#   * `core:page-down` Scrolls the view down by the height of the page
#   * `core:move-to-top` Scrolls the editor to the top
#   * `core:move-to-bottom` Scroll the editor to the bottom
#
# ## Examples
#
# ```coffee
# {ScrollView} = require 'atom'
#
# class MyView extends ScrollView
#   @content: ->
#     @div()
#
#   initialize: ->
#     super
#
#     @text('super long content that will scroll')
# ```
module.exports =
class ScrollView extends View
  initialize: ->
    @on 'core:move-up', => @scrollUp()
    @on 'core:move-down', => @scrollDown()
    @on 'core:page-up', => @pageUp()
    @on 'core:page-down', => @pageDown()
    @on 'core:move-to-top', => @scrollToTop()
    @on 'core:move-to-bottom', => @scrollToBottom()
