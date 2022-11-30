import * as React from 'react';

import {
  Alert,
  Button,
  Linking,
  SafeAreaView,
  StyleSheet,
  View,
} from 'react-native';
import {
  CameraPermissionStatus,
  CameraRuntimeError,
  MrzReaderView,
  MrzResult,
} from '@better-network/react-native-mrz-reader';

export default function App() {
  const [cameraPermissionStatus, setCameraPermissionStatus] =
    React.useState<CameraPermissionStatus>('not-determined');
  const [torch, setTorch] = React.useState<'on' | 'off'>('off');
  const [isScanning, setIsScanning] = React.useState(true);
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

  const onMrzResult = React.useCallback((event: MrzResult) => {
    // We presume that the scanning is stopped since we found results.
    // So we should update it properly in order to change it later.
    setIsScanning(false);
    Alert.alert(
      'MRZ found!',
      `Document Number: ${event.documentNumber}\nExpiryDate: ${new Date(
        event.expiryDate
      ).toLocaleDateString()}\nBirthdate: ${new Date(
        event.birthdate
      ).toLocaleDateString()}`,
      [{ text: 'Resume', onPress: () => setIsScanning(true) }]
    );
  }, []);

  const onError = React.useCallback((event: CameraRuntimeError) => {
    Alert.alert(event.cause?.message ?? 'An error has occurred', event.message);
  }, []);

  return (
    <View style={styles.container}>
      {cameraPermissionStatus === 'authorized' && (
        <MrzReaderView
          ref={mrzRef}
          torch={torch}
          isScanning={isScanning}
          onError={onError}
          onMrzResult={onMrzResult}
          style={[StyleSheet.absoluteFill]}
        />
      )}
      <SafeAreaView style={styles.button}>
        <Button
          color={'white'}
          title={torch === 'on' ? '🔦 ON' : '🔦 OFF'}
          onPress={() => setTorch(torch === 'on' ? 'off' : 'on')}
        />
      </SafeAreaView>
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    alignItems: 'center',
    justifyContent: 'center',
  },
  button: {
    position: 'absolute',
    alignSelf: 'center',
    right: 10,
    top: 0,
  },
});
