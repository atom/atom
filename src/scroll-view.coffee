{View} = require 'space-pen'

# Public: Represents a view that scrolls.
#
# This `View` subclass listens to events such as `page-up`, `page-down`,
# `move-to-top`, and `move-to-bottom`.
module.exports =
class ScrollView extends View

  # Internal: The constructor.
  initialize: ->
    @on 'core:page-up', => @pageUp()
    @on 'core:page-down', => @pageDown()
    @on 'core:move-to-top', => @scrollToTop()
    @on 'core:move-to-bottom', => @scrollToBottom()
