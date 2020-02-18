import React from 'react';
import {shallow} from 'enzyme';
import dedent from 'dedent-js';

import {cloneRepository, buildRepository} from '../helpers';
import CommitDetailItem from '../../lib/items/commit-detail-item';
import CommitDetailController from '../../lib/controllers/commit-detail-controller';

const VALID_SHA = '18920c900bfa6e4844853e7e246607a31c3e2e8c';

describe('CommitDetailController', function() {
  let atomEnv, repository, commit;

  beforeEach(async function() {
    atomEnv = global.buildAtomEnvironment();
    repository = await buildRepository(await cloneRepository('multiple-commits'));
    commit = await repository.getCommit(VALID_SHA);
  });

  afterEach(function() {
    atomEnv.destroy();
  });

  function buildApp(override = {}) {
    const props = {
      repository,
      commit,
      itemType: CommitDetailItem,

      workspace: atomEnv.workspace,
      commands: atomEnv.commands,
      keymaps: atomEnv.keymaps,
      tooltips: atomEnv.tooltips,
      config: atomEnv.config,
      destroy: () => {},

      ...override,
    };

    return <CommitDetailController {...props} />;
  }

  it('forwards props to its CommitDetailView', function() {
    const wrapper = shallow(buildApp());
    const view = wrapper.find('CommitDetailView');

    assert.strictEqual(view.prop('repository'), repository);
    assert.strictEqual(view.prop('commit'), commit);
    assert.strictEqual(view.prop('itemType'), CommitDetailItem);
  });

  it('passes unrecognized props to its CommitDetailView', function() {
    const extra = Symbol('extra');
    const wrapper = shallow(buildApp({extra}));
    assert.strictEqual(wrapper.find('CommitDetailView').prop('extra'), extra);
  });

  describe('commit body collapsing', function() {
    const LONG_MESSAGE = dedent`
      Lorem ipsum dolor sit amet, et his justo deleniti, omnium fastidii adversarium at has. Mazim alterum sea ea,
      essent malorum persius ne mei. Nam ea tempor qualisque, modus doming te has. Affert dolore albucius te vis, eam
      tantas nullam corrumpit ad, in oratio luptatum eleifend vim.

      Ea salutatus contentiones eos. Eam in veniam facete volutpat, solum appetere adversarium ut quo. Vel cu appetere
      urbanitas, usu ut aperiri mediocritatem, alia molestie urbanitas cu qui. Velit antiopam erroribus no eum, scripta
      iudicabit ne nam, in duis clita commodo sit.

      Assum sensibus oportere te vel, vis semper evertitur definiebas in. Tamquam feugiat comprehensam ut his, et eum
      voluptua ullamcorper, ex mei debitis inciderint. Sit discere pertinax te, an mei liber putant. Ad doctus tractatos
      ius, duo ad civibus alienum, nominati voluptaria sed an. Libris essent philosophia et vix. Nusquam reprehendunt et
      mea. Ea eius omnes voluptua sit.

      No cum illud verear efficiantur. Id altera imperdiet nec. Noster audiam accusamus mei at, no zril libris nemore
      duo, ius ne rebum doctus fuisset. Legimus epicurei in sit, esse purto suscipit eu qui, oporteat deserunt
      delicatissimi sea in. Est id putent accusata convenire, no tibique molestie accommodare quo, cu est fuisset
      offendit evertitur.
    `;

    it('is uncollapsible if the commit message is short', function() {
      sinon.stub(commit, 'getMessageBody').returns('short');
      const wrapper = shallow(buildApp());
      const view = wrapper.find('CommitDetailView');
      assert.isFalse(view.prop('messageCollapsible'));
      assert.isTrue(view.prop('messageOpen'));
    });

    it('is collapsible and begins collapsed if the commit message is long', function() {
      sinon.stub(commit, 'getMessageBody').returns(LONG_MESSAGE);

      const wrapper = shallow(buildApp());
      const view = wrapper.find('CommitDetailView');
      assert.isTrue(view.prop('messageCollapsible'));
      assert.isFalse(view.prop('messageOpen'));
    });

    it('toggles collapsed state', async function() {
      sinon.stub(commit, 'getMessageBody').returns(LONG_MESSAGE);

      const wrapper = shallow(buildApp());
      assert.isFalse(wrapper.find('CommitDetailView').prop('messageOpen'));

      await wrapper.find('CommitDetailView').prop('toggleMessage')();

      assert.isTrue(wrapper.find('CommitDetailView').prop('messageOpen'));
    });
  });
});
