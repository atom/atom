{
  var Substitution = require('command-interpreter/substitution');
}

substitution
  = "s" _ "/" find:([^/]*) "/" replace:([^/]*) "/" { return new Substitution(find.join(''), replace.join('')) }

_ = " "*
