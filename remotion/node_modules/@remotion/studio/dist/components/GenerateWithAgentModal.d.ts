import React from 'react';
import type { ModalState } from '../state/modals';
type State = Extract<ModalState, {
    type: 'generate-with-agent';
}>;
export declare const GenerateWithAgentModal: React.FC<{
    readonly state: State;
}>;
export {};
