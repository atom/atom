# GraphQL Builders

Consistently mocking the results from a GraphQL query fragment is difficult and error-prone. To help, these specialized builders use Relay-generated modules to ensure that the mock data we're constructing in our tests accurately reflects the shape of the real props that Relay will provide us at runtime.

## Using these builders in tests

GraphQL builders are intended to be used when you're writing tests for a component that's wrapped in a [Relay fragment container](https://facebook.github.io/relay/docs/en/fragment-container.html). Here's an example component we can use:

```js
import {React} from 'react';
import {createFragmentContainer, graphql} from 'react-relay';

export class BareUserView extends React.Component {
  render() {
    return (
      <div>
        <p>ID: {this.props.user.id}</p>
        <p>Login: {this.props.user.login}</p>
        <p>Real name: {this.props.user.realName}</p>
        <p>Role: {this.props.role.displayName}</p>
        {this.props.permissions.edges.map(e => (
          <p key={p.id}>Permission: {p.displayName}</p>
        ))}
      </div>
    )
  }
}

export default createFragmentContainer(BareUserView, {
  user: graphql`
    fragment userView_user on User {
      id
      login
      realName
    }
  `,
  role: graphql`
    fragment userView_role on Role {
      displayName
      internalName
      permissions {
        edge {
          node {
            id
            displayName
            aliasedField: userCount
          }
        }
      }
    }
  `,
})
```

Begin by locating the generated `*.graphql.js` files that correspond to the fragments the component is requesting. These should be located within a `__generated__` directory that's a sibling to the component source, with a filename based on the fragment name. In this case, they would be called `./__generated__/userView_user.graphql.js` and `./__generated__/userView_role.graphql.js`.

In your test file, import each of these modules, as well as the builder method corresponding to each fragment's root type:

```js
import {userBuilder} from '../builders/graphql/user';
import {roleBuilder} from '../builders/graphql/role';

import userQuery from '../../lib/views/__generated__/userView_user.graphql';
import roleQuery from '../../lib/views/__generated__/userView_role.graphql';
```

Now, when writing your test cases, call the builder method with the corresponding query to create a builder object. The builder has accessor methods corresponding to each property requested in the fragment. Set only the fields that you care about in that specific test, then call `.build()` to construct a prop ready to pass to your component.

```js
it('shows the user correctly', function() {
  // Scalar fields have accessors that accept their value directly.
  const user = userBuilder(userQuery)
    .login('the login')
    .realName('Real Name')
    .build();

  const wrapper = shallow(
    <UserView user={user} role={roleBuilder(roleQuery).build()} />,
  );

  // Assert that "the login" and "Real Name" show up in the right bits.
});

it('shows the role permissions', function() {
  // Linked fields have accessors that accept a block, which is called with a builder instance configured for the
  // linked type.
  const role = roleBuilder(roleQuery)
    .displayName('The Role')
    .permissions(conn => {
      conn.addEdge(e => e.node(p => p.displayName('Permission One')));

      // Note that aliased fields have accessors based on the *alias*
      conn.addEdge(e => e.node(p => p.displayName('Permission Two').aliasedField(7)));
    })
    .build();

  const wrapper = shallow(
    <UserView user={userBuilder(userQuery).build()} role={role} />,
  );

  // Assert that "Permission One" and "Permission Two" show up correctly.
});

// Will automatically include default, internally consistent props for anything that's requested by the GraphQL
// fragments, but not set with accessors.
it("doesn't care about the GraphQL response at all", function() {
  const wrapper = shallow(
    <UserView user={userBuilder(userQuery).build()}
    role={roleBuilder(roleQuery).build()}
  />);
})
```

If you add a field to your query, re-run `npm run relay`, and add the field to the builder, its default value will automatically be included in tests for any queries that request that field. If you remove a field from your query and re-run `npm run relay`, it will be omitted from the built objects, and tests that attempt to populate it with a setter will fail with an exception.

```js
it("will fail because this field is not included in this component's fragment", function() {
  const user = userBuilder(userQuery)
    .email('me@email.com')
    .build();
})
```

### Integration tests

Within our [integration tests](/test/integration), rather than constructing data to mimic what Relay is expected to provide a single component, we need to mimic what Relay itself expects to see from the live GraphQL API. These tests use the `expectRelayQuery()` method to supply this mock data to Relay's network layer. However, the format of the response data differs from the props passed to any component wrapped in a fragment container:

* Relay implicitly selects `id` and `__typename` fields on certain GraphQL types (but not all of them).
* Data from non-inline fragment spreads are included in-place.
* The top-level object is wrapped in a `{data: }` sandwich.

To generate mock data consistent with the final GraphQL query, use the special `relayResponseBuilder()`. The Relay response builder is able to parse the actual query text and use _that_ instead of a pre-parsed relay-compiler fragment to choose which fields to include.

```js
import {expectRelayQuery} from '../../lib/relay-network-layer-manager';
import {relayResponseBuilder} from '../builder/graphql/query';

describe('integration: doing a thing', function() {
  function expectSomeQuery() {
    return expectRelayQuery({
      name: 'someContainerQuery',
      variables: {
        one: 1,
        two: 'two',
      },
    }, op => {
      return relayResponseBuilder(op)
        .repository(r => {
          // These builders operate as before
          r.name('pushbot');
        })
        .build();
    })
  }

  // ...
});
```

⚠️ One major problem to watch for: if two queries used by the same integration test return data for _the same field_, you _must ensure that the IDs of the objects built at that field are the same_. Otherwise, you'll mess up Relay's store and start to see `undefined` for fields extracted from props.

For example:

```js
import {expectRelayQuery} from '../../lib/relay-network-layer-manager';
import {relayResponseBuilder} from '../builder/graphql/query';

describe('integration: doing a thing', function() {
  const repositoryID = 'repository0';

  // query { repository(name: 'x', owner: 'y') { pullRequest(number: 123) { id } } }
  function expectQueryOne() {
    return expectRelayQuery({name: 'containerOneQuery'}, op => {
      return relayResponseBuilder(op)
        .repository(r => {
          r.id(repositoryID); // <-- MUST MATCH
          r.pullRequest(pr => pr.number(123));
        })
        .build();
    })
  }

  // query { repository(name: 'x', owner: 'y') { issue(number: 456) { id } } }
  function expectQueryTwo() {
    return expectRelayQuery({name: 'containerTwoQuery'}, op => {
      return relayResponseBuilder(op)
        .repository(r => {
          r.id(repositoryID); // <-- MUST MATCH
          r.issue(i => i.number(456));
        })
        .build();
    })
  }

  // ...
});
```

## Writing builders

By convention, GraphQL builders should reside in the [`test/builder/graphql`](/test/builder/graphql) directory. Builders are organized into modules by the object type they construct, although some closely interrelated builders may be defined in the same module for convenience, like pull requests and review threads. In general, one builder class should exist for each GraphQL object type that we care about.

GraphQL builders may be constructed with the `createSpecBuilderClass()` method, defined in [`test/builder/graphql/helpers.js`](/test/builder/graphql/helpers.js). It accepts the name of the GraphQL type it expects to construct and an object describing the behavior of individual fields within that type.

Each key of the object describes a single field in the GraphQL response that the builder knows how to construct. The value that you provide is a sub-object that customizes the details of that field's construction. The set of keys passed to any single builder should be the **superset** of fields and aliases selected on its type in any query or fragment within the package.

Here's an example that illustrates the behavior of each recognized field description:

```js
import {createSpecBuilderClass} from './base';

export const CheckRunBuilder = createSpecBuilderClass('CheckRun', {
  // Simple, scalar field.
  // Generates an accessor method called ".name(_value)" that sets `.name` and returns the builder.
  // The "default" value is used if .name() is not called before `.build()`.
  name: {default: 'the check run'},

  // "default" may also be a function which will be invoked to construct this value in each constructed result.
  id: {default: () => { nextID++; return nextID; }},

  // The "default" function may accept an argument. Its properties will be the other, populated fields on the object
  // under construction. Beware: if a field you depend on isn't available, its property will be `undefined`.
  url: {default: f => {
    const id = f.id || 123;
    return `https://github.com/atom/atom/pull/123/checks?check_run_id=${id}`;
  }}

  // This field is a collection. It implicitly defaults to [].
  // Generates an accessor method called "addString()" that accepts a String and appends it to an array in the final
  // object, then returns the builder.
  strings: {plural: true, singularName: 'string'},

  // This field has a default, but may be omitted from real responses.
  // Generates accessor methods called ".summary(_value)" and ".nullSummary()". `.nullSummary` will explicitly set the
  // field to `null` and prevent its default value from being used. `.summary(null)` will work as well.
  summary: {default: 'some summary', nullable: true},

  // This field is a composite type.
  // Generates an accessor method called `.repository(_block = () => {})` that invokes its block with a
  // RepositoryBuilder instance. The model constructed by `.build()` is then set as this builder's "repository" field,
  // and the builder is returned.
  // If the accessor is not called, or if no block is provided, the `RepositoryBuilder` is used to set defaults for all
  // requested repository fields.
  repository: {linked: RepositoryBuilder},

  // This field is a collection of composite types. If defaults to [].
  // An `.addLine(block = () => {})` method is created that constructs a Line object with a LineBuilder.
  lines: {linked: LineBuilder, plural: true, singularName: 'line'},

  // "custom" allows you to add an arbitrary method to the builder class with the name of the field. "this" will be
  // set to the builder instance, so you can use this to define things like arbitrary, composite field setters, or field
  // aliases.
  extra: {custom: function() {}},

