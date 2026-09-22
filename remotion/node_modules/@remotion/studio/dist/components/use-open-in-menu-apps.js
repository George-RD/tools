"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.useOpenInMenuApps = void 0;
const react_1 = require("react");
const client_id_1 = require("../helpers/client-id");
const use_configure_default_apps_1 = require("./use-configure-default-apps");
const use_default_editor_info_1 = require("./use-default-editor-info");
const useOpenInMenuApps = () => {
    const connectionStatus = (0, react_1.useContext)(client_id_1.StudioServerConnectionCtx)
        .previewServerState.type;
    const { canConfigureApps, canOpenInEditor, defaultEditorId, defaultEditorName, editorInfo, } = (0, use_default_editor_info_1.useEditorOpening)(connectionStatus === 'connected');
    const codingAgentInfo = (0, use_default_editor_info_1.useDefaultCodingAgentInfo)(canConfigureApps);
    const onConfigureApps = (0, use_configure_default_apps_1.useConfigureDefaultApps)();
    const openInApps = (0, react_1.useMemo)(() => ({
        canOpenDesktopApps: canConfigureApps,
        canOpenInEditor,
        codingAgentInfo,
        defaultEditorId,
        defaultEditorName,
        editorInfo,
        onConfigureApps,
    }), [
        canOpenInEditor,
        canConfigureApps,
        codingAgentInfo,
        defaultEditorId,
        defaultEditorName,
        editorInfo,
        onConfigureApps,
    ]);
    return { connectionStatus, openInApps };
};
exports.useOpenInMenuApps = useOpenInMenuApps;
