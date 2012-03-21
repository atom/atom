{
  var Substitution = require('command-interpreter/substitution');
}

substitution
  = "s" _ "/" find:([^/]*) "/" replace:([^/]*) "/" _ options:[g]* {
    return new Substitution(find.join(''), replace.join(''), options)
  }

_ = " "*
