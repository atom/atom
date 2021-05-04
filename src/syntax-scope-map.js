const parser = require('postcss-selector-parser');

module.exports = class SyntaxScopeMap {
  constructor(resultsBySelector) {
    this.namedScopeTable = {};
    this.anonymousScopeTable = {};
    for (let selector in resultsBySelector) {
      this.addSelector(selector, resultsBySelector[selector]);
    }
    setTableDefaults(this.namedScopeTable, true);
    setTableDefaults(this.anonymousScopeTable, false);
  }

  addSelector(selector, result) {
    parser(parseResult => {
      for (let selectorNode of parseResult.nodes) {
        let currentTable = null;
        let currentIndexValue = null;

        for (let i = selectorNode.nodes.length - 1; i >= 0; i--) {
          const termNode = selectorNode.nodes[i];

          switch (termNode.type) {
            case 'tag':
              if (!currentTable) currentTable = this.namedScopeTable;
              if (!currentTable[termNode.value])
                currentTable[termNode.value] = {};
              currentTable = currentTable[termNode.value];
              if (currentIndexValue != null) {
                if (!currentTable.indices) currentTable.indices = {};
                if (!currentTable.indices[currentIndexValue])
                  currentTable.indices[currentIndexValue] = {};
                currentTable = currentTable.indices[currentIndexValue];
                currentIndexValue = null;
              }
              break;

            case 'string':
              if (!currentTable) currentTable = this.anonymousScopeTable;
              const value = termNode.value.slice(1, -1).replace(/\\"/g, '"');
              if (!currentTable[value]) currentTable[value] = {};
              currentTable = currentTable[value];
              if (currentIndexValue != null) {
                if (!currentTable.indices) currentTable.indices = {};
                if (!currentTable.indices[currentIndexValue])
                  currentTable.indices[currentIndexValue] = {};
                currentTable = currentTable.indices[currentIndexValue];
                currentIndexValue = null;
              }
              break;

            case 'universal':
              if (currentTable) {
                if (!currentTable['*']) currentTable['*'] = {};
                currentTable = currentTable['*'];
              } else {
                if (!this.namedScopeTable['*']) {
                  this.namedScopeTable['*'] = this.anonymousScopeTable[
                    '*'
                  ] = {};
                }
                currentTable = this.namedScopeTable['*'];
              }
              if (currentIndexValue != null) {
                if (!currentTable.indices) currentTable.indices = {};
                if (!currentTable.indices[currentIndexValue])
                  currentTable.indices[currentIndexValue] = {};
                currentTable = currentTable.indices[currentIndexValue];
                currentIndexValue = null;
              }
              break;

            case 'combinator':
              if (currentIndexValue != null) {
                rejectSelector(selector);
              }

              if (termNode.value === '>') {
                if (!currentTable.parents) currentTable.parents = {};
                currentTable = currentTable.parents;
              } else {
                rejectSelector(selector);
              }
              break;

            case 'pseudo':
              if (termNode.value === ':nth-child') {
                currentIndexValue = termNode.nodes[0].nodes[0].value;
              } else {
                rejectSelector(selector);
              }
              break;

            default:
              rejectSelector(selector);
          }
        }

        currentTable.result = result;
      }
    }).process(selector);
  }

  get(nodeTypes, childIndices, leafIsNamed = true) {
    let result;
    let i = nodeTypes.length - 1;
    let currentTable = leafIsNamed
      ? this.namedScopeTable[nodeTypes[i]]
      : this.anonymousScopeTable[nodeTypes[i]];

    if (!currentTable) currentTable = this.namedScopeTable['*'];

    while (currentTable) {
      if (currentTable.indices && currentTable.indices[childIndices[i]]) {
        currentTable = currentTable.indices[childIndices[i]];
      }

      if (currentTable.result != null) {
        result = currentTable.result;
      }

      if (i === 0) break;
      i--;
      currentTable =
        currentTable.parents &&
        (currentTable.parents[nodeTypes[i]] || currentTable.parents['*']);
    }

    return result;
  }
};

function setTableDefaults(table, allowWildcardSelector) {
  const defaultTypeTable = allowWildcardSelector ? table['*'] : null;

  for (let type in table) {
    let typeTable = table[type];
    if (typeTable === defaultTypeTable) continue;

    if (defaultTypeTable) {
      mergeTable(typeTable, defaultTypeTable);
    }

    if (typeTable.parents) {
      setTableDefaults(typeTable.parents, true);
    }

    for (let key in typeTable.indices) {
      const indexTable = typeTable.indices[key];
      mergeTable(indexTable, typeTable, false);
      if (indexTable.parents) {
        setTableDefaults(indexTable.parents, true);
      }
    }
  }
}

function mergeTable(table, defaultTable, mergeIndices = true) {
  if (mergeIndices && defaultTable.indices) {
    if (!table.indices) table.indices = {};
    for (let key in defaultTable.indices) {
      if (!table.indices[key]) table.indices[key] = {};
      mergeTable(table.indices[key], defaultTable.indices[key]);
    }
  }

  if (defaultTable.parents) {
    if (!table.parents) table.parents = {};
    for (let key in defaultTable.parents) {
      if (!table.parents[key]) table.parents[key] = {};
      mergeTable(table.parents[key], defaultTable.parents[key]);
    }
  }

  if (defaultTable.result != null && table.result == null) {
    table.result = defaultTable.result;
  }
}

function rejectSelector(selector) {
  throw new TypeError(`Unsupported selector '${selector}'`);
}
