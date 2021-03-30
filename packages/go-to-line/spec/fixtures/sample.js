function quicksort (...args) {
  function sort (items) {
    if (items.length <= 1) return items
    const pivot = items.pop()
    let current
    const left = []
    const right = []

    while (items.length > 0) {
      current = items.pop()
      current < pivot ? left.push(current) : right.push(current)
    }
    return sort(left).concat(pivot, sort(right))
  }

  return sort(Array.apply(this, args))
}

// adapted from:
// https://github.com/nzakas/computer-science-in-javascript/tree/master/algorithms/sorting/merge-sort-recursive
function mergeSort (items) {
  function merge (left, right) {
    let result = []
    let il = 0
    let ir = 0

    while (il < left.length && ir < right.length) {
      if (left[il] < right[ir]) {
        result.push(left[il++])
      } else {
        result.push(right[ir++])
      }
    }

    return result.concat(left.slice(il), right.slice(ir))
  }

  if (items.length < 2) {
    return items
  }

  let middle = Math.floor(items.length / 2)
  let left = items.slice(0, middle)
  let right = items.slice(middle)
  let params = merge(mergeSort(left), mergeSort(right))

  // Add the arguments to replace everything between 0 and last item in the array
  params.unshift(0, items.length)
  items.splice.apply(items, params)
  return items
}

// adapted from:
// https://github.com/nzakas/computer-science-in-javascript/blob/master/algorithms/sorting/bubble-sort/bubble-sort.js
function bubblesort (items) {
  function swap (items, firstIndex, secondIndex) {
    var temp = items[firstIndex]
    items[firstIndex] = items[secondIndex]
    items[secondIndex] = temp
  }

  const len = items.length

  for (let i = 0; i < len; i++) {
    for (let j = 0, stop = len - i; j < stop; j++) {
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
