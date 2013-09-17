_ = require 'underscore'
spacePen = require 'space-pen'
jQuery = require 'jquery'
ConfigObserver = require 'config-observer'
Subscriber = require 'subscriber'

_.extend spacePen.View.prototype, ConfigObserver
_.extend spacePen.View.prototype, Subscriber

originalCleanData = jQuery.cleanData
jQuery.cleanData = (elements) ->
  for element in elements
    if view = jQuery(element).view()
      view.unobserveConfig()
      view.unsubscribe()
  originalCleanData(elements)

module.exports = spacePen
