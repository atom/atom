var quicksort = function () {
  var sort = function (items) {
    if (items.length <= 1) return items
    var pivot = items.shift()
    var current
    var left = []
    var right = []

    while (items.length > 0) {
      current = items.shift()
      current < pivot ? left.push(current) : right.push(current)
    }
    return sort(left)
      .concat(pivot)
      .concat(sort(right))
  }

  return sort(Array.apply(this, arguments))
}

// adapted from:
// https://github.com/nzakas/computer-science-in-javascript/tree/master/algorithms/sorting/merge-sort-recursive
var mergeSort = function (items) {
  var merge = function (left, right) {
    var result = []
    var il = 0
    var ir = 0

    while (il < left.length && ir < right.length) {
      if (left[il] < right[ir]) {
        result.push(left[il++])
      } else {
        result.push(right[ir++])
      }
    }

    return result.concat(left.slice(il)).concat(right.slice(ir))
  }

  if (items.length < 2) {
    return items
  }

  var middle = Math.floor(items.length / 2)
  var left = items.slice(0, middle)
  var right = items.slice(middle)
  var params = merge(mergeSort(left), mergeSort(right))

  // Add the arguments to replace everything between 0 and last item in the array
  params.unshift(0, items.length)
  items.splice.apply(items, params)
  return items
}

// adapted from:
// https://github.com/nzakas/computer-science-in-javascript/blob/master/algorithms/sorting/bubble-sort/bubble-sort.js
var bubbleSort = function (items) {
  var swap = function (items, firstIndex, secondIndex) {
    var temp = items[firstIndex]
    items[firstIndex] = items[secondIndex]
    items[secondIndex] = temp
  }

  var len = items.length
  var i
  var j
  var stop

  for (i = 0; i < len; i++) {
    for (j = 0, stop = len - i; j < stop; j++) {
      if (items[j] > items[j + 1]) {
        swap(items, j, j + 1)
      }
    }
  }

  return items
}

module.exports = {
  bubbleSort,
  mergeSort,
  quicksort
}
