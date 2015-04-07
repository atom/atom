class Quicksort
  sort: (items) ->
    return items if items.length <= 1

    pivot = items.shift()
    left = []
    right = []

    # Comment in the middle

    while items.length > 0
      current = items.shift()
      if current < pivot
        left.push(current)
      else
        # coffeelint: disable=no_trailing_semicolons
        right.push(current);

    sort(left).concat(pivot).concat(sort(right))

  noop: ->
    # just a noop

exports.modules = quicksort
