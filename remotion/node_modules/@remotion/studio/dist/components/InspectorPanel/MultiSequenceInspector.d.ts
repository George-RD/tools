import React from 'react';
import type { TimelineSelection } from '../Timeline/TimelineSelection';
export declare const MultiSequenceInspector: React.FC<{
    readonly selections: readonly Extract<TimelineSelection, {
        type: 'sequence';
    }>[];
    readonly readOnlyStudio: boolean;
}>;
