body = leadingLines:bodyLineWithNewline* lastLine:bodyLine? {
  return lastLine ? leadingLines.concat([lastLine]) : leadingLines;
}
bodyLineWithNewline = bodyLine:bodyLine '\n' { return bodyLine; }
bodyLine = content:(tabStop / bodyText)* { return content; }
bodyText = text:bodyChar+ { return text.join(''); }
bodyChar = !(tabStop) char:[^\n] { return char; }
tabStop = simpleTabStop / tabStopWithPlaceholder
simpleTabStop = '$' index:[0-9]+ {
  return { index: parseInt(index), placeholderText: '' };
}
tabStopWithPlaceholder = '${' index:[0-9]+ ':' placeholderText:[^}]* '}' {
  return { index: parseInt(index), placeholderText: placeholderText.join('') };
}
