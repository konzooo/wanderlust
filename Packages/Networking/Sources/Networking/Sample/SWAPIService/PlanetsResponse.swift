//
//  PlanetsResponse.swift
//  Networking
//
//  Created by Rodrigo Mato Castellano on 5/1/25.
//

import Foundation

struct PlanetsResponse: Codable {
    let count: Int
    let results: [API.Planet]
}
