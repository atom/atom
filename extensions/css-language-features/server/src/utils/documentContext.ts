/*---------------------------------------------------------------------------------------------
 *  Copyright (c) Microsoft Corporation. All rights reserved.
 *  Licensed under the MIT License. See License.txt in the project root for license information.
 *--------------------------------------------------------------------------------------------*/

import { DocumentContext } from 'vscode-css-languageservice';
import { endsWith, startsWith } from '../utils/strings';
import * as url from 'url';
import { WorkspaceFolder } from 'vscode-languageserver';

export function getDocumentContext(documentUri: string, workspaceFolders: WorkspaceFolder[]): DocumentContext {
	function getRootFolder(): string | undefined {
		for (let folder of workspaceFolders) {
			let folderURI = folder.uri;
			if (!endsWith(folderURI, '/')) {
				folderURI = folderURI + '/';
			}
			if (startsWith(documentUri, folderURI)) {
				return folderURI;
			}
		}
		return void 0;
	}

	return {
		resolveReference: (ref, base = documentUri) => {
			if (ref[0] === '/') { // resolve absolute path against the current workspace folder
				if (startsWith(base, 'file://')) {
					let folderUri = getRootFolder();
					if (folderUri) {
						return folderUri + ref.substr(1);
					}
				}
			}
			return url.resolve(base, ref);
		},
	};
}

