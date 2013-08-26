{View} = require 'space-pen'

# Public: Represents a view that scrolls.
#
# This `View` subclass listens to events such as `page-up`, `page-down`,
# `move-to-top`, and `move-to-bottom`.
#
# FIXME: I don't actually understand if this is useful or not. I think it is
# a base of package widgets but I don't really understand how the core events
# work.
module.exports =
class ScrollView extends View

  # Internal: The constructor.
  initialize: ->
    @on 'core:page-up', => @pageUp()
    @on 'core:page-down', => @pageDown()
    @on 'core:move-to-top', => @scrollToTop()
    @on 'core:move-to-bottom', => @scrollToBottom()
