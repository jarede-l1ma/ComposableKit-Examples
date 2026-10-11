#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
composablekit-create.py
=======================
Creates a scene following the ComposableKit pattern (TCA syntax, iOS 15+).

Interactive:
    python3 composablekit-create.py

With arguments:
    python3 composablekit-create.py SafeMode ./Sources/Scenes

If the scene already exists, only the missing files are created (existing files
are left untouched). To regenerate the scene from the template, pass --force:
    python3 composablekit-create.py SafeMode ./Sources/Scenes --force

Generates 5 files:
    {SCENE}/Core/{SCENE}Feature.swift
    {SCENE}/UI/{SCENE}View.swift
    {SCENE}/Service/{SCENE}Service.swift
    {SCENE}/Service/{SCENE}Mapper.swift
    {SCENE}/Service/{SCENE}AnalyticsModel.swift

The Feature depends on `AnalyticsClient` (`@Dependency(\\.analytics)`), which must
exist once per module. If no file declares it, the script creates
Shared/Analytics/AnalyticsClient.swift next to the scenes folder.

Files are created on disk; projects with Xcode 16+ synchronized folders pick them
up automatically. Otherwise run your project generator (Tuist/XcodeGen) or drag
the {SCENE}/ folder into Xcode.

Tests are not generated here: once the feature is done, run the ios-tca-tests skill
(/ios-tca-tests {SCENE}) to write them for the real code.
"""

import os
import re
import sys


# ─────────────────────────────────────────────
# Helpers
# ─────────────────────────────────────────────

def to_kebab_case(pascal: str) -> str:
    """SafeMode → safe-mode  |  InvestHome → invest-home  |  MyPOCLife → my-poc-life

    Uppercase acronyms (POC, API, URL) become a single word.
    """
    kebab = re.sub(r"(?<=[a-z0-9])(?=[A-Z])|(?<=[A-Z])(?=[A-Z][a-z])", "-", pascal)
    return kebab.lower()


def validate_pascal(name: str) -> bool:
    return bool(re.match(r"^[A-Z][a-zA-Z0-9]+$", name))


def prompt(question: str, default: str = "") -> str:
    suffix = f" [{default}]" if default else ""
    try:
        value = input(f"{question}{suffix}: ").strip()
    except EOFError:
        # No terminal (CI, agent): there is no way to ask.
        print(f"\n❌ No interactive input. Pass the arguments: python3 {os.path.basename(sys.argv[0])} <Scene> <folder>")
        sys.exit(1)
    return value or default


def write_file(path: str, content: str) -> None:
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w", encoding="utf-8") as f:
        f.write(content)
    print(f"  ✅ {os.path.relpath(path)}")


def print_tree(scene: str, base: str) -> None:
    scene_path = os.path.join(base, scene)
    print(f"\n📂 {scene}/")
    for root, dirs, files in os.walk(scene_path):
        dirs.sort()
        level = root.replace(scene_path, "").count(os.sep)
        rel = os.path.relpath(root, scene_path)
        if rel != ".":
            print(f"{'│   ' * (level - 1)}├── {os.path.basename(root)}/")
        for i, file in enumerate(sorted(files)):
            connector = "└── " if i == len(files) - 1 else "├── "
            print(f"{'│   ' * level}{connector}{file}")


def uses_synchronized_folders(path: str) -> bool:
    """True if the .xcodeproj above `path` uses synchronized folders (Xcode 16+):
    new files join the target without touching the project."""
    current = os.path.abspath(path)
    while True:
        try:
            entries = os.listdir(current)
        except OSError:  # unreadable folder on the way up
            entries = []
        for entry in entries:
            if entry.endswith(".xcodeproj"):
                pbxproj = os.path.join(current, entry, "project.pbxproj")
                try:
                    with open(pbxproj, encoding="utf-8") as f:
                        if "PBXFileSystemSynchronizedRootGroup" in f.read():
                            return True
                except OSError:
                    pass
        parent = os.path.dirname(current)
        if parent == current:
            return False
        current = parent


def lower_first(name: str) -> str:
    """SafeMode → safeMode  |  APIHome → apiHome"""
    i = 0
    while i < len(name) and name[i].isupper():
        i += 1
    if i <= 1:
        return name[:1].lower() + name[1:]
    if i == len(name):
        return name.lower()
    return name[:i - 1].lower() + name[i - 1:]


# ─────────────────────────────────────────────
# Templates
# ─────────────────────────────────────────────

def feature_template(scene: str) -> str:
    client = lower_first(scene) + "Client"
    return f"""\
import ComposableKit
import Foundation

