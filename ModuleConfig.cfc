/**
 * AVIF Module
 * Utilities for encoding, decoding, and inspecting AVIF images from CFML.
 *
 * Backend: the libavif command-line tools (avifenc.exe / avifdec.exe), bundled
 * under bin/win-x64-<version>/ and invoked directly via Java ProcessBuilder.
 * libavif project + precompiled binaries: https://github.com/AOMediaCodec/libavif
 *
 * v1 is Windows x64 only (see getBinPath). OS selection is isolated here so
 * macOS / Linux can be added later without touching the public API.
 */
component {

    // Module Properties
    this.title             = "avif";
    this.author            = "Angry Sam Productions, Inc.";
    this.webURL            = "https://www.angrysam.com";
    this.description       = "ColdBox utilities for encoding, decoding, and inspecting AVIF images using bundled libavif binaries.";
    this.modelNamespace    = "avif";
    this.cfmapping         = "avif";
    this.dependencies      = [];
    this.applicationHelper = [];

    /**
     * Module Config
     */
    function configure(){
        // Module Settings — mirrors the webp module's override shape so consuming
        // apps can point at custom binaries the same way.
        settings = {
            // Folder holding the bundled libavif executables (trailing slash).
            binPath      : modulePath & "/bin/#getBinPath()#/",
            // Optional explicit overrides; when set, take precedence over binPath.
            avifencPath  : "",
            avifdecPath  : "",
            // Seconds before a conversion is forcibly terminated (AV1 encode is slow).
            timeout      : 60,
            // Guard for untrusted input: passed to avifdec --dimension-limit. 0 = unlimited.
            maxDimension : 16384
        };
    }

    /**
     * Resolve the bundled binary folder for the current platform.
     * v1: Windows x64 only. Any other OS throws a typed, actionable error.
     */
    private function getBinPath(){
        if ( server.os.name contains "Windows" && server.os.arch contains "64" ) {
            return "win-x64-1.4.2";
        }
        throw(
            type    = "avif.unsupportedPlatform",
            message = "The avif module currently supports Windows x64 only.",
            detail  = "Detected OS: #server.os.name# / arch: #server.os.arch#"
        );
    }

    /**
     * Fired when the module is registered and activated.
     */
    function onLoad(){
    }

}
