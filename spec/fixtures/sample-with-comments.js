var quicksort = function () {
  /*
    this is a multiline comment
    it is, I promise
  */
  var sort = function(items) {
    // This is a collection of
    // single line comments.
    // Wowza
    if (items.length <= 1) return items;
    var pivot = items.shift(), current, left = [], right = [];
    while(items.length > 0) {
      current = items.shift();
      current < pivot ? left.push(current) : right.push(current);
    }
    return sort(left).concat(pivot).concat(sort(right));
  };
  // this is a single-line comment
  return sort(Array.apply(this, arguments));
};