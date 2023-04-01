# frozen_string_literal: true

module ActiveRecord
  class CachePreserializer # :nodoc:
    FORMAT_VERSION = 1

    class << self
      def encode(input)
        [FORMAT_VERSION, self.new.encode(input)]
      end
      alias :dump :encode

      def decode(encoded)
        raise "Invalid format version" unless encoded[0] == FORMAT_VERSION
        self.new.decode(encoded[1])
      end
      alias :load :decode
    end

    def initialize
      @mappings = {}.compare_by_identity
      @signatures = {}
    end

    def encode(input)
      if input.is_a?(Array)
        input.map { |record| encode_record(record) }
      elsif input
        encode_record(input)
      end
    end

    def decode(encoded)
      if encoded_record?(encoded)
        decode_record(encoded)
      elsif encoded
        encoded.map { |encoded_record| decode_record(encoded_record) }
      end
    end

    def encode_record(record)
      @mappings.fetch(record) do
        encoded = [encode_class(record.class)]
        @mappings[record] = @mappings.size
        push_cached_associations(encoded, record)
        push_record_state(encoded, record)
        encoded
      end
    end

    def decode_record(encoded_or_id)
      @mappings.fetch(encoded_or_id) do
        encoded = encoded_or_id.dup
        klass = decode_class(encoded[0])
        @mappings[@mappings.size] = record = klass.allocate
        pop_record_state(encoded, record)
        pop_cached_associations(encoded, record)
        record
      end
    end

    def encode_class(klass)
      @mappings.fetch(klass) do
        serial_id = @mappings[klass] = @mappings.size

        @signatures[serial_id] = [
          klass.name,
          klass.attribute_names,
          klass.reflect_on_all_associations.map!(&:name),
        ]
      end
    end

    def decode_class(signature_or_id)
      @mappings.fetch(signature_or_id) do
        class_name = signature_or_id[0]
        @mappings[@mappings.size] = Object.const_get(class_name)
      end
    end

    def push_record_state(encoded, record)
      encoded << record.new_record?
      encoded_attribute_names(encoded).reverse_each do |name|
        value = record.read_attribute_for_database(name)
        encoded << (value.is_a?(::ActiveModel::Type::Binary::Data) ? value.to_s : value) # TODO...
      end
    end

    def pop_record_state(encoded, record)
      attributes_hash = encoded_attribute_names(encoded).to_h { |name| [name, encoded.pop] }
      attributes = record.class.attributes_builder.build_from_database(attributes_hash)
      record.init_with_attributes(attributes, encoded.pop)
    end

    def push_cached_associations(encoded, record)
      encoded_association_names(encoded).each do |name|
        encoded << if record.association_cached?(name)
          encode(record.association(name).target)
        end
      end
    end

    def pop_cached_associations(encoded, record)
      names = encoded_association_names(encoded)
      names.zip(encoded.pop(names.length)) do |name, target|
        target = decode(target)
        record.association(name).target = target if target
      rescue ActiveRecord::AssociationNotFoundError
        # The association no longer exists, so just skip it.
      end
    end

    def encoded_record?(encoded)
      encoded&.dig(0, 0).is_a?(String)
    end

    def encoded_attribute_names(encoded_record)
      @signatures.fetch(encoded_record[0], encoded_record[0])[1]
    end

    def encoded_association_names(encoded_record)
      @signatures.fetch(encoded_record[0], encoded_record[0])[2]
    end
  end
end
