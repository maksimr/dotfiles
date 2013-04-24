module.exports = function(grunt) {
    'use strict';

    grunt.initConfig({
        bats: {
            bin: 'lib/bats/bin/bats',
            args: ['tests/tests.bats']
        },
        // default watch configuration
        watch: {
            bash: {
                files: ['lib/*.bash', 'tests/**/*.bats'],
                tasks: 'test'
            }
        }
    });

    grunt.registerTask('bats', 'Bats is a test framework for shell', function() {
        var data = grunt.config('bats');
        var utils = grunt.util;
        var verbose = grunt.verbose;
        var args = grunt.file.expand(data.args);
        var log = grunt.log;
        var done = this.async();

        log.writeln('Running shell tests...');

        utils.spawn({
            cmd: data.bin,
            args: args
        }, function(err, result, code) {
            if (!code) {
                result.stdout.split('\n').forEach(log.writeln, log);
                return done(null);
            }

            // error handling
            verbose.or.writeln();
            (result.stdout || result.stderr).split('\n').forEach(log.error, log);
            done(false);
        });
    });

    // Alias the `test` task to run the `mocha` task instead
    grunt.registerTask('test', ['bats']);
    grunt.registerTask('default', ['watch']);
};
