import * as React from 'react';

import { Linking, StyleSheet, View } from 'react-native';
import {
  CameraPermissionStatus,
  MrzReaderView,
} from '@better-network/react-native-mrz-reader';

export default function App() {
  const [cameraPermissionStatus, setCameraPermissionStatus] =
    React.useState<CameraPermissionStatus>('not-determined');

  const mrzRef = React.useRef<MrzReaderView>(null);

  const requestCameraPermission = React.useCallback(async () => {
    console.log('Requesting camera permission...');
    const permission = await MrzReaderView.requestCameraPermission();
    console.log(`Camera permission status: ${permission}`);

    if (permission === 'denied') await Linking.openSettings();
    setCameraPermissionStatus(permission);
  }, []);

  React.useEffect(() => {
    requestCameraPermission();
  }, [requestCameraPermission]);

  return (
    <View style={styles.container}>
      {cameraPermissionStatus === 'authorized' && (
        <MrzReaderView ref={mrzRef} style={[StyleSheet.absoluteFill]} />
      )}
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    alignItems: 'center',
    justifyContent: 'center',
  },
});
