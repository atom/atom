{
  var CompositeCommand = require('command-panel/commands/composite-command')
  var Substitution = require('command-panel/commands/substitution');
  var ZeroAddress = require('command-panel/commands/zero-address');
  var EofAddress = require('command-panel/commands/eof-address');
  var LineAddress = require('command-panel/commands/line-address');
  var AddressRange = require('command-panel/commands/address-range');
  var CurrentSelectionAddress = require('command-panel/commands/current-selection-address')
  var RegexAddress = require('command-panel/commands/regex-address')
  var SelectAllMatches = require('command-panel/commands/select-all-matches')
  var SelectAllMatchesInProject = require('command-panel/commands/select-all-matches-in-project')
}

start = expressions:(expression+) {
  return new CompositeCommand(expressions)
}

expression = _ expression:(address / command) _ { return expression; }

address = addressRange / primitiveAddress

addressRange
  = start:primitiveAddress? _ ',' _ end:address? {
    if (!start) start = new ZeroAddress()
    if (!end) end = new EofAddress()
    return new AddressRange(start, end)
  }

primitiveAddress
  = '0' { return new ZeroAddress() }
  / '$' { return new EofAddress() }
  / '.' { return new CurrentSelectionAddress() }
  / lineNumber:integer { return new LineAddress(lineNumber) }
  / regexAddress

regexAddress
  = reverse:'-'? '/' pattern:pattern '/'? { return new RegexAddress(pattern, reverse.length > 0)}

command = substitution / selectAllMatches / selectAllMatchesInProject

substitution
  = "s" _ "/" find:pattern "/" replace:pattern "/" _ options:[g]* {
    return new Substitution(find, replace, options);
  }

selectAllMatches
  = 'x' _ '/' pattern:pattern '/'? { return new SelectAllMatches(pattern) }

selectAllMatchesInProject
  = 'X' _ 'x' _ '/' pattern:pattern '/'? { return new SelectAllMatchesInProject(pattern) }

pattern
  = pattern:[^/]* { return pattern.join('') }

integer
  = digits:[0-9]+ { return parseInt(digits.join('')); }

_ = " "*
