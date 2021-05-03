//
//  DDRequestTransport.swift
//  EquifyCRM
//
//  Created by Rostyslav Stepanyak on 25/06/18.
//  Copyright © 2017 DDragons LLC. All rights reserved.
//

import Foundation

typealias ErrorPayload = [String: Any]
protocol SMRequestService {
    func send<T>(request: SMRequest, completion: @escaping (T?, TransportError?, ErrorPayload?) -> Void) where T: SMResponse, T: Deserializable
}

struct TransportErrorCode {
    public static let BAD_REQUEST = 400
    public static let UNAUTHORIZED = 401
    public static let NOT_FOUND = 404
    public static let SERIALIZATION_FAILED = -330
    public static let DESERIALIZATION_FAILED = -331
    public static let REQUEST_FAILED = -332
}

enum TransportError: Error, LocalizedError {
    case SerializationFailed
    case DeserializationFailed
    case RequestFailed(error: Error?)
    case ServerError(code: Int)
    
    var errorDescription: String? {
        switch self {
            case .SerializationFailed: return "Request serialization failed"
            case .DeserializationFailed: return "Response deserialization failed"
            case .RequestFailed(let error):
                if let error = error {
                    if (error._code == -1009) {
                         return "Internet connection offline"
                    }
                    return error.localizedDescription
                }
                else {
                    return "Failed to send request"
                }
            case .ServerError(let code): return " Server responded with: \(code)"
        }
    }
    
    var code: Int {
        switch self {
        case .SerializationFailed: return TransportErrorCode.SERIALIZATION_FAILED
        case .DeserializationFailed: return TransportErrorCode.DESERIALIZATION_FAILED
        case .RequestFailed(let error):
            if let error = error {
                return error._code
            }
            else {
                return TransportErrorCode.REQUEST_FAILED
            }
        case .ServerError(let code): return code
        }
    }
}
