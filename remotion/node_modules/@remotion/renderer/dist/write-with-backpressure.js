"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.writeWithBackpressure = void 0;
const writeWithBackpressure = ({ data, writable, }) => {
    if (writable.write(data)) {
        return Promise.resolve();
    }
    return new Promise((resolve, reject) => {
        const cleanup = () => {
            writable.off('close', onClose);
            writable.off('drain', onDrain);
            writable.off('error', onError);
        };
        const onClose = () => {
            cleanup();
            reject(new Error('The writable stream closed before it accepted all data.'));
        };
        const onDrain = () => {
            cleanup();
            resolve();
        };
        const onError = (error) => {
            cleanup();
            reject(error);
        };
        writable.once('close', onClose);
        writable.once('drain', onDrain);
        writable.once('error', onError);
        if (writable.destroyed) {
            onClose();
        }
    });
};
exports.writeWithBackpressure = writeWithBackpressure;
