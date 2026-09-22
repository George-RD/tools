"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.useInspectorSectionExpanded = void 0;
const react_1 = require("react");
const persist_boolean_map_1 = require("../../helpers/persist-boolean-map");
const storageKey = 'remotion.editor.inspectorCollapsedSections';
const useInspectorSectionExpanded = (sectionId) => {
    const [collapsedSections, setCollapsedSections] = (0, react_1.useState)(() => (0, persist_boolean_map_1.loadPersistedBooleanMap)(storageKey));
    const setExpanded = (0, react_1.useCallback)((expanded) => {
        setCollapsedSections((previous) => ({
            ...previous,
            [sectionId]: !expanded,
        }));
        (0, persist_boolean_map_1.persistBooleanMap)(storageKey, {
            ...(0, persist_boolean_map_1.loadPersistedBooleanMap)(storageKey),
            [sectionId]: !expanded,
        });
    }, [sectionId]);
    return [!collapsedSections[sectionId], setExpanded];
};
exports.useInspectorSectionExpanded = useInspectorSectionExpanded;
