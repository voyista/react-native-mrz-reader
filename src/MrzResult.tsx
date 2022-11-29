export interface MrzResult {
  faceImage: string;
  documentImage: string;
  documentType: DocumentType;
  countryCode: string;
  surname: string;
  givenName: string;
  documentNumber: string;
  nationalityCountryCode: string;
  birthdate: string;
  sex: Sex;
  expiryDate: string;
  personalNumber: string;
  personalNumber2: string;
}

export enum DocumentType {
  Passport = 'P',
  Identity = 'I',
  Visa = 'V',
  Unknown = '_',
}

export enum Sex {
  Male = 'MALE',
  Female = 'FEMALE',
}
