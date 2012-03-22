{
  var Substitution = require('command-interpreter/substitution');
  var LineAddress = require('command-interpreter/line-address');
  var AddressRange = require('command-interpreter/address-range');
  var EofAddress = require('command-interpreter/eof-address');
  var CurrentSelectionAddress = require('command-interpreter/current-selection-address')
}

start
  = address:address? _ command:substitution? {
    var operations = [];
    if (address) operations.push(address);
    if (command) operations.push(command);
    return operations;
  }

address = addressRange / primitiveAddress

addressRange
  = start:primitiveAddress? _ ',' _ end:address? {
    if (!start) start = new LineAddress(0)
    if (!end) end = new EofAddress()
    return new AddressRange(start, end)
  }

primitiveAddress
  = lineNumber:integer { return new LineAddress(lineNumber) }
  / '$' { return new EofAddress() }
  / '.' { return new CurrentSelectionAddress() }

substitution
  = "s" _ "/" find:pattern "/" replace:pattern "/" _ options:[g]* {
    return new Substitution(find, replace, options);
  }

pattern
  = pattern:[^/]* { return pattern.join('') }

integer
  = digits:[0-9]+ { return parseInt(digits.join('')); }

_ = " "*
