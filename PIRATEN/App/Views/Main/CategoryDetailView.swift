//
//  CategoryDetailView.swift
//  PIRATEN
//
//  Stub view — will be fully implemented in M8-013.
//

import SwiftUI

struct CategoryDetailView: View {
    let category: KnowledgeCategory
    let topics: [KnowledgeTopic]
    let progressStore: TopicProgressProvider
    var topicDetailViewModelFactory: ((KnowledgeTopic) -> KnowledgeTopicDetailViewModel)?

    var body: some View {
        Text("Kategorie: \(category.title)")
            .navigationTitle(category.title)
    }
}
