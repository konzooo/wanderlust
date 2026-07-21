//
//  LinksHandler.swift
//  Wanderlust
//
//  Created by Rodrigo Mato Castellano on 4/23/25.
//

import Foundation
import UIKit

enum LinkError: Error {
    case invalidUrl(String)
    case cannotOpenUrl(String)
}

struct LocationLinkBuilder {

    /// Builds the best URL *without* opening it (Google Maps → Apple Maps → browser).
    static func preferredPlaceURL(name: String,
                                  latitude: Double,
                                  longitude: Double,
                                  placeID: String? = nil,
                                  zoom: Int = 16) -> URL? {

        // 1️⃣ Google Maps iOS app
        if let url = googleMapsAppURL(name: name,
                                      latitude: latitude,
                                      longitude: longitude,
                                      zoom: zoom),
           UIApplication.shared.canOpenURL(url) {
            return url
        }

        // 2️⃣ Apple Maps iOS app
        if let url = appleMapsURL(name: name,
                                  latitude: latitude,
                                  longitude: longitude),
           UIApplication.shared.canOpenURL(url) {
            return url
        }

        // 3️⃣ Browser (universal link)
        return googleMapsBrowserURL(name: name,
                                    latitude: latitude,
                                    longitude: longitude,
                                    placeID: placeID)
    }

    /// Opens the place card immediately, using the same fallback order.
    static func openPlace(name: String,
                          latitude: Double,
                          longitude: Double,
                          placeID: String? = nil,
                          zoom: Int = 16) throws {

        guard let url = preferredPlaceURL(name: name,
                                          latitude: latitude,
                                          longitude: longitude,
                                          placeID: placeID,
                                          zoom: zoom) else {
            throw LinkError.invalidUrl("No valid URL produced")
        }

        guard UIApplication.shared.canOpenURL(url) else {
            throw LinkError.cannotOpenUrl(url.absoluteString)
        }
        UIApplication.shared.open(url, options: [:])
    }

    // ---------- PRIVATE BUILDERS ----------

    private static func googleMapsAppURL(
        name: String,
        latitude: Double,
        longitude: Double,
        zoom: Int
    ) -> URL? {
        let enc = name.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? name
        return URL(string: "comgooglemaps://?q=\(enc)&center=\(latitude),\(longitude)&zoom=\(zoom)")
    }

    private static func appleMapsURL(
        name: String,
        latitude: Double,
        longitude: Double
    ) -> URL? {
        let enc = name.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? name
        return URL(string: "maps://?q=\(enc)&ll=\(latitude),\(longitude)")
    }

    private static func googleMapsBrowserURL(
        name: String,
        latitude: Double,
        longitude: Double,
        placeID: String?
    ) -> URL? {
        let enc = name.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? name
        var url = "https://www.google.com/maps/search/?api=1&query=\(enc)"
        if let pid = placeID, !pid.isEmpty {
            url += "&query_place_id=\(pid)"
        } else {
            url += "&query=\(latitude),\(longitude)"
        }
        return URL(string: url)
    }
}
