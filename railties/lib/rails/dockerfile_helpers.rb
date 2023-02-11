# frozen_string_literal: true

require "active_support/core_ext/enumerable"

module Rails
  module DockerfileHelpers
    def render(template_path)
      ERB.new(Rails.root.join(template_path).read, trim_mode: "-").result(binding)
    end

    def install_packages(*packages, skip_recommends: false)
      run apt_install(packages, skip_recommends: skip_recommends),
          mounts: mounts(:cache, ["/var/cache/apt", "/var/lib/apt"], sharing: "locked")
    end

    def install_gems(without: nil)
      run ("bundle config set --local without #{Array(without).join(" ").inspect}" if without),
          "gem update --system --no-document",
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


    def api_only?
      Rails.application.config.api_only
    end

    def gem?(name, *requirements)
      @gems ||= Bundler.definition.specs_for(Rails.groups).index_by(&:name)
      @gems[name] && version_requirement(*requirements).satisfied_by?(@gems[name].version)
    end

    def node?
      @node = Rails.root.join("package.json").exist? unless defined?(@node)
      @node
    end

    # Returns true if Ruby is currently running on the Windows operating system.
    def windows?
      Gem.win_platform?
    end


    def ruby_version
      @ruby_version ||= Gem.ruby_version.to_s.gsub(/\.([^0-9])/, '-\1')
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


    def runtime_packages
      [
        *runtime_db_packages,
        *rails_packages,
      ]
    end

    def runtime_db_packages(mysql: true, postgresql: true, redis: true, sqlite: true)
      [
        *("default-mysql-client" if mysql),
        *("postgresql-client" if postgresql),
        *("redis" if redis),
        *("libsqlite3-0" if sqlite),
      ]
    end

    def buildtime_packages
      [
        "build-essential",
        "git",
        *buildtime_db_packages,
        *rails_packages,
        *(node_packages if node?),
      ]
    end

    def buildtime_db_packages(mysql: true, postgresql: true, redis: true, sqlite: true)
      [
        "pkg-config",
        *("default-libmysqlclient-dev" if mysql),
        *("libpq-dev" if postgresql),
        *("redis" if redis),
      ]
    end

    def rails_packages(active_storage: gem?("activestorage"))
      [
        *("libvips" if active_storage),
      ]
    end

    def node_packages
      [
        "pkg-config",
        "curl",
        "node-gyp",
        targeting_debian_bullseye? ? "python-is-python3" : "python",
      ]
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

      def version_requirement(...)
        Gem::Requirement.create(...)
      end

      def targeting_debian_bullseye?
        version_requirement(">= 3.0.2").satisfied_by?(Gem.ruby_version) ||
          version_requirement("~> 2.7.4").satisfied_by?(Gem.ruby_version)
      end
  end
end
