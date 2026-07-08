/**
 * Integration tests for avif.encode()'s option matrix not covered by the
 * core avifTests.cfc suite. Real bundled binaries; Windows x64 only.
 * See avifTests.cfc for the assertion strategy (structured results / file
 * existence-size / info() numbers — never English tool-output fragments).
 */
component extends="tests.AvifTestHelper" {

    function run(){

        describe( "avif encode options", function(){

            it( "produces a smaller file at lower quality than at higher quality", function(){
                var lo = out( "avif" );
                var hi = out( "avif" );
                model.encode( source = variables._inputPath & "golden.jpg", destination = lo, quality = 10 );
                model.encode( source = variables._inputPath & "golden.jpg", destination = hi, quality = 90 );
                expect( getFileInfo( lo ).size ).toBeLT( getFileInfo( hi ).size );
            } );

            it( "accepts alphaQuality and preserves alpha", function(){
                var dest = out( "avif" );
                model.encode( source = variables._inputPath & "dog.png", destination = dest, alphaQuality = 25 );
                expect( fileExists( dest ) ).toBeTrue();
                expect( model.info( dest ).alpha ).toBeTrue();
            } );

            it( "accepts a custom speed", function(){
                var dest = out( "avif" );
                model.encode( source = variables._inputPath & "golden.jpg", destination = dest, speed = 10 );
                var meta = model.info( dest );
                expect( meta.width ).toBe( 640 );
                expect( meta.height ).toBe( 480 );
            } );

            it( "encodes at a specific output bit depth", function(){
                var dest = out( "avif" );
                model.encode( source = variables._inputPath & "golden.jpg", destination = dest, depth = 10 );
                expect( model.info( dest ).depth ).toBe( 10 );
            } );

            it( "encodes with a specific chroma subsampling", function(){
                var dest = out( "avif" );
                model.encode( source = variables._inputPath & "golden.jpg", destination = dest, chroma = "444" );
                expect( model.info( dest ).chroma ).toBe( "YUV444" );
            } );

            it( "strips metadata when metadata='none'", function(){
                var withMeta = out( "avif" );
                var noMeta   = out( "avif" );
                model.encode( source = variables._inputPath & "golden.jpg", destination = withMeta );
                model.encode( source = variables._inputPath & "golden.jpg", destination = noMeta, metadata = "none" );
                expect( fileExists( noMeta ) ).toBeTrue();
                expect( getFileInfo( noMeta ).size ).toBeLTE( getFileInfo( withMeta ).size );
            } );

            it( "encodes single-threaded when multiThreaded is false", function(){
                var dest = out( "avif" );
                model.encode( source = variables._inputPath & "golden.jpg", destination = dest, multiThreaded = false );
                expect( fileExists( dest ) ).toBeTrue();
                expect( getFileInfo( dest ).size ).toBeGT( 0 );
            } );

            it( "crops during encode via cfimage", function(){
                var dest = out( "avif" );
                model.encode(
                    source      = variables._inputPath & "golden.jpg",
                    destination = dest,
                    cropX       = 0,
                    cropY       = 0,
                    cropWidth   = 100,
                    cropHeight  = 50
                );
                var meta = model.info( dest );
                expect( meta.width ).toBe( 100 );
                expect( meta.height ).toBe( 50 );
            } );

            it( "crops and resizes during encode together", function(){
                var dest = out( "avif" );
                model.encode(
                    source      = variables._inputPath & "golden.jpg",
                    destination = dest,
                    cropX       = 0,
                    cropY       = 0,
                    cropWidth   = 320,
                    cropHeight  = 240,
                    resizeWidth = 160
                );
                var meta = model.info( dest );
                expect( meta.width ).toBe( 160 );
                expect( meta.height ).toBe( 120 );
            } );

            it( "accepts verbose and still returns the raw tool output", function(){
                var dest = out( "avif" );
                var result = model.encode( source = variables._inputPath & "golden.jpg", destination = dest, verbose = true );
                expect( isSimpleValue( result ) ).toBeTrue();
                expect( fileExists( dest ) ).toBeTrue();
            } );

            it( "overwrites an existing destination by default", function(){
                var dest = out( "avif" );
                model.encode( source = variables._inputPath & "golden.jpg", destination = dest, quality = 90 );
                var firstSize = getFileInfo( dest ).size;
                model.encode( source = variables._inputPath & "golden.jpg", destination = dest, quality = 10 );
                var secondSize = getFileInfo( dest ).size;
                expect( secondSize ).toBeLT( firstSize );
            } );

        } );
    }

}
