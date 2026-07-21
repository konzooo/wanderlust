//
//  PlanetsService.swift
//  CoreDependencies
//
//  Created by Rodrigo Mato Castellano
//

import Foundation

public protocol PlanetsService: Sendable {
    /// Fetches an array of `Planet` objects asynchronously
    /// - Throws: can throw errors due to networking/decoding
    /// - Returns: list of `Planet` if success
    func fetchPlanets() async throws -> [API.Planet]
}
