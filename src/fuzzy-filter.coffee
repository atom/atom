stringScore = require '../vendor/stringscore'
path = require 'path'

module.exports = (candidates, query, options={}) ->
  if query
    scoredCandidates = candidates.map (candidate) ->
      string = if options.key? then candidate[options.key] else candidate
      score = stringScore(string, query)

      unless /\//.test(query)
        # Basename matches count for more.
        score += stringScore(path.basename(string), query)

        # Shallow files are scored higher
        depth = Math.max(1, 10 - string.split('/').length - 1)
        score *= depth * 0.01

      { candidate, score }

    scoredCandidates.sort (a, b) ->
      if a.score > b.score then -1
      else if a.score < b.score then 1
      else 0
    candidates = (scoredCandidate.candidate for scoredCandidate in scoredCandidates when scoredCandidate.score > 0)

  candidates = candidates[0...options.maxResults] if options.maxResults?
  candidates