@Reducer
struct {scene}Feature {{

    // MARK: - State

    @ObservableState
    struct State: Equatable {{
        var isLoading = false
        var viewData: {scene}ViewData?
        var errorMessage: String?
    }}

    // MARK: - ViewData

    // `nonisolated`: the ViewData (and its fixtures in tests, including in
    // `@Test(arguments:)`) is used outside the MainActor in apps with default
    // MainActor isolation; without default isolation, nothing changes.
    nonisolated struct {scene}ViewData: Equatable {{
        // TODO: fill in with the display data — produced by the Mapper from the Response.
    }}

    // MARK: - Action
    //
    // `tap*` cases are sent by the View.
    // `did*` cases are sent by effects (network responses, etc.).

    enum Action: Equatable {{
        // Lifecycle
        case viewDidAppear

        // User
        case tapContinue
        case tapRetry
        case tapClose

        // Internal (Effect responses)
        case didLoad({scene}ViewData)
        case didFail(String)
    }}


    // `nonisolated`: in apps with default MainActor isolation, the id must be
    // Hashable & Sendable outside the MainActor (without default isolation, nothing changes).
    nonisolated enum CancelID {{
        case fetch
    }}

    // MARK: - Dependencies

    @Dependency(\\.{client}) var {client}
    @Dependency(\\.analytics) var analytics

    /// Navigation: injected by the Factory (whoever creates the scene decides the destination).
    // `nonisolated`: without it, in an app with default MainActor isolation, the compiler drops the
    // closure's `@MainActor` when capturing it in `.run` and it runs off the main thread (crash).
    nonisolated var navigate: @MainActor @Sendable ({scene}Route) -> Void = {{ _ in }}

    // MARK: - Body

    var body: some ReducerOf<Self> {{
        Reduce {{ state, action in
            switch action {{
            case .viewDidAppear, .tapRetry:
                // The View sends `viewDidAppear` on every appearance (including when coming
                // back from a pushed screen): with content on screen, it does not reload.
                if action == .viewDidAppear, state.viewData != nil {{ return .none }}
                state.isLoading = true
                state.errorMessage = nil
                return .run {{ [{client}] send in
                    let response = try await {client}.fetchData()
                    await send(.didLoad({scene}Mapper.map(response)))
                }} catch: {{ error, send in
                    await send(.didFail(error.localizedDescription))
                }}
                .cancellable(id: CancelID.fetch, cancelInFlight: true)

            case let .didLoad(viewData):
                state.isLoading = false
                state.viewData = viewData
                return .none

            case let .didFail(message):
                state.isLoading = false
                state.errorMessage = message
                return .none

            case .tapContinue:
                return .run {{ [navigate] _ in await navigate(.nextPage) }}

            case .tapClose:
                // Leaving the screen cancels the in-flight fetch (and its URLSession request).
                return .merge(
                    .cancel(id: CancelID.fetch),
                    .run {{ [navigate] _ in await navigate(.back) }}
                )
            }}
        }}

        // Centralized analytics: one event per Action. It receives the already
        // updated state, for events with State data (ids, codes).
        Reduce {{ state, action in
            if let event = Self.analyticsEvent(for: action, state: state) {{
                analytics.track(event)
            }}
            return .none
        }}
    }}

    // MARK: - Analytics

    /// `state` is the state **after** the Action: use it when the event needs
    /// screen data (e.g. `itemID: state.itemID`).
    static func analyticsEvent(for action: Action, state: State) -> (any AnalyticsEvent)? {{
        switch action {{
        case .didLoad:
            {scene}AnalyticsModel.ScreenViewEvent()
        case .tapContinue:
            {scene}AnalyticsModel.SelectContentEvent(item: .tapContinue)
        case .tapClose:
            {scene}AnalyticsModel.SelectContentEvent(item: .tapClose)
        case let .didFail(message):
            {scene}AnalyticsModel.AlertEvent(message: message)
        case .viewDidAppear, .tapRetry:
            nil
        }}
    }}
}}

// MARK: - Route

enum {scene}Route: Equatable, Sendable {{
    case back
    case nextPage
    // TODO: add cases with data if the next scene needs to receive information
}}
"""


def view_template(scene: str) -> str:
    client = lower_first(scene) + "Client"
    return f"""\
import ComposableKit
import SwiftUI
import UIKit

// PLACEHOLDER: replace this View with the real layout of the scene.
// When replacing it, keep the "View contract" of the ComposableKit architecture guide (section 9).

struct {scene}View: View {{
    @ObservedObject var store: StoreOf<{scene}Feature>

