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
                case .hook:        hookPage
                case .report:      reportPage
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

    // MARK: - Value pages

    private var hookPage: some View {
        valuePage(
            icon: "checkmark.seal.fill",
            title: L("Prove where you were."),
            body: L("GPS Camera burns location, time, and direction into every shot - so your photos hold up as evidence."),
            action: model.next)
    }

    private var reportPage: some View {
        pageScaffold(hero: AnyView(SampleStampView()),
                     title: L("Report-ready in one tap."),
                     body: L("A clean, stamped photo with coordinates, address, and time - drop it straight into your report."),
                     button: L("Continue"),
                     busy: false,
                     action: model.next)
    }

    private func valuePage(icon: String, title: String, body: String,
                           action: @escaping () -> Void) -> some View {
        pageScaffold(hero: AnyView(
            Image(systemName: icon)
                .font(.system(size: 72))
                .foregroundStyle(Color.accentColor)),
                     title: title, body: body,
                     button: L("Continue"), busy: false, action: action)
    }

    // MARK: - Permissions page

    private var permissionsPage: some View {
        pageScaffold(
            hero: AnyView(VStack(spacing: 16) {
                permissionRow(icon: "location.fill", title: L("Location"),
                              detail: L("Stamp coordinates, altitude, and address onto each photo."),
                              granted: model.locationGranted)
                permissionRow(icon: "camera.fill", title: L("Camera"),
                              detail: L("Capture the photos and videos you'll stamp."),
                              granted: model.cameraGranted)
            }),
            title: L("Turn on the essentials"),
            body: L("GPS Camera needs two permissions to stamp your photos."),
            button: L("Enable"),
            busy: model.requesting,
            action: model.requestPermissions)
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

    private func pageScaffold(hero: AnyView, title: String, body: String,
                              button: String, busy: Bool,
                              action: @escaping () -> Void) -> some View {
        VStack(spacing: 24) {
            Spacer()
            hero
            VStack(spacing: 12) {
                Text(title)
                    .font(.largeTitle.bold())
                    .multilineTextAlignment(.center)
                Text(body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            Spacer()
            Button(action: action) {
                Group {
                    if busy { ProgressView() } else { Text(button).font(.headline) }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
            }
            .buttonStyle(.borderedProminent)
            .disabled(busy)
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 24)
    }

    private var pageDots: some View {
        let steps: [OnboardingModel.Step] = [.hook, .report, .permissions]
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

/// Decoupled stand-in for a stamped photo (onboarding.md): a photo-like
/// gradient with an overlay-style info card. Swap in a real marketing image by
/// replacing this with `Image("OnboardingSample")` if desired.
private struct SampleStampView: View {
    var body: some View {
        ZStack(alignment: .bottomLeading) {
            LinearGradient(colors: [Color(.systemBlue).opacity(0.55),
                                    Color(.systemGray)],
                           startPoint: .top, endPoint: .bottom)
            VStack(alignment: .leading, spacing: 2) {
                Text("37.5665, 126.9780").font(.caption.monospaced().bold())
                Text("Seoul, South Korea").font(.caption2)
                Text("2026-07-10 14:05  N").font(.caption2.monospaced())
            }
            .foregroundStyle(.white)
            .padding(10)
            .background(.black.opacity(0.45), in: RoundedRectangle(cornerRadius: 8))
            .padding(12)
        }
        .frame(height: 200)
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
    func requestPermission() {}
}
