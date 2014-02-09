module.exports = (grunt) ->

  grunt.initConfig
    coffee:
      schedule_importer:
        expand: true
        cwd: 'nrod'
        src: ['**/*.coffee']
        dest: 'bin'
        ext: '.js'
    copy:
      executables:
        expand: true
        cwd: 'nrod'
        src: ['**/*.js']
        dest: 'bin'
    watch:
      app:
        files: 'nrod/**/*.coffee'
        tasks: ['coffee']
      executables:
        files: 'nrod/**/*.js'
        tasks: ['copy']

  grunt.loadNpmTasks 'grunt-contrib-coffee'
  grunt.loadNpmTasks 'grunt-contrib-copy'
  grunt.loadNpmTasks 'grunt-contrib-watch'

  grunt.registerTask 'default', ['coffee', 'copy']
