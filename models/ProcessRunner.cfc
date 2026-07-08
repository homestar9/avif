/**
 * ProcessRunner
 *
 * Runs an executable directly through Java `ProcessBuilder` — NO shell.
 *
 * This is the deliberate architectural improvement over the sibling `webp`
 * module, which shells out via `cmd.exe /c <cmd> 2>&1`. Passing each argument
 * as its own List<String> element means filenames are never re-parsed by a
 * shell, so paths containing spaces, `&`, `(`, `)`, `^`, etc. are safe and
 * there is no command-injection surface.
 *
 * stdout + stderr are merged (redirectErrorStream) and redirected to a temp
 * file, which the OS drains for us — this avoids the classic pipe-buffer
 * deadlock without needing a reader thread, and lets `waitFor(timeout)` cleanly
 * enforce the timeout.
 */
component singleton hint="Runs libavif executables via Java ProcessBuilder (no shell)" {

    function init(){
        return this;
    }

    /**
     * Execute a command and capture its merged stdout/stderr.
     *
     * @command Array of strings: [ exePath, arg1, arg2, ... ]. Every element is
     *          passed to the process verbatim as a separate argument.
     * @timeout Maximum seconds to wait before the process is forcibly terminated.
     *
     * @return struct { command, exitCode, output, timedOut, durationMs }
     */
    struct function run( required array command, numeric timeout = 60 ){

        var start = getTickCount();

        // Build a java.util.List<String> so ProcessBuilder binds to the List
        // constructor consistently across Lucee and Adobe ColdFusion.
        var jCommand = createObject( "java", "java.util.ArrayList" ).init();
        for ( var part in arguments.command ) {
            jCommand.add( javaCast( "string", part ) );
        }

        var logPath = getTempDirectory() & "avifproc_" & createUUID() & ".log";
        var logFile = createObject( "java", "java.io.File" ).init( logPath );

        var pb = createObject( "java", "java.lang.ProcessBuilder" ).init( jCommand );
        pb.redirectErrorStream( javaCast( "boolean", true ) );
        pb.redirectOutput( logFile );

        var timeUnit = createObject( "java", "java.util.concurrent.TimeUnit" ).SECONDS;
        var process  = pb.start();

        var timedOut = false;
        var exitCode = -1;

        if ( process.waitFor( javaCast( "long", arguments.timeout ), timeUnit ) ) {
            exitCode = process.exitValue();
        } else {
            timedOut = true;
            process.destroyForcibly();
            // Give the OS a moment to reap the process and release the log file.
            process.waitFor( javaCast( "long", 3 ), timeUnit );
        }

        var output = "";
        if ( fileExists( logPath ) ) {
            try {
                output = fileRead( logPath );
            } catch ( any e ) {
                output = "";
            }
            try {
                fileDelete( logPath );
            } catch ( any e ) {
            }
        }

        return {
            "command"    : arguments.command,
            "exitCode"   : exitCode,
            "output"     : output,
            "timedOut"   : timedOut,
            "durationMs" : getTickCount() - start
        };
    }

}
