module.exports =
  activate: ->

  deactivate: ->

  handleFirstServiceV3: (service) ->
    service('first-service-v3-used')

  handleFirstServiceV4: (service) ->
    service('first-service-v4-used')

  handleSecondService: (service) ->
    service('second-service-used')
