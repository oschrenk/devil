{
  description = "Devil - iPhone app for a Hario Switch coffee recipe";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";

  outputs =
    { self, nixpkgs }:
    let
      inherit (nixpkgs) lib;

      # aarch64-darwin only: the app is built by the Xcode toolchain, which
      # exists nowhere else.
      systems = [
        "aarch64-darwin"
      ];
      forAllSystems = f: lib.genAttrs systems (system: f nixpkgs.legacyPackages.${system});
    in
    {
      # No `packages` output on purpose. An iOS app bundle cannot be produced in
      # the nix sandbox: it needs the iOS SDK and the code-signing machinery that
      # live inside Xcode.app, neither of which is in nixpkgs. The other repos
      # here package a binary because they ship one; this repo ships to a phone,
      # so a package output would only pretend to work. `task build` and
      # `scripts/deploy-device.sh` are the real entry points.

      devShells = forAllSystems (pkgs: {
        # mkShellNoCC, not mkShell: a cc-wrapper in scope exports SDKROOT and
        # DEVELOPER_DIR pointing at nixpkgs' apple-sdk, and Xcode's swiftc
        # refuses that SDK outright ("this SDK is not supported by the
        # compiler"). That breaks every xcodebuild and swift invocation below.
        default = pkgs.mkShellNoCC {
          # No swift or sourcekit-lsp from nixpkgs on purpose: nixpkgs carries
          # 5.10.1 and it would shadow the Xcode toolchain on PATH. `swift` and
          # `xcodebuild` both stay as /usr/bin/swift and Xcode's own.
          packages = with pkgs; [
            xcodegen # generates Devil.xcodeproj from project.yml
            xcbeautify # makes xcodebuild output readable
            swiftformat # swift, formatter
            swiftlint # swift, linter
            go-task # task runner, drives taskfile.yml
            jq # reads the devicectl device list in scripts/deploy-device.sh
          ];

          # mkShellNoCC already blanks SDKROOT and DEVELOPER_DIR but still
          # exports MACOSX_DEPLOYMENT_TARGET from the nixpkgs SDK, which drags
          # SwiftPM to an older -target than Package.swift asks for. Hand the
          # whole SDK question back to Xcode.
          shellHook = ''
            unset SDKROOT DEVELOPER_DIR MACOSX_DEPLOYMENT_TARGET
          '';
        };
      });
    };
}
