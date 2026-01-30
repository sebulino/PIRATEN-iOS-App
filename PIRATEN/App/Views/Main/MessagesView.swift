//
//  MessagesView.swift
//  PIRATEN
//
//  Created by Claude Code on 30.01.26.
//

import SwiftUI

struct MessagesView: View {
    var body: some View {
        NavigationStack {
            VStack {
                Spacer()
                Text("Messages")
                    .font(.largeTitle)
                Spacer()
            }
            .navigationTitle("Messages")
        }
    }
}

#Preview {
    MessagesView()
}
