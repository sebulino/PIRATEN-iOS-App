//
//  ProfileView.swift
//  PIRATEN
//
//  Created by Claude Code on 30.01.26.
//

import SwiftUI

struct ProfileView: View {
    var body: some View {
        NavigationStack {
            VStack {
                Spacer()
                Text("Profile")
                    .font(.largeTitle)
                Spacer()
            }
            .navigationTitle("Profile")
        }
    }
}

#Preview {
    ProfileView()
}
