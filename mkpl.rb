#!/usr/bin/env ruby
# frozen_string_literal: true

require 'json'
require 'fileutils'

class PlaylistGenerator
  MP4_EXTENSIONS = %w[.mp4 .MP4].freeze
  EXTINF_FORMAT = '#EXTINF:%<duration>s,%<title>s'

  def initialize(directory)
    @directory = File.expand_path(directory)
  end

  def run
    unless File.directory?(@directory)
      abort "Erreur : '#{@directory}' n'est pas un répertoire valide."
    end

    video_files = find_video_files
    return if video_files.empty?

    playlist_path = File.join(@directory, 'playlist.m3u8')
    write_playlist(playlist_path, video_files)
    puts "Playlist créée : #{playlist_path} (#{video_files.size} entrée(s))"
  end

  private

  def find_video_files
    Dir.glob(File.join(@directory, '**', '*')).select do |file|
      MP4_EXTENSIONS.include?(File.extname(file)) && File.file?(file)
    end.sort_by { |f| natural_key(File.basename(f)) }
  end

  def natural_key(string)
    # Split the basename into a name + extension at the last dot so that
    # ".mp4" is kept as a whole unit, then tokenise the name part only.
    name, dot, ext = string.rpartition('.')
    (name.empty? ? [ext.downcase] : parts(name) + [dot + ext])
  end

  def parts(str)
    str.scan(/\d+|\D+/).map { |part| part =~ /^\d+$/ ? part.to_i : part.downcase }
  end

  def extract_metadata(file_path)
    json = `ffprobe -v quiet -print_format json -show_format -show_streams "#{file_path}" 2>&1`
    data = JSON.parse(json)

    duration = data.dig('format', 'duration').to_f
    title = data.dig('format', 'tags', 'title') || File.basename(file_path)

    {
      duration: duration,
      title: title
    }
  rescue JSON::ParserError, Errno::ENOENT
    {
      duration: 0.0,
      title: File.basename(file_path)
    }
  end

  def write_playlist(path, video_files)
    File.open(path, 'w') do |f|
      f.puts '#EXTM3U'
      video_files.each do |video|
        metadata = extract_metadata(video)
        duration = metadata[:duration]
        title = metadata[:title].gsub(',', '-')
        f.puts format(EXTINF_FORMAT, duration: duration, title: title)
        f.puts video
      end
    end
  end
end

if __FILE__ == $PROGRAM_NAME
  if ARGV.empty?
    abort "Usage : ruby mkpl.rb <repertoire>"
  end

  generator = PlaylistGenerator.new(ARGV[0])
  generator.run
end
