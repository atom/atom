{
  var CompositeCommand = require('command-panel/lib/commands/composite-command')
  var Substitution = require('command-panel/lib/commands/substitution');
  var ZeroAddress = require('command-panel/lib/commands/zero-address');
  var EofAddress = require('command-panel/lib/commands/eof-address');
  var LineAddress = require('command-panel/lib/commands/line-address');
  var AddressRange = require('command-panel/lib/commands/address-range');
  var DefaultAddressRange = require('command-panel/lib/commands/default-address-range');
  var CurrentSelectionAddress = require('command-panel/lib/commands/current-selection-address')
  var RegexAddress = require('command-panel/lib/commands/regex-address')
  var SelectAllMatches = require('command-panel/lib/commands/select-all-matches')
  var SelectAllMatchesInProject = require('command-panel/lib/commands/select-all-matches-in-project')
}

start = _ commands:( selectAllMatchesInProject / textCommand ) {
  return new CompositeCommand(commands);
}

textCommand = defaultAddress:defaultAddress? expressions:expression* {
  if (defaultAddress) expressions.unshift(defaultAddress);
  return expressions;
}

defaultAddress = !address {
  return new DefaultAddressRange();
}

expression = _ expression:(address / substitution / selectAllMatches) {
  return expression;
}

address = addressRange / primitiveAddress

addressRange = start:primitiveAddress? _ ',' _ end:address? {
  if (!start) start = new ZeroAddress();
  if (!end) end = new EofAddress();
  return new AddressRange(start, end);
}

primitiveAddress
  = '0' { return new ZeroAddress() }
  / '$' { return new EofAddress() }
  / '.' { return new CurrentSelectionAddress() }
  / lineNumber:integer { return new LineAddress(lineNumber) }
  / regexAddress

regexAddress
  = reverse:'-'? '/' pattern:pattern '/'? { return new RegexAddress(pattern, reverse.length > 0)}

substitution
  = "s" _ "/" find:pattern "/" replace:pattern "/" _ options:[g]* {
    return new Substitution(find, eval("'" + replace + "'"), options);
  }

selectAllMatches
  = 'x' _ '/' pattern:pattern '/'? { return new SelectAllMatches(pattern) }

selectAllMatchesInProject
  = 'X' _ 'x' _ '/' pattern:pattern '/'? { return [new SelectAllMatchesInProject(pattern)] }

pattern
  = pattern:('\\/' / [^/])* { return pattern.join('') }

integer
  = digits:[0-9]+ { return parseInt(digits.join('')); }

_ = " "*
