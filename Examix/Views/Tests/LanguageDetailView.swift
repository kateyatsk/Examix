//
//  LanguageDetailView.swift
//  Lingvistik
//
//  Created by Екатерина Яцкевич on 20.02.25.
//

import SwiftUI

struct LanguageDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var path: NavigationPath
    @EnvironmentObject var userSettings: UserSettings
    
    var language: String
    var body: some View {
        ZStack {
            Color(.lightBack)
                .ignoresSafeArea()
            
            VStack {
                Image("boy")

                HStack {
                    Text("Выберите ")
                        .font(.custom("MontserratAlternates-Medium", size: 24))
                        .foregroundColor(.darkAccent) +
                    Text("режим ")
                        .font(.custom("MontserratAlternates-Bold", size: 24))
                        .foregroundColor(.stock) +
                    Text("теста")
                        .font(.custom("MontserratAlternates-Medium", size: 24))
                        .foregroundColor(.darkAccent)
                }
                .padding()
                
                VStack(spacing: 16) {
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(.secondaryBlue, lineWidth: 2)
                        .frame(width: 320, height: 72)
                        .background(Color.clear)
                        .overlay(
                            HStack() {
                                Text("Случайный")
                                    .font(.custom("MontserratAlternates-Medium", size: 18))
                                    .foregroundColor(.darkAccent)
                                Spacer()
                                Image(systemName: "arrow.right")
                                    .fontWeight(.bold)
                                    .frame(width: 24, height: 24)
                                    .foregroundColor(.darkAccent)
                            }
                                .padding()
                        )
                        .contentShape(RoundedRectangle(cornerRadius: 12))
                        .onTapGesture {
                            userSettings.selectedVariant = nil
                            path.append(HomeView.Path.testView)
                        }
                    
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(.secondaryBlue, lineWidth: 2)
                        .frame(width: 320, height: 72)
                        .background(Color.clear)
                        .overlay(
                            HStack {
                                
                                Text("На выбор")
                                    .font(.custom("MontserratAlternates-Medium", size: 18))
                                    .foregroundColor(.darkAccent)
                                Spacer()
                                Image(systemName: "arrow.right")
                                    .fontWeight(.bold)
                                    .frame(width: 24, height: 24)
                                    .foregroundColor(.darkAccent)
                                
                                
                            }.contentShape(RoundedRectangle(cornerRadius: 12))
                                .onTapGesture {
                                    path.append(HomeView.Path.chooseVariant)
                                }
                                .padding()
                        )
                    Spacer()
                }
            }.toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    RoundedRectangle(cornerRadius: 12)
                        .frame(width: 40, height: 40)
                        .foregroundStyle(.mainBack)
                        .overlay {
                            Image(systemName: "arrow.backward")
                                .imageScale(.large)
                                .foregroundStyle(.darkAccent)
                        }
                        .onTapGesture {
                            dismiss()
                        }
                    
                }
            }
        }
        .navigationBarBackButtonHidden()
    }
}