    var body: some View {{
        VStack(spacing: 0) {{
            // Outside the content: "Close" also works while loading and on error.
            HStack {{
                Spacer()
                Button {{
                    store.send(.tapClose)
                }} label: {{
                    Image(systemName: "xmark")
                        .font(.title3.weight(.semibold))
                        .frame(width: 44, height: 44)
                }}
                .tint(.primary)
                .accessibilityLabel("Close")
            }}
            .padding(.horizontal, 8)

            Group {{
                if let viewData = store.viewData {{
                    // Loaded content stays on screen during "Try again";
                    // if the new attempt fails, the warning appears above it.
                    if let errorMessage = store.errorMessage {{
                        errorBanner(message: errorMessage)
                    }}
                    contentView(viewData: viewData)
                }} else if store.isLoading {{
                    ProgressView()
                }} else if let errorMessage = store.errorMessage {{
                    errorView(message: errorMessage)
                }} else {{
                    ProgressView() // idle
                }}
            }}
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }}
        .task {{ await store.send(.viewDidAppear).finish() }}
    }}

    @ViewBuilder
    private func contentView(viewData: {scene}Feature.{scene}ViewData) -> some View {{
        VStack(alignment: .leading, spacing: 0) {{
            // TODO: build the real layout of the scene here
            VStack(alignment: .leading, spacing: 24) {{
                Text("Scene title")
                    .font(.largeTitle.bold())
            }}
            .padding(.horizontal, 24)
            .padding(.top, 24)

            Spacer()

            Button {{
                store.send(.tapContinue)
            }} label: {{
                Text("Continue")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
            }}
            .buttonStyle(.borderedProminent)
            .padding(24)
        }}
    }}

    /// Reload failure with content on screen.
    @ViewBuilder
    private func errorBanner(message: String) -> some View {{
        VStack(alignment: .leading, spacing: 8) {{
            Text(message)
                .font(.body)

            Button("Try again") {{
                store.send(.tapRetry)
            }}
            .buttonStyle(.bordered)
        }}
        .padding(.horizontal, 24)
        .padding(.top, 16)
    }}

    @ViewBuilder
    private func errorView(message: String) -> some View {{
        VStack(spacing: 16) {{
            Text(message)
                .font(.body)
                .multilineTextAlignment(.center)

            Button {{
                store.send(.tapRetry)
            }} label: {{
                Text("Try again")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
            }}
            .buttonStyle(.borderedProminent)
        }}
        .padding(24)
    }}
}}

// MARK: - Factory

@MainActor
enum {scene}Factory {{
    static func make(
        navigate: @escaping @MainActor @Sendable ({scene}Route) -> Void = {{ _ in }}
    ) -> UIViewController {{
        let store = Store(initialState: {scene}Feature.State()) {{
            {scene}Feature(navigate: navigate)
        }}
        return UIHostingController(rootView: {scene}View(store: store))
    }}
}}

// MARK: - Preview

#Preview {{
    {scene}View(
        store: Store(initialState: {scene}Feature.State()) {{
            {scene}Feature()
        }} withDependencies: {{ deps in
            // TODO: return mock data for the Preview
            deps.{client}.fetchData = {{ {scene}Response() }}
            deps.analytics.track = {{ _ in }}
        }}
    )
}}
"""


def service_template(scene: str, slug: str) -> str:
    client = lower_first(scene) + "Client"
    return f"""\
import ComposableKit
import Foundation

// MARK: - Response
//
// `nonisolated`: the `Decodable` and the test fixtures are used outside the
// MainActor (in apps with default MainActor isolation; without it, nothing changes).

nonisolated struct {scene}Response: Decodable, Equatable, Sendable {{
    // TODO: replace with the real fields of the API response
}}

// MARK: - Client (the Feature's dependency)
//
// The Feature uses the client through `@Dependency(\\.{client})`. In tests, each
// endpoint is overridden: `deps.{client}.fetchData = {{ .fixture() }}`.

struct {scene}Client: Sendable {{
    var fetchData: @Sendable () async throws -> {scene}Response
}}

extension {scene}Client: DependencyKey {{
    static let liveValue = {scene}Client(
        fetchData: {{ try await {scene}Service().fetchData() }}
    )

    static let testValue = {scene}Client(
        fetchData: {{ throw UnimplementedError("{scene}Client.fetchData") }}
    )
}}

extension DependencyValues {{
    var {client}: {scene}Client {{
        get {{ self[{scene}Client.self] }}
        set {{ self[{scene}Client.self] = newValue }}
    }}
}}

