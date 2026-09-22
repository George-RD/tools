"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.getGitMenuItem = exports.openGitSource = exports.getDefaultOpenInTarget = exports.hasReadOnlyGitSource = exports.getGitRefUrl = exports.getGitSourceBranchUrl = exports.getGitSourceName = void 0;
const getGitSourceName = (gitSource) => {
    if (gitSource.type === 'github') {
        return 'GitHub';
    }
    throw new Error('Unknown git source type');
};
exports.getGitSourceName = getGitSourceName;
const getGitSourceBranchUrl = (gitSource) => {
    if (gitSource.type === 'github') {
        const relativeFromGitRoot = gitSource.relativeFromGitRoot.replaceAll('\\', '/');
        return `https://github.com/${gitSource.org}/${gitSource.name}/tree/${gitSource.ref}${relativeFromGitRoot ? `/${relativeFromGitRoot}` : ''}`;
    }
    throw new Error('Unknown git source type');
};
exports.getGitSourceBranchUrl = getGitSourceBranchUrl;
const getGitRefUrl = (gitSource, originalLocation, remotionRoot) => {
    if (gitSource.type === 'github') {
        if (!originalLocation.source) {
            return (0, exports.getGitSourceBranchUrl)(gitSource);
        }
        const source = originalLocation.source.replaceAll('\\', '/');
        const root = remotionRoot.replaceAll('\\', '/').replace(/\/+$/, '');
        const shouldCompareCaseInsensitive = /^[a-z]:\//i.test(source) || /^[a-z]:\//i.test(root);
        const comparableSource = shouldCompareCaseInsensitive
            ? source.toLowerCase()
            : source;
        const comparableRoot = shouldCompareCaseInsensitive
            ? root.toLowerCase()
            : root;
        const sourceIsInsideRoot = root.length > 0 && comparableSource.startsWith(`${comparableRoot}/`);
        const relativeSource = sourceIsInsideRoot
            ? source.slice(root.length + 1)
            : source.replace(/^\.\/+/, '');
        if (/^(?:[a-z]:\/|\/)/i.test(relativeSource)) {
            return (0, exports.getGitSourceBranchUrl)(gitSource);
        }
        const filePath = [
            gitSource.relativeFromGitRoot.replaceAll('\\', '/'),
            relativeSource,
        ]
            .filter(Boolean)
            .map((part) => part.replace(/^\/+|\/+$/g, ''))
            .join('/');
        const lineSuffix = originalLocation.line
            ? `#L${originalLocation.line}`
            : '';
        return `https://github.com/${gitSource.org}/${gitSource.name}/blob/${gitSource.ref}/${filePath}${lineSuffix}`;
    }
    throw new Error('Unknown git source type');
};
exports.getGitRefUrl = getGitRefUrl;
const hasReadOnlyGitSource = () => {
    return Boolean(window.remotion_isReadOnlyStudio && window.remotion_gitSource);
};
exports.hasReadOnlyGitSource = hasReadOnlyGitSource;
const getDefaultOpenInTarget = ({ canOpenInEditor, }) => {
    if (canOpenInEditor) {
        return 'editor';
    }
    return (0, exports.hasReadOnlyGitSource)() ? 'git-source' : null;
};
exports.getDefaultOpenInTarget = getDefaultOpenInTarget;
const openGitSource = ({ folder, location, }) => {
    const gitSource = window.remotion_gitSource;
    if (!gitSource) {
        return;
    }
    window.open(folder || !location
        ? (0, exports.getGitSourceBranchUrl)(gitSource)
        : (0, exports.getGitRefUrl)(gitSource, location, window.remotion_cwd), '_blank');
};
exports.openGitSource = openGitSource;
const getGitMenuItem = () => {
    if (!window.remotion_gitSource) {
        return null;
    }
    return {
        id: 'open-git-source',
        value: 'open-git-source',
        label: `Open ${(0, exports.getGitSourceName)(window.remotion_gitSource)} Repo`,
        onClick: () => {
            window.open((0, exports.getGitSourceBranchUrl)(window.remotion_gitSource), '_blank');
        },
        type: 'item',
        keyHint: null,
        leftItem: null,
        subMenu: null,
        quickSwitcherLabel: `Open ${(0, exports.getGitSourceName)(window.remotion_gitSource)} repo`,
    };
};
exports.getGitMenuItem = getGitMenuItem;
