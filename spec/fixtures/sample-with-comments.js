var quicksort = function () {
  /*
    this is a multiline comment
    it is, I promise
  */
  var sort = function(items) { // comment at the end of a foldable line
    // This is a collection of
    // single line comments.
    // Wowza
    if (items.length <= 1) return items;
    var pivot = items.shift(), current, left = [], right = [];
    /*
      This is a multiline comment block with
      an empty line inside of it.

      Awesome.
    */
    while(items.length > 0) {
      current = items.shift();
      current < pivot ? left.push(current) : right.push(current);
    }
    // This is a collection of
    // single line comments

    // ...with an empty line
    // among it, geez!
    return sort(left).concat(pivot).concat(sort(right));
  };
  // this is a single-line comment
  return sort(Array.apply(this, arguments));
};
