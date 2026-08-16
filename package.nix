{
  lib,
  stdenv,
  cmake,
  ninja,
  gradle_8,
  jdk17_headless,
  jdk17,
  pulseaudio,
  src,
  version ? "1.2.0-unstable",
}:

let
  pname = "wifi-audio-streaming";
in

stdenv.mkDerivation (finalAttrs: {
  inherit pname version src;

  nativeBuildInputs = [
    cmake
    ninja
    gradle_8
    jdk17
  ];

  # CMake/Ninja are subordinate build tools invoked by Gradle.
  # Do not let their setup hooks take over the top-level derivation phases.
  dontUseCmakeConfigure = true;
  dontUseNinjaBuild = true;
  dontUseNinjaInstall = true;
  dontUseNinjaCheck = true;

  /*
    Gradle dependencies are recorded separately so that the actual Nix build
    never needs network access.

    Generate/update this with the mitmCache update script whenever upstream
    changes Gradle dependencies.
  */
  mitmCache = gradle_8.fetchDeps {
    pkg = finalAttrs.finalPackage;
    data = ./deps.json;
  };

  /*
    WFAS requires JDK 17 and also uses java.home to locate the JNI headers
    passed to CMake.
  */
  JAVA_HOME = jdk17;

  gradleFlags = [
    "-Dorg.gradle.java.home=${jdk17}"
  ];

  gradleBuildTask = "nixCliDist";
  gradleUpdateTask = "nixDownloadDeps nixCliDist";

  postPatch = ''
        if grep -q 'foojay-resolver-convention' settings.gradle.kts; then
          sed -i '/foojay-resolver-convention/d' settings.gradle.kts
        fi

        substituteInPlace build.gradle.kts \
          --replace-fail \
            'cmakeArgs += listOf("-G", "Unix Makefiles")' \
            'cmakeArgs += listOf("-G", "Ninja")'

        # This is a CLI-only Nix package. Don't let the application attempt to
        # maintain ~/.local/bin/wfas itself.
        substituteInPlace src/main/kotlin/Main.kt \
          --replace-fail \
            '    CliPathInstaller.refreshIfOutdated()' \
            '    // Nix package manages the wfas launcher.'

        # The normal CLI server uses the native JNI audio engine. Upstream
        # unconditionally initializes JavaCV/FFmpeg before CLI dispatch, even though
        # FFmpeg is only needed by the legacy capture engine and HTTP AAC/Opus.
        # Avoid loading the JavaCPP FFmpeg natives for the headless native-engine
        # package.
        substituteInPlace src/main/kotlin/Main.kt \
          --replace-fail \
            '    org.bytedeco.javacv.FFmpegLogCallback.set()' \
            '    // FFmpeg initialization disabled by Nix CLI-only package.' \
          --replace-fail \
            '    org.bytedeco.ffmpeg.global.avdevice.avdevice_register_all()' \
            '    // FFmpeg avdevice initialization disabled by Nix CLI-only package.'

        # ProtocolRegistrar is desktop integration. In the upstream entry point it
        # currently also runs before CLI mode, which would make a headless service
        # try to modify ~/.local/share/applications.
        sed -i \
          '/Thread { runCatching { ProtocolRegistrar.ensureRegistered() } }/,/        .start()/d' \
          src/main/kotlin/Main.kt

        # Make a small JVM distribution: the WFAS jar plus its runtime jars.
        cat >> build.gradle.kts <<'EOF'
    tasks.register<org.gradle.api.tasks.Sync>("nixCliDist") {
        group = "distribution"
        description = "Assemble the WFAS CLI runtime for Nix"
        dependsOn("jar")

        into(layout.buildDirectory.dir("nix-cli/lib"))

        from(tasks.named("jar"))
        from(configurations.runtimeClasspath) {
            exclude("ffmpeg-*-linux-x86_64.jar")
            exclude("skiko-awt-runtime-linux-x64-*.jar")
        }
    }
    EOF
  '';

  /*
    The Gradle project does have a check task, but initially keeping package
    builds independent of upstream's full verification suite makes updating
    master less fragile.

    We still perform a basic installed CLI smoke test below.
  */
  doCheck = false;
  installPhase = ''
        runHook preInstall

        install -d \
          "$out/bin" \
          "$out/share/${pname}/lib" \
          "$out/share/man/man1"

        cp -a build/nix-cli/lib/. \
          "$out/share/${pname}/lib/"

        install -Dm444 \
          src/main/resources/man/wfas.1 \
          "$out/share/man/man1/wfas.1"

        cat > "$out/bin/wfas" <<EOF
    #!${stdenv.shell}

    export PATH="${lib.makeBinPath [ pulseaudio ]}:\''${PATH:-}"
    export LD_LIBRARY_PATH="${lib.makeLibraryPath [ pulseaudio ]}:\''${LD_LIBRARY_PATH:-}"

    if [ "\$#" -eq 0 ]; then
      set -- --cli-no-args
    fi

    exec ${jdk17_headless}/bin/java \
      -Djava.awt.headless=true \
      -Djava.net.preferIPv6Addresses=false \
      -cp "$out/share/${pname}/lib/*" \
      MainKt \
      "\$@"
    EOF

        chmod 0555 "$out/bin/wfas"

        runHook postInstall
  '';

  doInstallCheck = true;
  installCheckPhase = ''
    runHook preInstallCheck
    "$out/bin/wfas" --version
    "$out/bin/wfas" --help >/dev/null
    runHook postInstallCheck
  '';

  meta = {
    description = "Headless WiFi Audio Streaming server";
    homepage = "https://github.com/marcomorosi06/WiFiAudioStreaming-Desktop";
    license = lib.licenses.eupl12;
    mainProgram = "wfas";
    platforms = [
      "x86_64-linux"
    ];
    sourceProvenance = with lib.sourceTypes; [
      fromSource
      binaryBytecode
      binaryNativeCode
    ];
  };
})
