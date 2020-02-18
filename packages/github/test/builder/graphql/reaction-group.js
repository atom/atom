import {createSpecBuilderClass, createConnectionBuilderClass} from './base';

import {UserBuilder} from './user';

export const ReactionGroupBuilder = createSpecBuilderClass('ReactionGroup', {
  content: {default: 'ROCKET'},
  viewerHasReacted: {default: false},
  users: {linked: createConnectionBuilderClass('ReactingUser', UserBuilder)},
});
