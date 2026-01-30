//
//  KnowledgeView.swift
//  PIRATEN
//
//  Created by Claude Code on 30.01.26.
//

import SwiftUI

struct KnowledgeView: View {
    var body: some View {
        NavigationStack {
            VStack {
                Spacer()
                Text("Knowledge")
                    .font(.largeTitle)
                Spacer()
            }
            .navigationTitle("Knowledge")
        }
    }
}

#Preview {
    KnowledgeView()
}
