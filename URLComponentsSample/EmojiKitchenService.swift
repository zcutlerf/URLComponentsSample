//
//  EmojiService.swift
//  URLComponentsSample
//
//  Created by Zoe Cutler on 2/6/24.
//

import SwiftUI

/// Service for API from https://emk.vercel.app that creates emoji combinations.
class EmojiKitchenService {
    /// The scheme subcomponent of the URL. Usually https for APIs, but could be http.
    static let scheme = "https"
    
    /// The host subcomponent of the URL. (i.e.: everything between the http:// and the path extension.
    static let host = "emojik.vercel.app"
    
    /// I'm using an Endpoint enum to keep track of different endpoints I might request for this API.
    enum Endpoint {
        /// This endpoint has two associated values, because the API documentation says we have to pass 2 emojis into the path.
        /// We could also create a regular endpoint, such as `case someEndpoint` if we don't need associated values.
        case emojiCombination(emoji1: Character, emoji2: Character)
        
        /// The path for each endpoint.
        var path: String {
            switch self {
                // Because this endpoint has associated values, we're passing them into the path string.
            case .emojiCombination(let emoji1, let emoji2):
                "/s/\(emoji1)_\(emoji2)"
            }
        }
    }
    
    /// Custom errors that might occur during EmojiService methods.
    enum EmojiServiceError: LocalizedError {
        case sizeNotInRange, couldNotConstructImage
    }
    
    /// Contacts the `emk.vercel.app` API to get an image that is a combination of two emojis.
    /// - Parameters:
    ///   - emoji1: An emoji to combine.
    ///   - emoji2: Another emoji to combine.
    ///   - size: The size of the image to get back.
    /// - Returns: A SwiftUI Image representing the combination of both emojis.
    func getEmojiCombination(for emoji1: Character, and emoji2: Character, with size: Int) async throws -> Image {
        // The API says the size query item must be between 16 and 512, so let's check to make sure that is the case before continuing, and if it's not we can throw an error.
        guard size >= 16 && size <= 512 else {
            throw EmojiServiceError.sizeNotInRange
        }
        
        // Create a new instance of URLComponents and set the scheme and host.
        var components = URLComponents()
        components.scheme = Self.scheme
        components.host = Self.host
        
        // Create the endpoint's path based on the emojis we want.
        let endpoint = Endpoint.emojiCombination(emoji1: emoji1, emoji2: emoji2)
        components.path = endpoint.path
        
        // Attempt to construct a URL from our URLComponents.
        guard var url = components.url else {
            // If this doesn't work, we're going to throw a Bad URL error, so that we know what went wrong.
            throw URLError(.badURL)
        }
        
        // Some APIs need Query Items in the URL. These are the values that come after the "?" in a URL.
        // Our API suggested the URL of https://emojik.vercel.app/s/🥹_😗?size=128 so we know we need a query item called size with a value of 128. All names and values must be strings, so we're converting size into a String.
        let sizeQueryItem = URLQueryItem(name: "size", value: String(size))
        // Make sure to add your query items to your URL as an array of query items.
        url.append(queryItems: [sizeQueryItem])
        
        // Create a URL request from our URL. This allows us to specify a HTTP method, header fields, body, etc. (Note: the API for this project does not require any of these, so we don't technically need a URLRequest, but I'm including it here because it might be helpful for other APIs.)
        var request = URLRequest(url: url)
        // GET is the default HTTP method, but you can also specify POST or other methods that your API might require.
        request.httpMethod = "GET"
        
        // If our API requires us to set header fields, we can do that like this:
        // request.setValue("some value", forHTTPHeaderField: "some header field")
        
        // If our API requires a POST method with a HTTP body, we can set that now:
        // request.httpBody = (some data encoded as JSON or whatever our API requires.)
        
        // This is where we actually connect to the URL and attempt to download data from it.
        let data = try await URLSession.shared.data(for: request)
        
        // Because this URL returns us an image as Data, we have to attempt to convert it to an image.
        guard let uiImage = UIImage(data: data.0) else {
            // If this doesn't work, we should throw an error that describes the problem.
            throw EmojiServiceError.couldNotConstructImage
        }
        
        // If all of the above succeeds, we'll cast our UIImage to a SwiftUI Image and return it!
        return Image(uiImage: uiImage)
    }
}
