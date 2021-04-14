const scopesByFenceName = {
  bash: 'source.shell',
  sh: 'source.shell',
  powershell: 'source.powershell',
  ps1: 'source.powershell',
  c: 'source.c',
  'c++': 'source.cpp',
  cpp: 'source.cpp',
  coffee: 'source.coffee',
  'coffee-script': 'source.coffee',
  coffeescript: 'source.coffee',
  cs: 'source.cs',
  csharp: 'source.cs',
  css: 'source.css',
  sass: 'source.sass',
  scss: 'source.css.scss',
  erlang: 'source.erl',
  go: 'source.go',
  html: 'text.html.basic',
  java: 'source.java',
  javascript: 'source.js',
  js: 'source.js',
  json: 'source.json',
  less: 'source.less',
  mustache: 'text.html.mustache',
  objc: 'source.objc',
  'objective-c': 'source.objc',
  php: 'text.html.php',
  py: 'source.python',
  python: 'source.python',
  rb: 'source.ruby',
  ruby: 'source.ruby',
  text: 'text.plain',
  toml: 'source.toml',
  ts: 'source.ts',
  typescript: 'source.ts',
  xml: 'text.xml',
  yaml: 'source.yaml',
  yml: 'source.yaml'
}

module.exports = {
  scopeForFenceName (fenceName) {
    fenceName = fenceName.toLowerCase()

    return scopesByFenceName.hasOwnProperty(fenceName)
      ? scopesByFenceName[fenceName]
      : `source.${fenceName}`
  }
}
