//
//  SettingsView.swift
//  Lingvistik
//
//  Created by Екатерина Яцкевич on 17.04.25.
//

import SwiftUI
import FirebaseFirestore
import UIKit

struct SettingsView: View {
    @EnvironmentObject private var userSettings: UserSettings
    @State private var avatarImage: Image? = nil
    @State private var isPickerPresented = false
    @State private var pickedUIImage: UIImage? = nil

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Аватар").font(.custom("MontserratAlternates-Bold", size: 14))) {
                    HStack {
                        if let image = avatarImage {
                            image
                                .resizable()
                                .scaledToFill()
                                .frame(width: 60, height: 60)
                                .clipShape(Circle())
                        } else {
                            Circle()
                                .fill(Color.gray.opacity(0.3))
                                .frame(width: 60, height: 60)
                                .overlay(Image(systemName: "person.fill").foregroundColor(.white))
                        }

                        Button("Выбрать аватар") {
                            isPickerPresented = true
                        }
                        .font(.custom("MontserratAlternates-Medium", size: 14))
                    }
                }

                Section(header: Text("Язык обучения").font(.custom("MontserratAlternates-Bold", size: 14))) {
                    Picker("Выберите язык", selection: $userSettings.selectedLanguage) {
                        ForEach(Language.allCases, id: \ .self) { lang in
                            Text(lang.rawValue).tag(Optional(lang))
                                .font(.custom("MontserratAlternates-Medium", size: 14))
                        }
                    }
                }

                Section(header: Text("Правила").font(.custom("MontserratAlternates-Bold", size: 14))) {
                    NavigationLink("Посмотреть правила") {
                        if let lang = userSettings.selectedLanguage {
                            RulesView(language: lang)
                        } else {
                            Text("Сначала выберите язык")
                        }
                    }
                    .font(.custom("MontserratAlternates-Medium", size: 14))
                }

            }
            .navigationTitle("Настройки")
            .font(.custom("MontserratAlternates-Regular", size: 14))
            .sheet(isPresented: $isPickerPresented) {
                ImagePicker(image: $pickedUIImage) { selected in
                    if let uiImage = selected {
                        avatarImage = Image(uiImage: uiImage)
                        saveAvatarLocally(uiImage)
                    }
                }
            }
        }
        .onAppear {
            loadAvatar()
        }
    }

    func loadAvatar() {
        if let data = UserDefaults.standard.data(forKey: "localAvatar"),
           let uiImage = UIImage(data: data) {
            self.avatarImage = Image(uiImage: uiImage)
        }
    }

    func saveAvatarLocally(_ image: UIImage) {
        if let data = image.jpegData(compressionQuality: 0.8) {
            UserDefaults.standard.set(data, forKey: "localAvatar")
            print("✅ Аватар сохранён локально")
        } else {
            print("❌ Не удалось сохранить аватар")
        }
    }
}

struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView()
            .environmentObject(UserSettings())
    }
}

struct ImagePicker: UIViewControllerRepresentable {
    @Binding var image: UIImage?
    var onImagePicked: (UIImage?) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.delegate = context.coordinator
        picker.allowsEditing = true
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        let parent: ImagePicker

        init(_ parent: ImagePicker) {
            self.parent = parent
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            picker.dismiss(animated: true)
        }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            let selectedImage = (info[.editedImage] ?? info[.originalImage]) as? UIImage
            parent.image = selectedImage
            parent.onImagePicked(selectedImage)
            picker.dismiss(animated: true)
        }
    }
}
