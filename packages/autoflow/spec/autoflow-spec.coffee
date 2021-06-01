describe "Autoflow package", ->
  [autoflow, editor, editorElement] = []
  tabLength = 4

  describe "autoflow:reflow-selection", ->
    beforeEach ->
      activationPromise = null

      waitsForPromise ->
        atom.workspace.open()

      runs ->
        editor = atom.workspace.getActiveTextEditor()
        editorElement = atom.views.getView(editor)

        atom.config.set('editor.preferredLineLength', 30)
        atom.config.set('editor.tabLength', tabLength)

        activationPromise = atom.packages.activatePackage('autoflow')

        atom.commands.dispatch editorElement, 'autoflow:reflow-selection'

      waitsForPromise ->
        activationPromise

    it "uses the preferred line length based on the editor's scope", ->
      atom.config.set('editor.preferredLineLength', 4, scopeSelector: '.text.plain.null-grammar')
      editor.setText("foo bar")
      editor.selectAll()
      atom.commands.dispatch editorElement, 'autoflow:reflow-selection'

      expect(editor.getText()).toBe """
        foo
        bar
      """

    it "rearranges line breaks in the current selection to ensure lines are shorter than config.editor.preferredLineLength honoring tabLength", ->
      editor.setText "\t\tThis is the first paragraph and it is longer than the preferred line length so it should be reflowed.\n\n\t\tThis is a short paragraph.\n\n\t\tAnother long paragraph, it should also be reflowed with the use of this single command."

      editor.selectAll()
      atom.commands.dispatch editorElement, 'autoflow:reflow-selection'

      exedOut = editor.getText().replace(/\t/g, Array(tabLength+1).join 'X')
      expect(exedOut).toBe "XXXXXXXXThis is the first\nXXXXXXXXparagraph and it is\nXXXXXXXXlonger than the\nXXXXXXXXpreferred line length\nXXXXXXXXso it should be\nXXXXXXXXreflowed.\n\nXXXXXXXXThis is a short\nXXXXXXXXparagraph.\n\nXXXXXXXXAnother long\nXXXXXXXXparagraph, it should\nXXXXXXXXalso be reflowed with\nXXXXXXXXthe use of this single\nXXXXXXXXcommand."

    it "rearranges line breaks in the current selection to ensure lines are shorter than config.editor.preferredLineLength", ->
      editor.setText """
        This is the first paragraph and it is longer than the preferred line length so it should be reflowed.

        This is a short paragraph.

        Another long paragraph, it should also be reflowed with the use of this single command.
      """

      editor.selectAll()
      atom.commands.dispatch editorElement, 'autoflow:reflow-selection'

      expect(editor.getText()).toBe """
        This is the first paragraph
        and it is longer than the
        preferred line length so it
        should be reflowed.

        This is a short paragraph.

        Another long paragraph, it
        should also be reflowed with
        the use of this single
        command.
      """

    it "is not confused when the selection boundary is between paragraphs", ->
      editor.setText """
        v--- SELECTION STARTS AT THE BEGINNING OF THE NEXT LINE (pos 1,0)

        The preceding newline should not be considered part of this paragraph.

        The newline at the end of this paragraph should be preserved and not
        converted into a space.

        ^--- SELECTION ENDS AT THE BEGINNING OF THE PREVIOUS LINE (pos 6,0)
      """

      editor.setCursorBufferPosition([1, 0])
      editor.selectToBufferPosition([6, 0])
      atom.commands.dispatch editorElement, 'autoflow:reflow-selection'

      expect(editor.getText()).toBe """
        v--- SELECTION STARTS AT THE BEGINNING OF THE NEXT LINE (pos 1,0)

        The preceding newline should
        not be considered part of this
        paragraph.

        The newline at the end of this
        paragraph should be preserved
        and not converted into a
        space.

        ^--- SELECTION ENDS AT THE BEGINNING OF THE PREVIOUS LINE (pos 6,0)
      """

    it "reflows the current paragraph if nothing is selected", ->
      editor.setText """
        This is a preceding paragraph, which shouldn't be modified by a reflow of the following paragraph.

        The quick brown fox jumps over the lazy
        dog. The preceding sentence contains every letter
        in the entire English alphabet, which has absolutely no relevance
        to this test.

        This is a following paragraph, which shouldn't be modified by a reflow of the preciding paragraph.

      """

      editor.setCursorBufferPosition([3, 5])
      atom.commands.dispatch editorElement, 'autoflow:reflow-selection'

      expect(editor.getText()).toBe """
        This is a preceding paragraph, which shouldn't be modified by a reflow of the following paragraph.

        The quick brown fox jumps over
        the lazy dog. The preceding
        sentence contains every letter
        in the entire English
        alphabet, which has absolutely
        no relevance to this test.

        This is a following paragraph, which shouldn't be modified by a reflow of the preciding paragraph.

      """

    it "allows for single words that exceed the preferred wrap column length", ->
      editor.setText("this-is-a-super-long-word-that-shouldn't-break-autoflow and these are some smaller words")

      editor.selectAll()
      atom.commands.dispatch editorElement, 'autoflow:reflow-selection'

      expect(editor.getText()).toBe """
        this-is-a-super-long-word-that-shouldn't-break-autoflow
        and these are some smaller
        words
      """

  describe "reflowing text", ->
    beforeEach ->
      autoflow = require("../lib/autoflow")

    it 'respects current paragraphs', ->
      text = '''
        Lorem ipsum dolor sit amet, consectetur adipiscing elit. Phasellus gravida nibh id magna ullamcorper sagittis. Maecenas
        et enim eu orci tincidunt adipiscing
        aliquam ligula.

        Lorem ipsum dolor sit amet, consectetur adipiscing elit.
        Phasellus gravida
        nibh id magna ullamcorper
        tincidunt adipiscing lacinia a dui. Etiam quis erat dolor.
        rutrum nisl fermentum rhoncus. Duis blandit ligula facilisis fermentum.
      '''

      res = '''
        Lorem ipsum dolor sit amet, consectetur adipiscing elit. Phasellus gravida nibh
        id magna ullamcorper sagittis. Maecenas et enim eu orci tincidunt adipiscing
        aliquam ligula.

        Lorem ipsum dolor sit amet, consectetur adipiscing elit. Phasellus gravida nibh
        id magna ullamcorper tincidunt adipiscing lacinia a dui. Etiam quis erat dolor.
        rutrum nisl fermentum rhoncus. Duis blandit ligula facilisis fermentum.
      '''
      expect(autoflow.reflow(text, wrapColumn: 80)).toEqual res

    it 'respects indentation', ->
      text = '''
        Lorem ipsum dolor sit amet, consectetur adipiscing elit. Phasellus gravida nibh id magna ullamcorper sagittis. Maecenas
        et enim eu orci tincidunt adipiscing
        aliquam ligula.

            Lorem ipsum dolor sit amet, consectetur adipiscing elit.
            Phasellus gravida
            nibh id magna ullamcorper
            tincidunt adipiscing lacinia a dui. Etiam quis erat dolor.
            rutrum nisl fermentum  rhoncus. Duis blandit ligula facilisis fermentum
      '''

      res = '''
        Lorem ipsum dolor sit amet, consectetur adipiscing elit. Phasellus gravida nibh
        id magna ullamcorper sagittis. Maecenas et enim eu orci tincidunt adipiscing
        aliquam ligula.

            Lorem ipsum dolor sit amet, consectetur adipiscing elit. Phasellus gravida
            nibh id magna ullamcorper tincidunt adipiscing lacinia a dui. Etiam quis
            erat dolor. rutrum nisl fermentum  rhoncus. Duis blandit ligula facilisis
            fermentum
      '''
      expect(autoflow.reflow(text, wrapColumn: 80)).toEqual res

    it 'respects prefixed text (comments!)', ->
      text = '''
        Lorem ipsum dolor sit amet, consectetur adipiscing elit. Phasellus gravida nibh id magna ullamcorper sagittis. Maecenas
        et enim eu orci tincidunt adipiscing
        aliquam ligula.

          #  Lorem ipsum dolor sit amet, consectetur adipiscing elit.
          #  Phasellus gravida
          #  nibh id magna ullamcorper
          #  tincidunt adipiscing lacinia a dui. Etiam quis erat dolor.
          #  rutrum nisl fermentum  rhoncus. Duis blandit ligula facilisis fermentum
      '''

      res = '''
        Lorem ipsum dolor sit amet, consectetur adipiscing elit. Phasellus gravida nibh
        id magna ullamcorper sagittis. Maecenas et enim eu orci tincidunt adipiscing
        aliquam ligula.

          #  Lorem ipsum dolor sit amet, consectetur adipiscing elit. Phasellus gravida
          #  nibh id magna ullamcorper tincidunt adipiscing lacinia a dui. Etiam quis
          #  erat dolor. rutrum nisl fermentum  rhoncus. Duis blandit ligula facilisis
          #  fermentum
      '''
      expect(autoflow.reflow(text, wrapColumn: 80)).toEqual res

    it 'respects multiple prefixes (js/c comments)', ->
      text = '''
        // Lorem ipsum dolor sit amet, consectetur adipiscing elit. Phasellus gravida
        et enim eu orci tincidunt adipiscing
        aliquam ligula.
      '''

      res = '''
        // Lorem ipsum dolor sit amet, consectetur adipiscing elit. Phasellus gravida et
        // enim eu orci tincidunt adipiscing aliquam ligula.
      '''
      expect(autoflow.reflow(text, wrapColumn: 80)).toEqual res

    it 'properly handles * prefix', ->
      text = '''
        * Lorem ipsum dolor sit amet, consectetur adipiscing elit. Phasellus gravida
        et enim eu orci tincidunt adipiscing
        aliquam ligula.

          * soidjfiojsoidj foi
      '''

      res = '''
        * Lorem ipsum dolor sit amet, consectetur adipiscing elit. Phasellus gravida et
        * enim eu orci tincidunt adipiscing aliquam ligula.

          * soidjfiojsoidj foi
      '''
      expect(autoflow.reflow(text, wrapColumn: 80)).toEqual res

    it "does not throw invalid regular expression errors (regression)", ->
      text = '''
        *** Lorem ipsum dolor sit amet
      '''

      expect(autoflow.reflow(text, wrapColumn: 80)).toEqual text

    it 'handles different initial indentation', ->
      text = '''
        Magna ea magna fugiat nisi minim in id duis. Culpa sit sint consequat quis elit magna pariatur incididunt
          proident laborum deserunt est aliqua reprehenderit. Occaecat et ex non do Lorem irure adipisicing mollit excepteur
          eu ullamco consectetur. Ex ex Lorem duis labore quis ad exercitation elit dolor non adipisicing. Pariatur commodo ullamco
          culpa dolor sunt enim. Ullamco dolore do ea nulla ut commodo minim consequat cillum ad velit quis.
      '''

      res = '''
        Magna ea magna fugiat nisi minim in id duis. Culpa sit sint consequat quis elit
        magna pariatur incididunt proident laborum deserunt est aliqua reprehenderit.
        Occaecat et ex non do Lorem irure adipisicing mollit excepteur eu ullamco
        consectetur. Ex ex Lorem duis labore quis ad exercitation elit dolor non
        adipisicing. Pariatur commodo ullamco culpa dolor sunt enim. Ullamco dolore do
        ea nulla ut commodo minim consequat cillum ad velit quis.
      '''
      expect(autoflow.reflow(text, wrapColumn: 80)).toEqual res

    it 'properly handles CRLF', ->
      text = "This is the first line and it is longer than the preferred line length so it should be reflowed.\r\nThis is a short line which should\r\nbe reflowed with the following line.\rAnother long line, it should also be reflowed with everything above it when it is all reflowed."

      res =
        '''
        This is the first line and it is longer than the preferred line length so it
        should be reflowed. This is a short line which should be reflowed with the
        following line. Another long line, it should also be reflowed with everything
        above it when it is all reflowed.
        '''
      expect(autoflow.reflow(text, wrapColumn: 80)).toEqual res

    it 'handles cyrillic text', ->
      text = '''
        В начале июля, в чрезвычайно жаркое время, под вечер, один молодой человек вышел из своей каморки, которую нанимал от жильцов в С-м переулке, на улицу и медленно, как бы в нерешимости, отправился к К-ну мосту.
      '''

      res = '''
        В начале июля, в чрезвычайно жаркое время, под вечер, один молодой человек вышел
        из своей каморки, которую нанимал от жильцов в С-м переулке, на улицу и
        медленно, как бы в нерешимости, отправился к К-ну мосту.
      '''

      expect(autoflow.reflow(text, wrapColumn: 80)).toEqual res

    it 'handles `yo` character properly', ->
      # Because there're known problems with this character in major regex engines
      text = 'Ё Ё Ё'

      res = '''
        Ё
        Ё
        Ё
      '''

      expect(autoflow.reflow(text, wrapColumn: 2)).toEqual res

    it 'properly reflows // comments ', ->
      text =
        '''
        // Beard pinterest actually brunch brooklyn jean shorts YOLO. Knausgaard sriracha banh mi, cold-pressed retro whatever ethical man braid asymmetrical fingerstache narwhal. Intelligentsia wolf photo booth, tumblr pinterest quinoa leggings four loko poutine. DIY tattooed drinking vinegar, wolf retro actually aesthetic austin keffiyeh marfa beard. Marfa trust fund salvia sartorial letterpress, keffiyeh plaid butcher. Swag try-hard dreamcatcher direct trade, tacos pickled fanny pack literally meh pinterest slow-carb. Meditation microdosing distillery 8-bit humblebrag migas.
        '''

      res =
        '''
        // Beard pinterest actually brunch brooklyn jean shorts YOLO. Knausgaard
        // sriracha banh mi, cold-pressed retro whatever ethical man braid asymmetrical
        // fingerstache narwhal. Intelligentsia wolf photo booth, tumblr pinterest
        // quinoa leggings four loko poutine. DIY tattooed drinking vinegar, wolf retro
        // actually aesthetic austin keffiyeh marfa beard. Marfa trust fund salvia
        // sartorial letterpress, keffiyeh plaid butcher. Swag try-hard dreamcatcher
        // direct trade, tacos pickled fanny pack literally meh pinterest slow-carb.
        // Meditation microdosing distillery 8-bit humblebrag migas.
        '''

      expect(autoflow.reflow(text, wrapColumn: 80)).toEqual res

    it 'properly reflows /* comments ', ->
      text =
        '''
        /* Beard pinterest actually brunch brooklyn jean shorts YOLO. Knausgaard sriracha banh mi, cold-pressed retro whatever ethical man braid asymmetrical fingerstache narwhal. Intelligentsia wolf photo booth, tumblr pinterest quinoa leggings four loko poutine. DIY tattooed drinking vinegar, wolf retro actually aesthetic austin keffiyeh marfa beard. Marfa trust fund salvia sartorial letterpress, keffiyeh plaid butcher. Swag try-hard dreamcatcher direct trade, tacos pickled fanny pack literally meh pinterest slow-carb. Meditation microdosing distillery 8-bit humblebrag migas. */
        '''

      res =
        '''
        /* Beard pinterest actually brunch brooklyn jean shorts YOLO. Knausgaard
           sriracha banh mi, cold-pressed retro whatever ethical man braid asymmetrical
           fingerstache narwhal. Intelligentsia wolf photo booth, tumblr pinterest
           quinoa leggings four loko poutine. DIY tattooed drinking vinegar, wolf retro
           actually aesthetic austin keffiyeh marfa beard. Marfa trust fund salvia
           sartorial letterpress, keffiyeh plaid butcher. Swag try-hard dreamcatcher
           direct trade, tacos pickled fanny pack literally meh pinterest slow-carb.
           Meditation microdosing distillery 8-bit humblebrag migas. */
        '''

      expect(autoflow.reflow(text, wrapColumn: 80)).toEqual res

    it 'properly reflows pound comments ', ->
      text =
        '''
        # Beard pinterest actually brunch brooklyn jean shorts YOLO. Knausgaard sriracha banh mi, cold-pressed retro whatever ethical man braid asymmetrical fingerstache narwhal. Intelligentsia wolf photo booth, tumblr pinterest quinoa leggings four loko poutine. DIY tattooed drinking vinegar, wolf retro actually aesthetic austin keffiyeh marfa beard. Marfa trust fund salvia sartorial letterpress, keffiyeh plaid butcher. Swag try-hard dreamcatcher direct trade, tacos pickled fanny pack literally meh pinterest slow-carb. Meditation microdosing distillery 8-bit humblebrag migas.
        '''

      res =
        '''
        # Beard pinterest actually brunch brooklyn jean shorts YOLO. Knausgaard sriracha
        # banh mi, cold-pressed retro whatever ethical man braid asymmetrical
        # fingerstache narwhal. Intelligentsia wolf photo booth, tumblr pinterest quinoa
        # leggings four loko poutine. DIY tattooed drinking vinegar, wolf retro actually
        # aesthetic austin keffiyeh marfa beard. Marfa trust fund salvia sartorial
        # letterpress, keffiyeh plaid butcher. Swag try-hard dreamcatcher direct trade,
        # tacos pickled fanny pack literally meh pinterest slow-carb. Meditation
        # microdosing distillery 8-bit humblebrag migas.
        '''

      expect(autoflow.reflow(text, wrapColumn: 80)).toEqual res

    it 'properly reflows - list items ', ->
      text =
        '''
        - Beard pinterest actually brunch brooklyn jean shorts YOLO. Knausgaard sriracha banh mi, cold-pressed retro whatever ethical man braid asymmetrical fingerstache narwhal. Intelligentsia wolf photo booth, tumblr pinterest quinoa leggings four loko poutine. DIY tattooed drinking vinegar, wolf retro actually aesthetic austin keffiyeh marfa beard. Marfa trust fund salvia sartorial letterpress, keffiyeh plaid butcher. Swag try-hard dreamcatcher direct trade, tacos pickled fanny pack literally meh pinterest slow-carb. Meditation microdosing distillery 8-bit humblebrag migas.
        '''

      res =
        '''
        - Beard pinterest actually brunch brooklyn jean shorts YOLO. Knausgaard sriracha
          banh mi, cold-pressed retro whatever ethical man braid asymmetrical
          fingerstache narwhal. Intelligentsia wolf photo booth, tumblr pinterest quinoa
          leggings four loko poutine. DIY tattooed drinking vinegar, wolf retro actually
          aesthetic austin keffiyeh marfa beard. Marfa trust fund salvia sartorial
          letterpress, keffiyeh plaid butcher. Swag try-hard dreamcatcher direct trade,
          tacos pickled fanny pack literally meh pinterest slow-carb. Meditation
          microdosing distillery 8-bit humblebrag migas.
        '''

      expect(autoflow.reflow(text, wrapColumn: 80)).toEqual res

    it 'properly reflows % comments ', ->
      text =
        '''
        % Beard pinterest actually brunch brooklyn jean shorts YOLO. Knausgaard sriracha banh mi, cold-pressed retro whatever ethical man braid asymmetrical fingerstache narwhal. Intelligentsia wolf photo booth, tumblr pinterest quinoa leggings four loko poutine. DIY tattooed drinking vinegar, wolf retro actually aesthetic austin keffiyeh marfa beard. Marfa trust fund salvia sartorial letterpress, keffiyeh plaid butcher. Swag try-hard dreamcatcher direct trade, tacos pickled fanny pack literally meh pinterest slow-carb. Meditation microdosing distillery 8-bit humblebrag migas.
        '''

      res =
        '''
        % Beard pinterest actually brunch brooklyn jean shorts YOLO. Knausgaard sriracha
        % banh mi, cold-pressed retro whatever ethical man braid asymmetrical
        % fingerstache narwhal. Intelligentsia wolf photo booth, tumblr pinterest quinoa
        % leggings four loko poutine. DIY tattooed drinking vinegar, wolf retro actually
        % aesthetic austin keffiyeh marfa beard. Marfa trust fund salvia sartorial
        % letterpress, keffiyeh plaid butcher. Swag try-hard dreamcatcher direct trade,
        % tacos pickled fanny pack literally meh pinterest slow-carb. Meditation
        % microdosing distillery 8-bit humblebrag migas.
        '''

      expect(autoflow.reflow(text, wrapColumn: 80)).toEqual res

    it "properly reflows roxygen comments ", ->
      text =
        '''
        #' Beard pinterest actually brunch brooklyn jean shorts YOLO. Knausgaard sriracha banh mi, cold-pressed retro whatever ethical man braid asymmetrical fingerstache narwhal. Intelligentsia wolf photo booth, tumblr pinterest quinoa leggings four loko poutine. DIY tattooed drinking vinegar, wolf retro actually aesthetic austin keffiyeh marfa beard. Marfa trust fund salvia sartorial letterpress, keffiyeh plaid butcher. Swag try-hard dreamcatcher direct trade, tacos pickled fanny pack literally meh pinterest slow-carb. Meditation microdosing distillery 8-bit humblebrag migas.
        '''

      res =
        '''
        #' Beard pinterest actually brunch brooklyn jean shorts YOLO. Knausgaard
        #' sriracha banh mi, cold-pressed retro whatever ethical man braid asymmetrical
        #' fingerstache narwhal. Intelligentsia wolf photo booth, tumblr pinterest
        #' quinoa leggings four loko poutine. DIY tattooed drinking vinegar, wolf retro
        #' actually aesthetic austin keffiyeh marfa beard. Marfa trust fund salvia
        #' sartorial letterpress, keffiyeh plaid butcher. Swag try-hard dreamcatcher
        #' direct trade, tacos pickled fanny pack literally meh pinterest slow-carb.
        #' Meditation microdosing distillery 8-bit humblebrag migas.
        '''

      expect(autoflow.reflow(text, wrapColumn: 80)).toEqual res

    it "properly reflows -- comments ", ->
      text =
        '''
        -- Beard pinterest actually brunch brooklyn jean shorts YOLO. Knausgaard sriracha banh mi, cold-pressed retro whatever ethical man braid asymmetrical fingerstache narwhal. Intelligentsia wolf photo booth, tumblr pinterest quinoa leggings four loko poutine. DIY tattooed drinking vinegar, wolf retro actually aesthetic austin keffiyeh marfa beard. Marfa trust fund salvia sartorial letterpress, keffiyeh plaid butcher. Swag try-hard dreamcatcher direct trade, tacos pickled fanny pack literally meh pinterest slow-carb. Meditation microdosing distillery 8-bit humblebrag migas.
        '''

      res =
        '''
        -- Beard pinterest actually brunch brooklyn jean shorts YOLO. Knausgaard
        -- sriracha banh mi, cold-pressed retro whatever ethical man braid asymmetrical
        -- fingerstache narwhal. Intelligentsia wolf photo booth, tumblr pinterest
        -- quinoa leggings four loko poutine. DIY tattooed drinking vinegar, wolf retro
        -- actually aesthetic austin keffiyeh marfa beard. Marfa trust fund salvia
        -- sartorial letterpress, keffiyeh plaid butcher. Swag try-hard dreamcatcher
        -- direct trade, tacos pickled fanny pack literally meh pinterest slow-carb.
        -- Meditation microdosing distillery 8-bit humblebrag migas.
        '''

      expect(autoflow.reflow(text, wrapColumn: 80)).toEqual res

    it "properly reflows ||| comments ", ->
      text =
        '''
        ||| Beard pinterest actually brunch brooklyn jean shorts YOLO. Knausgaard sriracha banh mi, cold-pressed retro whatever ethical man braid asymmetrical fingerstache narwhal. Intelligentsia wolf photo booth, tumblr pinterest quinoa leggings four loko poutine. DIY tattooed drinking vinegar, wolf retro actually aesthetic austin keffiyeh marfa beard. Marfa trust fund salvia sartorial letterpress, keffiyeh plaid butcher. Swag try-hard dreamcatcher direct trade, tacos pickled fanny pack literally meh pinterest slow-carb. Meditation microdosing distillery 8-bit humblebrag migas.
        '''

      res =
        '''
        ||| Beard pinterest actually brunch brooklyn jean shorts YOLO. Knausgaard
        ||| sriracha banh mi, cold-pressed retro whatever ethical man braid asymmetrical
        ||| fingerstache narwhal. Intelligentsia wolf photo booth, tumblr pinterest
        ||| quinoa leggings four loko poutine. DIY tattooed drinking vinegar, wolf retro
        ||| actually aesthetic austin keffiyeh marfa beard. Marfa trust fund salvia
        ||| sartorial letterpress, keffiyeh plaid butcher. Swag try-hard dreamcatcher
        ||| direct trade, tacos pickled fanny pack literally meh pinterest slow-carb.
        ||| Meditation microdosing distillery 8-bit humblebrag migas.
        '''

      expect(autoflow.reflow(text, wrapColumn: 80)).toEqual res

    it 'properly reflows ;; comments ', ->
      text =
        '''
        ;; Beard pinterest actually brunch brooklyn jean shorts YOLO. Knausgaard sriracha banh mi, cold-pressed retro whatever ethical man braid asymmetrical fingerstache narwhal. Intelligentsia wolf photo booth, tumblr pinterest quinoa leggings four loko poutine. DIY tattooed drinking vinegar, wolf retro actually aesthetic austin keffiyeh marfa beard. Marfa trust fund salvia sartorial letterpress, keffiyeh plaid butcher. Swag try-hard dreamcatcher direct trade, tacos pickled fanny pack literally meh pinterest slow-carb. Meditation microdosing distillery 8-bit humblebrag migas.
        '''

      res =
        '''
        ;; Beard pinterest actually brunch brooklyn jean shorts YOLO. Knausgaard
        ;; sriracha banh mi, cold-pressed retro whatever ethical man braid asymmetrical
        ;; fingerstache narwhal. Intelligentsia wolf photo booth, tumblr pinterest
        ;; quinoa leggings four loko poutine. DIY tattooed drinking vinegar, wolf retro
        ;; actually aesthetic austin keffiyeh marfa beard. Marfa trust fund salvia
        ;; sartorial letterpress, keffiyeh plaid butcher. Swag try-hard dreamcatcher
        ;; direct trade, tacos pickled fanny pack literally meh pinterest slow-carb.
        ;; Meditation microdosing distillery 8-bit humblebrag migas.
        '''

      expect(autoflow.reflow(text, wrapColumn: 80)).toEqual res

    it 'does not treat lines starting with a single semicolon as ;; comments', ->
      text =
        '''
        ;! Beard pinterest actually brunch brooklyn jean shorts YOLO. Knausgaard sriracha banh mi, cold-pressed retro whatever ethical man braid asymmetrical fingerstache narwhal. Intelligentsia wolf photo booth, tumblr pinterest quinoa leggings four loko poutine. DIY tattooed drinking vinegar, wolf retro actually aesthetic austin keffiyeh marfa beard. Marfa trust fund salvia sartorial letterpress, keffiyeh plaid butcher. Swag try-hard dreamcatcher direct trade, tacos pickled fanny pack literally meh pinterest slow-carb. Meditation microdosing distillery 8-bit humblebrag migas.
        '''

      res =
        '''
        ;! Beard pinterest actually brunch brooklyn jean shorts YOLO. Knausgaard
        sriracha banh mi, cold-pressed retro whatever ethical man braid asymmetrical
        fingerstache narwhal. Intelligentsia wolf photo booth, tumblr pinterest quinoa
        leggings four loko poutine. DIY tattooed drinking vinegar, wolf retro actually
        aesthetic austin keffiyeh marfa beard. Marfa trust fund salvia sartorial
        letterpress, keffiyeh plaid butcher. Swag try-hard dreamcatcher direct trade,
        tacos pickled fanny pack literally meh pinterest slow-carb. Meditation
        microdosing distillery 8-bit humblebrag migas.
        '''

      expect(autoflow.reflow(text, wrapColumn: 80)).toEqual res

    it 'properly reflows > ascii email inclusions ', ->
      text =
        '''
        > Beard pinterest actually brunch brooklyn jean shorts YOLO. Knausgaard sriracha banh mi, cold-pressed retro whatever ethical man braid asymmetrical fingerstache narwhal. Intelligentsia wolf photo booth, tumblr pinterest quinoa leggings four loko poutine. DIY tattooed drinking vinegar, wolf retro actually aesthetic austin keffiyeh marfa beard. Marfa trust fund salvia sartorial letterpress, keffiyeh plaid butcher. Swag try-hard dreamcatcher direct trade, tacos pickled fanny pack literally meh pinterest slow-carb. Meditation microdosing distillery 8-bit humblebrag migas.
        '''

      res =
        '''
        > Beard pinterest actually brunch brooklyn jean shorts YOLO. Knausgaard sriracha
        > banh mi, cold-pressed retro whatever ethical man braid asymmetrical
        > fingerstache narwhal. Intelligentsia wolf photo booth, tumblr pinterest quinoa
        > leggings four loko poutine. DIY tattooed drinking vinegar, wolf retro actually
        > aesthetic austin keffiyeh marfa beard. Marfa trust fund salvia sartorial
        > letterpress, keffiyeh plaid butcher. Swag try-hard dreamcatcher direct trade,
        > tacos pickled fanny pack literally meh pinterest slow-carb. Meditation
        > microdosing distillery 8-bit humblebrag migas.
        '''

      expect(autoflow.reflow(text, wrapColumn: 80)).toEqual res

    it "doesn't allow special characters to surpass wrapColumn", ->
      test =
        '''
        Imagine that I'm writing some LaTeX code. I start a comment, but change my mind. %

        Now I'm just kind of trucking along, doing some math and stuff. For instance, $3 + 4 = 7$. But maybe I'm getting really crazy and I use subtraction. It's kind of an obscure technique, but often it goes a bit like this: let $x = 2 + 2$, so $x - 1 = 3$ (quick maths).

        That's OK I guess, but now look at this cool thing called set theory: $\\{n + 42 : n \\in \\mathbb{N}\\}$. Wow. Neat. But we all know why we're really here. If you peer deep down into your heart, and you stare into the depths of yourself: is $P = NP$? Beware, though; many have tried and failed to answer this question. It is by no means for the faint of heart.
        '''

      res =
        '''
        Imagine that I'm writing some LaTeX code. I start a comment, but change my mind.
        %

        Now I'm just kind of trucking along, doing some math and stuff. For instance, $3
        + 4 = 7$. But maybe I'm getting really crazy and I use subtraction. It's kind of
        an obscure technique, but often it goes a bit like this: let $x = 2 + 2$, so $x
        - 1 = 3$ (quick maths).

        That's OK I guess, but now look at this cool thing called set theory: $\\{n + 42
        : n \\in \\mathbb{N}\\}$. Wow. Neat. But we all know why we're really here. If you
        peer deep down into your heart, and you stare into the depths of yourself: is $P
        = NP$? Beware, though; many have tried and failed to answer this question. It is
        by no means for the faint of heart.
        '''

      expect(autoflow.reflow(test, wrapColumn: 80)).toEqual res

    describe 'LaTeX', ->
      it 'properly reflows text around LaTeX tags', ->
        text =
          '''
          \\begin{verbatim}
              Lorem ipsum dolor sit amet, nisl odio amet, et tempor netus neque at at blandit, vel vestibulum libero dolor, semper lobortis ligula praesent. Eget condimentum integer, porta sagittis nam, fusce vitae a vitae augue. Nec semper quis sed ut, est porttitor praesent. Nisl velit quam dolore velit quam, elementum neque pellentesque pulvinar et vestibulum.
          \\end{verbatim}
          '''

        res =
          '''
          \\begin{verbatim}
              Lorem ipsum dolor sit amet, nisl odio amet, et tempor netus neque at at
              blandit, vel vestibulum libero dolor, semper lobortis ligula praesent. Eget
              condimentum integer, porta sagittis nam, fusce vitae a vitae augue. Nec
              semper quis sed ut, est porttitor praesent. Nisl velit quam dolore velit
              quam, elementum neque pellentesque pulvinar et vestibulum.
          \\end{verbatim}
          '''

        expect(autoflow.reflow(text, wrapColumn: 80)).toEqual res

      it 'properly reflows text inside LaTeX tags', ->
        text =
          '''
          \\item{
              Lorem ipsum dolor sit amet, nisl odio amet, et tempor netus neque at at blandit, vel vestibulum libero dolor, semper lobortis ligula praesent. Eget condimentum integer, porta sagittis nam, fusce vitae a vitae augue. Nec semper quis sed ut, est porttitor praesent. Nisl velit quam dolore velit quam, elementum neque pellentesque pulvinar et vestibulum.
          }
          '''

        res =
          '''
          \\item{
              Lorem ipsum dolor sit amet, nisl odio amet, et tempor netus neque at at
              blandit, vel vestibulum libero dolor, semper lobortis ligula praesent. Eget
              condimentum integer, porta sagittis nam, fusce vitae a vitae augue. Nec
              semper quis sed ut, est porttitor praesent. Nisl velit quam dolore velit
              quam, elementum neque pellentesque pulvinar et vestibulum.
          }
          '''

        expect(autoflow.reflow(text, wrapColumn: 80)).toEqual res

      it 'properly reflows text inside nested LaTeX tags', ->
        text =
          '''
          \\begin{enumerate}[label=(\\alph*)]
              \\item{
                  Lorem ipsum dolor sit amet, nisl odio amet, et tempor netus neque at at blandit, vel vestibulum libero dolor, semper lobortis ligula praesent. Eget condimentum integer, porta sagittis nam, fusce vitae a vitae augue. Nec semper quis sed ut, est porttitor praesent. Nisl velit quam dolore velit quam, elementum neque pellentesque pulvinar et vestibulum.
              }
          \\end{enumerate}
          '''

        res =
          '''
          \\begin{enumerate}[label=(\\alph*)]
              \\item{
                  Lorem ipsum dolor sit amet, nisl odio amet, et tempor netus neque at at
                  blandit, vel vestibulum libero dolor, semper lobortis ligula praesent.
                  Eget condimentum integer, porta sagittis nam, fusce vitae a vitae augue.
                  Nec semper quis sed ut, est porttitor praesent. Nisl velit quam dolore
                  velit quam, elementum neque pellentesque pulvinar et vestibulum.
              }
          \\end{enumerate}
          '''

        expect(autoflow.reflow(text, wrapColumn: 80)).toEqual res

      it 'does not attempt to reflow a selection that contains only LaTeX tags and nothing else', ->
        text =
          '''
          \\begin{enumerate}
          \\end{enumerate}
          '''

        expect(autoflow.reflow(text, wrapColumn: 5)).toEqual text
