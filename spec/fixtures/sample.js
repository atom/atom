function quicksort () {
  function sort (items) {
    if (items.length <= 1) return items;

    const pivot = items.pop()
    const left = [], right = [];
    let current;
    while (items.length > 0) {
      current = items.pop();
      current < pivot ? left.push(current) : right.push(current);
    }
    return sort(left).concat(pivot, sort(right));
  };

  return sort(Array.apply(this, arguments));
};