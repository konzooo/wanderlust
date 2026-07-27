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
    @MainActor static func preferredPlaceURL(name: String,
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

    /// Builds a link for a place we can name but not pin, using the same app order.
    /// A Maps *search* never claims a precise spot, so a name we can't resolve to
    /// coordinates degrades into "here are the results" instead of a wrong pin.
    @MainActor static func searchURL(name: String) -> URL? {
        let enc = encoded(name)

        if let url = URL(string: "comgooglemaps://?q=\(enc)"),
           UIApplication.shared.canOpenURL(url) {
            return url
        }

        if let url = URL(string: "maps://?q=\(enc)"),
           UIApplication.shared.canOpenURL(url) {
            return url
        }

        return URL(string: "https://www.google.com/maps/search/?api=1&query=\(enc)")
    }

    /// Opens the place card immediately, using the same fallback order.
    @MainActor static func openPlace(name: String,
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

    /// `.urlQueryAllowed` leaves `&`, `+` and `=` intact, which splits a place name
    /// like "Brunch & Cake" into two query parameters. Escape those too.
    private static func encoded(_ name: String) -> String {
        let allowed = CharacterSet.urlQueryAllowed.subtracting(CharacterSet(charactersIn: "&+=?#"))
        return name.addingPercentEncoding(withAllowedCharacters: allowed) ?? name
    }

    private static func googleMapsAppURL(
        name: String,
        latitude: Double,
        longitude: Double,
        zoom: Int
    ) -> URL? {
        let enc = encoded(name)
        return URL(string: "comgooglemaps://?q=\(enc)&center=\(latitude),\(longitude)&zoom=\(zoom)")
    }

    private static func appleMapsURL(
        name: String,
        latitude: Double,
        longitude: Double
    ) -> URL? {
        let enc = encoded(name)
        return URL(string: "maps://?q=\(enc)&ll=\(latitude),\(longitude)")
    }

    private static func googleMapsBrowserURL(
        name: String,
        latitude: Double,
        longitude: Double,
        placeID: String?
    ) -> URL? {
        let enc = encoded(name)
        var url = "https://www.google.com/maps/search/?api=1&query=\(enc)"
        if let pid = placeID, !pid.isEmpty {
            url += "&query_place_id=\(pid)"
        } else {
            url += "&query=\(latitude),\(longitude)"
        }
        return URL(string: url)
    }
}
