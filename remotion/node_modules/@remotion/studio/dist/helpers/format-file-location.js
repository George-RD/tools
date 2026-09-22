"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.formatContextForAgents = exports.formatFileLocation = exports.getRelativeFileLocation = void 0;
const normalizeSlashes = (path) => path.replace(/\\/g, '/');
const stripTrailingSlashes = (path) => path.replace(/\/+$/, '');
const stripLeadingDotSlash = (path) => path.replace(/^\.\/+/, '');
const getRelativeFileLocation = ({ location, root, }) => {
    if (!(location === null || location === void 0 ? void 0 : location.source) || location.line === null) {
        return null;
    }
    const source = normalizeSlashes(location.source);
    const normalizedRoot = stripTrailingSlashes(normalizeSlashes(root));
    const shouldCompareCaseInsensitive = /^[a-z]:\//i.test(source) || /^[a-z]:\//i.test(normalizedRoot);
    const sourceForComparison = shouldCompareCaseInsensitive
        ? source.toLowerCase()
        : source;
    const rootForComparison = shouldCompareCaseInsensitive
        ? normalizedRoot.toLowerCase()
        : normalizedRoot;
    const sourceIsInsideRoot = normalizedRoot.length > 0 &&
        sourceForComparison.startsWith(rootForComparison + '/');
    const relativeSource = sourceIsInsideRoot
        ? source.slice(normalizedRoot.length + 1)
        : source;
    return {
        filename: stripLeadingDotSlash(relativeSource),
        line: location.line,
    };
};
exports.getRelativeFileLocation = getRelativeFileLocation;
const formatFileLocation = ({ location, root, }) => {
    const relativeLocation = (0, exports.getRelativeFileLocation)({ location, root });
    if (relativeLocation === null) {
        return null;
    }
    return `${relativeLocation.filename}:${relativeLocation.line}`;
};
exports.formatFileLocation = formatFileLocation;
const formatContextForAgents = ({ name, location, root, }) => {
    const fileLocation = (0, exports.formatFileLocation)({ location, root });
    if (!name || !fileLocation) {
        return null;
    }
    return `${name} in ${fileLocation}`;
};
exports.formatContextForAgents = formatContextForAgents;
