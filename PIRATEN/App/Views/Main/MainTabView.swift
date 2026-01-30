//
//  MainTabView.swift
//  PIRATEN
//
//  Created by Claude Code on 30.01.26.
//

import SwiftUI

struct MainTabView: View {
    @ObservedObject var forumViewModel: ForumViewModel
    @ObservedObject var todosViewModel: TodosViewModel

    var body: some View {
        TabView {
            ForumView(viewModel: forumViewModel)
                .tabItem {
                    Label("Forum", systemImage: "bubble.left.and.bubble.right")
                }

            MessagesView()
                .tabItem {
                    Label("Messages", systemImage: "envelope")
                }

            KnowledgeView()
                .tabItem {
                    Label("Knowledge", systemImage: "book")
                }

            TodosView(viewModel: todosViewModel)
                .tabItem {
                    Label("Todos", systemImage: "checklist")
                }

            ProfileView()
                .tabItem {
                    Label("Profile", systemImage: "person.circle")
                }
        }
    }
}

#Preview {
    MainTabView(
        forumViewModel: ForumViewModel(discourseRepository: FakeDiscourseRepository()),
        todosViewModel: TodosViewModel(todoRepository: FakeTodoRepository())
    )
}
