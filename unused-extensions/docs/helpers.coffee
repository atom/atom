hbar       = require 'handlebars'
{Showdown} = require './showdown'
converter  = new Showdown.converter

hbar.registerHelper 'format', (comment) ->
  comment = comment+''

  # param - info => <b>param:</b> info
  comment = comment.replace /(?:^\s*(\S+?)\s+-\s+(.+)$)+/img,
    '<br>**$1:** $2'
  comment = comment.replace '<br>**', '<br><br>**'

  # markdownize
  comment = converter.makeHtml comment

  # <pre><code>code</code></pre> => <pre>code</pre>
  comment = comment.replace /<pre><code>((?:.|\n)+)<\/code><\/pre>/img,
    '<pre>$1</pre>'

  new hbar.SafeString comment
