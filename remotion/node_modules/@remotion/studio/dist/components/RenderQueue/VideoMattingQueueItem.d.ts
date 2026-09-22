import React from 'react';
import type { VideoMattingJob } from './video-matting-job-types';
export declare const VideoMattingQueueItem: React.FC<{
    readonly job: VideoMattingJob;
    readonly selected: boolean;
}>;
