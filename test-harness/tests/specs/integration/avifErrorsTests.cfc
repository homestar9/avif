/**
 * Integration tests for avif.cfc's typed error paths and settings overrides
 * not covered by the core avifTests.cfc suite: avif.invalidDestination,
 * avif.binaryNotFound, avif.timeout, avif.binaryExecutionFailed, and
 * settings plumb-through (custom avifencPath/avifdecPath/timeout/maxDimension).
 *
 * Uses AvifTestHelper.buildModel() to construct avif.cfc instances with
 * overridden settings and/or a mocked ProcessRunner via TestBox
 * prepareMock()/$property() — no production code changes required.
 */
component extends="tests.AvifTestHelper" {

    private struct function timedOutResult(){
        return { command : [], exitCode : -1, output : "", timedOut : true, durationMs : 1001 };
    }

    function run(){

        describe( "avif typed errors and settings overrides", function(){

            /* ------------------------- invalidDestination ------------------------- */

            it( "throws avif.invalidDestination when the encode destination dir is missing", function(){
                var dest = variables._outputPath & "no-such-dir\x.avif";
                expect( function(){
                    model.encode( source = variables._inputPath & "golden.jpg", destination = dest );
                } ).toThrow( type = "avif.invalidDestination" );
            } );

            it( "throws avif.invalidDestination when the decode destination dir is missing", function(){
                var dest = variables._outputPath & "no-such-dir\x.png";
                expect( function(){
                    model.decode( source = variables._inputPath & "golden.avif", destination = dest );
                } ).toThrow( type = "avif.invalidDestination" );
            } );

            it( "throws avif.invalidDestination on encode when overwrite=false and destination exists", function(){
                var dest = out( "avif" );
                fileWrite( dest, "x" );
                expect( function(){
                    model.encode( source = variables._inputPath & "golden.jpg", destination = dest, overwrite = false );
                } ).toThrow( type = "avif.invalidDestination" );
                expect( getFileInfo( dest ).size ).toBe( 1 );
            } );

            it( "throws avif.invalidDestination on decode when overwrite=false and destination exists", function(){
                var dest = out( "png" );
                fileWrite( dest, "x" );
                expect( function(){
                    model.decode( source = variables._inputPath & "golden.avif", destination = dest, overwrite = false );
                } ).toThrow( type = "avif.invalidDestination" );
                expect( getFileInfo( dest ).size ).toBe( 1 );
            } );

            /* --------------------------- binaryNotFound ---------------------------- */

            it( "throws avif.binaryNotFound when avifencPath is overridden to a missing file", function(){
                var svc = buildModel( { avifencPath : variables._outputPath & "missing-avifenc.exe" } );
                expect( function(){
                    svc.encode( source = variables._inputPath & "golden.jpg", destination = out( "avif" ) );
                } ).toThrow( type = "avif.binaryNotFound" );
            } );

            it( "throws avif.binaryNotFound when avifdecPath is overridden to a missing file", function(){
                var svc = buildModel( { avifdecPath : variables._outputPath & "missing-avifdec.exe" } );
                expect( function(){
                    svc.info( source = variables._inputPath & "golden.avif" );
                } ).toThrow( type = "avif.binaryNotFound" );
            } );

            /* ------------------------------- timeout -------------------------------- */

            it( "throws avif.timeout when encode's process runner reports a timeout", function(){
                var fakeRunner = createEmptyMock( "avif.models.ProcessRunner" );
                fakeRunner.$( "run", timedOutResult() );
                var svc = buildModel( {}, fakeRunner );
                expect( function(){
                    svc.encode( source = variables._inputPath & "golden.jpg", destination = out( "avif" ) );
                } ).toThrow( type = "avif.timeout" );
            } );

            it( "throws avif.timeout when decode's process runner reports a timeout", function(){
                var fakeRunner = createEmptyMock( "avif.models.ProcessRunner" );
                fakeRunner.$( "run", timedOutResult() );
                var svc = buildModel( {}, fakeRunner );
                expect( function(){
                    svc.decode( source = variables._inputPath & "golden.avif", destination = out( "png" ) );
                } ).toThrow( type = "avif.timeout" );
            } );

            it( "throws avif.timeout when info's process runner reports a timeout", function(){
                var fakeRunner = createEmptyMock( "avif.models.ProcessRunner" );
                fakeRunner.$( "run", timedOutResult() );
                var svc = buildModel( {}, fakeRunner );
                expect( function(){
                    svc.info( source = variables._inputPath & "golden.avif" );
                } ).toThrow( type = "avif.timeout" );
            } );

            /* --------------------------- binaryExecutionFailed ---------------------- */

            it( "throws avif.binaryExecutionFailed decoding a corrupt avif file", function(){
                var badSource = variables._outputPath & "corrupt-" & createUUID() & ".avif";
                fileWrite( badSource, "this is not an avif file" );
                var dest = out( "png" );
                expect( function(){
                    model.decode( source = badSource, destination = dest );
                } ).toThrow( type = "avif.binaryExecutionFailed" );
                expect( fileExists( dest ) ).toBeFalse();
            } );

            it( "throws avif.binaryExecutionFailed calling info() on a corrupt avif file", function(){
                var badSource = variables._outputPath & "corrupt-" & createUUID() & ".avif";
                fileWrite( badSource, "this is not an avif file" );
                expect( function(){
                    model.info( source = badSource );
                } ).toThrow( type = "avif.binaryExecutionFailed" );
            } );

            it( "throws avif.binaryExecutionFailed encoding a corrupt jpg file", function(){
                var badSource = variables._outputPath & "corrupt-" & createUUID() & ".jpg";
                fileWrite( badSource, "this is not a jpg file" );
                var dest = out( "avif" );
                expect( function(){
                    model.encode( source = badSource, destination = dest );
                } ).toThrow( type = "avif.binaryExecutionFailed" );
                expect( fileExists( dest ) ).toBeFalse();
            } );

            /* -------------------------- settings plumb-through ----------------------- */

            it( "passes the resolved timeout through to the process runner", function(){
                var fakeRunner = createEmptyMock( "avif.models.ProcessRunner" );
                fakeRunner.$( "run", { command : [], exitCode : 0, output : " * Resolution     : 640x480", timedOut : false, durationMs : 5 } );
                var svc = buildModel( {}, fakeRunner );
                svc.info( source = variables._inputPath & "golden.avif", timeout = 42 );
                var calls = fakeRunner.$callLog().run;
                expect( arrayLen( calls ) ).toBe( 1 );
                expect( calls[ 1 ][ 2 ] ).toBe( 42 );
            } );

            it( "uses overridden avifencPath/avifdecPath and reports bundled=false", function(){
                var s   = moduleSettings();
                var svc = buildModel( {
                    avifencPath : s.binPath & "avifenc.exe",
                    avifdecPath : s.binPath & "avifdec.exe"
                } );
                expect( svc.version().bundled ).toBeFalse();
                var dest = out( "avif" );
                svc.encode( source = variables._inputPath & "golden.jpg", destination = dest );
                expect( fileExists( dest ) ).toBeTrue();
            } );

            it( "enforces settings.maxDimension via avifdec --dimension-limit", function(){
                var svc = buildModel( { maxDimension : 100 } );
                expect( function(){
                    svc.decode( source = variables._inputPath & "golden.avif", destination = out( "png" ) );
                } ).toThrow( type = "avif.binaryExecutionFailed" );
            } );

        } );
    }

}
