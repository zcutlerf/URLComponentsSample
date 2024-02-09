//
//  SwiftUIView.swift
//  URLComponentsSample
//
//  Created by Zoe Cutler on 2/8/24.
//

import SwiftUI
import SwiftData

@Model
class Something: Identifiable, ObservableObject {
    var id = UUID()
    var name: String
    
    init(name: String) {
        self.name = name
    }
}

struct SwiftUIView: View {
    @Environment(\.modelContext) var modelContext
    
    @StateObject private var something = Something(name: "idk")
    
    @Query private var favorites: [Something]
    
    var body: some View {
        VStack {
            TextField("", text: $something.name)
            Text(something.name)
        }
    }
}

#Preview {
    SwiftUIView()
}
