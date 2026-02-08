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
                Text("Hier statischer Text mit Infos zu 'Was ist Kommunalpolitik?', 'Was macht ein Schatzmeister?', ...")
                    .font(.largeTitle)
                Spacer()
            }
            .navigationTitle("Wissen")
        }
    }
}

#Preview {
    KnowledgeView()
}
