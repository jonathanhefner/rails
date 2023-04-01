# frozen_string_literal: true

module ActiveRecord
  class CachePreserializer # :nodoc:
    def encode_record(record)
      @mappings.fetch(record) do
        signature = encode_class(record.class)
        @mappings[record] = @mappings.size
        record_state = encode_record_state(record, signature)
        record_associations = encode_record_associations(record, signature)
        [signature, record_state, *record_associations]
      end
    end

    def decode_record(encoded)
      @mappings.fetch(encoded) do
        signature, record_state, *record_associations = encoded
        klass = decode_class(signature)
        @mappings[@mappings.size] = record = klass.allocate
        decode_record_state(record, signature, record_state)
        decode_record_associations(record, signature, record_associations)
        record
      end
    end

    def encode_record_state(record, signature)
      attribute_names_in_signature(signature).map do |name|
        value = record.read_attribute_for_database(name)
        value.is_a?(::ActiveModel::Type::Binary::Data) ? value.to_s : value # TODO...
      end << record.new_record?
    end

    def decode_record_state(record, signature, record_state)
      attributes_hash = attribute_names_in_signature(signature).zip(record_state).to_h
      attributes = record.class.attributes_builder.build_from_database(attributes_hash)
      record.init_with_attributes(attributes, record_state.last)
    end

    def attributes_in_signature(signature)
      @signatures.fetch(signature, signature)[1]
    end

    def associations_in_signature(signature)
      @signatures.fetch(signature, signature)[2]
    end
  end
end
