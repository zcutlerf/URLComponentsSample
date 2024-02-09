//
//  ContentView.swift
//  URLComponentsSample
//
//  Created by Zoe Cutler on 2/6/24.
//

import SwiftUI

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

#Preview {
    ContentView()
}
