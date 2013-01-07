body = content:(tabStop / bodyText)* { return content; }
bodyText = text:bodyChar+ { return text.join(''); }
bodyChar = !tabStop char:. { return char; }
tabStop = simpleTabStop / tabStopWithPlaceholder
simpleTabStop = '$' index:[0-9]+ {
  return { index: parseInt(index), placeholderText: '' };
}
tabStopWithPlaceholder = '${' index:[0-9]+ ':' placeholderText:[^}]* '}' {
  return { index: parseInt(index), placeholderText: placeholderText.join('') };
}
