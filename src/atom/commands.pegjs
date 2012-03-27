{
  var CompositeCommand = require('command-interpreter/composite-command')
  var Substitution = require('command-interpreter/substitution');
  var LineAddress = require('command-interpreter/line-address');
  var AddressRange = require('command-interpreter/address-range');
  var EofAddress = require('command-interpreter/eof-address');
  var CurrentSelectionAddress = require('command-interpreter/current-selection-address')
  var RegexAddress = require('command-interpreter/regex-address')
  var SelectAllMatches = require('command-interpreter/select-all-matches')
}

start = expressions:(expression+) {
  return new CompositeCommand(expressions)
}

expression = _ expression:(address / command) _ { return expression; }

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

command = substitution / selectAllMatches

substitution
  = "s" _ "/" find:pattern "/" replace:pattern "/" _ options:[g]* {
    return new Substitution(find, replace, options);
  }

selectAllMatches
  = 'x' _ '/' pattern:pattern '/'? { return new SelectAllMatches(pattern) }

pattern
  = pattern:[^/]* { return pattern.join('') }

integer
  = digits:[0-9]+ { return parseInt(digits.join('')); }

_ = " "*
