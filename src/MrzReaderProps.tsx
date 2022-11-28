import type { ViewProps } from 'react-native';
import type { MrzResult } from './MrzResult';

export interface MrzReaderProps extends ViewProps {
  onMrzResult?: (event: MrzResult) => void;
}
