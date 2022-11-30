import type { ViewProps } from 'react-native';
import type { CameraRuntimeError, MrzResult } from '.';

export interface MrzReaderProps extends ViewProps {
  /**
   * Called when results of scanning have been found.
   */
  onMrzResult?: (event: MrzResult) => void;
  /**
   * Called when any kind of runtime error occured.
   */
  onError?: (error: CameraRuntimeError) => void;
  /**
   * Set the current torch mode.
   *
   * Note: The torch is only available on `"back"` cameras, and isn't supported by every phone.
   *
   * @default "off"
   */
  torch?: 'off' | 'on';
  /**
   * This can be compared to a Video component, where `isScanning` specifies whether the video is paused or not.
   */
  isScanning?: boolean;
}
