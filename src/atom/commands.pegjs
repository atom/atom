{
  var Substitution = require('command-interpreter/substitution');
  var Address = require('command-interpreter/address');
}

start
  = address:address? _ command:substitution? {
    var operations = [];
    if (address) operations.push(address);
    if (command) operations.push(command);
    return operations;
  }

address
  = start:integer _ ',' _ end:integer {
    return new Address(start, end)
  }

substitution
  = "s" _ "/" find:pattern "/" replace:pattern "/" _ options:[g]* {
    return new Substitution(find, replace, options);
  }

pattern
  = pattern:[^/]* { return pattern.join('') }

integer
  = digits:[0-9]+ { return parseInt(digits.join('')); }

_ = " "*
