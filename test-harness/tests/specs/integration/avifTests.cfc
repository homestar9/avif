/**
 * Integration tests for the avif model. These exercise the REAL bundled
 * libavif binaries (avifenc.exe / avifdec.exe), so they only pass on Windows x64.
 *
 * Assertion strategy (per the design plan): assert on structured results,
 * output-file existence/size, and info() dimensions — never on English text
 * fragments from the tools' diagnostic output, which can change upstream.
 */
component extends="coldbox.system.testing.BaseTestCase" {

    variables._cleanOutput = true;

    /*********************************** LIFE CYCLE Methods ***********************************/

    function beforeAll(){
        super.beforeAll();
        super.setup();
        // Resolve fixtures from THIS spec file's location. expandPath() is
        // unreliable here — it resolves against the TestBox runner directory,
        // not the spec — so canonicalize relative to getCurrentTemplatePath().
        var specDir = getDirectoryFromPath( getCurrentTemplatePath() );
        variables._inputPath  = canonicalDir( specDir & "..\..\resources" );
        variables._outputPath = canonicalDir( specDir & "..\..\resources\output" );
        model = getInstance( "avif@avif" );
        if ( !directoryExists( variables._outputPath ) ) {
            directoryCreate( variables._outputPath );
        }
    }

    private string function canonicalDir( required string path ){
        return createObject( "java", "java.io.File" ).init( arguments.path ).getCanonicalPath() & "\";
    }

    function afterAll(){
        super.afterAll();
        if ( variables._cleanOutput && directoryExists( variables._outputPath ) ) {
            directoryList( path = variables._outputPath, type = "file" ).each( function( item ){
                fileDelete( item );
            } );
        }
    }

    /*********************************** HELPERS ***********************************/

    private string function out( required string ext ){
        return variables._outputPath & createUUID() & "." & arguments.ext;
    }

    /*********************************** BDD SUITES ***********************************/

    function run(){

        describe( "avif model", function(){

            it( "can be created", function(){
                expect( model ).toBeComponent();
            } );

            it( "reports version info for the bundled binaries", function(){
                var v = model.version();
                expect( v.platform ).toBe( "windows-x64" );
                expect( v.avifencVersion ).toMatch( "^[0-9]+\.[0-9]+" );
                expect( v.avifdecVersion ).toMatch( "^[0-9]+\.[0-9]+" );
                expect( v.bundled ).toBeTrue();
            } );

            it( "reports the full version() struct shape for the bundled binaries", function(){
                var v = model.version();
                expect( v.backend ).toBe( "libavif" );
                expect( fileExists( v.avifencPath ) ).toBeTrue();
                expect( fileExists( v.avifdecPath ) ).toBeTrue();
            } );

            it( "reports capabilities", function(){
                var c = model.capabilities();
                expect( c.supported ).toBeTrue();
                expect( c.decodeOutputFormats ).toInclude( "jpg" );
                expect( c.transforms ).toBeTrue();
            } );

            it( "reports the full capabilities() struct shape", function(){
                var c = model.capabilities();
                expect( c ).toHaveKey( "platform,supported,encodeInputFormats,decodeOutputFormats,alpha,lossless,metadata,animation,transforms" );
                expect( c.encodeInputFormats ).toInclude( "png" );
                expect( c.animation ).toBeFalse();
                expect( c.alpha ).toBeTrue();
                expect( c.lossless ).toBeTrue();
                expect( c.metadata ).toBeTrue();
            } );

            /* ---------------------------------- encode ---------------------------------- */

            it( "encodes a jpg into avif", function(){
                var dest = out( "avif" );
                model.encode( source = variables._inputPath & "golden.jpg", destination = dest );
                expect( fileExists( dest ) ).toBeTrue();
                expect( getFileInfo( dest ).size ).toBeGT( 0 );
            } );

            it( "encodes a png (with alpha) into avif", function(){
                var dest = out( "avif" );
                model.encode( source = variables._inputPath & "dog.png", destination = dest );
                expect( fileExists( dest ) ).toBeTrue();
                expect( getFileInfo( dest ).size ).toBeGT( 0 );
            } );

            it( "encodes losslessly", function(){
                var dest = out( "avif" );
                model.encode( source = variables._inputPath & "dog.png", destination = dest, lossless = true );
                expect( fileExists( dest ) ).toBeTrue();
                expect( getFileInfo( dest ).size ).toBeGT( 0 );
            } );

            it( "resizes during encode via cfimage (interface parity with webp)", function(){
                var dest = out( "avif" );
                model.encode(
                    source      = variables._inputPath & "golden.jpg",
                    destination = dest,
                    resizeWidth = 320
                );
                var meta = model.info( source = dest );
                expect( meta.width ).toBe( 320 );
                // 640x480 source keeps aspect ratio -> 320x240
                expect( meta.height ).toBe( 240 );
            } );

            it( "throws avif.invalidSource for a missing source", function(){
                expect( function(){
                    model.encode( source = variables._inputPath & "does-not-exist.jpg", destination = out( "avif" ) );
                } ).toThrow( type = "avif.invalidSource" );
            } );

            /* ---------------------------------- decode ---------------------------------- */

            it( "decodes an avif into png", function(){
                var dest = out( "png" );
                model.decode( source = variables._inputPath & "golden.avif", destination = dest );
                expect( fileExists( dest ) ).toBeTrue();
                expect( getFileInfo( dest ).size ).toBeGT( 0 );
            } );

            it( "decodes an avif directly into jpg (improvement over webp)", function(){
                var dest = out( "jpg" );
                model.decode( source = variables._inputPath & "golden.avif", destination = dest );
                expect( fileExists( dest ) ).toBeTrue();
                expect( getFileInfo( dest ).size ).toBeGT( 0 );
            } );

            it( "throws avif.unsupportedFormat for an unsupported decode target", function(){
                expect( function(){
                    model.decode( source = variables._inputPath & "golden.avif", destination = out( "gif" ) );
                } ).toThrow( type = "avif.unsupportedFormat" );
            } );

            /* ----------------------------------- info ----------------------------------- */

            it( "returns stable width/height from info()", function(){
                var meta = model.info( source = variables._inputPath & "golden.avif" );
                expect( meta ).toHaveKey( "width" );
                expect( meta ).toHaveKey( "height" );
                expect( meta.width ).toBe( 640 );
                expect( meta.height ).toBe( 480 );
                expect( meta.depth ).toBe( 8 );
                expect( meta.success ).toBeTrue();
            } );

            it( "reports chroma subsampling from info()", function(){
                var meta = model.info( source = variables._inputPath & "golden.avif" );
                expect( meta.chroma ).toBe( "YUV420" );
            } );

            it( "reports alpha=true from info() for an avif encoded from a transparent source", function(){
                var avifPath = out( "avif" );
                model.encode( source = variables._inputPath & "dog.png", destination = avifPath );
                var meta = model.info( source = avifPath );
                expect( meta.alpha ).toBeTrue();
            } );

            it( "includes rawOutput in info() only when verbose=true", function(){
                var verboseMeta = model.info( source = variables._inputPath & "golden.avif", verbose = true );
                expect( verboseMeta ).toHaveKey( "rawOutput" );
                expect( len( verboseMeta.rawOutput ) ).toBeGT( 0 );

                var defaultMeta = model.info( source = variables._inputPath & "golden.avif" );
                expect( defaultMeta ).notToHaveKey( "rawOutput" );
            } );

        } );
    }

}