// MARK: - Implementation
//
// `URLSession` with async/await: cancelling the effect (`.cancel(id:)`,
// `cancelInFlight`) cancels the request too. Swap it for your app's networking
// layer if it has one; keep the `async throws` signature.

nonisolated struct {scene}Service: Sendable {{
    var baseURL = URL(string: "https://api.example.com")! // TODO: your API's base URL
    var session: URLSession = .shared

    func fetchData() async throws -> {scene}Response {{
        let url = baseURL.appendingPathComponent("{slug}") // TODO: the real endpoint
        let (data, response) = try await session.data(from: url)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {{
            throw URLError(.badServerResponse)
        }}
        return try JSONDecoder().decode({scene}Response.self, from: data)
    }}
}}
"""


def mapper_template(scene: str) -> str:
    return f"""\
import Foundation

enum {scene}Mapper {{
    static func map(_ result: {scene}Response) -> {scene}Feature.{scene}ViewData {{
        // TODO: turn the domain model into display data.
        {scene}Feature.{scene}ViewData()
    }}
}}
"""


def analytics_template(scene: str, slug: str) -> str:
    return f"""\
// TODO: event names and parameters are placeholders until you have the tracking spec.
// `{slug}` (screen_name) was derived from the scene name: check it against the spec.
enum {scene}AnalyticsModel {{
    struct ScreenViewEvent: AnalyticsEvent {{
        let name = "screen_view"
        var parameters: [String: String] {{ ["screen_name": "{slug}"] }}
    }}

    struct SelectContentEvent: AnalyticsEvent {{
        let name = "select_content"
        let item: Item
        var parameters: [String: String] {{ ["screen_name": "{slug}", "item": item.rawValue] }}

        enum Item: String {{
            case tapContinue = "continue"
            case tapClose = "close"
        }}
    }}

    struct AlertEvent: AnalyticsEvent {{
        let name = "alert"
        let message: String
        var parameters: [String: String] {{ ["screen_name": "{slug}", "message": message] }}
    }}
}}
"""


# Created once per module, when no file declares `var analytics: AnalyticsClient`.
ANALYTICS_CLIENT = """\
import ComposableKit

// MARK: - Analytics
//
// Analytics dependency used by the Features (`@Dependency(\\.analytics)`).
// It must exist ONCE per module (or in a shared module). In production it forwards
// to your analytics SDK; in tests it does nothing, unless the test overrides
// `deps.analytics.track` to capture events.

/// An analytics event. Each scene declares its events in `<Scene>AnalyticsModel`.
// `nonisolated`: in apps with default MainActor isolation, events are created and
// read outside the MainActor (without default isolation, nothing changes).
nonisolated protocol AnalyticsEvent {
    var name: String { get }
    var parameters: [String: String] { get }
}

struct AnalyticsClient: Sendable {
    var track: @Sendable (any AnalyticsEvent) -> Void
}

extension AnalyticsClient: DependencyKey {
    static let liveValue = AnalyticsClient { event in
        // TODO: forward to your analytics SDK (Firebase, Amplitude, ...).
        print("[Analytics] \\(event.name) \\(event.parameters)")
    }

    static let testValue = AnalyticsClient { _ in }
}