// (Optional) a String describing the interfaces implemented by this type in the schema, separated by &.
}, 'Node & UniformResourceLocatable');

// By convention, I export a method that creates each top-level builder type. (It makes the method call read slightly
// cleaner.)
export function checkRunBuilder(...nodes) {
  return CheckRunBuilder.onFragmentQuery(nodes);
}
```

### Paginated collections

One common pattern used in GraphQL schema is a [connection type](https://facebook.github.io/relay/graphql/connections.htm) for traversing a paginated collection. The `createConnectionBuilderClass()` method constructs the builders needed, saving a little bit of boilerplate.

```js
import {createConnectionBuilderClass} from './base';

export const CommentBuilder = createSpecBuilderClass('PullRequestReviewComment', {
  path: {default: 'first.txt'},
})

export const CommentConnectionBuilder = createConnectionBuilderClass(
  'PullRequestReviewComment',
  CommentBuilder,
);


export const ReviewThreadBuilder = createSpecBuilderClass('PullRequestReviewThread', {
  comments: {linked: CommentConnectionBuilder},
});
```

The connection builder class can be used like any other builder:

```js
const reviewThread = reviewThreadBuilder(query)
  .pageInfo(i => {
    i.hasNextPage(true); // defaults to false
    i.endCursor('zzz'); // defaults to null
  })
  .addEdge(e => {
    e.cursor('aaa'); // defaults to an arbitrary string

    // .node() is a linked builder of the builder class you provided to createConnectionBuilderClass()
    e.node(c => c.path('file0.txt'));
  })
  // Can also populate the direct "nodes" link
  .addNode(c => c.path('file1.txt'));
  .totalCount(100) // Will be inferred from `.addNode` or `.addEdge` calls if either are configured
  .build();
