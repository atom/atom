{
  var CompositeCommand = require('command-interpreter/composite-command')
  var Substitution = require('command-interpreter/substitution');
  var LineAddress = require('command-interpreter/line-address');
  var AddressRange = require('command-interpreter/address-range');
  var EofAddress = require('command-interpreter/eof-address');
  var CurrentSelectionAddress = require('command-interpreter/current-selection-address')
  var RegexAddress = require('command-interpreter/regex-address')
}

start
  = address:address? _ command:substitution? {
    var commands = [];
    if (address) commands.push(address);
    if (command) commands.push(command);

    return new CompositeCommand(commands);
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
  / '/' pattern:pattern '/'? { return new RegexAddress(pattern)}

substitution
  = "s" _ "/" find:pattern "/" replace:pattern "/" _ options:[g]* {
    return new Substitution(find, replace, options);
  }

pattern
  = pattern:[^/]* { return pattern.join('') }

integer
  = digits:[0-9]+ { return parseInt(digits.join('')); }

_ = " "*
