//
//  DeviceIDProvider.swift
//  CoreArchitecture
//
//  Created by Rodrigo Mato Castellano on 6/1/25.
//

public protocol DeviceIDProvider {
    /// Returns the stable identifier for this install.
    func deviceID() -> String
}
