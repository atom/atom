_ = require 'underscore-plus'

escapeNode = null

escapeHtml = (str) ->
  escapeNode ?= document.createElement('div')
  escapeNode.innerText = str
  escapeNode.innerHTML

escapeRegex = (str) ->
  str.replace /[.?*+^$[\]\\(){}|-]/g, (match) -> "\\" + match

sanitizePattern = (pattern) ->
  pattern = escapeHtml(pattern)
  pattern.replace(/\n/g, '\\n').replace(/\t/g, '\\t')

getReplacementResultsMessage = ({findPattern, replacePattern, replacedPathCount, replacementCount}) ->
  if replacedPathCount
    "<span class=\"text-highlight\">Replaced <span class=\"highlight-error\">#{sanitizePattern(findPattern)}</span> with <span class=\"highlight-success\">#{sanitizePattern(replacePattern)}</span> #{_.pluralize(replacementCount, 'time')} in #{_.pluralize(replacedPathCount, 'file')}</span>"
  else
    "<span class=\"text-highlight\">Nothing replaced</span>"

getSearchResultsMessage = (results) ->
  if results?.findPattern?
    {findPattern, matchCount, pathCount, replacedPathCount} = results
    if matchCount
      "#{_.pluralize(matchCount, 'result')} found in #{_.pluralize(pathCount, 'file')} for <span class=\"highlight-info\">#{sanitizePattern(findPattern)}</span>"
    else
      "No #{if replacedPathCount? then 'more' else ''} results found for '#{sanitizePattern(findPattern)}'"
  else
    ''

showIf = (condition) ->
  if condition
    null
  else
    {display: 'none'}

module.exports = {
  escapeHtml, escapeRegex, sanitizePattern, getReplacementResultsMessage,
  getSearchResultsMessage, showIf
}
