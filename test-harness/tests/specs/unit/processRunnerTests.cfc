/**
 * Unit tests for ProcessRunner — no ColdBox required, exercises the real
 * Java ProcessBuilder wrapper directly with a system executable (ping.exe)
 * so timeout/exit-code behavior is verified deterministically, without
 * touching libavif or wall-clock-sensitive encode timing.
 */
component extends="testbox.system.BaseSpec" {

    function beforeAll(){
        variables.runner  = new avif.models.ProcessRunner();
        variables.pingExe = createObject( "java", "java.lang.System" ).getenv( "SystemRoot" ) & "\System32\ping.exe";
    }

    function run(){
        describe( "ProcessRunner", function(){

            it( "runs a command successfully and captures output", function(){
                var result = runner.run( [ pingExe, "-n", "1", "127.0.0.1" ], 30 );
                expect( result.exitCode ).toBe( 0 );
                expect( result.timedOut ).toBeFalse();
                expect( len( result.output ) ).toBeGT( 0 );
                expect( result.durationMs ).toBeGTE( 0 );
            } );

            it( "times out a long-running command", function(){
                var result = runner.run( [ pingExe, "-n", "30", "127.0.0.1" ], 1 );
                expect( result.timedOut ).toBeTrue();
                expect( result.durationMs ).toBeLT( 15000 );
            } );

            it( "reports a non-zero exit code for a failing command", function(){
                var result = runner.run( [ pingExe, "-badflag" ], 15 );
                expect( result.exitCode ).notToBe( 0 );
                expect( result.timedOut ).toBeFalse();
            } );

        } );
    }

}
