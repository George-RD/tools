"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.canShowUpdates = void 0;
const canShowUpdates = ({ connectionStatus, isBrowserStudio, readOnlyStudio, }) => {
    return (connectionStatus === 'connected' && !isBrowserStudio && !readOnlyStudio);
};
exports.canShowUpdates = canShowUpdates;
