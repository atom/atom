keystrokePattern = key:key additionalKeys:additionalKey* { return [key].concat(additionalKeys); }
additionalKey = '-' key:key { return key; }
key = '-' / chars:[^-]+ { return chars.join('') }
