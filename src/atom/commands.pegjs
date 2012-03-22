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
  = "s" _ "/" find:([^/]*) "/" replace:([^/]*) "/" _ options:[g]* {
    return new Substitution(find.join(''), replace.join(''), options);
  }

integer
  = digits:[0-9]+ { return parseInt(digits.join('')); }

_ = " "*
