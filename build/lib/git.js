/*---------------------------------------------------------------------------------------------
 *  Copyright (c) Microsoft Corporation. All rights reserved.
 *  Licensed under the MIT License. See License.txt in the project root for license information.
 *--------------------------------------------------------------------------------------------*/
'use strict';
Object.defineProperty(exports, "__esModule", { value: true });
const path = require("path");
const fs = require("fs");
/**
 * Returns the sha1 commit version of a repository or undefined in case of failure.
 */
function getVersion(repo) {
    const git = path.join(repo, '.git');
    const headPath = path.join(git, 'HEAD');
    let head;
    try {
        head = fs.readFileSync(headPath, 'utf8').trim();
    }
    catch (e) {
        return void 0;
    }
    if (/^[0-9a-f]{40}$/i.test(head)) {
        return head;
    }
    const refMatch = /^ref: (.*)$/.exec(head);
    if (!refMatch) {
        return void 0;
    }
    const ref = refMatch[1];
    const refPath = path.join(git, ref);
    try {
        return fs.readFileSync(refPath, 'utf8').trim();
    }
    catch (e) {
        // noop
    }
    const packedRefsPath = path.join(git, 'packed-refs');
    let refsRaw;
    try {
        refsRaw = fs.readFileSync(packedRefsPath, 'utf8').trim();
    }
    catch (e) {
        return void 0;
    }
    const refsRegex = /^([0-9a-f]{40})\s+(.+)$/gm;
    let refsMatch;
    let refs = {};
    while (refsMatch = refsRegex.exec(refsRaw)) {
        refs[refsMatch[2]] = refsMatch[1];
    }
    return refs[ref];
}
exports.getVersion = getVersion;
