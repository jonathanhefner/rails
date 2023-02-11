# frozen_string_literal: true

require "shellwords"
require "active_support/core_ext/object/with_options"

module Rails
  module DockerfileHelpers
    def render(template_path)
      ERB.new(Rails.root.join(template_path).read, trim_mode: "-").result(binding)
    end

    def setup(user:, workdir:)
      <<~DOCKERFILE.strip
        #{self.user user}

        #{self.workdir workdir}

        ENV RAILS_ENV=#{Rails.env}
      DOCKERFILE
    end

    def user(name)
      <<~DOCKERFILE.strip
        ARG USER=#{name}
        RUN useradd $USER
        USER $USER:$USER
      DOCKERFILE
    end

    def workdir(path)
      <<~DOCKERFILE.strip
        ARG WORKDIR=#{path.inspect}
        WORKDIR $WORKDIR
      DOCKERFILE
    end

    def install_packages(*packages, deploy: false, **options)
      if packages.empty?
        packages = all_packages(deploy: deploy, **options)
      else
        packages = packages.flatten.compact
      end
      packages.sort!.uniq!

      run "apt-get update -qq",
          "apt-get install#{" --no-install-recommends" if deploy} -y #{packages.join(" ")}",
          ("rm -rf /var/lib/apt/lists /var/cache/apt/archives" if deploy)
    end

    def install_node(node_version: self.node_version, yarn_version: self.yarn_version)
      <<~DOCKERFILE.strip
        ARG NODE_VERSION=#{node_version}
        ARG YARN_VERSION=#{yarn_version}
        ENV VOLTA_HOME="/usr/local"
        #{run "curl https://get.volta.sh | bash",
              "volta install node@$NODE_VERSION yarn@$YARN_VERSION"}
      DOCKERFILE
    end

    def install_node_modules
      <<~DOCKERFILE.strip
        COPY package.json yarn.lock .
        #{run "yarn install"}
      DOCKERFILE
    end

    def install_gems
      <<~DOCKERFILE.strip
        COPY Gemfile Gemfile.lock .
        #{run "bundle install",
              ("bundle exec bootsnap precompile --gemfile" if bootsnap?)}
      DOCKERFILE
    end

    def prepare_app(*run_additional, change_binstubs: windows?, precompile_assets: !api_only?)
      <<~DOCKERFILE.strip
        COPY . .
        #{run ("bundle exec bootsnap precompile app/ lib/" if bootsnap?),
              ("bundle exec rails binstubs:change" if change_binstubs),
              ("SECRET_KEY_BASE_DUMMY=1 bin/rails assets:precompile" if precompile_assets),
              *run_additional}
      DOCKERFILE
    end

    def copy_artifacts(*artifacts, from:)
      if artifacts.empty?
        artifacts = ["/usr/local/bundle", "$WORKDIR"]
      else
        artifacts = artifacts.flatten.compact.uniq
      end

      artifacts.map do |artifact|
        "COPY --from=#{from} --chown=$USER:$USER #{artifact} #{artifact}"
      end.join("\n")
    end

    def expose_server(entrypoint: "bin/docker-entrypoint", cmd: "bin/rails server", port: 3000)
      <<~DOCKERFILE.strip
        ENTRYPOINT #{Shellwords.split entrypoint}
        CMD #{Shellwords.split cmd}
        EXPOSE #{port}
      DOCKERFILE
    end


    def all_packages(node: node?, **options)
      with_options(node: node, **options) do
        [*essential_packages, *db_packages, *rails_packages, *(node_packages if node)]
      end
    end

    def essential_packages(deploy: false, **)
      if deploy
        []
      else
        %w[build-essential git]
      end
    end

    def db_packages(deploy: false, **)
      if deploy
        %w[libsqlite3-0 postgresql-client default-mysql-client redis]
      else
        %w[pkg-config libpq-dev default-libmysqlclient-dev redis]
      end
    end

    def rails_packages(active_storage: active_storage?, **)
      [*(%w[libvips] if active_storage)]
    end

    def node_packages(deploy: false, **)
      if deploy
        []
      else
        %w[pkg-config curl node-gyp] + [targeting_debian_bullseye? ? "python-is-python3" : "python"]
      end
    end


    def ruby_version
      @ruby_version ||= Gem.ruby_version
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

    private
      def run(*commands)
        commands = commands.flatten.compact
        "RUN #{commands.join(" && \\\n    ")}" unless commands.empty?
      end

      def targeting_debian_bullseye?
        ruby_version >= "3.0.2" || (ruby_version < "3" && ruby_version >= "2.7.4")
      end
  end
end
