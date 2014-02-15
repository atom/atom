
module.exports = (grunt) ->
  grunt.registerTask 'report-licenses', 'Report the licenses of all dependencies', ->
    legalEagle = require 'legal-eagle'
    done = @async()

    options =
      path: process.cwd()
      overrides: ManualOverrides

    legalEagle options, (err, summary) ->
      if err?
        console.error(err)
        exit 1
      console.log getSummaryText(summary)
      done()

getSummaryText = (summary) ->
  {keys} = require 'underscore-plus'
  text = ""
  names = keys(summary).sort()
  for name in names
    {license, source, sourceText} = summary[name]
    text += "## #{name}\n\n"
    text += "* License: #{license}\n"
    text += "* License Source: #{source}\n" if source?
    if sourceText?
      text += "* Source Text:\n"
      for line in sourceText.split('\n')
        text += "> #{line}\n"
    text += '\n'
  text

ManualOverrides =
  'underscore@1.4.4':
    repository: 'https://github.com/documentcloud/underscore'
    license: 'MIT'
    source: 'LICENSE'
    sourceText: """
      Copyright (c) 2009-2013 Jeremy Ashkenas, DocumentCloud and Investigative
      Reporters & Editors

      Permission is hereby granted, free of charge, to any person
      obtaining a copy of this software and associated documentation
      files (the "Software"), to deal in the Software without
      restriction, including without limitation the rights to use,
      copy, modify, merge, publish, distribute, sublicense, and/or sell
      copies of the Software, and to permit persons to whom the
      Software is furnished to do so, subject to the following
      conditions:

      The above copyright notice and this permission notice shall be
      included in all copies or substantial portions of the Software.

      THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
      EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES
      OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
      NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT
      HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
      WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
      FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
      OTHER DEALINGS IN THE SOFTWARE.
    """
