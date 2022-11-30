import type { ErrorWithCause } from '.';

export interface OnErrorEvent {
  code: string;
  message: string;
  cause?: ErrorWithCause;
}
