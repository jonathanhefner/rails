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
      @attributes_by_class = {}
      @associations_by_class = {}
    end

    def encode(input)
      if input.is_a?(Array)
        input.map { |record| encode_record(record) }
      elsif input
        encode_record(input)
      end
    end

    def decode(encoded)
      if encoded_array?(encoded)
        encoded.map { |encoded_record| decode_record(encoded_record) }
      elsif encoded
        decode_record(encoded)
      end
    end

    def encode_record(record)
      @mappings.fetch(record) do
        encoded = begin_encode(record.class)
        @mappings[record] = @mappings.size
        push_cached_associations(encoded, record)
        push_record_state(encoded, record)
        encoded
      end
    end

    def decode_record(encoded_or_id)
      @mappings.fetch(encoded_or_id) do
        encoded = encoded_or_id.dup
        klass = begin_decode(encoded)
        @mappings[@mappings.size] = record = klass.allocate
        pop_record_state(encoded, record)
        pop_cached_associations(encoded, record)
        record
      end
    end

    def begin_encode(klass)
      Array(@mappings.fetch(klass) do
        @mappings[klass] = @mappings.size
        attributes = @attributes_by_class[klass] = klass.attribute_names
        associations = @associations_by_class[klass] = klass.reflect_on_all_associations.map!(&:name)
        [klass.name, attributes, associations]
      end)
    end

    def begin_decode(encoded)
      @mappings.fetch(encoded[0]) do
        klass = @mappings[@mappings.size] = Object.const_get(encoded[0])
        @attributes_by_class[klass] = encoded[1]
        @associations_by_class[klass] = encoded[2]
        klass
      end
    end

    def push_record_state(encoded, record)
      encoded << record.new_record?
      # @attributes_by_class[record.class].each do |name|
      @attributes_by_class[record.class].reverse_each do |name|
        value = record.read_attribute_for_database(name)
        value = value.to_s if value.is_a?(::ActiveModel::Type::Binary::Data) # TODO...
        encoded << value
      end
    end

    def pop_record_state(encoded, record)
      # names = @attributes_by_class[record.class]
      # attributes_hash = names.zip(encoded.pop(names.length)).to_h
      attributes_hash = @attributes_by_class[record.class].to_h { |name| [name, encoded.pop] }
      attributes = record.class.attributes_builder.build_from_database(attributes_hash)
      record.init_with_attributes(attributes, encoded.pop)
    end


    def push_cached_associations(encoded, record)
      @associations_by_class[record.class].each do |name|
        encoded << if record.association_cached?(name)
          encode(record.association(name).target)
        end
      end
    end

    def pop_cached_associations(encoded, record)
      names = @associations_by_class[record.class]
      names.zip(encoded.pop(names.length)) do |name, target|
        target = decode(target)
        record.association(name).target = target if target
      rescue ActiveRecord::AssociationNotFoundError
        # The association no longer exists, so just skip it.
      end
    end

    def encoded_array?(encoded)
      encoded.is_a?(Array) && (encoded.empty? || encoded[0].is_a?(Array))
    end
  end
end
