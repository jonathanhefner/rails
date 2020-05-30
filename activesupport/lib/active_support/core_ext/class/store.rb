# frozen_string_literal: true

require "active_support/core_ext/class/attribute"
require "active_support/core_ext/class/subclasses"
require "active_support/core_ext/module/redefine_method"
require "active_support/core_ext/object/try"

class Class
  def class_store(*names, default: {}, instance_reader: false) # :nodoc:
    class_methods = names.map do |attr|
      class_attribute(attr, default: default, instance_reader: instance_reader,
        instance_writer: false, instance_predicate: false)

      store_method_name = attr.to_s.sub(/^(_*)/, '\1store_') # e.g. "_foos" => "_store_foos"

      <<~RUBY
        silence_redefinition_of_method def #{store_method_name}(values_hash)
          if #{attr}.equal?(superclass.try(:#{attr}))
            self.#{attr} = #{attr}.dup
          end

          values_hash.each do |key, value|
            _propagate_#{attr}_value(key, value, true)
          end

          #{attr}
        end

        silence_redefinition_of_method def _propagate_#{attr}_value(key, value, at_root)
          (@_overridden_#{attr}_keys ||= Set.new) << key if at_root

          if at_root || !defined?(@_overridden_#{attr}_keys) || !@_overridden_#{attr}_keys.include?(key)
            #{attr}[key] = value

            subclasses.each do |klass|
              klass._propagate_#{attr}_value(key, value, false) unless klass.#{attr}.equal?(#{attr})
            end
          end
        end
      RUBY
    end

    location = caller_locations(1, 1).first
    class_eval(["class << self", *class_methods, "end"].join(";").tr("\n", ";"), location.path, location.lineno)
  end
end
