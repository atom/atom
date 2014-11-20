module.exports =
class Message
  constructor: (@type, @message, @options={}) ->

  getType: -> @type

  getMessage: -> @message

  isClosable: ->
    !!@options.closable

  getIcon: ->
    return @options.icon if @options.icon?
    switch @type
      when 'fatal' then 'flame'
      when 'error' then 'bug'
      when 'warning' then 'alert'
      when 'info' then 'info'
      when 'success' then 'check'

  getIssueUrl: ->
    "https://github.com/atom/atom/issues/new?title=#{encodeURI(@getIssueTitle())}&body=#{encodeURI(@getIssueBody())}"

  getIssueTitle: ->
    @message

  getIssueBody: ->
    # TODO: crib version information from bug-report: https://github.com/lee-dohm/bug-report/blob/master/lib/bug-report.coffee#L69
    """
    There was an unhandled error

    Stack Trace
    ```
    At #{@options.errorDetail}

    #{@options.stack}
    ```
    """
