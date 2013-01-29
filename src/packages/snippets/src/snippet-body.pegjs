bodyContent = content:(tabStop / bodyContentText)* { return content; }
bodyContentText = text:bodyContentChar+ { return text.join(''); }
bodyContentChar = !tabStop char:. { return char; }

tabStop = simpleTabStop / tabStopWithPlaceholder
simpleTabStop = '$' index:[0-9]+ {
  return { index: parseInt(index), content: [] };
}
tabStopWithPlaceholder = '${' index:[0-9]+ ':' content:placeholderContent '}' {
  return { index: parseInt(index), content: content };
}
placeholderContent = content:(tabStop / variable / placeholderContentText)* { return content; }
placeholderContentText = text:placeholderContentChar+ { return text.join(''); }
placeholderContentChar = !tabStop !variable char:[^}] { return char; }

variable = '${' variableContent '}' {
  return ''; // we eat variables and do nothing with them for now
}
variableContent = content:(variable / variableContentText)* { return content; }
variableContentText = text:variableContentChar+ { return text.join(''); }
variableContentChar = !variable char:[^}] { return char; }
