module.exports = (grunt) ->

  # Project configuration.
  grunt.initConfig
    coffee:
      schedule_importer:
        expand: true
        cwd: 'nrod'
        src: ['**/*.coffee']
        dest: 'bin'
        ext: '.js'
    watch:
      app:
        files: 'nrod/**/*.coffee'
        tasks: ['coffee']

  # These plugins provide necessary tasks.
  grunt.loadNpmTasks 'grunt-contrib-coffee'
  grunt.loadNpmTasks 'grunt-contrib-watch'

  # Default task.
  grunt.registerTask 'default', ['coffee']
