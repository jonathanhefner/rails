# frozen_string_literal: true

require "active_support/core_ext/enumerable"

module Rails
  module DockerfileHelpers
    GEM_RUNTIME_PACKAGES = {
      "mysql2" => %w[default-mysql-client],
      "pg" => %w[postgresql-client],
      "redis" => %w[redis],
      "ruby-vips" => %w[libvips],
      "sqlite3" => %w[libsqlite3-0],
    }

    GEM_BUILDTIME_PACKAGES = GEM_RUNTIME_PACKAGES.merge(
      "mysql2" => %w[pkg-config default-libmysqlclient-dev],
      "pg" => %w[pkg-config libpq-dev],
    )

    def gem?(name)
      gem_specs[name]
    end

    # Returns true if Ruby is currently running on the Windows operating system.
    def windows?
      Gem.win_platform?
    end

    def node?
      @node = Rails.root.join("package.json").exist? unless defined?(@node)
      @node
    end

    def api_only?
      Rails.application.config.api_only
    end


    def ruby_version
      Gem.ruby_version.to_s.gsub(/\.([^0-9])/, '-\1')
    end

    def node_version
      @node_version ||= begin
        `node --version`[/\d+\.\d+\.\d+/] if node?
      rescue Errno::ENOENT
        "lts"
      end
    end

    def yarn_version
      @yarn_version ||= begin
        `yarn --version`[/\d+\.\d+\.\d+/] if node?
      rescue Errno::ENOENT
        "latest"
      end
    end


    def render(template_path)
      ERB.new(Rails.root.join(template_path).read, trim_mode: "-").result(binding)
    end

    def install_packages(*packages, skip_recommends: false)
      run apt_install(packages, skip_recommends: skip_recommends),
          mounts: mounts(:cache, ["/var/cache/apt", "/var/lib/apt"], sharing: "locked")
    end

    def install_gems
      without = (Bundler.definition.groups - gem_groups).sort.join(":")
      run "gem update --system --no-document",
          ("bundle config set --local without #{without.inspect}" unless without.empty?),
          "BUNDLE_CACHE_ALL=1 bundle cache",
          "bundle config set --local path vendor/bundle",
          "BUNDLE_CACHE_PATH=#{gem_home}/cache bundle install --prefer-local --no-cache",
          ("bundle exec bootsnap precompile --gemfile" if gem?("bootsnap")),
          mounts: mounts(:cache, [gem_home], sharing: "locked")
    end

    def install_node
      <<~DOCKERFILE.strip
        ENV VOLTA_HOME=/usr/local
        #{run "curl https://get.volta.sh | bash",
              "volta install node@#{node_version} yarn@#{yarn_version}"}
      DOCKERFILE
    end

    def install_node_modules
      run "yarn install"
    end

    def prepare_app(*run_additional, change_binstubs: windows?, precompile_assets: !api_only?)
      <<~DOCKERFILE.strip
        ENV RAILS_ENV=production
        #{run ("bundle exec bootsnap precompile app/ lib/" if gem?("bootsnap")),
              ("bundle exec rails binstubs:change" if change_binstubs),
              ("SECRET_KEY_BASE_DUMMY=1 bin/rails assets:precompile" if precompile_assets),
              *run_additional,
              mounts: mounts(:cache, ["tmp/cache/assets"], uid: 1000, gid: 1000)}
      DOCKERFILE
    end


    def runtime_packages
      GEM_RUNTIME_PACKAGES.slice(*gem_specs.keys).values.flatten
    end

    def buildtime_packages(node: node?)
      gem_packages = GEM_BUILDTIME_PACKAGES.slice(*gem_specs.keys).values.flatten
      ["build-essential", "git", *gem_packages, *(node_packages if node)]
    end

    private
      def run(*commands, mounts: nil)
        commands = commands.flatten.compact
        unless commands.empty?
          "RUN #{[*mounts, commands.join(" && \\\n    ")].join(" \\\n    ")}"
        end
      end

      def mounts(type, targets, **options)
        option_strings = options.compact.map { |key, value| "#{key}=#{value}" }
        targets.map { |target| ["--mount=type=#{type},target=#{target}", *option_strings].join(",") }
      end

      def apt_install(*packages, skip_recommends: false)
        packages = packages.flatten.compact.sort.uniq

        [
          "apt-get update -qq",
          "apt-get install#{" --no-install-recommends" if skip_recommends} -y #{packages.join(" ")}",
        ]
      end

      def gem_home
        "/usr/local/bundle"
      end

      def gem_groups
        (RequiredGemGroupsTracker.groups || Rails.groups).map(&:to_sym).uniq
      end

      def gem_specs
        @gem_specs ||= Bundler.definition.specs_for(gem_groups).index_by(&:name)
      end

      def node_packages
        [
          "pkg-config",
          "curl",
          "node-gyp",
          targeting_debian_bullseye? ? "python-is-python3" : "python",
        ]
      end

      def targeting_debian_bullseye?
        Gem::Requirement.create(">= 3.0.2").satisfied_by?(Gem.ruby_version) ||
          Gem::Requirement.create("~> 2.7.4").satisfied_by?(Gem.ruby_version)
      end

      module RequiredGemGroupsTracker # :nodoc:
        singleton_class.attr_accessor :groups

        def require(*groups, **)
          (RequiredGemGroupsTracker.groups ||= []).concat(groups)
          super
        end

        Bundler.singleton_class.prepend self
      end
  end
end
