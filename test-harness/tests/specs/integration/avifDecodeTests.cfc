/**
 * Integration tests for avif.decode()'s option matrix not covered by the
 * core avifTests.cfc suite — crop/resize/flip (the entire cfimage
 * post-process path), jpeg quality, png depth, and upsampling.
 * Real bundled binaries; Windows x64 only.
 */
component extends="tests.AvifTestHelper" {

    function run(){

        describe( "avif decode options", function(){

            it( "crops during decode via cfimage", function(){
                var dest = out( "png" );
                model.decode(
                    source      = variables._inputPath & "golden.avif",
                    destination = dest,
                    cropX       = 0,
                    cropY       = 0,
                    cropWidth   = 100,
                    cropHeight  = 50
                );
                var img = imageRead( dest );
                expect( imageGetWidth( img ) ).toBe( 100 );
                expect( imageGetHeight( img ) ).toBe( 50 );
            } );

            it( "resizes during decode via cfimage", function(){
                var dest = out( "png" );
                model.decode(
                    source      = variables._inputPath & "golden.avif",
                    destination = dest,
                    resizeWidth = 320
                );
                var img = imageRead( dest );
                expect( imageGetWidth( img ) ).toBe( 320 );
                expect( imageGetHeight( img ) ).toBe( 240 );
            } );

            it( "flips the image vertically (pixel-verified)", function(){
                var plain   = out( "png" );
                var flipped = out( "png" );
                model.decode( source = variables._inputPath & "golden.avif", destination = plain );
                model.decode( source = variables._inputPath & "golden.avif", destination = flipped, flipImage = true );

                var a    = imageGetBufferedImage( imageRead( plain ) );
                var b    = imageGetBufferedImage( imageRead( flipped ) );
                var h    = a.getHeight();
                var x    = 100;
                var y    = 40;
                var mask = 16777215; // RGB only, ignore any alpha byte

                // Sanity guard: the fixture must actually differ vertically at this probe point.
                expect( bitAnd( a.getRGB( x, y ), mask ) ).notToBe( bitAnd( a.getRGB( x, h - 1 - y ), mask ) );
                // Flip contract: flipped(x,y) == plain(x, h-1-y)
                expect( bitAnd( b.getRGB( x, y ), mask ) ).toBe( bitAnd( a.getRGB( x, h - 1 - y ), mask ) );
            } );

            it( "decodes to jpg at different quality levels", function(){
                var lo = out( "jpg" );
                var hi = out( "jpg" );
                model.decode( source = variables._inputPath & "golden.avif", destination = lo, quality = 20 );
                model.decode( source = variables._inputPath & "golden.avif", destination = hi, quality = 95 );
                expect( getFileInfo( lo ).size ).toBeLT( getFileInfo( hi ).size );
            } );

            it( "decodes to png at a specific bit depth", function(){
                var d8  = out( "png" );
                var d16 = out( "png" );
                model.decode( source = variables._inputPath & "golden.avif", destination = d8, depth = 8 );
                model.decode( source = variables._inputPath & "golden.avif", destination = d16, depth = 16 );
                expect( getFileInfo( d16 ).size ).toBeGT( getFileInfo( d8 ).size );
            } );

            it( "accepts an explicit upsampling mode", function(){
                var dest = out( "png" );
                model.decode( source = variables._inputPath & "golden.avif", destination = dest, upsampling = "nearest" );
                expect( fileExists( dest ) ).toBeTrue();
                var img = imageRead( dest );
                expect( imageGetWidth( img ) ).toBe( 640 );
            } );

        } );
    }

}
