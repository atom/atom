{
  var Snippet = require('snippets/src/snippet');
  var Point = require('point');
}

snippets = snippets:snippet+ ws? {
  var snippetsByPrefix = {};
  snippets.forEach(function(snippet) {
    snippetsByPrefix[snippet.prefix] = snippet
  });
  return snippetsByPrefix;
}

snippet = ws? start ws prefix:prefix ws description:string bodyPosition:beforeBody body:body end {
  return new Snippet({ bodyPosition: bodyPosition, prefix: prefix, description: description, body: body });
}

start = 'snippet'
prefix = prefix:[A-Za-z0-9_]+ { return prefix.join(''); }
string = ['] body:[^']* ['] { return body.join(''); }
       / ["] body:[^"]* ["] { return body.join(''); }

beforeBody = [ ]* '\n' { return new Point(line, 0); } // return start position of body: body begins on next line, so don't subtract 1 from line

body = bodyLine+
bodyLine = content:(tabStop / bodyText)* '\n' { return content; }
bodyText = text:bodyChar+ { return text.join(''); }
bodyChar = !(end / tabStop) char:[^\n] { return char; }
tabStop = simpleTabStop / tabStopWithPlaceholder
simpleTabStop = '$' index:[0-9]+ {
  return { index: parseInt(index), placeholderText: '' };
}
tabStopWithPlaceholder = '${' index:[0-9]+ ':' placeholderText:[^}]* '}' {
  return { index: parseInt(index), placeholderText: placeholderText.join('') };
}

end = 'endsnippet'
ws = ([ \n] / comment)+
comment = '#' [^\n]*
