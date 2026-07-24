/**
 * AVIF Encoder / Decoder / Inspector
 *
 * A ColdBox model that encodes, decodes, and inspects AVIF images by shelling
 * out to the bundled libavif command-line tools (avifenc.exe / avifdec.exe)
 * through Java ProcessBuilder (see ProcessRunner.cfc — no shell is used).
 *
 * --- Hot-swap sibling of the `webp` module ---------------------------------
 * This module is designed so a consuming app (e.g. a CMS) can swap
 * `inject="webp@webp"` for `inject="avif@avif"` with no call-site changes.
 * The public methods and the argument NAMES for options both formats share
 * (source, destination, quality, lossless, alphaQuality, crop*, resize*,
 * multiThreaded, verbose, timeout) match the webp module. encode()/decode()
 * return the raw tool output as a string (webp parity); info() returns a
 * struct that is guaranteed to contain numeric `width` and `height` keys
 * (webp's info() also returns a struct keyed by width/height).
 *
 * AVIF and WebP are different formats, so:
 *   - AVIF-only options are added: speed, depth, chroma.
 *   - libavif's avifenc/avifdec cannot crop or resize raster pixels, so crop
 *     and resize are performed with ColdFusion's native cfimage functions
 *     (a temporary PNG on encode; in-place on decode).
 *   - WebP-only options (nearLossless, preset, compressionMethod, filter*,
 *     jpegLike, sourceHint, psnr, autoFilter, losslessCompressionMode) are NOT
 *     declared. CFML silently drops undeclared named arguments, so a hot-swapped
 *     call that passes them still works — they are simply ignored, honestly.
 *
 * Quality note: avifenc `-q` is 0..100 where 100 is (near) lossless — the same
 * direction as cwebp `-q` — so `quality=80` is a meaningful hot-swap value,
 * though the visual result differs between formats (inherent, not a bug).
 *
 * See AGENTS.md and plans/AVIF_MODULE_HANDOFF.md for architecture notes and a
 * self-contained reference to the `webp` module this one mirrors.
 */
