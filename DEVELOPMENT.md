# Development

## Requirements

Xcode supplies the Swift compiler, the iOS SDK, `xcodebuild`, `simctl` and `devicectl`.
You must install it.
You do not have to open it, apart from the one-time signing setup below.

The flake supplies everything around it:

```sh
nix develop
```

Or, with [direnv](https://direnv.net/), run `direnv allow` once and the shell loads on `cd`.

That shell provides `xcodegen`, `xcbeautify`, `swiftformat`, `swiftlint`, `go-task` and `jq`.
It leaves out `swift` and `sourcekit-lsp` on purpose. nixpkgs carries Swift 5.10.1, and that version would shadow the Xcode toolchain on `PATH`.

Check that you selected Xcode, and not the standalone Command Line Tools:

```sh
xcode-select -p
```

That must print a path inside an `Xcode.app` bundle.
If it prints `/Library/Developer/CommandLineTools`, point it at Xcode:

```sh
sudo xcode-select -s /Applications/Xcode.app/Contents/Developer
```

The standalone Command Line Tools package provides `clang` and `git`.
It has no iOS SDK and no `devicectl`, so it cannot build this app.

## First Run

```sh
cp Local.xcconfig.example Local.xcconfig
task run
```

`Local.xcconfig` holds the bundle prefix and the Apple Team ID.
Git ignores it, because both values belong to one account.
A simulator build needs only the prefix.
The team ID can stay empty until you install on a phone.

## Tasks

- `task generate` Write `Devil.xcodeproj` from `project.yml`
- `task build` Build for the simulator, unsigned
- `task test` Run the `DevilKit` tests
- `task run` Build, install and launch on a simulator
- `task format` Format using the rules in `.swiftformat`
- `task lint` Lint using the rules in `.swiftlint.yml`
- `task device` Build and install on a connected iPhone
- `task clean` Remove the build directories and the generated project

`task run` takes a `SIMULATOR` override:

```sh
task run SIMULATOR="iPhone Air"
```

`xcrun simctl list devices available` names the rest.

## The Project Is Generated

`project.yml` is the project.
`xcodegen` writes `Devil.xcodeproj` from it, and git ignores the result.

This is what keeps the Xcode window shut.
An `.xcodeproj` is a directory that Xcode rewrites constantly.
It also merges badly in git.
A YAML file does neither.

Do not change anything inside the generated project.
The next `task generate` discards it.
Change `project.yml` instead.

To prove the generated project is disposable:

```sh
rm -rf Devil.xcodeproj && task build
```

## Tests Run Without a Simulator

`swift test` covers `DevilKit`, the package that holds the recipe.
It runs on the host in a few seconds.
It needs neither `xcodebuild` nor a booted simulator.
The recipe model belongs in a package rather than the app target for that reason.

The app target holds SwiftUI views with nothing to assert on.
Building it is the check.

## Installing on a Physical iPhone

A simulator build uses an ad-hoc signature, so the loop above needs no certificate.
A device build needs a real one.

One-time setup, and the only part that wants the Xcode window:

1. Open Xcode, go to `Settings > Accounts`, and add your Apple ID.
2. Open `Manage Certificates`, press `+`, and choose `Apple Development`.
   Xcode puts the certificate and its private key in your login keychain.
   You cannot download that private key again, so back the keychain up.
3. Set `DEVELOPMENT_TEAM` in `Local.xcconfig` to your Team ID.
4. Plug the iPhone in and trust this computer on the phone.

Then:

```sh
task device
```

`scripts/deploy-device.sh` archives with `-allowProvisioningUpdates`.
That flag fetches the provisioning profile from Apple during the build.
The script then installs the app with `devicectl`.

An `Apple Development` identity differs from a `Developer ID Application` identity.
The second one signs Mac apps for other people to run, and this app does not need it. iOS also has no notarization step.
Notarization applies to Mac distribution only.

The script checks the config file, the team ID, the identity and the connected device before it starts.
An archive takes minutes, and you can know every one of those failures up front.

**Partly verified.**
The archive signs and Apple issues the profile.
`codesign` reports a full chain, `Apple Development` to `Apple Worldwide Developer Relations` to `Apple Root CA`.
The entitlements show the team prefix.
Nobody has run the `devicectl` install, because no phone has reached the machine yet.
`DEVIL-01` covers that last step.

## No `nix build`

The flake offers a `devShell` and no packages.

Nix cannot produce an iOS app bundle in its sandbox.
The build needs the iOS SDK and the code-signing tools inside `Xcode.app`, and nixpkgs has neither.
The other repositories here package a binary because they release one.
This repository installs to a phone, so a package output would only pretend to work.

`task build` and `scripts/deploy-device.sh` are the real entry points.

## `project.yml` Holds the Version

`MARKETING_VERSION` in `project.yml` is the version, and there is no `VERSION` file.

A `VERSION` file would have to reach the build somehow.
`xcodegen` does expand `${VAR}` from the environment.
When the variable is unset it writes the literal `${VAR}` into the project and reports nothing.
A plain `xcodegen generate` outside the task runner would then produce a version-less app.
One value in one file cannot drift and cannot fail quietly.

## Issues

### `xcrun: error: unable to lookup item 'PlatformPath'`

You selected the Command Line Tools instead of Xcode.
See the check under Requirements.

### `0 valid identities found`, with the Certificate Right There

`security find-identity -v -p codesigning` counts a certificate only when its whole chain resolves.
Drop the `-v` to see it without that test:

```sh
security find-identity -p codesigning
```

One identity there and none under `Valid identities only` points at the chain, not at the certificate.
The usual cause is a missing intermediate.
`Apple Worldwide Developer Relations Certification Authority` `OU=G3` issues an `Apple Development` certificate.
A keychain often holds only the older intermediate, which expired in February 2023.
Check the intermediates you have:

```sh
security find-certificate -a -c "Worldwide Developer Relations" -p |   openssl x509 -noout -subject -dates
```

Fetch the right one and add it:

```sh
curl -fsSLO https://www.apple.com/certificateauthority/AppleWWDRCAG3.cer
security add-certificates -k ~/Library/Keychains/login.keychain-db AppleWWDRCAG3.cer
```

Nothing else changes.
The certificate and its private key were right all along.

### `iOS <version> Is Not Installed`

`xcode-select` points at an Xcode whose iOS platform never finished downloading.
Opening a different Xcode moves that selection without asking, so this arrives out of nowhere.

```sh
xcode-select -p
```

Point it at the Xcode that has the platform:

```sh
sudo xcode-select -s /Applications/Xcode-beta.app/Contents/Developer
```

Both Xcodes report the same from `xcodebuild -showsdks` and `-showdestinations`, so neither tells you which is which.
What separates them is resolving a device destination:

```sh
xcodebuild -project Devil.xcodeproj -scheme Devil   -destination 'generic/platform=iOS' -showBuildSettings
```

That exits 64 on the Xcode that cannot, and 0 on the one that can.
`scripts/deploy-device.sh` runs it before the archive for that reason.

### `swiftc` Rejects the SDK

A build that fails with `this SDK is not supported by the compiler` has nixpkgs' Apple SDK on the environment.
The dev shell uses `mkShellNoCC` and unsets `SDKROOT`, `DEVELOPER_DIR` and `MACOSX_DEPLOYMENT_TARGET` to prevent that.
Check them:

```sh
echo "[$SDKROOT] [$DEVELOPER_DIR] [$MACOSX_DEPLOYMENT_TARGET]"
```

All three must be empty.
