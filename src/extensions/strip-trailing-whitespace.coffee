module.exports =
  name: "strip trailing whitespace"

  activate: (rootView) ->
    rootView.eachBuffer (buffer) ->
      buffer.on 'before-save', ->
        buffer.scan /[ \t]+$/g, (match, range, { replace }) ->
          replace('')
