# Using URLComponents and URLRequest to Contact an API in Swift


## TL;DR

We're going to call the [Emoji Kitchen API](https://emk.vercel.app) by [@arnav-kr](https://github.com/arnav-kr). This API will take 2 emojis, and return an image representing the combination of both emojis.
We'll talk about how `URLComponents` and `URLRequest` allow us to customize our URLs and be safer

> [!NOTE]
> If you want to skip to the [sample code](https://github.com/zcutlerf/URLComponentsSample) for this project, you can find that [here](https://github.com/zcutlerf/URLComponentsSample).


## Topics Covered

* [URLComponents](https://developer.apple.com/documentation/foundation/urlcomponents)
    * Scheme
    * Host
    * Path
* [URL Query items](https://developer.apple.com/documentation/foundation/urlqueryitem)
* [URLRequest](https://developer.apple.com/documentation/foundation/urlrequest)
    * HTTP method
    * Header fields
    * HTTP body
* [URLSession](https://developer.apple.com/documentation/foundation/urlsession)
    * Receiving data using [Swift Concurrency](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/concurrency/)
* Decoding an [Image from Data](https://developer.apple.com/documentation/uikit/uiimage/1624106-init)


## The Old Way

Without using URLComponents and URLRequest, we could call the Emoji Kitchen API like this:

```Swift
func getEmojiCombination(for emoji1: Character, and emoji2: Character, with size: Int) async throws -> Image {
    guard let url = URL(string: "https://emojik.vercel.app/s/\(emoji1)_\(emoji2)?size=\(size)") else {
        // Throw an error
    }
    let data = try await URLSession.shared.data(from: url)
    guard let uiImage = UIImage(data: data.0) else {
        // Throw an error
    }
    return Image(uiImage: uiImage)
}
```

This will work, but there are some problems with this approach.
* **What if we need to add another query item that is a `String`?** If we end up with spaces or other nonstandard characters in our URL, Swift won't be able to construct an appropriate URL for us.
* **What if we need to add header fields?** Some APIs require header fields, i.e.: for authentication. We can't do this without URLRequest.
* **What if we need to change the HTTP method?** By default, the HTTP method is `GET`, but some APIs require `POST`, `PUT`, `DELETE`, etc. We can't do this without URLRequest.
* **What if we are passing an HTTP body to our `POST` request?** We can't do this without URLRequest.
* **Our code will be less reusable.** Creating a URL from URLComponents allows us to write more reusable and modular code.


## Creating an API Service
Let's start by creating a service for the Emoji Kitchen API. We'll need to specify:
* `scheme`: Which protocol to use to contact our URL. For this API, we need to use the Hypertext Transfer Protocol Secure (HTTPS). (Note: we do not need to include the `://` because Swift will add this for us.)
* `host`: Where our API is located. This is the basic part of the URL, before the path.

```Swift
class EmojiKitchenService {
    static let scheme = "https"
    static let host = "emojik.vercel.app"
    
    // ...
}
```

Then, we'll want to outline the endpoints available from our API. We can do this with an enum that has a computed property for the `path` for each endpoint.

```Swift
class EmojiKitchenService {
    static let scheme = "https"
    static let host = "emojik.vercel.app"

    enum Endpoint {
        case emojiCombination(emoji1: Character, emoji2: Character)
        
        var path: String {
            switch self {
            case .emojiCombination(let emoji1, let emoji2):
                "/s/\(emoji1)_\(emoji2)"
            }
        }
    }
    
    // ...
}
```

> [!NOTE]
> This API tells us to use the path `/s/:emojis`, where `:emojis` represents a dynamic extension. We are supposed to put two emojis (or code points) separated by an underscore here. Because of this, we're using an enum with [associated values](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/enumerations/#Associated-Values).

Now, lets define a method to call this endpoint **inside EmojiKitchenService**. We'll need to know the two emojis to combine, as well as the size of the image to be returned. This method will be asynchronous and could encounter errors. If all goes well, we'll return an image.

```Swift
func getEmojiCombination(for emoji1: Character, and emoji2: Character, with size: Int) async throws -> Image {
    // ...
}
```

> [!NOTE]
> In order to use `Image` as a type, you'll need to `import SwiftUI`.

The API documentation says that size must be between 16 and 512. Lets check for this upfront, so that we aren't wasting time sending improper information.
* Create an EmojiServiceError enum **inside EmojiKitchenService**, with a case for `sizeNotInRange`.
* Check if the size passed into `getEmojiCombination(for:and:with:)` is in the right range, and otherwise throw our custom error.

```Swift
enum EmojiServiceError: LocalizedError {
    case sizeNotInRange
}

func getEmojiCombination(for emoji1: Character, and emoji2: Character, with size: Int) async throws -> Image {
    guard size >= 16 && size <= 512 else {
        throw EmojiServiceError.sizeNotInRange
    }
}
```

## Building a URL with URLComponents

Instead of making a URL from a String, we're going to build it incrementally using URLComponents. We need to:
1. Create a new instance of URLComponents and set the scheme and host.
2. Create the endpoint's path based on the emojis we need.
3. Attempt to construct a URL from our URLComponents.
    * If this doesn't work, we can use Swift's built in URLError to throw `URLError.Code.badURL`.

```Swift
func getEmojiCombination(for emoji1: Character, and emoji2: Character, with size: Int) async throws -> Image {
    // ...

    var components = URLComponents()
    components.scheme = Self.scheme
    components.host = Self.host
    
    let endpoint = Endpoint.emojiCombination(emoji1: emoji1, emoji2: emoji2)
    components.path = endpoint.path
    
    guard var url = components.url else {
        throw URLError(.badURL)
    }
    
    // ...
}
```

## Adding Query Items

Some APIs need query items in the URL. These are the values that come after the "?" in a URL. Our API suggested the URL of `https://emojik.vercel.app/s/🥹_😗?size=128` so we know we need a query item called "size" with a value of `Int`. All names and values must be strings, so we're converting `size` into a String.
* Create a `URLQueryItem` for each parameter we need to specify.
* Append these query items to the URL.
```Swift
func getEmojiCombination(for emoji1: Character, and emoji2: Character, with size: Int) async throws -> Image {
    // ...

    let sizeQueryItem = URLQueryItem(name: "size", value: String(size))
    url.append(queryItems: [sizeQueryItem])
    
    // ...
}
```


## Creating a URLRequest

Create a URL request from our URL. This allows us to specify a HTTP method, header fields, body, etc.

> [!NOTE]
> The API for this project does not require any of these, so we don't technically need a URLRequest, but I'm including it here because it might be helpful for other APIs.)
    
```Swift
func getEmojiCombination(for emoji1: Character, and emoji2: Character, with size: Int) async throws -> Image {
    // ...

    var request = URLRequest(url: url)
    // GET is the default HTTP method, but you can also specify POST or other methods that your API might require.
    request.httpMethod = "GET"
    
    // If our API requires us to set header fields, we can do that like this:
    // request.setValue("some value", forHTTPHeaderField: "some header field")
    
    // If our API requires a POST method with a HTTP body, we can set that now:
    // request.httpBody = (some data encoded as JSON or whatever our API requires.)
    
    // ...
}
```


## Fetching Data from URLSession

Now we can actually connect to the URL and attempt to download data from it.
```Swift
func getEmojiCombination(for emoji1: Character, and emoji2: Character, with size: Int) async throws -> Image {
    // ...

    let data = try await URLSession.shared.data(for: request)
    
    // ...
}
```


## Converting Data to Image
Because this URL returns us an image as Data, we have to attempt to convert it to an image.
* Use the `UIImage(data:)` initializer to convert Data to a UIImage.
* If this doesn't work, throw an error. (Hint: Add a `couldNotConstructImage` case to your `EmojiServiceError` enum.)
```Swift
func getEmojiCombination(for emoji1: Character, and emoji2: Character, with size: Int) async throws -> Image {
    // ...

    guard let uiImage = UIImage(data: data.0) else {
        // If this doesn't work, we should throw an error that describes the problem.
        throw EmojiServiceError.couldNotConstructImage
    }
    
    // If all of the above succeeds, we'll cast our UIImage to a SwiftUI Image and return it!
    return Image(uiImage: uiImage)

    // ...
}
```


## Wrapping Up

Now, all that's left is to use our API where we need it! Here's an example of a SwiftUI View that lets a user input 2 emojis, and asks the API for an Image that is the combination of these emojis.

```Swift
struct ContentView: View {
    let emojiService = EmojiKitchenService()
    
    @State private var emoji1 = ""
    @State private var emoji2 = ""
    
    @State private var isShowingErrorAlert = false
    @State private var errorAlertTitle = ""
    
    @State private var isLoading = false
    @State private var image: Image?
    
    var body: some View {
        VStack {
            TextField("Emoji 1", text: $emoji1)
                .textFieldStyle(.roundedBorder)
            
            Image(systemName: "plus")
                .font(.largeTitle)
            
            TextField("Emoji 2", text: $emoji2)
                .textFieldStyle(.roundedBorder)
            
            Button {
                combineEmoji()
            } label: {
                Label("Combine", systemImage: "wand.and.stars")
            }
            .buttonStyle(.borderedProminent)
            .disabled(emoji1.isEmpty || emoji2.isEmpty)
            
            if isLoading {
                ProgressView()
                Text("Making image...")
            } else if let image {
                image
            }
        }
        .padding()
        .alert(errorAlertTitle, isPresented: $isShowingErrorAlert) {
            Button("dismiss") { }
        }
    }
    
    func combineEmoji() {
        Task {
            isLoading = true
            do {
                guard let firstEmoji = emoji1.first,
                      let secondEmoji = emoji2.first else {
                    errorAlertTitle = "Please enter exactly 1 emoji in each text field."
                    isShowingErrorAlert = true
                    return
                }
                
                let size = 100
                image = try await emojiService.getEmojiCombination(for: firstEmoji, and: secondEmoji, with: size)
            } catch {
                errorAlertTitle = error.localizedDescription
                isShowingErrorAlert = true
                image = nil
            }
            isLoading = false
        }
    }
}
```


## Full EmojiKitchenService Code

```Swift
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
```
