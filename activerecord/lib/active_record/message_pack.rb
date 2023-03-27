# frozen_string_literal: true

module ActiveRecord
  module MessagePack # :nodoc:
    FORMAT_VERSION = 1

    class << self
      def dump(input)
        encoder = Encoder.new
        [FORMAT_VERSION, encoder.encode(input), encoder.entries]
      end

      def load(dumped)
        format_version, top_level, entries = dumped
        unless format_version == FORMAT_VERSION
          raise "Invalid format version: #{format_version.inspect}"
        end
        Decoder.new(entries).decode(top_level)
      end
    end

    module Extensions
      extend self

      def install(serializer)
        serializer.register_type 120, ActiveRecord::Base,
          packer: method(:write_record),
          unpacker: method(:read_record),
          recursive: true
      end

      def write_record(record, packer)
        packer.write(ActiveRecord::MessagePack.dump(record))
      end

      def read_record(unpacker)
        ActiveRecord::MessagePack.load(unpacker.read)
      end
    end

    class Encoder
      attr_reader :entries

      def initialize
        @entries = []
        @refs = {}.compare_by_identity
      end

      def encode(input)
        if input.is_a?(Array)
          input.map { |record| encode_record(record) }
        elsif input
          encode_record(input)
        end
      end

      def encode_record(record)
        ref = @refs[record]

        if !ref
          ref = @refs[record] = @entries.size
          @entries << build_entry(record)
          add_cached_associations(record, @entries.last)
        end

        ref
      end

      def build_entry(record)
        attributes_hash = record.attributes_for_database
        attributes_hash.transform_values! do |value|
          # FIXME Handle this in a better way.
          value.is_a?(::ActiveModel::Type::Binary::Data) ? value.to_s : value
        end

        [record.class.name, attributes_hash, record.new_record?]
      end

      def add_cached_associations(record, entry)
        record.class.reflections.each_value do |reflection|
          if record.association_cached?(reflection.name)
            entry << reflection.name << encode(record.association(reflection.name).target)
          end
        end
      end
    end

    class Decoder
      def initialize(entries)
        @records = entries.map { |entry| build_record(entry) }
        @records.zip(entries) { |record, entry| resolve_cached_associations(record, entry) }
      end

      def decode(ref)
        if ref.is_a?(Array)
          ref.map { |r| @records[r] }
        elsif ref
          @records[ref]
        end
      end

      def build_record(entry)
        class_name, attributes_hash, is_new_record, * = entry
        record = Object.const_get(class_name).allocate
        attributes = record.class.attributes_builder.build_from_database(attributes_hash)
        record.init_with_attributes(attributes, is_new_record)
      end

      def resolve_cached_associations(record, entry)
        i = 3 # entry == [class_name, attributes_hash, is_new_record, *associations]
        while i < entry.length
          begin
            record.association(entry[i]).target = decode(entry[i + 1])
          rescue ActiveRecord::AssociationNotFoundError
            # The association no longer exists, so just skip it.
          end
          i += 2
        end
      end
    end
  end
end
