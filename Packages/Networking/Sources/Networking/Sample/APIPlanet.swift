//
//  Planet.swift
//  Networking
//
//  Created by Rodrigo Mato Castellano
//

import Foundation

public enum API {
    public struct Planet: Codable, Equatable, Sendable {
        public let name: String
        public let rotationPeriod: String
        public let orbitalPeriod: String
        public let diameter: String
        public let climate: String
        public let gravity: String
        public let terrain: String
        public let surfaceWater: String
        public let population: String
        public let residents: [URL]
        public let films: [URL]
        public let created: Date
        public let edited: Date
        public let url: URL

        enum CodingKeys: String, CodingKey {
            case name
            case rotationPeriod  = "rotation_period"
            case orbitalPeriod   = "orbital_period"
            case diameter
            case climate
            case gravity
            case terrain
            case surfaceWater    = "surface_water"
            case population
            case residents
            case films
            case created
            case edited
            case url
        }
    }
}

