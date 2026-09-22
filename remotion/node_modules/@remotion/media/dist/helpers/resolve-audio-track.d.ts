import type { InputAudioTrack, InputVideoTrack } from 'mediabunny';
export declare const resolveAudioTrack: ({ videoTrack, audioTracks, audioStreamIndex, }: {
    videoTrack: InputVideoTrack | null;
    audioTracks: InputAudioTrack[];
    audioStreamIndex: number | null;
}) => Promise<InputAudioTrack | null>;
