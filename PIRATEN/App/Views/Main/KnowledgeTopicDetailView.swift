//
//  KnowledgeTopicDetailView.swift
//  PIRATEN
//
//  Stub view — will be fully implemented in M8-014.
//

import SwiftUI

struct KnowledgeTopicDetailView: View {
    @ObservedObject var viewModel: KnowledgeTopicDetailViewModel

    var body: some View {
        Text("Thema: \(viewModel.topic.title)")
            .navigationTitle(viewModel.topic.title)
    }
}
