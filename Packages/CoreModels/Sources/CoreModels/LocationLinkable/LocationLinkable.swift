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
        var attrString = Self.attributed(from: text)
        guard let locations else { return attrString }

        for loc in locations {
            // With coordinates we can open the place card itself; without them we still
            // link, as a Maps search on the full place name.
            let placeURL: URL?
            if let lat = loc.latitude.flatMap(Double.init), let lng = loc.longitude.flatMap(Double.init) {
                placeURL = LocationLinkBuilder.preferredPlaceURL(
                    name: loc.placeName,
                    latitude: lat,
                    longitude: lng,
                    placeID: loc.placeID
                )
            } else {
                placeURL = LocationLinkBuilder.searchURL(name: loc.placeName)
            }

            guard let url = placeURL else { continue }

            // The model sometimes echoes its own emphasis markers into linkSubstring,
            // which can never match the parsed text. Search for the bare name.
            let needle = loc.linkSubstring.trimmingCharacters(in: CharacterSet(charactersIn: "*_ "))
            guard !needle.isEmpty else { continue }

            var cursor = attrString.startIndex
            while let found = attrString[cursor...]
                      .range(of: needle, options: .caseInsensitive) {

                // A place name that carries Markdown's bold intent renders as bold and
                // swallows the link styling, so the blue underline never appears. Link
                // affordance wins: drop the emphasis wherever we attach a link.
                attrString[found].inlinePresentationIntent = nil

                attrString[found].link = url                      // Add the tappable link
                attrString[found].foregroundColor = Color(red: 0.039, green: 0.518, blue: 1.0)     // Add an extra color for this range
                attrString[found].underlineStyle = .single        // solid single line

                cursor = found.upperBound
            }
        }
        return attrString
    }

    /// The model emphasises place names with Markdown (`**Park Güell**`) even though the
    /// prompt asks for plain values, so parse it instead of letting the markers leak into
    /// the UI as literal asterisks. Inline-only, whitespace-preserving: bullets, headings
    /// and paragraph breaks stay untouched, and unparseable text falls back to plain.
    static func attributed(from raw: String) -> AttributedString {
        let parsed = try? AttributedString(
            markdown: raw,
            options: .init(
                allowsExtendedAttributes: false,
                interpretedSyntax: .inlineOnlyPreservingWhitespace,
                failurePolicy: .returnPartiallyParsedIfPossible
            )
        )
        return parsed ?? AttributedString(raw)
    }
}
