var utils = require("./utils");

/* Thrown when the grammar contains an error. */
module.exports = function(message) {
  this.name = "GrammarError";
  this.message = message;
};

utils.subclass(module.exports, Error);
