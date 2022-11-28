//
//  QKMRZScanResult.swift
//  QKMRZScanner
//
//  Created by Matej Dorcak on 16/10/2018.
//

import Foundation
import QKMRZParser
import UIKit

public class MRZScanResult {
    public let documentImage: UIImage
    public let documentType: String
    public let countryCode: String
    public let surnames: String
    public let givenNames: String
    public let documentNumber: String
    public let nationalityCountryCode: String
    public let birthdate: Date?
    public let sex: String?
    public let expiryDate: Date?
    public let personalNumber: String
    public let personalNumber2: String?
    
    public lazy fileprivate(set) var faceImage: UIImage? = {
        guard let documentImage = CIImage(image: documentImage) else {
            return nil
        }
        
        let faceDetector = CIDetector(ofType: CIDetectorTypeFace, context: CIContext.shared, options: [CIDetectorAccuracy: CIDetectorAccuracyLow])!
        
        guard let face = faceDetector.features(in: documentImage).first else {
            return nil
        }
        
        let increasedFaceBounds = face.bounds.insetBy(dx: -30, dy: -85).offsetBy(dx: 0, dy: 50)
        let faceImage = documentImage.cropped(to: increasedFaceBounds)
        
        guard let cgImage = CIContext.shared.createCGImage(faceImage, from: faceImage.extent) else {
            return nil
        }
        
        return UIImage(cgImage: cgImage)
    }()
    
    init(mrzResult: QKMRZResult, documentImage image: UIImage) {
        documentImage = image
        documentType = mrzResult.documentType
        countryCode = mrzResult.countryCode
        surnames = mrzResult.surnames
        givenNames = mrzResult.givenNames
        documentNumber = mrzResult.documentNumber
        nationalityCountryCode = mrzResult.nationalityCountryCode
        birthdate = mrzResult.birthdate
        sex = mrzResult.sex
        expiryDate = mrzResult.expiryDate
        personalNumber = mrzResult.personalNumber
        personalNumber2 = mrzResult.personalNumber2
    }

    fileprivate func dateFormatter(date: Date?) -> String {
       let formatter = ISO8601DateFormatter()
       return date != nil ? formatter.string(from: date!) : ""
    }
    
    fileprivate func convertImageToBase64String (img: UIImage?) -> String {
        return img != nil ? ( img!.jpegData(compressionQuality: 1)?.base64EncodedString() ?? "") : ""
    }
    
    public func getMrzResultDictionary() -> [String : String]? {
        return [
            "documentImage": self.convertImageToBase64String(img: documentImage),
            "personalNumber": personalNumber,
            "documentType": documentType,
            "countryCode": countryCode,
            "surname": surnames,
            "givenName": givenNames,
            "documentNumber": documentNumber,
            "nationalityCountryCode": nationalityCountryCode,
            "birthdate": self.dateFormatter(date: birthdate),
            "sex": sex ?? "-",
            "expiryDate": self.dateFormatter(date: expiryDate),
            "personalNumber": personalNumber,
            "personalNumber2": personalNumber2 ?? ""
        ]
    }
}
