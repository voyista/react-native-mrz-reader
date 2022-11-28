export interface MrzResult {
  documentImage: string;
  documentType: DocumentType;
  countryCode: string;
  surname: string;
  givenName: string;
  documentNumber: string;
  nationalityCountryCode: string;
  birthdate: Date;
  sex: Sex;
  expiryDate: Date;
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
