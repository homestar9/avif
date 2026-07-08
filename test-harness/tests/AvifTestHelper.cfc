/**
 * Shared base for AVIF integration specs: fixture path resolution, output-dir
 * cleanup, and a buildModel() helper for constructing avif.cfc instances with
 * overridden settings and/or a mocked ProcessRunner — with zero production
 * code changes (TestBox prepareMock + $property against the WireBox-injected
 * `settings` / `processRunner` properties on avif.cfc).
 *
 * NOTE: lives directly under tests/ (not tests/specs/) so the TestBox runner
 * (directory=tests.specs, recurse=true) never treats it as its own spec bundle.
 */
component extends="coldbox.system.testing.BaseTestCase" {

    variables._cleanOutput = true;

    function beforeAll(){
        super.beforeAll();
        super.setup();
        // NOTE: getCurrentTemplatePath() inside an inherited method resolves to
        // the calling CHILD spec's own file location on this engine, not to
        // where this method is defined — so it can't be used to locate
        // resources relative to THIS file. Use the stable "/tests" CF mapping
        // (set once, absolutely, in tests/Application.cfc) instead.
        variables._inputPath  = canonicalDir( expandPath( "/tests/resources" ) );
        variables._outputPath = canonicalDir( expandPath( "/tests/resources/output" ) );
        model = getInstance( "avif@avif" );
        if ( !directoryExists( variables._outputPath ) ) {
            directoryCreate( variables._outputPath );
        }
    }

    function afterAll(){
        super.afterAll();
        if ( variables._cleanOutput && directoryExists( variables._outputPath ) ) {
            directoryList( path = variables._outputPath, type = "file" ).each( function( item ){
                fileDelete( item );
            } );
        }
    }

    private string function canonicalDir( required string path ){
        return createObject( "java", "java.io.File" ).init( arguments.path ).getCanonicalPath() & "\";
    }

    private string function out( required string ext ){
        return variables._outputPath & createUUID() & "." & arguments.ext;
    }

    private struct function moduleSettings(){
        return getInstance( dsl = "coldbox:modulesettings:avif" );
    }

    /**
     * Build an avif.cfc instance with overridden settings and/or a swapped
     * ProcessRunner, via TestBox mock property injection — no production
     * code changes needed.
     */
    private any function buildModel( struct overrides = {}, any runner ){
        var s = duplicate( moduleSettings() );
        structAppend( s, arguments.overrides, true );
        var svc = prepareMock( new avif.models.avif() );
        svc.$property( propertyName = "settings", mock = s );
        svc.$property(
            propertyName = "processRunner",
            mock         = isNull( arguments.runner ) ? new avif.models.ProcessRunner() : arguments.runner
        );
        return svc;
    }

}
