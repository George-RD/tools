"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.searchCompositionTree = void 0;
const normalizeSearchText = (text) => {
    return text
        .trim()
        .toLowerCase()
        .replace(/[\s/-]/g, '');
};
const getMatchScore = (query, candidate) => {
    const normalizedCandidate = normalizeSearchText(candidate);
    if (normalizedCandidate === query) {
        return 400000 - normalizedCandidate.length;
    }
    if (normalizedCandidate.startsWith(query)) {
        return 300000 - (normalizedCandidate.length - query.length);
    }
    const substringIndex = normalizedCandidate.indexOf(query);
    if (substringIndex !== -1) {
        return (200000 -
            substringIndex * 100 -
            (normalizedCandidate.length - query.length));
    }
    let previousIndex = -1;
    let firstIndex = -1;
    let gapCount = 0;
    for (const character of query) {
        const nextIndex = normalizedCandidate.indexOf(character, previousIndex + 1);
        if (nextIndex === -1) {
            return null;
        }
        if (firstIndex === -1) {
            firstIndex = nextIndex;
        }
        else {
            gapCount += nextIndex - previousIndex - 1;
        }
        previousIndex = nextIndex;
    }
    return (100000 -
        gapCount * 100 -
        firstIndex * 10 -
        (normalizedCandidate.length - query.length));
};
const searchCompositionTree = ({ items, query, }) => {
    const normalizedQuery = normalizeSearchText(query);
    const filterAndRank = (treeItems, level, inheritedFolderScore) => {
        const rankedItems = treeItems
            .map((item, originalIndex) => {
            if (item.type === 'composition') {
                const compositionPath = [
                    item.composition.parentFolderName,
                    item.composition.folderName,
                    item.composition.id,
                ]
                    .filter(Boolean)
                    .join('/');
                const idScore = normalizedQuery === ''
                    ? 0
                    : getMatchScore(normalizedQuery, item.composition.id);
                const compositionPathScore = normalizedQuery === ''
                    ? 0
                    : getMatchScore(normalizedQuery, compositionPath);
                const directScore = Math.max(idScore !== null && idScore !== void 0 ? idScore : -1, compositionPathScore !== null && compositionPathScore !== void 0 ? compositionPathScore : -1);
                const score = Math.max(directScore, inheritedFolderScore !== null && inheritedFolderScore !== void 0 ? inheritedFolderScore : -1);
                if (score === -1) {
                    return null;
                }
                return {
                    result: {
                        type: 'composition',
                        composition: item.composition,
                        level,
                        score,
                    },
                    originalIndex,
                };
            }
            const fullPath = [item.parentName, item.folderName]
                .filter(Boolean)
                .join('/');
            const nameScore = normalizedQuery === ''
                ? 0
                : getMatchScore(normalizedQuery, item.folderName);
            const pathScore = normalizedQuery === '' ? 0 : getMatchScore(normalizedQuery, fullPath);
            const directFolderScore = Math.max(nameScore !== null && nameScore !== void 0 ? nameScore : -1, pathScore !== null && pathScore !== void 0 ? pathScore : -1);
            const folderScore = Math.max(directFolderScore === -1 ? -1 : directFolderScore - 1, inheritedFolderScore !== null && inheritedFolderScore !== void 0 ? inheritedFolderScore : -1);
            const children = filterAndRank(item.items, level + 1, folderScore === -1 ? null : folderScore);
            if (children.length === 0) {
                return null;
            }
            return {
                result: {
                    type: 'folder',
                    id: `folder-${fullPath}`,
                    title: item.folderName,
                    level,
                    score: Math.max(folderScore, ...children.map((child) => child.score)),
                    children,
                },
                originalIndex,
            };
        })
            .filter((item) => item !== null);
        if (normalizedQuery !== '') {
            rankedItems.sort((a, b) => {
                return (b.result.score - a.result.score || a.originalIndex - b.originalIndex);
            });
        }
        return rankedItems.map((item) => item.result);
    };
    const flatten = (rankedItems) => {
        return rankedItems.flatMap((item) => {
            if (item.type === 'composition') {
                return [
                    {
                        type: 'composition',
                        composition: item.composition,
                        level: item.level,
                    },
                ];
            }
            return [
                {
                    type: 'folder',
                    id: item.id,
                    title: item.title,
                    level: item.level,
                },
                ...flatten(item.children),
            ];
        });
    };
    return flatten(filterAndRank(items, 0, null));
};
exports.searchCompositionTree = searchCompositionTree;
