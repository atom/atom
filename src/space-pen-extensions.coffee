_ = require 'underscore-plus'
spacePen = require 'space-pen'
ConfigObserver = require './config-observer'
{Subscriber} = require 'emissary'

_.extend spacePen.View.prototype, ConfigObserver
Subscriber.includeInto(spacePen.View)

jQuery = spacePen.jQuery
originalCleanData = jQuery.cleanData
jQuery.cleanData = (elements) ->
  for element in elements
    if view = jQuery(element).view()
      view.unobserveConfig()
      view.unsubscribe()
  originalCleanData(elements)

module.exports = spacePen
