{View} = require './space-pen-extensions'

# Public: Represents a view that scrolls.
#
# Subclasses must call `super` if overriding the `initialize` method or else
# the following events won't be handled by the ScrollView.
#
# ## Events
#   * `core:move-up`
#   * `core:move-down`
#   * `core:page-up`
#   * `core:page-down`
#   * `core:move-to-top`
#   * `core:move-to-bottom`
#
# ## Requiring in packages
#
# ```coffee
#   {ScrollView} = require 'atom'
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