extension DependencyValues {
    var analytics: AnalyticsClient {
        get { self[AnalyticsClient.self] }
        set { self[AnalyticsClient.self] = newValue }
    }
}
"""


def find_analytics_client(root: str):
    """The .swift file under `root` that declares `var analytics: AnalyticsClient`, if any."""
    for current, dirs, files in os.walk(root):
        dirs[:] = [d for d in dirs if not d.startswith(".") and d not in ("build", "DerivedData")]
        for name in files:
            if name.endswith(".swift"):
                path = os.path.join(current, name)
                try:
                    with open(path, encoding="utf-8") as f:
                        if "var analytics: AnalyticsClient" in f.read():
                            return path
                except (OSError, UnicodeDecodeError):
                    pass
    return None


def ensure_analytics_client(base_path: str) -> None:
    """Creates Shared/Analytics/AnalyticsClient.swift next to the scenes folder if the
    module (the parent of the scenes folder) does not declare `AnalyticsClient` yet."""
    module_root = os.path.dirname(os.path.abspath(base_path))
    if find_analytics_client(module_root):
        return
    print()
    print("No AnalyticsClient found in the module: creating the shared one…")
    write_file(os.path.join(module_root, "Shared", "Analytics", "AnalyticsClient.swift"), ANALYTICS_CLIENT)


# ─────────────────────────────────────────────
# Main
# ─────────────────────────────────────────────

def main() -> None:
    # Force UTF-8 on the terminal (needed on Windows with cp1252)
    if hasattr(sys.stdout, "reconfigure"):
        sys.stdout.reconfigure(encoding="utf-8")

    print()
    print("=" * 48)
    print("  ComposableKit - create a scene")
    print("  Pattern: ComposableKit SPM (5 files)")
    print("=" * 48)
    print()

    # ── Collect inputs ──────────────────────────────
    usage = "Usage: <Scene> <folder> [--force]"
    force = False
    args = []
    for arg in sys.argv[1:]:
        if arg == "--force":
            force = True
        elif arg.startswith("-"):
            print(f"\n❌ Unknown option: {arg}. {usage}")
            sys.exit(1)
        else:
            args.append(arg)

    if len(args) >= 1:
        scene = args[0]
    else:
        scene = prompt("Scene name? (e.g. SafeMode)")

    if not validate_pascal(scene):
        print(f"\n❌ '{scene}' is not PascalCase. Use e.g. SafeMode, InvestHome")
        sys.exit(1)

    if scene.endswith("Feature") and len(scene) > len("Feature"):
        print(f"\n❌ Do not end the name with 'Feature' (it would generate {scene}Feature). Use: {scene[:-len('Feature')]}")
        sys.exit(1)

    if len(args) >= 2:
        base_path = args[1]
    else:
        base_path = prompt("Folder where the scene is created", default=".")

    base_path = os.path.expanduser(base_path)

    if not os.path.isdir(base_path):
        print(f"\n❌ Folder '{base_path}' not found.")
        sys.exit(1)

    # ── Derived variables ───────────────────────────
    slug = to_kebab_case(scene)

    print()
    print(f"  SCENE       : {scene}")
    print(f"  SLUG        : {slug}")
    print(f"  Destination : {os.path.abspath(base_path)}/{scene}/")

    # ── Write the 5 files ───────────────────────────
    # Existing scene: only create what is missing. Never overwrite already
    # implemented code without --force.
    scene_dir = os.path.join(base_path, scene)
    files = [
        (os.path.join(scene_dir, "Core", f"{scene}Feature.swift"), feature_template(scene)),
        (os.path.join(scene_dir, "UI", f"{scene}View.swift"), view_template(scene)),
        (os.path.join(scene_dir, "Service", f"{scene}Service.swift"), service_template(scene, slug)),
        (os.path.join(scene_dir, "Service", f"{scene}Mapper.swift"), mapper_template(scene)),
        (os.path.join(scene_dir, "Service", f"{scene}AnalyticsModel.swift"), analytics_template(scene, slug)),
    ]
    existing = [path for path, _ in files if os.path.exists(path)]

    if existing and not force and len(existing) == len(files):
        print(f"\n⚠️  The scene '{scene}/' already exists with all 5 files. Nothing was changed.")
        print("   To regenerate everything from the template (discards the implementation), use --force.")
        sys.exit(1)

    print()
    if existing and force:
        print(f"♻️  --force: {len(existing)} existing file(s) go back to the template.")
    print("Creating files…")
    for path, content in files:
        if path in existing and not force:
            print(f"  ⏭️  {os.path.relpath(path)} (already exists, kept)")
            continue
        write_file(path, content)

    ensure_analytics_client(base_path)

    # ── Tree of created files ───────────────────────
    print_tree(scene, base_path)

    # ── Post-generation instructions ────────────────
    print()
    print("─" * 50)
    if uses_synchronized_folders(base_path):
        print("✅ The project uses Xcode synchronized folders: the files")
        print("   are already part of the target, no need to add them.")
    else:
        print("⚠️  The files were created on disk but NOT")
        print("   added to the Xcode project automatically.")
        print()
        print("   Ways to add them to the project:")
        print("   1. Run your project generator (Tuist / XcodeGen)")
        print(f"   2. Drag the '{scene}/' folder into Xcode")
    print()
    print("📋 Required TODOs before using the scene:")
    print(f"   • {scene}Service   → Response fields + endpoint (the {scene}Client already calls the Service)")
    print(f"   • {scene}Mapper    → Response → ViewData logic")
    print(f"   • {scene}Feature   → State.viewData, Actions/Routes (remove the template ones you do not use), events in analyticsEvent(for:state:)")
    print(f"   • {scene}View      → replace the placeholder with the real layout")
    print(f"   • {scene}AnalyticsModel → event names and parameters (placeholders; '{slug}' came from the scene name)")
    print()
    print(f"🧪 When the feature is done, run /ios-tca-tests {scene} to generate its tests.")
    print("─" * 50)
    print()


if __name__ == "__main__":
    main()
