# -*- coding: utf-8 -*-
module Gemirro
  ##
  # The GemsFetcher class is responsible for downloading Gems from an external
  # source.
  #
  # @!attribute [r] source
  #  @return [Source]
  # @!attribute [r] versions_file
  #  @return [Gemirro::VersionsFile]
  #
  class GemsFetcher
    attr_reader :source, :versions_file

    ##
    # @param [Source] source
    # @param [Gemirro::VersionsFile] versions_file
    #
    def initialize(source, versions_file)
      @source        = source
      @versions_file = versions_file
    end

    ##
    # Fetches the Gems.
    #
    def fetch
      @source.gems.each do |gem|
        versions_for(gem).each do |version|
          if gem.gemspec?
            gemfile = fetch_gemspec(gem, version)
            Utils.configuration.mirror_gemspecs_directory
                 .add_file(gem.gemspec_filename(version), gemfile) if gemfile
          else
            gemfile = fetch_gem(gem, version)
            Utils.configuration.mirror_gems_directory
                 .add_file(gem.filename(version), gemfile) if gemfile
          end
        end
      end
    end

    ##
    # Returns an Array containing the versions that should be fetched for a
    # Gem.
    #
    # @param [Gemirro::Gem] gem
    # @return [Array]
    #
    def versions_for(gem)
      available = @versions_file.versions_for(gem.name)
      return [available.last] if gem.only_latest?

      versions = available.select do |v|
        gem.requirement.satisfied_by?(v)
      end

      versions = [available.last] if versions.empty?

      versions
    end

    ##
    # Tries to download gemspec from a given name and version
    #
    # @param [Gemirro::Gem] gem
    # @param [Gem::Version] version
    # @return [String]
    #
    def fetch_gemspec(gem, version)
      filename = gem.gemspec_filename(version)
      puts filename.inspect
      satisfied = if gem.only_latest?
                    true
                  else
                    gem.requirement.satisfied_by?(version)
                  end

      if gemspec_exists?(filename) || !satisfied
        Utils.logger.debug("Skipping #{filename}")
        return
      end

      Utils.logger.info("Fetching #{filename}")
      fetch_from_source(filename, gem, version, true)
    end

    ##
    # Tries to download the gem file from a given nam and version
    #
    # @param [Gemirro::Gem] gem
    # @param [Gem::Version] version
    # @return [String]
    #
    def fetch_gem(gem, version)
      filename = gem.filename(version)
      satisfied = if gem.only_latest?
                    true
                  else
                    gem.requirement.satisfied_by?(version)
                  end
      name = gem.name

      if gem_exists?(filename) || ignore_gem?(name, version) || !satisfied
        Utils.logger.debug("Skipping #{filename}")
        return
      end

      Utils.configuration.ignore_gem(gem.name, version)
      Utils.logger.info("Fetching #{filename}")

      fetch_from_source(filename, gem, version)
    end

    ##
    #
    # @param [String] filename
    # @param [Gemirro::Gem] gem
    # @param [Gem::Version] version
    # @return [String]
    #
    def fetch_from_source(filename, gem, version, gemspec = false)
      data = nil
      begin
        data = @source.fetch_gem(filename) unless gemspec
        data = @source.fetch_gemspec(filename) if gemspec
      rescue => e
        filename = gem.filename(version)
        Utils.logger.error("Failed to retrieve #{filename}: #{e.message}")
        Utils.logger.debug("Adding #{filename} to the list of ignored Gems")

        Utils.configuration.ignore_gem(gem.name, version)
      end

      data
    end

    ##
    # Checks if a given Gem has already been downloaded.
    #
    # @param [String] filename
    # @return [TrueClass|FalseClass]
    #
    def gem_exists?(filename)
      Utils.configuration.mirror_gems_directory.file_exists?(filename)
    end

    ##
    # Checks if a given Gemspec has already been downloaded.
    #
    # @param [String] filename
    # @return [TrueClass|FalseClass]
    #
    def gemspec_exists?(filename)
      Utils.configuration.mirror_gemspecs_directory.file_exists?(filename)
    end

    ##
    # @see Gemirro::Configuration#ignore_gem?
    #
    def ignore_gem?(*args)
      Utils.configuration.ignore_gem?(*args)
    end
  end
end
