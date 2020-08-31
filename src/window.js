// Public: Measure how long a function takes to run.
//
// description - A {String} description that will be logged to the console when
//               the function completes.
// fn - A {Function} to measure the duration of.
//
// Returns the value returned by the given function.
window.measure = function(description, fn) {
  let start = Date.now();
  let value = fn();
  let result = Date.now() - start;
  console.log(description, result);
  return value;
};

// Public: Create a dev tools profile for a function.
//
// description - A {String} description that will be available in the Profiles
//               tab of the dev tools.
// fn - A {Function} to profile.
//
// Returns the value returned by the given function.
window.profile = function(description, fn) {
  window.measure(description, function() {
    console.profile(description);
    let value = fn();
    console.profileEnd(description);
    return value;
  });
};
