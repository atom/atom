bodyContent = content:(tabStop / bodyContentText)* { return content; }
bodyContentText = text:bodyContentChar+ { return text.join(''); }
bodyContentChar = !tabStop char:. { return char; }

placeholderContent = content:(tabStop / placeholderContentText)* { return content; }
placeholderContentText = text:placeholderContentChar+ { return text.join(''); }
placeholderContentChar = !tabStop char:[^}] { return char; }

tabStop = simpleTabStop / tabStopWithPlaceholder
simpleTabStop = '$' index:[0-9]+ {
  return { index: parseInt(index), content: [] };
}
tabStopWithPlaceholder = '${' index:[0-9]+ ':' content:placeholderContent '}' {
  return { index: parseInt(index), content: content };
}
