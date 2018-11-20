# VSCode JSON Language Server

[![NPM Version](https://img.shields.io/npm/v/vscode-json-languageserver.svg)](https://npmjs.org/package/vscode-json-languageserver)
[![NPM Downloads](https://img.shields.io/npm/dm/vscode-json-languageserver.svg)](https://npmjs.org/package/vscode-json-languageserver)
[![NPM Version](https://img.shields.io/npm/l/vscode-json-languageserver.svg)](https://npmjs.org/package/vscode-json-languageserver)

The JSON Language server provides language-specific smarts for editing, validating and understanding JSON documents. It runs as a separate executable and implements the [language server protocol](https://microsoft.github.io/language-server-protocol/overview) to be connected by any code editor or IDE.

## Capabilities

### Server capabilities

The JSON language server supports requests on documents of language id `json` and `jsonc`.
- `json` documents are parsed and validated following the [JSON specification](https://tools.ietf.org/html/rfc7159).
- `jsonc` documents additionally accept single line (`//`) and multi-line comments (`/* ... */`) and accepts trailing commas. JSONC is a VSCode specific file format, intended for VSCode configuration files, without any aspirations to define a new common file format.

The server implements the following capabilities of the language server protocol:

- [Code completion](https://microsoft.github.io/language-server-protocol/specification#textDocument_completion) for JSON properties and values based on the document's [JSON schema](http://json-schema.org/) or based on existing properties and values used at other places in the document. JSON schemas are configured through the server configuration options.
- [Hover](https://microsoft.github.io/language-server-protocol/specification#textDocument_hover) for values based on descriptions in the document's [JSON schema](http://json-schema.org/).
- [Document Symbols](https://microsoft.github.io/language-server-protocol/specification#textDocument_documentSymbol) for quick navigation to properties in the document.
- [Document Colors](https://microsoft.github.io/language-server-protocol/specification#textDocument_documentColor) for showing color decorators on values representing colors and [Color Presentation](https://microsoft.github.io/language-server-protocol/specification#textDocument_colorPresentation) for color presentation information to support color pickers. The location of colors is defined by the document's [JSON schema](http://json-schema.org/). All values marked with `"format": "color-hex"` (VSCode specific, non-standard JSON Schema extension) are considered color values. The supported color formats are `#rgb[a]` and `#rrggbb[aa]`.
- [Code Formatting](https://microsoft.github.io/language-server-protocol/specification#textDocument_rangeFormatting) supporting ranges and formatting the whole document.
- [Diagnostics (Validation)](https://microsoft.github.io/language-server-protocol/specification#textDocument_publishDiagnostics) are pushed for all open documents
   - syntax errors
   - structural validation based on the document's [JSON schema](http://json-schema.org/).

In order to load JSON schemas, the JSON server uses NodeJS `http` and `fs` modules. For all other features, the JSON server only relies on the documents and settings provided by the client through the LSP.

### Client requirements:

The JSON language server expects the client to only send requests and notifications for documents of language id `json` and `jsonc`.

The JSON language server has the following dependencies on the client's capabilities:

- Code completion requires that the client capability has *snippetSupport*. If not supported by the client, the server will not offer the completion capability.
- Formatting support requires the client to support *dynamicRegistration* for *rangeFormatting*. If not supported by the client, the server will not offer the format capability.

## Configuration

### Settings

Clients may send a `workspace/didChangeConfiguration` notification to notify the server of settings changes.
The server supports the following settings:

- http
   - `proxy`: The URL of the proxy server to use when fetching schema. When undefined or empty, no proxy is used.
   - `proxyStrictSSL`: Whether the proxy server certificate should be verified against the list of supplied CAs.

- json
  - `format`
    - `enable`: Whether the server should register the formatting support. This option is only applicable if the client supports *dynamicRegistration* for *rangeFormatting*
    - `schema`: Configures association of file names to schema URL or schemas and/or associations of schema URL to schema content.
	  - `fileMatch`: an array or file names or paths (separated by `/`). `*` can be used as a wildcard.
	  - `url`: The URL of the schema, optional when also a schema is provided.
	  - `schema`: The schema content.

```json
	{
        "http": {
            "proxy": "",
            "proxyStrictSSL": true
        },
        "json": {
            "format": {
                "enable": true
            },
            "schemas": [
                {
                    "fileMatch": [
                        "foo.json",
                        "*.superfoo.json"
                    ],
                    "url": "http://json.schemastore.org/foo",
                    "schema": {
                    	"type": "array"
                    }
                }
            ]
        }
    }
```

### Schema configuration and custom schema content delivery

[JSON schemas](http://json-schema.org/) are essential for code assist, hovers, color decorators to work and are required for structural validation.

To find the schema for a given JSON document, the server uses the following mechanisms:
- JSON documents can define the schema URL using a `$schema` property
- The settings define a schema association based on the documents URL. Settings can either associate a schema URL to a file or path pattern, and they can directly provide a schema.
- Additionally, schema associations can also be provided by a custom 'schemaAssociations' configuration call.

Schemas are identified by URLs. To load the content of a schema, the JSON language server tries to load from that URL or path. The following URL schemas are supported:
- `http`, `https`: Loaded using NodeJS's HTTP support. Proxies can be configured through the settings.
- `file`: Loaded using NodeJS's `fs` support.
- `vscode`: Loaded by an LSP call to the client.

#### Schema associations notification

In addition to the settings, schemas associations can also be provided through a notification from the client to the server. This notification is a JSON language server specific, non-standardized, extension to the LSP.

Notification:
- method: 'json/schemaAssociations'
- params: `ISchemaAssociations` defined as follows

```ts
interface ISchemaAssociations {
	[pattern: string]: string[];
}
```
  - keys: a file names or file path (separated by `/`). `*` can be used as a wildcard.
  - values: An array of schema URLs

#### Schema content request

The schema content for schema URLs that start with `vscode://` will be requested from the client through an LSP request. This request is a JSON language server specific, non-standardized, extension to the LSP.

Request:
- method: 'vscode/content'
- params: `string` - The schema URL to request. The server will only ask for URLs that start with `vscode://`
- response: `string` - The content of the schema with the given URL

#### Schema content change notification

When the client is aware that a schema content has changed, it will notify the server through a notification. This notification is a JSON language server specific, non-standardized, extension to the LSP.
The server will, as a response, clear the schema content from the cache and reload the schema content when required again.

Notification:
- method: 'json/schemaContent'
- params: `string` the URL of the schema that has changed.

## Try

The JSON language server is shipped with [Visual Studio Code](https://code.visualstudio.com/) as part of the built-in VSCode extension `json-language-features`. The server is started when the first JSON file is opened. The [VSCode JSON documentation](https://code.visualstudio.com/docs/languages/json) for detailed information on the user experience and has more information on how to configure the language support.

## Integrate

If you plan to integrate the JSON language server into an editor and IDE, check out [this page](https://microsoft.github.io/language-server-protocol/implementors/tools/) if there's already an LSP client integration available.

You can also launch the language server as a command and connect to it.
For that, install the `json-language-server` npm module:

`npm install -g json-language-server`

Start the language server with the `json-language-server` command. Use a command line argument to specify the prefered communication channel:

```
json-language-server --node-ipc
json-language-server --stdio
json-language-server --socket=<port>
```

To connect to the server from NodeJS, see Remy Suen's great write-up on [how to communicate with the server](https://github.com/rcjsuen/dockerfile-language-server-nodejs#communicating-with-the-server) through the available communication channels.

## Participate

The source code of the JSON language server can be found [VSCode repository](https://github.com/Microsoft/vscode) at [extensions/json-language-features/server](https://github.com/Microsoft/vscode/tree/master/extensions/json-language-features/server).
File issues and pull requests in the [VSCode GitHub Issues](https://github.com/Microsoft/vscode/issues). See the document [How to Contribute](https://github.com/Microsoft/vscode/wiki/How-to-Contribute) on how to build and run from source.

Most of the functionality of the server is located in libraries:
- [jsonc-parser](https://github.com/Microsoft/node-jsonc-parser) contains the JSON parser and scanner.
- [vscode-json-languageservice](https://github.com/Microsoft/vscode-json-languageservice) contains the implementation of all features as a re-usable library.
- [vscode-languageserver-node](https://github.com/Microsoft/vscode-languageserver-node) contains the implementation of language server for NodeJS.

Help on any of these projects is very welcome.

Please see also our [Code of Conduct](CODE_OF_CONDUCT.md).

## License

Copyright (c) Microsoft Corporation. All rights reserved.

Licensed under the [MIT](LICENSE.txt) License.
