# frozen_string_literal: true

require "active_support/core_ext/class/attribute"
require "active_support/core_ext/class/subclasses"
require "active_support/core_ext/module/redefine_method"

class Class
  def class_store(*names, default: {}, instance_reader: false) # :nodoc:
    class_methods = names.map do |attr|
      class_attribute(attr, default: default, instance_reader: instance_reader,
        instance_writer: false, instance_predicate: false)

      # e.g. "_foos" => "_update_foos_with_heritable_value"
      method_name = attr.to_s.sub(/\A(_*)(.+)\z/, '\1update_\2_with_heritable_value')

      <<~RUBY
        silence_redefinition_of_method def #{method_name}(key, value, _at_root = true)
          if _at_root
            if !defined?(@_overridden_#{attr}_keys)
              self.#{attr} = #{attr}.dup
              @_overridden_#{attr}_keys = Set.new
            end
            @_overridden_#{attr}_keys << key
          end

          if _at_root || !defined?(@_overridden_#{attr}_keys) || !@_overridden_#{attr}_keys.include?(key)
            #{attr}[key] = value

            subclasses.each do |klass|
              klass.#{method_name}(key, value, false) unless klass.#{attr}.equal?(#{attr})
            end
          end

          #{attr}
        end
      RUBY
    end

    location = caller_locations(1, 1).first
    class_eval(["class << self", *class_methods, "end"].join(";").tr("\n", ";"), location.path, location.lineno)
  end
end
