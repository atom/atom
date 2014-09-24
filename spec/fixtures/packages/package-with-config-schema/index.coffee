module.exports =
  config:
    numbers:
      type: 'object'
      properties:
        one:
          type: 'integer'
          default: 1
        two:
          type: 'integer'
          default: 2

  activate: -> # no-op
