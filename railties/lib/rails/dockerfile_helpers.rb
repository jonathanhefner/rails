# frozen_string_literal: true

require "shellwords"
require "active_support/core_ext/object/with_options"

module Rails
  module DockerfileHelpers
    def render(template_path)
      ERB.new(Rails.root.join(template_path).read, trim_mode: "-").result(binding)
    end

    def initial_stage(name = "initial", base: "ruby:#{ruby_version}-slim", platform: nil)
      stage from: base, platform: platform, as: name do
        "ENV BUNDLE_APP_CONFIG=.bundle"
      end
    end

    def runtime_packages_stage(name = "runtime_packages", base: "initial", plus: [])
      stage from: base, as: name do
        install_packages runtime_packages + plus, skip_recommends: true
      end
    end

    def buildtime_packages_stage(name = "buildtime_packages", base: "runtime_packages", plus: [])
      stage from: base, as: name do
        install_packages buildtime_packages + plus
      end
    end

    def gems_stage(name = "gems", base: "buildtime_packages", bundle_without: %w[development])
      stage from: base, as: name do
        ["WORKDIR staged", copy(%w[Gemfile Gemfile.lock]), install_gems(without: bundle_without)]
      end
    end

    def node_modules_stage(name = "node_modules", base: "buildtime_packages")
      stage from: base, as: name do
        [install_node, "", "WORKDIR staged", copy(%w[package.json yarn.lock]), install_node_modules]
      end
    end

    def final_stage(base: "runtime_packages", user: nil, workdir:, gems_stage: "gems", node_modules_stage: "node_modules")
      user_id = "1000:1000" if user

      stage from: base do
        [
          (["RUN useradd #{user}", "USER #{user_id}", ""] if user),
          "WORKDIR #{workdir}", "",
          copy("staged", from: gems_stage, chown: user_id),
          (copy("staged", from: node_modules_stage, chown: user_id) if node?),
          copy(".", chown: user_id),
        ]
      end
    end


    def install_packages(*packages, skip_recommends: false, cache: true)
      run apt_install(packages, skip_recommends: skip_recommends),
          mounts: (mounts(:cache, ["/var/cache/apt", "/var/lib/apt"], sharing: "locked") if cache)
    end

    def install_gems(without: nil)
      run ("bundle config set --local without #{Array(without).join(" ").inspect}" if without),
          "gem update --system --no-document",
          "BUNDLE_CACHE_ALL=1 bundle cache",
          "bundle config set --local path vendor/bundle",
          "BUNDLE_CACHE_PATH=#{gem_home}/cache bundle install --prefer-local --no-cache",
          ("bundle exec bootsnap precompile --gemfile" if bootsnap?),
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

    def prepare_app(*run_additional, change_binstubs: windows?, precompile_assets: !api_only?, uid: 1000, gid: uid)
      <<~DOCKERFILE.strip
        ENV RAILS_ENV=production
        #{run ("bundle exec bootsnap precompile app/ lib/" if bootsnap?),
              ("bundle exec rails binstubs:change" if change_binstubs),
              ("SECRET_KEY_BASE_DUMMY=1 bin/rails assets:precompile" if precompile_assets),
              *run_additional,
              mounts: mounts(:cache, ["tmp/cache/assets"], uid: uid, gid: gid)}
      DOCKERFILE
    end

    def expose_server(entrypoint: "bin/docker-entrypoint", cmd: "bin/rails server", port: 3000)
      cmd += " --port=#{port}" unless port.to_s == "3000"

      <<~DOCKERFILE.strip
        ENTRYPOINT #{Shellwords.split entrypoint}
        CMD #{Shellwords.split cmd}
        EXPOSE #{port}
      DOCKERFILE
    end


    def active_storage?
      defined?(ActiveStorage::Engine)
    end

    def bootsnap?
      defined?(Bootsnap)
    end

    def api_only?
      Rails.application.config.api_only
    end

    def node?
      @node = Rails.root.join("package.json").exist? unless defined?(@node)
      @node
    end

    def windows?
      Gem.win_platform?
    end


    def ruby_version
      @ruby_version ||= Gem::Version.new(Gem.ruby_version.segments[0, 3].join("."))
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
        *rails_packages
      ]
    end

    def runtime_db_packages(sqlite: true, postgresql: true, mysql: true, redis: true)
      [
        *("libsqlite3-0" if sqlite),
        *("postgresql-client" if postgresql),
        *("default-mysql-client" if mysql),
        *("redis" if redis),
      ]
    end

    def buildtime_packages
      [
        "build-essential",
        "git",
        *buildtime_db_packages,
        *rails_packages,
        *(node_packages if node?)
      ]
    end

    def buildtime_db_packages(sqlite: true, postgresql: true, mysql: true, redis: true)
      [
        "pkg-config",
        *("libpq-dev" if postgresql),
        *("default-libmysqlclient-dev" if mysql),
        *("redis" if redis),
      ]
    end

    def rails_packages(active_storage: active_storage?)
      [
        *("libvips" if active_storage),
      ]
    end

    def node_packages
      [
        "pkg-config",
        "curl",
        "node-gyp",
        targeting_debian_bullseye? ? "python-is-python3" : "python"
      ]
    end

    private
      def stage(from:, platform: nil, as: nil, &block)
        content = Array(block.call).compact.join("\n").presence

        [ "FROM #{from}", ("--platform=#{platform}" if platform), (" as #{as}" if as),
          ("\n\n" if content),
          content
        ].compact.join
      end

      def run(*commands, mounts: nil)
        commands = commands.flatten.compact
        unless commands.empty?
          "RUN #{[*mounts, commands.join(" && \\\n    ")].join(" \\\n    ")}"
        end
      end

      def copy(srcs, dst = ".", from: nil, chown: nil)
        ["COPY", *("--from=#{from}" if from), *("--chown=#{chown}" if chown), *srcs, dst].join(" ")
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

      def targeting_debian_bullseye?
        ruby_version >= "3.0.2" || (ruby_version < "3" && ruby_version >= "2.7.4")
      end
  end
end
