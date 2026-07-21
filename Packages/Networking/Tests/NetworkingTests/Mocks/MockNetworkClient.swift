//
//  MockNetworkClient.swift
//  Networking
//
//  Created by Rodrigo Mato on 10/6/25.
//

import Foundation
@testable import Networking
import XCTest

class MockNetworkClient: NetworkClient, @unchecked Sendable {
    enum NetworkStub {
        case success(Data)
        case failure(Error)
    }
    let stub: NetworkStub
    var capturedHeaders: [String: String]?
    var capturedBody: Data?
    
    init(stub: NetworkStub, capturedHeaders: [String: String]? = nil) {
        self.stub = stub
        self.capturedHeaders = capturedHeaders
    }
    
    func get(url: URL, queryItems: [URLQueryItem]?, headers: [String: String]) async throws -> Data {
        capturedHeaders = headers
        switch stub {
        case .success(let data):  return data
        case .failure(let error): throw error
        }
    }

    func post(url: URL, body: Data?, headers: [String: String]) async throws -> Data {
        capturedHeaders = headers
        capturedBody = body
        switch stub {
        case .success(let data):  return data
        case .failure(let error): throw error
        }
    }
}
