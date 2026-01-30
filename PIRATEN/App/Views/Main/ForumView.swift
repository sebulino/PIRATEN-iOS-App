//
//  ForumView.swift
//  PIRATEN
//
//  Created by Claude Code on 30.01.26.
//

import SwiftUI

struct ForumView: View {
    var body: some View {
        NavigationStack {
            VStack {
                Spacer()
                Text("Forum")
                    .font(.largeTitle)
                Spacer()
            }
            .navigationTitle("Forum")
        }
    }
}

#Preview {
    ForumView()
}
