//
//  OnboardingView.swift
//  Onboarding - the first-run flow UI (onboarding.md "Flow"). Two value pages
//  then a permissions page; native look, all copy through L().
//

import SwiftUI

struct OnboardingView: View {
    @ObservedObject var model: OnboardingModel

    var body: some View {
        VStack(spacing: 0) {
            pageDots
            Group {
                switch model.step {
                case .value:       valuePage
                case .permissions: permissionsPage
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .transition(.opacity)
        }
        .animation(.easeInOut, value: model.step)
        .background(Color(.systemBackground))
        .onAppear { model.start() }
    }

    // MARK: - Value page

    /// Sample stamped photo + the title + three proof bullets.
    private let valueBullets: [(icon: String, text: String)] = [
        ("location.fill", "Burn location and time into every shot"),
        ("checkmark.seal.fill", "Your photos hold up as evidence"),
        ("doc.text.fill", "Drop it straight into your report"),
    ]

    private var valuePage: some View {
        VStack(spacing: 24) {
            Spacer()
            SampleStampView()
            Text(L("Prove where you were."))
                .font(.largeTitle.bold())
                .multilineTextAlignment(.center)
            VStack(alignment: .leading, spacing: 16) {
                ForEach(valueBullets, id: \.text) { bullet in
                    HStack(spacing: 14) {
                        Image(systemName: bullet.icon)
                            .font(.title3)
                            .foregroundStyle(Color.accentColor)
                            .frame(width: 28)
                        Text(L(bullet.text))
                        Spacer(minLength: 0)
                    }
                }
            }
            Spacer()
            continueButton(L("Continue"), busy: false, action: model.next)
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 24)
    }

    // MARK: - Permissions page

    private var permissionsPage: some View {
        VStack(spacing: 24) {
            Spacer()
            VStack(spacing: 12) {
                Text(L("Almost ready"))
                    .font(.largeTitle.bold())
                    .multilineTextAlignment(.center)
                Text(L("Enable access to capture and stamp your photos."))
                    .multilineTextAlignment(.center)
            }
            VStack(spacing: 16) {
                permissionRow(icon: "location.fill", title: L("Location"),
                              detail: L("Stamp coordinates, altitude, and address onto each photo."),
                              granted: model.locationGranted)
                permissionRow(icon: "camera.fill", title: L("Camera"),
                              detail: L("Capture the photos and videos you'll stamp."),
                              granted: model.cameraGranted)
                permissionRow(icon: "photo.fill", title: L("Photos"),
                              detail: L("Save every capture to your photo library."),
                              granted: model.photosGranted)
            }
            Spacer()
            continueButton(L("Enable"), busy: model.requesting,
                           action: model.requestPermissions)
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 24)
    }

    private func permissionRow(icon: String, title: String, detail: String,
                               granted: Bool?) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(Color.accentColor)
                .frame(width: 38, height: 38)
                .background(Color.accentColor.opacity(0.12),
                            in: RoundedRectangle(cornerRadius: 10))
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.headline)
                Text(detail).font(.subheadline).foregroundStyle(.secondary)
            }
            Spacer()
            if let granted {
                Image(systemName: granted ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .foregroundStyle(granted ? Color.green : Color.secondary)
            }
        }
        .padding(14)
        .background(Color(.secondarySystemBackground),
                    in: RoundedRectangle(cornerRadius: 14))
    }

    // MARK: - Scaffold

    private func continueButton(_ title: String, busy: Bool,
                                action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Group {
                if busy { ProgressView() } else { Text(title).font(.headline) }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)
        }
        .buttonStyle(.borderedProminent)
        .disabled(busy)
    }

    private var pageDots: some View {
        let steps: [OnboardingModel.Step] = [.value, .permissions]
        return HStack(spacing: 8) {
            ForEach(steps.indices, id: \.self) { i in
                Circle()
                    .fill(steps[i] == model.step ? Color.accentColor : Color(.systemGray4))
                    .frame(width: 7, height: 7)
            }
        }
        .padding(.top, 16)
    }
}

/// A stamped-photo mock (onboarding.md): the `OnboardingSample` photo asset with
/// an overlay-style info card. Falls back to a gradient until the asset is added
/// (add an image set named "OnboardingSample" to Assets.xcassets).
private struct SampleStampView: View {
    var body: some View {
        // The gradient base fixes the layout size; the photo fills it as an
        // overlay and is clipped, so scaledToFill can't inflate the box (which
        // would push the bottom-anchored card out of view).
        LinearGradient(colors: [Color(.systemBlue).opacity(0.55),
                                Color(.systemGray)],
                       startPoint: .top, endPoint: .bottom)
            .overlay {
                Image("OnboardingSample")
                    .resizable()
                    .scaledToFill()
            }
            .frame(maxWidth: .infinity)
            .frame(height: 200)
            .clipped()
            .overlay(alignment: .bottomLeading) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("40.7484, -73.9857").font(.caption.monospaced().bold())
                    Text(L("Empire State Building, New York")).font(.caption2)
                    Text("2026-07-10 14:05  N").font(.caption2.monospaced())
                }
                .foregroundStyle(.white)
                .padding(10)
                .background(.black.opacity(0.45), in: RoundedRectangle(cornerRadius: 8))
                .padding(12)
            }
            .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

#Preview {
    OnboardingView(model: OnboardingModel(
        location: PreviewLocation(), store: SettingsStore(),
        events: NoopTracker()))
}

/// Minimal `LocationProviding` for previews.
private final class PreviewLocation: LocationProviding {
    var snapshot: LocationSnapshot? { nil }
    var authorization: PermissionStatus { .notDetermined }
    func start() {}
    func stop() {}
    func requestPermission(_ completion: @escaping (PermissionStatus) -> Void) {
        completion(.notDetermined)
    }
}
