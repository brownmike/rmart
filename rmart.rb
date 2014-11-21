#!/usr/bin/env ruby

# Ruby Mac Adware Removal Tool

require 'fileutils'
require 'yaml'

class RMART
  attr_reader :removed_components, :user_library, :adware_definitions

  def initialize
    @removed_components = []
    @adware_definitions = YAML.load_file 'adware_definitions.yaml'
    @user_library = File.expand_path '~/Library'
    system 'clear'
  end

  def sweep
    adware_definitions.each do |adware|
      puts "\n== Checking for #{adware['title']} =="
      if adware['process_names']
        killall adware['process_names']
      end

      adware['components'].each do |component|
        remove_file component
      end

      if adware['firefox_keywords'] && firefox_installed?
        remove_firefox_components adware['firefox_keywords']
      end

      if adware['safari_keywords']
        remove_safari_components adware['safari_keywords']
      end

      if adware['chrome_keywords'] && chrome_installed?
        remove_chrome_components adware['chrome_keywords']
      end

      if adware['startup_keywords']
        remove_startup_items adware['startup_keywords']
      end
    end

    print_summary
  end

  def firefox_installed?
    unless @firefox_installed
      @firefox_installed = File.exist? '/Applications/Firefox.app'
    end
    @firefox_installed
  end

  def chrome_installed?
    unless @chrome_installed
      @chrome_installed = File.exist? '/Applications/Google Chrome.app'
    end
    @chrome_installed
  end

  private

  # Also removes folders - requires full expanded path
  def remove_file file
    if File.exist? file
      puts "- Removing #{file}"
      FileUtils.rm_rf file
      @removed_components << file
    end
  end

  def killall process_names
    process_names.each do |process_name|
      system "killall #{process_name}"
    end
  end

  def remove_startup_items keywords
    startup_paths = [
      "#{user_library}/LaunchAgents/",
      "/Library/LaunchAgents/",
      "/Library/LaunchDaemons/",
      "/Library/StartupItems/"
    ]

    puts "\nSearching startup entries for keywords #{keywords.join ', '}"
    search_and_destroy startup_paths, patternize(keywords)
  end

  def remove_safari_components keywords
    safari_paths = [
      "#{user_library}/Safari/Extensions/",
      "#{user_library}/Internet Plug-Ins/",
      "/Library/Internet Plug-Ins/"
    ]
    puts "\nSearching Safari extensions for keywords #{keywords.join ', '}"
    search_and_destroy safari_paths, patternize(keywords)
  end

  def remove_chrome_components keywords
    chrome_paths = [
      "#{user_library}/Application Support/Google/Chrome/Default/Extensions/",
      "#{user_library}/Application Support/Google/Chrome/External Extensions/"
    ]

    puts "\nSearching Chrome extensions for keywords #{keywords.join ', '}"
    search_and_destroy chrome_paths, patternize(keywords)
  end

  def remove_firefox_components keywords
    firefox_paths = [
      firefox_default_profile_path,
      firefox_default_profile_path + '/extensions/',
      firefox_default_profile_path + '/searchplugins/',
      "#{user_library}/Application Support/Mozilla/Extensions/"
    ]

    puts "\nSearching Firefox for keywords #{keywords.join ', '}"
    search_and_destroy firefox_paths, patternize(keywords)
  end

  def firefox_default_profile_path
    Dir.glob("#{user_library}/Application Support/Firefox/Profiles/*").select do |folder|
      folder[/.*\.default$/]
    end.first
  end

  def search_and_destroy paths, name_pattern
    paths.each do |path|
      next unless File.exist?(path)
      Dir.foreach(File.expand_path(path)) do |file|
        if file =~ name_pattern
          puts "\n- #{path}#{file} matches common adware naming schemes."
          print "- Delete #{file} (Y/N)? "

          answer = ''
          until answer =~ /^[n|y]$/i
            answer = gets.chomp
          end

          if answer.downcase == 'y'
            remove_file "#{File.expand_path(path)}/#{file}"
          else
            puts "!! Leaving #{path}#{file} in place !!"
          end
        end
      end
    end
  end

  def print_summary
    # Obsessive? Maybe.
    proper_length_equals_separator = "=" * (14 + @removed_components.size.to_s.length)

    puts "\n#{proper_length_equals_separator}"
    puts "Removed #{@removed_components.size} items"
    puts "#{proper_length_equals_separator}\n"
  end

  # Creates single regex to match any string from a list
  def patternize strings
    /#{strings.join('|')}/i
  end
end
