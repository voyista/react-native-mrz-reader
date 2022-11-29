# @better-network/react-native-mrz-reader

React native library for reading Machine Readable Zone documents

## Installation

```sh
npm install @better-network/react-native-mrz-reader
```

```sh
npx pod-install
```

Since the library is using camera, you will need to add the camera usage description key into info.plist

```xml
<key>NSCameraUsageDescription</key>
<string>MRZ Reader needs access to your Camera for very obvious reasons.</string>
```

## Usage

```js
import { MrzReaderView, MrzResult } from '@better-network/react-native-mrz-reader';
// ...

<MrzReaderView onMrzResult={(result: MrzResult) => {/* Here you get the result from the passport details */}} style={[StyleSheet.absoluteFill]} />
```

### Platform support roadmap

- [x] IOS
- [] Android

## Contributing

See the [contributing guide](CONTRIBUTING.md) to learn how to contribute to the repository and the development workflow.

