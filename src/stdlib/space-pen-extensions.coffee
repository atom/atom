_ = require 'underscore'
{View} = require 'space-pen'
jQuery = require 'jquery'
ConfigObserver = require 'config-observer'
Subscriber = require 'subscriber'

_.extend View.prototype, ConfigObserver
_.extend View.prototype, Subscriber

originalCleanData = jQuery.cleanData
jQuery.cleanData = (elements) ->
  for element in elements
    if view = jQuery(element).view()
      view.unobserveConfig()
      view.unsubscribe()
  originalCleanData(elements)
