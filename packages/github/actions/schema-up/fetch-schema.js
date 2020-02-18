const fs = require('fs');
const path = require('path');
const fetch = require('node-fetch');

const {buildClientSchema, printSchema} = require('graphql/utilities');
const SERVER = 'https://api.github.com/graphql';
const introspectionQuery = `
  query IntrospectionQuery {
    __schema {
      queryType { name }
      mutationType { name }
      subscriptionType { name }
      types {
        ...FullType
      }
      directives {
        name
        description
        locations
        args {
          ...InputValue
        }
      }
    }
  }
  fragment FullType on __Type {
    kind
    name
    description
    fields(includeDeprecated: false) {
      name
      description
      args {
        ...InputValue
      }
      type {
        ...TypeRef
      }
      isDeprecated
      deprecationReason
    }
    inputFields {
      ...InputValue
    }
    interfaces {
      ...TypeRef
    }
    enumValues(includeDeprecated: false) {
      name
      description
      isDeprecated
      deprecationReason
    }
    possibleTypes {
      ...TypeRef
    }
  }
  fragment InputValue on __InputValue {
    name
    description
    type { ...TypeRef }
    defaultValue
  }
  fragment TypeRef on __Type {
    kind
    name
    ofType {
      kind
      name
      ofType {
        kind
        name
        ofType {
          kind
          name
          ofType {
            kind
            name
            ofType {
              kind
              name
              ofType {
                kind
                name
                ofType {
                  kind
                  name
                }
              }
            }
          }
        }
      }
    }
  }
`;

module.exports = async function() {
  const token = process.env.GITHUB_TOKEN;
  if (!token) {
    throw new Error('You must specify a GitHub auth token in GITHUB_TOKEN');
  }

  const schemaPath = path.resolve(process.env.GITHUB_WORKSPACE, 'graphql', 'schema.graphql');

  const res = await fetch(SERVER, {
    method: 'POST',
    headers: {
      'Accept': 'application/vnd.github.antiope-preview+json',
      'Content-Type': 'application/json',
      'Authorization': 'bearer ' + token,
    },
    body: JSON.stringify({query: introspectionQuery}),
  });
  const schemaJSON = await res.json();
  const graphQLSchema = buildClientSchema(schemaJSON.data);
  await new Promise((resolve, reject) => {
    fs.writeFile(schemaPath, printSchema(graphQLSchema), {encoding: 'utf8'}, err => {
      if (err) { reject(err); } else { resolve(); }
    });
  });
};
