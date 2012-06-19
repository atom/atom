snippets = snippets:snippet+ {
  var snippetsByPrefix = {};
  snippets.forEach(function(snippet) {
    snippetsByPrefix[snippet.prefix] = snippet
  });
  return snippetsByPrefix;
}

snippet = ws? start ws prefix:prefix ws description:string separator body:body end {
  return { prefix: prefix, description: description, body: body };
}

separator = [ ]* '\n'
start = 'snippet'
prefix = prefix:[A-Za-z0-9_]+ { return prefix.join(''); }
body = body:bodyCharacter* { return body.join(''); }
bodyCharacter = !end char:. { return char; }
end = '\nendsnippet'
string
  = ['] body:[^']* ['] { return body.join(''); }
  / ["] body:[^"]* ["] { return body.join(''); }
ws = [ \n]+
