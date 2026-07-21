//
//  Planet.swift
//  PlanetsFeature
//
//  Created by Rodrigo Mato Castellano
//

public struct Planet: Equatable, Identifiable, Sendable, Hashable {
    public var id: String { name } // simple, unique (enough ATM)
    public let name: String
    public let climate: String
    public let population: String
    public let diameter: String
    public let gravity: String
    public let terrain: String

    public init(name: String, climate: String, population: String, diameter: String, gravity: String, terrain: String) {
        self.name = name
        self.climate = climate
        self.population = population
        self.diameter = diameter
        self.gravity = gravity
        self.terrain = terrain
    }
}

extension Planet {
    static var mock: Self {
        .init(
            name: "Coruscant",
            climate: "temperate",
            population: "1000000000000",
            diameter: "12240",
            gravity: "1 standard",
            terrain: "cityscape, mountains"
        )
    }
}
