{
  lib,
  stdenv,
  fetchurl,
  makeWrapper,
  makeDesktopItem,
  autoPatchelfHook,

  # JVM args appended at launch via --launcher.appendVmargs.
  # Override via .override { vmArgs = [ "-Xmx4g" ]; }
  vmArgs ? [ "-Djdk.http.auth.tunneling.disabledSchemes=" ],

  # --- X11 ---
  libx11, # (FAQ) used because of GDK_BACKEND=x11
  libxext,
  libxrender, # Java2D
  libxtst, # XTest
  libxi, # XInput
  libxcb,
  libxcomposite,
  libxdamage,
  libxfixes,
  libxrandr,

  # --- GTK / GLib ---
  gtk3,
  glib,
  glib-networking, # GIO_EXTRA_MODULES
  gsettings-desktop-schemas, # XDG_DATA_DIRS
  pango,
  cairo,
  at-spi2-core, # covers atk + at-spi2-atk

  # --- Input & Audio ---
  ibus, # (FAQ) prevents SWT/libgdk crash at GTK init
  alsa-lib,

  # --- Chromium / CEF ---
  nss,
  nspr,
  cups,
  dbus,
  dbus-glib, # libgconf-2.so.4 (bundled in CEF plugin) needs it
  libdrm,
  mesa,
  libGL, # bundled CEF plugins link against libGL.so.1
  expat,
  libxkbcommon,
  wayland, # bundled CEF plugins link against wayland, despite x11 backend
  zlib,

  # --- Fonts ---
  fontconfig,
  # freetype omitted, as bundled JRE ships its own

  # --- Miscellaneous ---
  libsecret, # SWT-based plugin for secure-storage
  perl, # dependency of autoPatchelfHook
}:

let
  pname = "knime";
  version = "5.11.0";
  os = "linux";
  arch = "x86_64";

  runtimeDeps = [
    stdenv.cc.cc.lib
    libx11
    libxext
    libxrender
    libxtst
    libxi
    libxcb
    libxcomposite
    libxdamage
    libxfixes
    libxrandr
    gtk3
    glib
    pango
    cairo
    at-spi2-core
    ibus
    alsa-lib
    nss
    nspr
    cups.lib
    dbus.lib
    dbus-glib
    libdrm
    mesa
    libGL
    expat
    libxkbcommon
    wayland
    zlib
    fontconfig
    libsecret
  ];

  desktopItem = makeDesktopItem {
    name = "knime";
    desktopName = "KNIME Analytics Platform";
    icon = "knime";
    exec = "knime %u";
    categories = [ "Science" "Education" ];
    # .knwf/.knap use Eclipse-internal content-type APIs, not freedesktop MIME
    mimeTypes = [ "x-scheme-handler/knime" ];
    startupNotify = true;
  };

  meta = {
    description = "Data analytics, reporting and integration platform";
    longDescription = ''
      KNIME Analytics Platform is the open source software for creating data-science
      workflows via a visual drag-and-drop node editor. It provides hundreds of nodes
      for data I/O, transformation, analysis, and visualization.
    '';
    homepage = "https://www.knime.com/knime-analytics-platform";
    license = with lib.licenses; [
      gpl3Only
      epl20
    ];
    mainProgram = "knime";
    platforms = [ "${arch}-${os}" ];
    sourceProvenance = with lib.sourceTypes; [ binaryNativeCode ];
  };
in
stdenv.mkDerivation {
  inherit
    pname
    version
    desktopItem
    meta
    ;

  src = fetchurl {
    url = "https://download.knime.org/analytics-platform/${os}/knime_${version}.${os}.gtk.${arch}.tar.gz";
    hash = "sha256-jdroMqKjm66tX0tFvNJWHEpueJQFc5kTllzqZvFXvsc=";
  };

  nativeBuildInputs = [
    autoPatchelfHook
    makeWrapper
    perl
  ];

  buildInputs = runtimeDeps;
  dontBuild = true;

  # libcef.so is bundled inside the CEF plugin dir and resolved from $out by autoPatchelf.
  # libc.so.8 is the DragonFly BSD JNA variant; the linux-x86-64 variant is used instead.
  autoPatchelfIgnoreMissingDeps = [
    "libcef.so"
    "libc.so.8"
  ];

  installPhase = ''
    runHook preInstall

    # Eclipse resolves knime.ini and all plugins relative to the launcher binary,
    # so the whole tree must stay together under lib/knime/.
    _lib="$out/lib/knime"
    mkdir -p "$_lib"
    cp -r . "$_lib"

    iconPlugin=$(find "$_lib/plugins" -maxdepth 1 -name "org.knime.product_${version}*" -type d | head -1)
    for size in 16 32 48 64 128 256; do
      install -Dm644 "$iconPlugin/icons/png/knime_$size.png" \
        "$out/share/icons/hicolor/''${size}x''${size}/apps/knime.png"
    done
    install -Dm444 -t "$out/share/applications" \
      "${desktopItem}/share/applications/"*

    # (FAQ) GDK_BACKEND=x11: Eclipse/SWT has incomplete Wayland support.
    # (FAQ) GTK_IM_MODULE=ibus: SWT/libgdk crashes without ibus at GTK init.
    # OSGi config is read-only in the Nix store; on first launch the wrapper
    # copies it to XDG_CONFIG_HOME and passes -configuration to Eclipse.
    makeWrapper "$_lib/knime" "$out/bin/knime" \
      --set    GDK_BACKEND          x11 \
      --set    GTK_IM_MODULE        ibus \
      --set    KNIME_CONFIGURATION  "$_lib/configuration" \
      --prefix LD_LIBRARY_PATH      : "${lib.makeLibraryPath runtimeDeps}" \
      --prefix GIO_EXTRA_MODULES    : "${glib-networking}/lib/gio/modules" \
      --prefix XDG_DATA_DIRS        : "${gsettings-desktop-schemas}/share/gsettings-schemas/${gsettings-desktop-schemas.name}:${gtk3}/share/gsettings-schemas/${gtk3.name}" \
      --run    '_cfg="''${XDG_CONFIG_HOME:-$HOME/.config}/knime/configuration"' \
      --run    '[ -d "$_cfg" ] || { mkdir -p "''${_cfg%/*}"; cp -r "$KNIME_CONFIGURATION" "$_cfg"; chmod -R u+rw "$_cfg"; }' \
      --add-flags '-configuration file://$_cfg' \
      --append-flags "--launcher.appendVmargs ${lib.escapeShellArgs vmArgs}"

    runHook postInstall
  '';
}
