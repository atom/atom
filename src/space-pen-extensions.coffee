_ = require './underscore-extensions'
spacePen = require 'space-pen'
jQuery = require './jquery-extensions'
ConfigObserver = require './config-observer'
{Subscriber} = require 'emissary'

_.extend spacePen.View.prototype, ConfigObserver
Subscriber.includeInto(spacePen.View)

originalCleanData = jQuery.cleanData
jQuery.cleanData = (elements) ->
  for element in elements
    if view = jQuery(element).view()
      view.unobserveConfig()
      view.unsubscribe()
  originalCleanData(elements)

module.exports = spacePen
