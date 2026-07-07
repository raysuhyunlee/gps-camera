//
//  PurchaseSuccessView.swift
//  Monetization - modal shown after a successful purchase (monetization.md
//  "Paywall"). Presented in its own window so it shows over any screen.
//  Lottie celebration on top; falls back to an SF Symbol when the bundled
//  animation is missing.
//

import Lottie
import SwiftUI

/// Presents the modal in its own alert-level window, independent of whatever
/// screen or sheet stack is frontmost (the paywall may already be tearing
/// down when entitlement flips to pro).
@MainActor
enum PurchaseSuccess {
    private static var window: UIWindow?

    static func present() {
        let scenes = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
        guard let scene = scenes.first(where: {
            $0.activationState == .foregroundActive }) ?? scenes.first
        else { return }
        let overlay = UIWindow(windowScene: scene)
        overlay.windowLevel = .alert
        let root = UIViewController()
        root.view.backgroundColor = .clear
        overlay.rootViewController = root
        overlay.makeKeyAndVisible()
        let host = UIHostingController(
            rootView: PurchaseSuccessView(onContinue: dismiss))
        host.isModalInPresentation = true
        if let sheet = host.sheetPresentationController {
            sheet.detents = [.medium()]
        }
        root.present(host, animated: true)
        window = overlay
    }

    private static func dismiss() {
        window?.rootViewController?.dismiss(animated: true) {
            window?.isHidden = true
            window = nil
        }
    }
}

struct PurchaseSuccessView: View {
    let onContinue: () -> Void

    var body: some View {
        VStack(spacing: 8) {
            celebration
                .frame(width: 180, height: 180)
                .padding(.top, 32)
            Text(L("Pro unlocked!"))
                .font(.title.bold())
            Text(L("Enjoy all features"))
                .foregroundStyle(.secondary)
            Spacer()
            Button {
                onContinue()
            } label: {
                Text(L("Continue"))
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
            }
            .buttonStyle(.borderedProminent)
            .padding(.horizontal, 24)
            .padding(.bottom, 8)
        }
        .background(Color(.systemBackground))
    }

    @ViewBuilder
    private var celebration: some View {
        if let animation = LottieAnimation.named("PurchaseSuccess") {
            LottieView(animation: animation)
                .playing(loopMode: .playOnce)
        } else {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 96))
                .foregroundStyle(.green)
        }
    }
}

#Preview {
    PurchaseSuccessView(onContinue: {})
}
