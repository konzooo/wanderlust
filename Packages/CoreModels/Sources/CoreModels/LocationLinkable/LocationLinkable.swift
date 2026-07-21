//
//  LocationLinkableText.swift
//  Wanderlust
//
//  Created by Rodrigo Mato Castellano on 4/24/25.
//

import Foundation
import struct SwiftUI.Color
import UIKit

public protocol LocationLinkable {
    var text: String { get }
    var locations: [Trip.Itinerary.Location]? { get }
}

public extension LocationLinkable {
    @MainActor
    public var linkedText: AttributedString {
        var attrString = AttributedString(text)
        guard let locations else { return attrString }

        for loc in locations {
            guard
                let lat = Double(loc.latitude),
                let lng = Double(loc.longitude),
                let url = LocationLinkBuilder.preferredPlaceURL(
                    name: loc.placeName,
                    latitude: lat,
                    longitude: lng,
                    placeID: loc.placeID
                )
            else { continue }

            var cursor = attrString.startIndex
            while let found = attrString[cursor...]
                      .range(of: loc.linkSubstring, options: .caseInsensitive) {

                attrString[found].link = url                      // Add the tappable link
                attrString[found].foregroundColor = Color(red: 0.039, green: 0.518, blue: 1.0)     // Add an extra color for this range
                attrString[found].underlineStyle = .single        // solid single line

                cursor = found.upperBound
            }
        }
        return attrString
    }
}
