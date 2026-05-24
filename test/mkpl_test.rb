#!/usr/bin/env ruby
# frozen_string_literal: true

require 'minitest/autorun'
require 'tmpdir'
require 'json'
require 'fileutils'

require_relative '../mkpl'

class PlaylistGeneratorTest < Minitest::Test
  def setup
    @target_dir = Dir.mktmpdir
    @playlist_path = File.join(@target_dir, 'playlist.m3u8')
  end

  def teardown
    FileUtils.rm_rf(@target_dir)
  end

  # --- helpers ---

  def create_fake_mp4(name, duration: 10.0, title: name)
    path = File.join(@target_dir, name)
    generator = PlaylistGenerator.new(@target_dir)
    generator.define_singleton_method(:extract_metadata) { |_path| { duration: duration, title: title } }
    generator.send(:write_playlist, @playlist_path, [path]) # write an initial playlist when needed
    path
  end

  def stub_ffprobe(video_path, duration:, title: File.basename(video_path))
    generator = PlaylistGenerator.new(@target_dir)
    generator.define_singleton_method(:extract_metadata) { |_path| { duration: duration, title: title } }
    generator
  end

  def parse_m3u8(path)
    entries = []
    current_info = nil

    File.foreach(path) do |line|
      line.chomp!
      case line
      when /^#EXTINF:([\d.]+),(.*)$/
        current_info = { duration: Regexp.last_match(1).to_f, title: Regexp.last_match(2) }
      when /^[^#]/
        entries << { filename: line, info: current_info }
        current_info = nil
      end
    end
    entries
  end

  # --- tests ---

  def test_directory_does_not_exist
    assert_raises(SystemExit) do
      PlaylistGenerator.new('/nonexistent_dir_/').run
    end
    refute File.exist?(File.join('/nonexistent_dir_/', 'playlist.m3u8'))
  end

  def test_no_video_files_does_not_create_playlist
    FileUtils.touch(File.join(@target_dir, 'notes.txt'))
    generator = PlaylistGenerator.new(@target_dir)
    generator.run
    refute File.exist?(@playlist_path), "playlist.m3u8 should not be created when there are no mp4 files"
  end

  def test_playslist_output_written_after_run
    path1 = create_fake_mp4('lesson1.mp4', duration: 10.0)
    FileUtils.touch(path1) # actual file exists

    generator = stub_ffprobe(path1, duration: 60.0)
    generator.run

    assert File.exist?(@playlist_path), "playlist.m3u8 should have been created"
  end

  def test_single_video_produces_one_entry
    path = File.join(@target_dir, 'lesson1.mp4')
    FileUtils.touch(path)

    generator = stub_ffprobe(path, duration: 120.5, title: 'Lesson 1')
    generator.run

    entries = parse_m3u8(@playlist_path)
    assert_equal 1, entries.size
    assert_equal path,  entries.first[:filename]
    assert_in_delta 120.5, entries.first[:info][:duration], 0.01
    assert_equal 'Lesson 1', entries.first[:info][:title]
  end

  def test_multiple_videos_sorted_numerically
    # In alphabetical order lesson10 would appear before lesson2.
    # Numerical sort must place lesson10 after lesson2 and lesson3.
    p3  = File.join(@target_dir, 'lesson3.mp4')
    p10 = File.join(@target_dir, 'lesson10.mp4')
    p2  = File.join(@target_dir, 'lesson2.mp4')
    [p3, p10, p2].each { |f| FileUtils.touch(f) }

    generator = PlaylistGenerator.new(@target_dir)
    generator.run

    entries = parse_m3u8(@playlist_path)
    assert_equal 3, entries.size
    assert_equal [p2, p3, p10], entries.map { |e| e[:filename] }
  end

  def test_m3u8_header_present
    path = File.join(@target_dir, 'lesson1.mp4')
    FileUtils.touch(path)

    stub_ffprobe(path, duration: 5.0).run

    content = File.read(@playlist_path)
    assert_equal '#EXTM3U', content.lines.first.chomp
  end

  def test_extinf_format_line
    path = File.join(@target_dir, 'my_video.mp4')
    FileUtils.touch(path)

    stub_ffprobe(path, duration: 55.0, title: 'My Video').run

    content = File.read(@playlist_path)
    assert_match(/^#EXTINF:55.0,My Video/, content)
  end

  def test_csv_character_in_title_is_replaced
    path = File.join(@target_dir, 'x.mp4')
    FileUtils.touch(path)

    stub_ffprobe(path, duration: 10.0, title: 'Alpha, Beta').run

    content = File.read(@playlist_path)
    refute_match(/Alpha, Beta/, content)
    assert_match(/Alpha- Beta/, content)
  end

  def test_different_durations_in_entries
    p_short = File.join(@target_dir, 'short.mp4')
    p_long  = File.join(@target_dir, 'long.mp4')
    FileUtils.touch(p_short)
    FileUtils.touch(p_long)

    generator = stub_ffprobe(p_short, duration: 0.3)

    durations = {}
    generator.define_singleton_method(:extract_metadata) do |path|
      durations[path] ||= path == p_short ? 0.3 : 7_200.0
      { duration: durations[path], title: File.basename(path) }
    end
    generator.run

    entries = parse_m3u8(@playlist_path)
    assert_equal 2, entries.size, "playlist should have 2 entries"

    by_filename = entries.to_h { |e| [e[:filename], e[:info][:duration]] }
    assert_in_delta 0.3,     by_filename[p_short],             0.01
    assert_in_delta 7_200.0, by_filename[p_long],              0.01
  end

  def test_capitalized_extension_is_detected
    path = File.join(@target_dir, 'Lesson.MP4')
    FileUtils.touch(path)

    generator = stub_ffprobe(path, duration: 5.0)
    generator.run

    entries = parse_m3u8(@playlist_path)
    assert_equal 1, entries.size, "Fichier .MP4 devrait être détecté"
  end

  def test_playlist_contains_absolute_paths
    path = File.join(@target_dir, 'lesson1.mp4')
    FileUtils.touch(path)

    stub_ffprobe(path, duration: 5.0).run

    entries = parse_m3u8(@playlist_path)
    assert_equal path, entries.first[:filename]
  end

  def test_natural_key_order
    gen = PlaylistGenerator.new(@target_dir)
    k1 = gen.send(:natural_key, 'lesson1.mp4')
    k2 = gen.send(:natural_key, 'lesson2.mp4')
    k10 = gen.send(:natural_key, 'lesson10.mp4')
    assert_equal ["lesson", 1, ".mp4"], k1
    assert_equal ["lesson", 2, ".mp4"], k2
    assert_equal ["lesson", 10, ".mp4"], k10
    assert (k1 <=> k2) == -1, 'lesson1 should sort before lesson2'
    assert (k2 <=> k10) == -1, 'lesson2 should sort before lesson10'
  end

  def test_natural_key_mixed_case_and_numbers
    gen = PlaylistGenerator.new(@target_dir)
    k1 = gen.send(:natural_key, 'lesson1.mp4')
    k2 = gen.send(:natural_key, 'Lesson10.MP4')
    k3 = gen.send(:natural_key, 'lesson2.MP4')
    assert (k1 <=> k3) == -1, 'lesson1 < lesson2 (case-insensitive)'
    assert (k3 <=> k2) == -1, 'lesson2 < lesson10 (case-insensitive)'
  end

  def test_natural_key_no_extension
    gen = PlaylistGenerator.new(@target_dir)
    assert_equal ["foobar"], gen.send(:natural_key, 'foobar')
  end

  def test_natural_key_no_number_with_extension
    gen = PlaylistGenerator.new(@target_dir)
    assert_equal ["foobar", ".mp4"], gen.send(:natural_key, 'foobar.mp4')
  end
end
