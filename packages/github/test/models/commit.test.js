import dedent from 'dedent-js';

import {nullCommit} from '../../lib/models/commit';
import {commitBuilder} from '../builder/commit';

describe('Commit', function() {
  describe('isBodyLong()', function() {
    it('returns false if the commit message body is short', function() {
      const commit = commitBuilder().messageBody('short').build();
      assert.isFalse(commit.isBodyLong());
    });

    it('returns true if the commit message body is long', function() {
      const messageBody = dedent`
        Lorem ipsum dolor sit amet, et his justo deleniti, omnium fastidii adversarium at has. Mazim alterum sea ea,
        essent malorum persius ne mei. Nam ea tempor qualisque, modus doming te has. Affert dolore albucius te vis, eam
        tantas nullam corrumpit ad, in oratio luptatum eleifend vim.

        Ea salutatus contentiones eos. Eam in veniam facete volutpat, solum appetere adversarium ut quo. Vel cu appetere
        urbanitas, usu ut aperiri mediocritatem, alia molestie urbanitas cu qui. Velit antiopam erroribus no eum,
        scripta iudicabit ne nam, in duis clita commodo sit.

        Assum sensibus oportere te vel, vis semper evertitur definiebas in. Tamquam feugiat comprehensam ut his, et eum
        voluptua ullamcorper, ex mei debitis inciderint. Sit discere pertinax te, an mei liber putant. Ad doctus
        tractatos ius, duo ad civibus alienum, nominati voluptaria sed an. Libris essent philosophia et vix. Nusquam
        reprehendunt et mea. Ea eius omnes voluptua sit.

        No cum illud verear efficiantur. Id altera imperdiet nec. Noster audiam accusamus mei at, no zril libris nemore
        duo, ius ne rebum doctus fuisset. Legimus epicurei in sit, esse purto suscipit eu qui, oporteat deserunt
        delicatissimi sea in. Est id putent accusata convenire, no tibique molestie accommodare quo, cu est fuisset
        offendit evertitur.
      `;
      const commit = commitBuilder().messageBody(messageBody).build();
      assert.isTrue(commit.isBodyLong());
    });

    it('returns true if the commit message body contains too many newlines', function() {
      let messageBody = 'a\n';
      for (let i = 0; i < 50; i++) {
        messageBody += 'a\n';
      }
      const commit = commitBuilder().messageBody(messageBody).build();
      assert.isTrue(commit.isBodyLong());
    });

    it('returns false for a null commit', function() {
      assert.isFalse(nullCommit.isBodyLong());
    });
  });

  describe('abbreviatedBody()', function() {
    it('returns the message body as-is when the body is short', function() {
      const commit = commitBuilder().messageBody('short').build();
      assert.strictEqual(commit.abbreviatedBody(), 'short');
    });

    it('truncates the message body at the last paragraph boundary before the cutoff if one is present', function() {
      const body = dedent`
        Lorem ipsum dolor sit amet, et his justo deleniti, omnium fastidii adversarium at has. Mazim alterum sea ea,
        essent malorum persius ne mei.

        Nam ea tempor qualisque, modus doming te has. Affert dolore albucius te vis, eam tantas nullam corrumpit ad, in
        oratio luptatum eleifend vim.

        Ea salutatus contentiones eos. Eam in veniam facete volutpat, solum appetere adversarium ut quo. Vel cu appetere
        urbanitas, usu ut aperiri mediocritatem, alia molestie urbanitas cu qui.

        Velit antiopam erroribus no eu|m, scripta iudicabit ne nam, in duis clita commodo sit. Assum sensibus oportere
        te vel, vis semper evertitur definiebas in. Tamquam feugiat comprehensam ut his, et eum voluptua ullamcorper, ex
        mei debitis inciderint. Sit discere pertinax te, an mei liber putant. Ad doctus tractatos ius, duo ad civibus
        alienum, nominati voluptaria sed an. Libris essent philosophia et vix. Nusquam reprehendunt et mea. Ea eius
        omnes voluptua sit.
      `;

      const commit = commitBuilder().messageBody(body).build();
      assert.strictEqual(commit.abbreviatedBody(), dedent`
        Lorem ipsum dolor sit amet, et his justo deleniti, omnium fastidii adversarium at has. Mazim alterum sea ea,
        essent malorum persius ne mei.

        Nam ea tempor qualisque, modus doming te has. Affert dolore albucius te vis, eam tantas nullam corrumpit ad, in
        oratio luptatum eleifend vim.
        ...
      `);
    });

    it('truncates the message body at the nearest word boundary before the cutoff if one is present', function() {
      // The | is at the 400-character mark.
      const body = dedent`
        Lorem ipsum dolor sit amet, et his justo deleniti, omnium fastidii adversarium at has. Mazim alterum sea ea,
        essent malorum persius ne mei. Nam ea tempor qualisque, modus doming te has. Affert dolore albucius te vis, eam
        tantas nullam corrumpit ad, in oratio luptatum eleifend vim. Ea salutatus contentiones eos. Eam in veniam facete
        volutpat, solum appetere adversarium ut quo. Vel cu appetere urban|itas, usu ut aperiri mediocritatem, alia
        molestie urbanitas cu qui. Velit antiopam erroribus no eum, scripta iudicabit ne nam, in duis clita commodo
        sit. Assum sensibus oportere te vel, vis semper evertitur definiebas in. Tamquam feugiat comprehensam ut his, et
        eum voluptua ullamcorper, ex mei debitis inciderint. Sit discere pertinax te, an mei liber putant. Ad doctus
        tractatos ius, duo ad civibus alienum, nominati voluptaria sed an. Libris essent philosophia et vix. Nusquam
        reprehendunt et mea. Ea eius omnes voluptua sit. No cum illud verear efficiantur. Id altera imperdiet nec.
        Noster audiam accusamus mei at, no zril libris nemore duo, ius ne rebum doctus fuisset. Legimus epicurei in
        sit, esse purto suscipit eu qui, oporteat deserunt delicatissimi sea in. Est id putent accusata convenire, no
        tibique molestie accommodare quo, cu est fuisset offendit evertitur.
      `;

      const commit = commitBuilder().messageBody(body).build();
      assert.strictEqual(commit.abbreviatedBody(), dedent`
        Lorem ipsum dolor sit amet, et his justo deleniti, omnium fastidii adversarium at has. Mazim alterum sea ea,
        essent malorum persius ne mei. Nam ea tempor qualisque, modus doming te has. Affert dolore albucius te vis, eam
        tantas nullam corrumpit ad, in oratio luptatum eleifend vim. Ea salutatus contentiones eos. Eam in veniam facete
        volutpat, solum appetere adversarium ut quo. Vel cu appetere...
      `);
    });

    it('truncates the message body at the character cutoff if no word or paragraph boundaries can be found', function() {
      // The | is at the 400-character mark.
      const body = 'Loremipsumdolorsitametethisjustodelenitiomniumfastidiiadversariumathas' +
        'MazimalterumseaeaessentmalorumpersiusnemeiNameatemporqualisquemodusdomingtehasAffertdolore' +
        'albuciusteviseamtantasnullamcorrumpitadinoratioluptatumeleifendvimEasalutatuscontentioneseos' +
        'EaminveniamfacetevolutpatsolumappetereadversariumutquoVelcuappetereurbanitasusuutaperiri' +
        'mediocritatemaliamolestieurbanitascuquiVelitantiopamerroribu|snoeumscriptaiudicabitnenamin' +
        'duisclitacommodositAssumsensibusoporteretevelvissemperevertiturdefiniebasinTamquamfeugiat' +
        'comprehensamuthiseteumvoluptuaullamcorperexmeidebitisinciderintSitdiscerepertinaxteanmei' +
        'liberputantAddoctustractatosiusduoadcivibusalienumnominativoluptariasedanLibrisessent' +
        'philosophiaetvixNusquamreprehenduntetmeaEaeiusomnesvoluptuasitNocumilludverearefficianturId' +
        'alteraimperdietnecNosteraudiamaccusamusmeiatnozrillibrisnemoreduoiusnerebumdoctusfuisset' +
        'LegimusepicureiinsitessepurtosuscipiteuquioporteatdeseruntdelicatissimiseainEstidputent' +
        'accusataconvenirenotibiquemolestieaccommodarequocuestfuissetoffenditevertitur';

      // Note that the elision happens three characters before the 400-mark to leave room for the "..."
      const commit = commitBuilder().messageBody(body).build();
      assert.strictEqual(
        commit.abbreviatedBody(),
        'Loremipsumdolorsitametethisjustodelenitiomniumfastidiiadversariumathas' +
        'MazimalterumseaeaessentmalorumpersiusnemeiNameatemporqualisquemodusdomingtehasAffertdolore' +
        'albuciusteviseamtantasnullamcorrumpitadinoratioluptatumeleifendvimEasalutatuscontentioneseos' +
        'EaminveniamfacetevolutpatsolumappetereadversariumutquoVelcuappetereurbanitasusuutaperiri' +
        'mediocritatemaliamolestieurbanitascuquiVelitantiopamerror...',
      );
    });

    it('truncates the message body when it contains too many newlines', function() {
      let messageBody = '';
      for (let i = 0; i < 50; i++) {
        messageBody += `${i}\n`;
      }
      const commit = commitBuilder().messageBody(messageBody).build();
      assert.strictEqual(commit.abbreviatedBody(), '0\n1\n2\n3\n4\n5\n...');
    });
  });

  it('returns the author name', function() {
    const authorName = 'Tilde Ann Thurium';
    const commit = commitBuilder().addAuthor('email', authorName).build();
    assert.strictEqual(commit.getAuthorName(), authorName);
  });

  describe('isEqual()', function() {
    it('returns true when commits are identical', function() {
      const a = commitBuilder()
        .sha('01234')
        .addAuthor('me@email.com', 'me')
        .authorDate(0)
        .messageSubject('subject')
        .messageBody('body')
        .addCoAuthor('me@email.com', 'name')
        .setMultiFileDiff()
        .build();

      const b = commitBuilder()
        .sha('01234')
        .addAuthor('me@email.com', 'me')
        .authorDate(0)
        .messageSubject('subject')
        .messageBody('body')
        .addCoAuthor('me@email.com', 'name')
        .setMultiFileDiff()
        .build();

      assert.isTrue(a.isEqual(b));
    });

    it('returns false if a directly comparable attribute differs', function() {
      const a = commitBuilder().sha('01234').build();
      const b = commitBuilder().sha('56789').build();

      assert.isFalse(a.isEqual(b));
    });

    it('returns false if author differs', function() {
      const a = commitBuilder().addAuthor('Tilde Ann Thurium', 'tthurium@gmail.com').build();

      const b = commitBuilder().addAuthor('Vanessa Yuen', 'vyuen@gmail.com').build();
      assert.isFalse(a.isEqual(b));
    });

    it('returns false if a co-author differs', function() {
      const a = commitBuilder().addCoAuthor('me@email.com', 'me').build();

      const b0 = commitBuilder().addCoAuthor('me@email.com', 'me').addCoAuthor('extra@email.com', 'extra').build();
      assert.isFalse(a.isEqual(b0));

      const b1 = commitBuilder().addCoAuthor('me@email.com', 'different').build();
      assert.isFalse(a.isEqual(b1));
    });

    it('returns false if the diff... differs', function() {
      const a = commitBuilder()
        .setMultiFileDiff(mfp => {
          mfp.addFilePatch(fp => {
            fp.addHunk(hunk => hunk.unchanged('-').added('plus').deleted('minus').unchanged('-'));
          });
        })
        .build();

      const b = commitBuilder()
        .setMultiFileDiff(mfp => {
          mfp.addFilePatch(fp => {
            fp.addHunk(hunk => hunk.unchanged('-').added('different').deleted('patch').unchanged('-'));
          });
        })
        .build();

      assert.isFalse(a.isEqual(b));
    });
  });
});
