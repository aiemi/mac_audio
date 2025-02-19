//
//  HomeView.swift
//  AudioTapExample
//
//  Created by 大大 on 2025/2/17.
//

import SwiftUI

struct HomeView: View {
    
    @StateObject var presenter = HomePresenter()
    
    var body: some View {
        VStack {
            Button {
                presenter.reload()
            } label: {
                Text("权限开始")
            }
            .padding()

            Button {
                presenter.start()
            } label: {
                Text("开始")
            }
            .padding()
            
            Button {
                presenter.stop()
            } label: {
                Text("结束打开")
            }
            .padding()
        }
        .padding()
    }
}

#Preview {
    HomeView()
}
