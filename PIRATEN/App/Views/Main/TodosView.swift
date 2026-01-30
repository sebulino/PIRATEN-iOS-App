//
//  TodosView.swift
//  PIRATEN
//
//  Created by Claude Code on 30.01.26.
//

import SwiftUI

struct TodosView: View {
    var body: some View {
        NavigationStack {
            VStack {
                Spacer()
                Text("Todos")
                    .font(.largeTitle)
                Spacer()
            }
            .navigationTitle("Todos")
        }
    }
}

#Preview {
    TodosView()
}
