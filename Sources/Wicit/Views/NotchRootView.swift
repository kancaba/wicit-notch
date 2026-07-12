import SwiftUI

struct NotchRootView: View {
    @ObservedObject var state: NotchState
    @ObservedObject private var theme = ThemeStore.shared
    @ObservedObject private var nowPlaying = NowPlayingService.shared
    @ObservedObject private var timer = CountdownTimer.shared

    var body: some View {
        panel
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var panelShape: NotchShape {
        NotchShape(
            topRadius: NotchLayout.topRadius(isOpen: state.isOpen),
            bottomRadius: NotchLayout.bottomRadius(isOpen: state.isOpen)
        )
    }

    private var panel: some View {
        ZStack {
            // Closed: solid black so the strip is indistinguishable from the
            // notch. Open: black at the top easing into the Space's theme.
            panelShape
                .fill(
                    state.isOpen
                        ? AnyShapeStyle(
                            LinearGradient(
                                colors: [Color.black, theme.current.bottom],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        : AnyShapeStyle(Color.black)
                )
                .animation(.easeInOut(duration: 0.3), value: theme.current)

            // Optional per-Space image background — only while open, heavily
            // darkened so content stays readable and the top blends into the
            // notch.
            if state.isOpen, let background = theme.backgroundImage {
                GeometryReader { geo in
                    Image(nsImage: background)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: geo.size.width, height: geo.size.height)
                        .clipped()
                        .overlay(
                            LinearGradient(
                                stops: [
                                    .init(color: .black, location: 0),
                                    .init(color: .black.opacity(0.55), location: 0.35),
                                    .init(color: .black.opacity(0.65), location: 1)
                                ],
                                startPoint: .top, endPoint: .bottom
                            )
                        )
                }
                .transition(.opacity)
            }

            if state.isOpen {
                expandedContent
                    // Fade in only after the window has (mostly) reached its
                    // open size — laying out content at intermediate sizes is
                    // what made the opening stutter.
                    .transition(
                        .asymmetric(
                            insertion: .opacity.animation(
                                .easeOut(duration: 0.16).delay(NotchState.animationDuration * 0.7)
                            ),
                            removal: .opacity.animation(.easeOut(duration: 0.08))
                        )
                    )
            } else if nowPlaying.track != nil || timer.isActive {
                ClosedMediaBar(track: nowPlaying.track, notchWidth: state.metrics.notchWidth)
                    .transition(.opacity)
            }
        }
        .clipShape(panelShape)
    }

    private var expandedContent: some View {
        VStack(spacing: NotchLayout.toolbarSpacing) {
            NotchToolbar(state: state)
                .frame(height: NotchLayout.toolbarHeight)
            tabContent
        }
        .padding(.horizontal, NotchLayout.horizontalPadding)
        .padding(.top, NotchLayout.topPadding)
        .padding(.bottom, NotchLayout.bottomPadding)
    }

    @ViewBuilder
    private var tabContent: some View {
        switch state.selectedTab {
        case .widgets:
            WidgetDashboardView()
        case .shelf:
            HomeView(state: state)
        case .clipboard:
            ClipboardView()
        case .timer:
            TimerView()
        case .prompter:
            PrompterView()
        case .settings:
            SettingsView()
        }
    }
}
