# nix-knime

KNIME Analytics Platform packaged as a Nix flake for Linux.

## What is this?

This repository packages [KNIME Analytics Platform](https://www.knime.com/knime-analytics-platform) for NixOS and Nix on Linux. It handles all native library dependencies (X11, GTK, CEF/Chromium, Java2D, ...) via `autoPatchelfHook` and wraps the Eclipse-based launcher with the environment required to run reliably under NixOS.

KNIME bundles its own JRE ([Eclipse Adoptium](https://adoptium.net/)) and a Chromium Embedded Framework ([Equo Chromium](https://www.equo.dev/chromium)) as browser -- no system Java installation is required.

## How to use

### Run directly

```bash
nix run github:3nol/nix-knime
```

### Install via flake

Add to your flake inputs:

```nix
inputs.nix-knime.url = "github:3nol/nix-knime";
```

Then, add the package to your NixOS or Home Manager configuration:

```nix
# Via "NixOS".
environment.systemPackages = [ inputs.nix-knime.packages.x86_64-linux.knime ];

# Via "Home Manager".
home.packages = [ inputs.nix-knime.packages.x86_64-linux.knime ];
```

### Build locally

```bash
git clone https://github.com/3nol/nix-knime \
&& cd nix-knime \
&& nix run .
```

## Configuration

See the official [KNIME documentation](https://docs.knime.com/ap/latest/analytics_platform_user_guide/#configuring-knime-analytics-platform) for all available configuration options.

### Custom JVM arguments

The `vmArgs` parameter lets you append extra JVM arguments at launch via  
`--launcher.appendVmargs`. Override it in your flake, as follows:

```nix
inputs.nix-knime.packages.x86_64-linux.knime.override {
  vmArgs = [ "-Xmx8g" ];
}
```

The default sets `-Djdk.http.auth.tunneling.disabledSchemes=""`, which re-enables HTTP Basic authentication over CONNECT proxy tunnels (see [FAQ](https://www.knime.com/faq#q42)).

### Workspace and Eclipse runtime options

Standard Eclipse runtime options (incl. launcher flags) should work as normal:

```bash
knime -data "$HOME/knime-workspace"   # sets workspace directory
knime -clean                          # clears OSGi caches on startup
knime -debug                          # enables OSGi debug mode
```

See the official [Eclipse documentation](https://help.eclipse.org/latest/index.jsp?topic=%2Forg.eclipse.platform.doc.isv%2Freference%2Fmisc%2Fruntime-options.html) for all runtime options.
