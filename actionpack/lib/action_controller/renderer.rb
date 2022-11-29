# frozen_string_literal: true

module ActionController
  # ActionController::Renderer allows you to render arbitrary templates without
  # being inside a controller action.
  #
  # You can get a renderer instance by calling +renderer+ on a controller class:
  #
  #   ApplicationController.renderer
  #   PostsController.renderer
  #
  # and render a template by calling the #render method:
  #
  #   ApplicationController.renderer.render template: "posts/show", assigns: { post: Post.first }
  #   PostsController.renderer.render :show, assigns: { post: Post.first }
  #
  # As a shortcut, you can also call +render+ directly on the controller class itself:
  #
  #   ApplicationController.render template: "posts/show", assigns: { post: Post.first }
  #   PostsController.render :show, assigns: { post: Post.first }
  #
  class Renderer
    attr_reader :controller

    DEFAULTS = {
      method: "get",
      script_name: "",
      input: ""
    }.freeze

    # Creates a new renderer using the given controller class. See ::new.
    def self.for(controller, env = nil, defaults = DEFAULTS)
      new(controller, env, defaults)
    end

    # Creates a new renderer using the same controller, but with a new Rack env.
    #
    #   ApplicationController.renderer.new(method: "post")
    #
    def new(env = nil)
      self.class.new controller, env, @defaults
    end

    # Creates a new renderer using the same controller, but with the given
    # defaults merged on top of the previous defaults.
    def with_defaults(defaults)
      self.class.new controller, @env, @defaults.merge(defaults)
    end

    # Initializes a new Renderer.
    #
    # ==== Parameters
    #
    # * +controller+ - The controller class to instantiate for rendering.
    # * +env+ - The Rack env to use for mocking a request when rendering.
    #   Entries can be typical Rack env keys and values, or they can be any of
    #   the following, which will be converted appropriately:
    #   * +:http_host+ - The HTTP host for the incoming request. Converts to
    #     Rack's +HTTP_HOST+.
    #   * +:https+ - Boolean indicating whether the incoming request uses HTTPS.
    #     Converts to Rack's +HTTPS+.
    #   * +:method+ - The HTTP method for the incoming request, case-insensitive.
    #     Converts to Rack's +REQUEST_METHOD+.
    #   * +:script_name+ - The portion of the incoming request's URL path that
    #     corresponds to the application. Converts to Rack's +SCRIPT_NAME+.
    #   * +:input+ - The input stream. Converts to Rack's +rack.input+.
    # * +defaults+ - Default values for the Rack env. Entries are specified in
    #   the same format as +env+. +env+ will be merged on top of these values.
    #   +defaults+ will be retained when calling #new on a renderer instance.
    #
    # If no HTTP host is specified, the HTTP host will be derived from the
    # routes' +default_url_options+ (which can be configured via
    # +Rails.application.default_url_options+). In this case, the +https+
    # boolean will be derived from +ActionDispatch::Http::URL.secure_protocol+
    # (which can be configured via +Rails.application.config.force_ssl+). If an
    # HTTP host cannot be derived, it will default to <tt>"example.org"</tt>.
    def initialize(controller, env, defaults)
      @controller = controller
      @defaults = defaults
      if env.blank? && @defaults == DEFAULTS
        @env = nil
      else
        @env = normalize_env(@defaults)
        @env.merge!(normalize_env(env)) unless env.blank?
      end
    end

    def defaults # :nodoc:
      @defaults = @defaults.dup if @defaults.frozen?
      @defaults
    end
    # :attr_reader: defaults

    # Render templates with any options from ActionController::Base#render_to_string.
    #
    # The primary options are:
    # * <tt>:partial</tt> - See ActionView::PartialRenderer for details.
    # * <tt>:file</tt> - Renders an explicit template file. Add <tt>:locals</tt> to pass in, if so desired.
    #   It shouldn’t be used directly with unsanitized user input due to lack of validation.
    # * <tt>:inline</tt> - Renders an ERB template string.
    # * <tt>:plain</tt> - Renders provided text and sets the content type as <tt>text/plain</tt>.
    # * <tt>:html</tt> - Renders the provided HTML safe string, otherwise
    #   performs HTML escape on the string first. Sets the content type as <tt>text/html</tt>.
    # * <tt>:json</tt> - Renders the provided hash or object in JSON. You don't
    #   need to call <tt>.to_json</tt> on the object you want to render.
    # * <tt>:body</tt> - Renders provided text and sets content type of <tt>text/plain</tt>.
    # * <tt>:status</tt> - Specifies the HTTP status code to send with the response. Defaults to 200.
    #
    # If no <tt>options</tt> hash is passed or if <tt>:update</tt> is specified, then:
    #
    # If an object responding to +render_in+ is passed, +render_in+ is called on the object,
    # passing in the current view context.
    #
    # Otherwise, a partial is rendered using the second parameter as the locals hash.
    def render(*args)
      raise "missing controller" unless controller

      # request = ActionDispatch::Request.new((@env || DEFAULT_ENV).dup)
      request = ActionDispatch::Request.new(env.dup)
      request.routes = controller._routes

      instance = controller.new
      instance.set_request! request
      instance.set_response! controller.make_response!(request)
      instance.render_to_string(*args)
    end
    alias_method :render_to_string, :render # :nodoc:

    private
      def self.normalize_env(env)
        new_env = {}

        env.each_pair do |key, value|
          case key
          when :https
            value = value ? "on" : "off"
          when :method
            value = -value.upcase
          end

          key = RACK_KEY_TRANSLATION[key] || key.to_s

          new_env[key] = value
        end

        new_env["rack.url_scheme"] = new_env["HTTPS"] == "on" ? "https" : "http"

        new_env
      end

      RACK_KEY_TRANSLATION = {
        http_host:   "HTTP_HOST",
        https:       "HTTPS",
        method:      "REQUEST_METHOD",
        script_name: "SCRIPT_NAME",
        input:       "rack.input"
      }

      DEFAULT_ENV = normalize_env(DEFAULTS).freeze # :nodoc:
      DEFAULT_ENV_FOR_URL_OPTIONS = Concurrent::Map.new # :nodoc:

      delegate :normalize_env, to: :class

      def url_options
        # TODO no slice
        controller._routes.default_url_options.slice(:protocol, :host, :port)
      end

      def update_env_with_url_options(env, url_options)
        if url_options[:host]
          protocol, host = ActionDispatch::Http::URL.url_for(url_options).split("://", 2)
          env["HTTP_HOST"] = host
          env["HTTPS"] = protocol == "https" ? "on" : "off"
        else
          env["HTTP_HOST"] = "example.org"
          env["HTTPS"] = "off"
        end

        env
      end

      def env # TODO rename
        if @env.nil?
          @env = DEFAULT_ENV_FOR_URL_OPTIONS.fetch_or_store(url_options) do |url_options|
            update_env_with_url_options(DEFAULT_ENV.dup, url_options).freeze
          end
        elsif !@env.key?("HTTP_HOST")
          @env = update_env_with_url_options(@env, url_options)
        end

        @env
      end
  end
end
