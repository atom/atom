OnigRegExp.prototype.getCaptureTree = (string, startPosition) ->
  buildCaptureTree = (captures, startPositions, totalCaptures=captures.length) ->
    index = totalCaptures - captures.length
    text = captures.shift()
    startPosition = startPositions.shift()
    endPosition = startPosition + text.length

    tree = { index, text, position: startPosition }

    childCaptures = []
    while startPositions[0] < endPosition
      subtree = buildCaptureTree(captures, startPositions, totalCaptures)
      childCaptures.push(subtree) if subtree.text.length

    tree.captures = childCaptures if childCaptures.length
    tree

  if match = @search(string, startPosition)
    buildCaptureTree(match, match.indices)
