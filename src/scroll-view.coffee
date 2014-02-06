{View} = require './space-pen-extensions'

# Public: Represents a view that scrolls.
#
# Subclasses must call `super` if overriding the `initialize` method or else
# the following events won't be handled by the ScrollView.
#
# ## Events
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
    @on 'core:page-up', => @pageUp()
    @on 'core:page-down', => @pageDown()
    @on 'core:move-to-top', => @scrollToTop()
    @on 'core:move-to-bottom', => @scrollToBottom()