```

### Union types

Sometimes, a GraphQL field's type will be specified as an interface which many concrete types may implement. To allow callers to construct the linked object as one of the concrete types, use a _union builder class_:

```js
import {createSpecBuilderClass, createUnionBuilderClass} from './base';

// A pair of builders for concrete types

const IssueBuilder = createSpecBuilderClass('Issue', {
  number: {default: 100},
});

const PullRequestBuilder = createSpecBuilderClass('PullRequest', {
  number: {default: 200},
});

// A union builder that may construct either of them.
// The convention is to specify each alternative as "beTypeName()".

const IssueishBuilder = createUnionBuilderClass('Issueish', {
  beIssue: IssueBuilder,
  bePullRequest: PullRequestBuilder,
  default: 'beIssue',
});

// Another builder that uses the union builder as a linked type

const RepositoryBuilder = createSpecBuilderClass('Repository', {
  issueOrPullRequest: {linked: IssueishBuilder},
});
```

The concrete type for a specific response may be chosen by calling one of the "be" methods on the union builder, which behaves just like a linked field:

```js
repositoryBuilder(someFragment)
  .issueOrPullRequest(u => {
    u.bePullRequest(pr => {
      pr.number(300);
    });
  })
  .build();
```

### Circular dependencies

When writing builders, you'll often hit a situation where two builders in two source files have a circular dependency on one another. If this happens, the builder class will be `undefined` in one of the modules.

To resolve this, on either side, use the `defer()` helper to lazily load the builder when it's used:

```js
const {createSpecBuilderClass, defer} = require('./base');

// defer() accepts:
// * The module to load **relative to the ./helpers module**
// * The **exported** name of the builder class
const PullRequestBuilder = defer('./pr', 'PullRequestBuilder');

const RepositoryBuilder = createSpecBuilderClass('Repository', {
  pullRequest: {linked: PullRequestBuilder},

  // ...
})
```
