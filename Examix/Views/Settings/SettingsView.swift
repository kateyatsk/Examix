//
//  SettingsView.swift
//  Lingvistik
//
//  Created by Екатерина Яцкевич on 17.04.25.
//

import SwiftUI
import UIKit

struct SettingsView: View {
    @EnvironmentObject private var userSettings: UserSettings
    @EnvironmentObject private var authManager: AuthenticationManager
    @State private var avatarImage: Image? = nil
    @State private var isPickerPresented = false
    @State private var pickedUIImage: UIImage? = nil

    private var displayUserName: String {
        (try? authManager.getAuthenticatedUser().name) ?? "Пользователь"
    }

    var body: some View {
        NavigationStack {
            ZStack {
                ExamixStyle.practiceScreenWash
                    .ignoresSafeArea()

                ScrollView(.vertical, showsIndicators: true) {
                    VStack(spacing: 20) {
                        avatarCard
                        languageCard
                        hintsCard
                        rulesCard
                        featureTourCard
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 16)
                    .padding(.bottom, 24)
                }
            }
            .navigationTitle("Настройки")
            .navigationBarTitleDisplayMode(.large)
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

    private var avatarCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Аватар")
                .font(.custom("MontserratAlternates-Bold", size: 16))
                .foregroundColor(.darkAccent)

            HStack(spacing: 18) {
                ZStack {
                    Group {
                        if let image = avatarImage {
                            image
                                .resizable()
                                .scaledToFill()
                        } else {
                            ZStack {
                                Circle()
                                    .fill(ExamixStyle.squircleFill)
                                Image(systemName: "person.fill")
                                    .font(.system(size: 28))
                                    .foregroundStyle(.white.opacity(0.9))
                            }
                        }
                    }
                    VStack {
                        Spacer(minLength: 0)
                        Text(displayUserName)
                            .font(.custom("MontserratAlternates-SemiBold", size: 11))
                            .foregroundStyle(.white)
                            .lineLimit(1)
                            .minimumScaleFactor(0.65)
                            .frame(maxWidth: 76)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 6)
                            .frame(maxWidth: .infinity)
                            .background(Color.black.opacity(0.48))
                    }
                }
                .frame(width: 76, height: 76)
                .clipShape(Circle())
                .overlay(
                    Circle()
                        .stroke(ExamixStyle.accentMuted.opacity(0.45), lineWidth: 2.5)
                )

                VStack(alignment: .leading, spacing: 10) {
                    Text("Фото видно в профиле")
                        .font(.custom("MontserratAlternates-Regular", size: 13))
                        .foregroundColor(.secondary)

                    Button {
                        isPickerPresented = true
                    } label: {
                        Text("Изменить фото")
                            .font(.custom("MontserratAlternates-Medium", size: 15))
                            .foregroundColor(.darkAccent)
                            .padding(.horizontal, 18)
                            .padding(.vertical, 10)
                            .background(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .fill(ExamixStyle.chipFill)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .stroke(ExamixStyle.accentCool.opacity(0.25), lineWidth: 1)
                            )
                    }
                    .buttonStyle(.plain)
                }

                Spacer(minLength: 0)
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(examixCardBackground())
    }

    private var languageCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Предмет обучения")
                .font(.custom("MontserratAlternates-Bold", size: 16))
                .foregroundColor(.darkAccent)

            Text("Варианты тестов и практика подстраиваются под выбранный предмет.")
                .font(.custom("MontserratAlternates-Regular", size: 12))
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            VStack(spacing: 8) {
                ForEach(Language.allCases, id: \.self) { lang in
                    let isSelected = userSettings.selectedLanguage == lang
                    Button {
                        userSettings.selectedLanguage = lang
                    } label: {
                        HStack(spacing: 12) {
                            Image(lang.flagName)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 32, height: 22)
                                .clipShape(RoundedRectangle(cornerRadius: 3, style: .continuous))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                                        .stroke(Color.black.opacity(0.08), lineWidth: 1)
                                )
                            Text(lang.rawValue)
                                .font(.custom("MontserratAlternates-Medium", size: 15))
                                .foregroundColor(.darkAccent)
                            Spacer()
                            if isSelected {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 20))
                                    .foregroundStyle(ExamixStyle.accentCool)
                            }
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(isSelected ? ExamixStyle.accentMuted.opacity(0.18) : Color.primary.opacity(0.04))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(isSelected ? ExamixStyle.accentCool.opacity(0.45) : Color.clear, lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(examixCardBackground())
    }

    private static func hintLimitTitle(for value: Int) -> String {
        switch value {
        case -1: return "Без ограничения"
        case 0: return "Не использовать"
        case 1: return "1 подсказка"
        default: return "\(value) подсказок"
        }
    }

    private var hintsCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .center, spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    ExamixStyle.accentCool.opacity(0.35),
                                    ExamixStyle.accentMuted.opacity(0.25)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 44, height: 44)
                    Image(systemName: "lightbulb.fill")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(Color(.darkAccent))
                }
                .frame(width: 44, height: 44)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Подсказки в тесте")
                        .font(.custom("MontserratAlternates-Bold", size: 16))
                        .foregroundColor(.darkAccent)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Text("Сколько раз за один проход можно открыть пояснение к заданию.")
                        .font(.custom("MontserratAlternates-Regular", size: 12))
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Лимит")
                    .font(.custom("MontserratAlternates-Medium", size: 13))
                    .foregroundStyle(.secondary)

                Menu {
                    Button("Без ограничения") { userSettings.maxHintsPerTest = -1 }
                    Button("Не использовать") { userSettings.maxHintsPerTest = 0 }
                    Divider()
                    ForEach(1...10, id: \.self) { n in
                        Button(Self.hintLimitTitle(for: n)) {
                            userSettings.maxHintsPerTest = n
                        }
                    }
                } label: {
                    HStack(alignment: .center, spacing: 10) {
                        Text(Self.hintLimitTitle(for: userSettings.maxHintsPerTest))
                            .font(.custom("MontserratAlternates-SemiBold", size: 15))
                            .foregroundStyle(Color(.darkAccent))
                            .multilineTextAlignment(.leading)
                            .lineLimit(2)
                            .minimumScaleFactor(0.82)
                            .fixedSize(horizontal: false, vertical: true)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        Image(systemName: "chevron.up.chevron.down")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(Color(.darkAccent).opacity(0.45))
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(Color.primary.opacity(0.045))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(
                                LinearGradient(
                                    colors: [
                                        ExamixStyle.accentCool.opacity(0.28),
                                        ExamixStyle.practiceTypesGradientColors[1].opacity(0.2)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1
                            )
                    )
                    .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                .menuActionDismissBehavior(.automatic)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(examixCardBackground())
    }

    private var rulesCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Правила")
                .font(.custom("MontserratAlternates-Bold", size: 16))
                .foregroundColor(.darkAccent)

            NavigationLink {
                Group {
                    if let lang = userSettings.selectedLanguage {
                        RulesView(language: lang)
                    } else {
                        ZStack {
                            ExamixStyle.screenCanvas.ignoresSafeArea()
                            VStack(spacing: 12) {
                                Image(systemName: "globe")
                                    .font(.system(size: 40))
                                    .foregroundStyle(ExamixStyle.accentCool.opacity(0.55))
                                Text("Сначала выберите предмет обучения")
                                    .font(.custom("MontserratAlternates-Medium", size: 16))
                                    .foregroundColor(.darkAccent)
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal, 32)
                            }
                        }
                    }
                }
            } label: {
                HStack(spacing: 14) {
                    ExamixSquircleIcon(systemName: "doc.text.fill", side: 44, iconPointSize: 17)

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Правила и условия")
                            .font(.custom("MontserratAlternates-Medium", size: 16))
                            .foregroundColor(.darkAccent)
                        Text("Экзамен, формат заданий, оценивание")
                            .font(.custom("MontserratAlternates-Regular", size: 12))
                            .foregroundColor(.secondary)
                    }

                    Spacer(minLength: 0)

                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.tertiary)
                }
                .padding(14)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color.primary.opacity(0.045))
                )
            }
            .buttonStyle(.plain)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(examixCardBackground())
    }

    private var featureTourCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Экскурсия")
                .font(.custom("MontserratAlternates-Bold", size: 16))
                .foregroundColor(.darkAccent)

            Text("Краткий обзор главной, тестов, результатов, профиля и настроек.")
                .font(.custom("MontserratAlternates-Regular", size: 12))
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Button {
                userSettings.requestFeatureOnboardingReplay()
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "rectangle.stack.fill.badge.person.crop")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(ExamixStyle.accentCool)
                        .frame(width: 40, height: 40)
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(ExamixStyle.accentMuted.opacity(0.2))
                        )

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Показать экскурсию снова")
                            .font(.custom("MontserratAlternates-SemiBold", size: 15))
                            .foregroundColor(.darkAccent)
                        Text("Полноэкранный сценарий из нескольких шагов")
                            .font(.custom("MontserratAlternates-Regular", size: 11))
                            .foregroundColor(.secondary)
                    }

                    Spacer(minLength: 0)

                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.tertiary)
                }
                .padding(14)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color.primary.opacity(0.045))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(ExamixStyle.accentCool.opacity(0.2), lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(examixCardBackground())
    }

    private func examixCardBackground() -> some View {
        RoundedRectangle(cornerRadius: 20, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [Color.white, Color(red: 0.93, green: 0.96, blue: 1.0)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .shadow(color: Color.black.opacity(0.07), radius: 16, x: 0, y: 6)
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(
                        LinearGradient(
                            colors: [
                                ExamixStyle.practiceThemesGradientColors[0].opacity(0.26),
                                ExamixStyle.practiceTypesGradientColors[1].opacity(0.22)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            )
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
            .environmentObject(AuthenticationManager.shared)
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
