# frozen_string_literal: true

$t = <<~ERB
<hr>
<%= method(:url_options).inspect %><br>
<%= url_options.inspect %>
<hr>
<%= method(:default_url_options).inspect %><br>
<%= default_url_options.inspect %>
<hr>
<%= method(:url_for).inspect %><br>
<%= method(:posts_url).inspect %><br>
<%= posts_url %>
<hr>
ERB

module ActionController
  # ActionController::Renderer allows you to render arbitrary templates
  # without requirement of being in controller actions.
  #
  # You get a concrete renderer class by invoking ActionController::Base#renderer.
  # For example:
  #
  #   ApplicationController.renderer
  #
  # It allows you to call method #render directly.
  #
  #   ApplicationController.renderer.render template: '...'
  #
  # You can use this shortcut in a controller, instead of the previous example:
  #
  #   ApplicationController.render template: '...'
  #
  # #render allows you to use the same options that you can use when rendering in a controller.
  # For example:
  #
  #   FooController.render :action, locals: { ... }, assigns: { ... }
  #
  # The template will be rendered in a Rack environment which is accessible through
  # ActionController::Renderer#env. You can set it up in two ways:
  #
  # *  by changing renderer defaults, like
  #
  #       ApplicationController.renderer.defaults # => hash with default Rack environment
  #
  # *  by initializing an instance of renderer by passing it a custom environment.
  #
  #       ApplicationController.renderer.new(method: 'post', https: true)
  #
  class Renderer
    attr_reader :controller

    DEFAULTS = {
      method: "get",
      script_name: "",
      input: ""
    }.freeze

    # Create a new renderer instance for a specific controller class.
    def self.for(controller, env = nil, defaults = DEFAULTS)
      # pp [controller, controller.method(:_routes), controller._routes]
      new(controller, env, defaults)
    end

    # Create a new renderer for the same controller but with a new env.
    def new(env = nil)
      self.class.new controller, env, defaults
    end

    # Create a new renderer for the same controller but with new defaults.
    def with_defaults(defaults)
      self.class.new controller, @env, self.defaults.merge(defaults)
    end

    # Accepts a custom Rack environment to render templates in.
    # It will be merged with the default Rack environment defined by
    # +ActionController::Renderer::DEFAULTS+.
    def initialize(controller, env, defaults)
      @controller = controller
      @defaults = defaults
      if env.blank? && @defaults == DEFAULTS
        @env = nil
      else
        @env = self.class.normalize_env(@defaults)
        @env.merge!(self.class.normalize_env(env)) unless env.blank?
      end
    end

    def defaults
      @defaults = @defaults.dup if @defaults.frozen?
      @defaults
    end

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
      request = ActionDispatch::Request.new(env.dup)
      request.routes = controller._routes

      instance = controller.new
      instance.set_request! request
      instance.set_response! controller.make_response!(request)

      instance.render_to_string(*args)
    end
    alias_method :render_to_string, :render # :nodoc:

    private
      class << self
        # def update_env_with_url_options(env, url_options)
        #   if url_options[:host]
        #     protocol, host = ActionDispatch::Http::URL.url_for(url_options).split("://", 2)
        #     env[rack_key_for(:http_host)] = host
        #     env[rack_key_for(:https)] = rack_value_for(:https, protocol == "https")
        #   else
        #     env[rack_key_for(:http_host)] = "example.org"
        #     env[rack_key_for(:https)] = rack_value_for(:https, false)
        #   end

        #   env
        # end

        # def normalize_keys(env)
        #   new_env = {}
        #   env.each_pair { |k, v| new_env[rack_key_for(k)] = rack_value_for(k, v) }
        #   new_env["rack.url_scheme"] = new_env["HTTPS"] == "on" ? "https" : "http"
        #   new_env
        # end

        # def rack_key_for(key)
        #   RACK_KEY_TRANSLATION[key] || key.to_s
        # end

        # def rack_value_for(key, value)
        #   case key
        #   when :https
        #     value ? "on" : "off"
        #   when :method
        #     -value.upcase
        #   else
        #     value
        #   end
        # end

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

        def normalize_env(env)
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
      end

      RACK_KEY_TRANSLATION = {
        http_host:   "HTTP_HOST",
        https:       "HTTPS",
        method:      "REQUEST_METHOD",
        script_name: "SCRIPT_NAME",
        input:       "rack.input",
      }

      DEFAULT_ENV = normalize_env(DEFAULTS).freeze # :nodoc:

      DEFAULT_ENV_FOR_URL_OPTIONS = Hash.new do |h, url_options| # :nodoc:
        h[url_options] = update_env_with_url_options(DEFAULT_ENV.dup, url_options).freeze
      end

      def url_options
        controller._routes.default_url_options.slice(:protocol, :host, :port)
      end

      ###

      # def new_request
      #   env =
      #     if @env.nil?
      #       DEFAULT_ENV_FOR_URL_OPTIONS[url_options].dup
      #     elsif !@env.key?("HTTP_HOST")
      #       self.class.update_env_with_url_options(@env, url_options)
      #     else
      #       @env
      #     end

      #   request = ActionDispatch::Request.new(env)
      #   request.routes = controller._routes
      #   request
      # end

      ###

      def env
        if @env.nil?
          @env = DEFAULT_ENV_FOR_URL_OPTIONS[url_options]
        elsif !@env.key?("HTTP_HOST")
          @env = self.class.update_env_with_url_options(@env, url_options)
        end

        @env
      end

      ###

      # def update_env_with_url_options!
      #   @env_url_options ||= nil
      #   url_options = self.url_options

      #   if @env_url_options != url_options
      #     self.class.update_env_with_url_options(@env, url_options)
      #     @env_url_options = url_options
      #   end
      # end

      # def env
      #   if @env.nil?
      #     @env = DEFAULT_ENV_FOR_URL_OPTIONS[url_options]
      #   else
      #     update_env_with_url_options! unless @defaults[:http_host] # TODO unless frozen...
      #     @env
      #   end
      # end
  end
end