component singleton hint="I am the avif encoder/decoder/inspector" {

    property name="settings"      inject="coldbox:modulesettings:avif";
    property name="processRunner" inject="ProcessRunner@avif";

    // Output formats avifdec can write, inferred from the destination extension.
    variables.DECODE_FORMATS = "png,jpg,jpeg,y4m";

    function init(){
        return this;
    }

    /**
     * Encode an image (JPEG / PNG / Y4M) into AVIF.
     * Mirrors webp.encode() for the shared arguments; adds AVIF-native options.
     *
     * @source Full path to the source file (must exist).
     * @destination Full path to the .avif output file (parent dir must exist).
     * @quality (int 0-100) Color quality. 100 is (near) lossless. avifenc -q.
     * @lossless (boolean) Encode losslessly (overrides quality). avifenc -l.
     * @alphaQuality (int 0-100) Alpha channel quality. avifenc --qalpha.
     * @cropX @cropY @cropWidth @cropHeight (int) Pixel crop (all four together). Applied with cfimage.
     * @resizeWidth @resizeHeight (int) Resize; 0 preserves aspect ratio. Applied with cfimage.
     * @multiThreaded (boolean) Use all worker threads (avifenc -j all) vs single (-j 1).
     * @metadata (string) "none" strips EXIF/XMP/ICC; otherwise metadata is preserved.
     * @overwrite (boolean) Replace an existing destination (default true).
     * @verbose (boolean) Accepted for webp parity; tool output is always captured/returned.
     * @timeout (int) Seconds before the process is killed. 0 = use module setting.
     * @speed (int 0-10) Encoder speed/effort; 0 slowest/best, 10 fastest. avifenc -s.
     * @depth (int 8|10|12) Output bit depth. avifenc -d.
     * @chroma (string auto|444|422|420|400) Chroma subsampling. avifenc -y.
     *
     * @return string The raw avifenc output.
     */
    string function encode(
        required string source,
        required string destination,

        numeric quality      = 80,
        boolean lossless      = false,
        numeric alphaQuality,

        numeric cropX,
        numeric cropY,
        numeric cropWidth,
        numeric cropHeight,

        numeric resizeWidth   = 0,
        numeric resizeHeight  = 0,

        boolean multiThreaded = true,
        string  metadata,
        boolean overwrite     = true,
        boolean verbose       = false,
        numeric timeout       = 0,

        numeric speed         = 6,
        numeric depth,
        string  chroma        = ""
    ){
        var exe = resolveBinary( "avifenc" );
        validateSource( arguments.source );
        validateDestinationDir( arguments.destination );
        guardOverwrite( arguments.destination, arguments.overwrite );

        // avifenc cannot crop/resize raster pixels — do it with cfimage first,
        // writing a lossless PNG intermediate to hand to the encoder.
        var encodeSource = arguments.source;
        var tempInput    = "";
        if ( needsTransform( argumentCollection = arguments ) ) {
            tempInput    = getTempDirectory() & createUUID() & ".png";
            applyImageTransforms( opts = arguments, sourcePath = arguments.source, outPath = tempInput );
            encodeSource = tempInput;
        }

        // Encode to a temp file in the destination directory, then move on success.
        var tempOut = getDirectoryFromPath( arguments.destination ) & createUUID() & ".avif.tmp";

        var cmd = [ exe ];
        if ( arguments.lossless ) {
            cmd.append( "-l" );
        } else {
            cmd.append( "-q" );
            cmd.append( int( arguments.quality ) );
        }
        if ( arguments.keyExists( "alphaQuality" ) ) {
            cmd.append( "--qalpha" );
            cmd.append( int( arguments.alphaQuality ) );
        }
        cmd.append( "-s" );
        cmd.append( int( arguments.speed ) );
        cmd.append( "-j" );
        cmd.append( arguments.multiThreaded ? "all" : "1" );
        if ( arguments.keyExists( "depth" ) ) {
            cmd.append( "-d" );
            cmd.append( int( arguments.depth ) );
        }
        if ( len( arguments.chroma ) ) {
            cmd.append( "-y" );
            cmd.append( arguments.chroma );
        }
        if ( arguments.keyExists( "metadata" ) && arguments.metadata == "none" ) {
            cmd.append( "--ignore-exif" );
            cmd.append( "--ignore-xmp" );
            cmd.append( "--ignore-icc" );
        }
        // End of options; everything after is a filename (protects untrusted paths).
        cmd.append( "--" );
        cmd.append( encodeSource );
        cmd.append( tempOut );

        var result = processRunner.run( cmd, resolveTimeout( arguments.timeout ) );
        try {
            assertSuccess( result, tempOut, "avifenc" );
            moveInto( tempOut, arguments.destination, arguments.overwrite );
            return result.output;
        } finally {
            cleanup( tempInput );
            cleanup( tempOut );
        }
    }

    /**
     * Decode an AVIF image into PNG / JPEG / Y4M (output format inferred from
     * the destination extension). Mirrors webp.decode() for shared arguments.
     *
     * NOTE: avifdec can write JPEG directly — an improvement over the webp
     * module, whose dwebp binary could not output JPG.
     *
     * @source Full path to the .avif source file.
     * @destination Full path to the output file (.png, .jpg, .jpeg, .y4m).
     * @quality (int 0-100) JPEG output quality (JPEG destinations only). avifdec -q.
     * @depth (int 8|16) PNG output depth (PNG destinations only). avifdec -d.
     * @upsampling (string) Chroma upsampling: automatic|fastest|best|nearest|bilinear. avifdec -u.
     * @cropX @cropY @cropWidth @cropHeight (int) Pixel crop (cfimage post-process).
     * @resizeWidth @resizeHeight (int) Resize; 0 preserves aspect ratio (cfimage post-process).
     * @flipImage (boolean) Flip vertically (cfimage post-process). Named flipImage for webp parity.
     * @multiThreaded (boolean) Use all worker threads (avifdec -j all) vs single (-j 1).
     * @overwrite (boolean) Replace an existing destination (default true).
     * @verbose (boolean) Accepted for webp parity; tool output is always captured/returned.
     * @timeout (int) Seconds before the process is killed. 0 = use module setting.
     *
     * @return string The raw avifdec output.
     */
    string function decode(
        required string source,
        required string destination,

        numeric quality       = 90,
        numeric depth,
        string  upsampling    = "automatic",

        numeric cropX,
        numeric cropY,
        numeric cropWidth,
        numeric cropHeight,

        numeric resizeWidth   = 0,
        numeric resizeHeight  = 0,
        boolean flipImage     = false,

        boolean multiThreaded = true,
        boolean overwrite     = true,
        boolean verbose       = false,
        numeric timeout       = 0
    ){
        var exe = resolveBinary( "avifdec" );
        validateSource( arguments.source );
        validateDestinationDir( arguments.destination );

        var ext = lCase( getFileExtension( getFileFromPath( arguments.destination ) ) );
        if ( !listFindNoCase( variables.DECODE_FORMATS, ext ) ) {
            throw(
                type    = "avif.unsupportedFormat",
                message = "Unsupported decode output format: '#ext#'. Supported: #variables.DECODE_FORMATS#."
            );
        }
        guardOverwrite( arguments.destination, arguments.overwrite );

        // Decode to a temp file (with the correct extension so avifdec picks the
        // right output format), then move on success.
        var tempOut = getDirectoryFromPath( arguments.destination ) & createUUID() & "." & ext;

        var cmd = [ exe, "-j", ( arguments.multiThreaded ? "all" : "1" ) ];
        if ( listFindNoCase( "jpg,jpeg", ext ) ) {
            cmd.append( "-q" );
            cmd.append( int( arguments.quality ) );
        }
        if ( arguments.keyExists( "depth" ) && ext == "png" ) {
            cmd.append( "-d" );
            cmd.append( int( arguments.depth ) );
        }
        cmd.append( "-u" );
        cmd.append( arguments.upsampling );
        if ( settings.keyExists( "maxDimension" ) && settings.maxDimension > 0 ) {
            cmd.append( "--dimension-limit" );
            cmd.append( int( settings.maxDimension ) );
        }
        cmd.append( "--" );
        cmd.append( arguments.source );
        cmd.append( tempOut );

        var result = processRunner.run( cmd, resolveTimeout( arguments.timeout ) );
        try {
            assertSuccess( result, tempOut, "avifdec" );
            // avifdec can't crop/resize/flip — do it on the decoded file with cfimage.
            if ( needsTransform( argumentCollection = arguments ) ) {
                applyImageTransforms( opts = arguments, sourcePath = tempOut, outPath = tempOut );
            }
            moveInto( tempOut, arguments.destination, arguments.overwrite );
            return result.output;
        } finally {
            cleanup( tempOut );
        }
    }

    /**
     * Inspect an AVIF file and return a normalized struct.
     * Guarantees numeric `width` and `height` keys (hot-swap parity with webp.info()).
     * Also exposes: depth, alpha (boolean), chroma, plus the raw parsed keys
     * (Resolution, BitDepth, Format, Range, ...).
     *
     * @source Full path to the .avif file.
     * @timeout (int) Seconds before the process is killed. 0 = use module setting.
     * @verbose (boolean) Include the raw avifdec output under `rawOutput`.
     */
    struct function info(
        required string source,
        numeric timeout = 0,
        boolean verbose = false
    ){
        var exe = resolveBinary( "avifdec" );
        validateSource( arguments.source );

        var cmd = [ exe, "--info", "--", arguments.source ];
        var result = processRunner.run( cmd, resolveTimeout( arguments.timeout ) );

        if ( result.timedOut ) {
            throw( type = "avif.timeout", message = "avifdec --info timed out.", detail = result.output );
        }
        if ( result.exitCode != 0 ) {
            throw( type = "avif.binaryExecutionFailed", message = "avifdec --info failed (exit #result.exitCode#).", detail = result.output );
        }
        return parseInfo( result.output, arguments.source, arguments.verbose );
    }

    /**
     * Report backend + binary versions. Additive to the webp interface.
     */
    struct function version(){
        var encExe = resolveBinary( "avifenc" );
        var decExe = resolveBinary( "avifdec" );
        var enc = processRunner.run( [ encExe, "--version" ], 15 );
        var dec = processRunner.run( [ decExe, "--version" ], 15 );
        return {
            "backend"        : "libavif",
            "avifencPath"    : encExe,
            "avifdecPath"    : decExe,
            "avifencVersion" : parseVersion( enc.output ),
            "avifdecVersion" : parseVersion( dec.output ),
            "platform"       : "windows-x64",
            "bundled"        : !len( settings.avifencPath ) && !len( settings.avifdecPath )
        };
    }

    /**
     * Report static module capabilities. Additive to the webp interface.
     */
    struct function capabilities(){
        return {
            "platform"            : "windows-x64",
            "supported"           : true,
            "encodeInputFormats"  : [ "jpg", "jpeg", "png", "y4m" ],
            "decodeOutputFormats" : [ "png", "jpg", "jpeg", "y4m" ],
            "alpha"               : true,
            "lossless"            : true,
            "metadata"            : true,
            "animation"           : false,
            "transforms"          : true
        };
    }

    /* =============================== Private =============================== */

    /**
     * Resolve the full path to a bundled (or overridden) libavif executable.
     */
    private string function resolveBinary( required string tool ){
        var override = ( arguments.tool == "avifenc" ) ? settings.avifencPath : settings.avifdecPath;
        var path = len( override ) ? override : settings.binPath & arguments.tool & ".exe";
        if ( !fileExists( path ) ) {
            throw(
                type    = "avif.binaryNotFound",
                message = "libavif '#arguments.tool#' binary not found.",
                detail  = "Expected at: #path#"
            );
        }
        return path;
    }

    private numeric function resolveTimeout( required numeric requested ){
        if ( arguments.requested > 0 ) {
            return arguments.requested;
        }
        return settings.keyExists( "timeout" ) ? settings.timeout : 60;
    }

    private void function validateSource( required string source ){
        if ( !fileExists( arguments.source ) ) {
            throw( type = "avif.invalidSource", message = "Source file does not exist: #arguments.source#" );
        }
    }

    private void function validateDestinationDir( required string destination ){
        var dir = getDirectoryFromPath( arguments.destination );
        if ( !directoryExists( dir ) ) {
            throw( type = "avif.invalidDestination", message = "Destination directory does not exist: #dir#" );
        }
    }

    private void function guardOverwrite( required string destination, required boolean overwrite ){
        if ( !arguments.overwrite && fileExists( arguments.destination ) ) {
            throw(
                type    = "avif.invalidDestination",
                message = "Destination already exists and overwrite is false: #arguments.destination#"
            );
        }
    }

    /**
     * True if any crop / resize / flip argument was supplied.
     */
    private boolean function needsTransform(){
        var a = arguments;
        var hasCrop = a.keyExists( "cropX" ) && a.keyExists( "cropY" )
                   && a.keyExists( "cropWidth" ) && a.keyExists( "cropHeight" );
        var hasResize = ( a.keyExists( "resizeWidth" ) && a.resizeWidth > 0 )
                     || ( a.keyExists( "resizeHeight" ) && a.resizeHeight > 0 );
        var hasFlip = a.keyExists( "flipImage" ) && a.flipImage;
        return hasCrop || hasResize || hasFlip;
    }

    /**
     * Apply crop / resize / flip with ColdFusion image functions.
     */
    private string function applyImageTransforms( required struct opts, required string sourcePath, required string outPath ){
        var o   = arguments.opts;
        var img = imageRead( arguments.sourcePath );

        if ( o.keyExists( "cropX" ) && o.keyExists( "cropY" ) && o.keyExists( "cropWidth" ) && o.keyExists( "cropHeight" ) ) {
            imageCrop( img, o.cropX, o.cropY, o.cropWidth, o.cropHeight );
        }

        var rw = o.keyExists( "resizeWidth" ) ? o.resizeWidth : 0;
        var rh = o.keyExists( "resizeHeight" ) ? o.resizeHeight : 0;
        if ( rw > 0 || rh > 0 ) {
            /* Compute the missing dimension from the source aspect ratio instead of passing "".
               The ACF/Lucee "empty string preserves aspect ratio" idiom fails on BoxLang:
               bx-image declares imageResize's width/height as numeric and rejects a string. */
            var srcInfo = imageInfo( img );
            if ( rw <= 0 ) { rw = max( 1, round( rh * srcInfo.width / srcInfo.height ) ); }
            if ( rh <= 0 ) { rh = max( 1, round( rw * srcInfo.height / srcInfo.width ) ); }
            imageResize( img, rw, rh );
        }

        if ( o.keyExists( "flipImage" ) && o.flipImage ) {
            imageFlip( img, "vertical" );
        }

        imageWrite( img, arguments.outPath );
        return arguments.outPath;
    }

    /**
     * Turn a process result into a typed error unless the tool succeeded and
     * produced a non-empty output file.
     */
    private void function assertSuccess( required struct result, required string outputFile, required string tool ){
        if ( arguments.result.timedOut ) {
            throw( type = "avif.timeout", message = "#arguments.tool# timed out.", detail = arguments.result.output );
        }
        var produced = fileExists( arguments.outputFile ) && getFileInfo( arguments.outputFile ).size > 0;
        if ( arguments.result.exitCode != 0 || !produced ) {
            throw(
                type    = "avif.binaryExecutionFailed",
                message = "#arguments.tool# failed (exit #arguments.result.exitCode#).",
                detail  = arguments.result.output
            );
        }
    }

    private void function moveInto( required string temp, required string destination, required boolean overwrite ){
        if ( fileExists( arguments.destination ) ) {
            if ( !arguments.overwrite ) {
                throw( type = "avif.invalidDestination", message = "Destination already exists: #arguments.destination#" );
            }
            fileDelete( arguments.destination );
        }
        fileMove( arguments.temp, arguments.destination );
    }

    private void function cleanup( required string path ){
        if ( len( arguments.path ) && fileExists( arguments.path ) ) {
            try {
                fileDelete( arguments.path );
            } catch ( any e ) {
            }
        }
    }

    /**
     * Parse `avifdec --info` output.
     *
     * Lines look like:
     *    * Resolution     : 640x480
     *    * Bit Depth      : 8
     *    * Format         : YUV420
     *    * Alpha          : Absent
     */
    private struct function parseInfo( required string raw, required string source, boolean verbose = false ){
        var out = {
            "success" : true,
            "source"  : arguments.source,
            "backend" : "libavif"
        };

        for ( var line in listToArray( arguments.raw, chr( 10 ) ) ) {
            var t = trim( line );
            if ( left( t, 1 ) != "*" ) {
                continue; // only the ' * Key : Value' metadata lines
            }
            t = trim( mid( t, 2, len( t ) ) ); // drop leading '*'
            var colon = find( ":", t );
            if ( colon <= 1 ) {
                continue;
            }
            var key = reReplace( left( t, colon - 1 ), "[^0-9A-Za-z]", "", "all" ); // "Bit Depth" -> "BitDepth"
            if ( !len( key ) ) {
                continue;
            }
            out[ key ] = trim( mid( t, colon + 1, len( t ) ) );
        }

        // Normalized, guaranteed keys for the hot-swap contract.
        out[ "width" ]  = 0;
        out[ "height" ] = 0;
        if ( out.keyExists( "Resolution" ) ) {
            var m = reFind( "([0-9]+)x([0-9]+)", out.Resolution, 1, true );
            if ( arrayLen( m.pos ) >= 3 && m.pos[ 2 ] > 0 ) {
                out[ "width" ]  = val( mid( out.Resolution, m.pos[ 2 ], m.len[ 2 ] ) );
                out[ "height" ] = val( mid( out.Resolution, m.pos[ 3 ], m.len[ 3 ] ) );
            }
        }
        out[ "depth" ]  = out.keyExists( "BitDepth" ) ? val( out.BitDepth ) : 0;
        // avifdec reports "Absent" when there's no alpha plane, and
        // "Not premultiplied" / "Premultiplied" (never literally "Present")
        // when there is one — so "present" means "anything but Absent".
        out[ "alpha" ]  = out.keyExists( "Alpha" ) ? ( out.Alpha != "Absent" ) : false;
        out[ "chroma" ] = out.keyExists( "Format" ) ? out.Format : "";

        if ( arguments.verbose ) {
            out[ "rawOutput" ] = arguments.raw;
        }
        return out;
    }

    /**
     * Extract the "1.4.2" style version from a libavif tool's --version output:
     *   "Version: 1.4.2 (dav1d [dec]:1.5.3-..., aom [enc]:3.14.1)"
     */
    private string function parseVersion( required string raw ){
        var m = reFind( "Version:\s*([0-9][0-9.]*)", arguments.raw, 1, true );
        if ( arrayLen( m.pos ) >= 2 && m.pos[ 2 ] > 0 ) {
            return mid( arguments.raw, m.pos[ 2 ], m.len[ 2 ] );
        }
        return trim( arguments.raw );
    }

    /**
     * Return the file extension (text after the last dot), or "".
     */
    private string function getFileExtension( required string filename ){
        if ( find( ".", arguments.filename ) ) {
            return listLast( arguments.filename, "." );
        }
        return "";
    }

}
