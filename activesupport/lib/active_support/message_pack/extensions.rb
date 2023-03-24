# frozen_string_literal: true

require "bigdecimal"
require "date"
require "ipaddr"
require "pathname"
require "uri/generic"
require "msgpack/bigint"
require "active_support/hash_with_indifferent_access"
require "active_support/time"

module ActiveSupport
  module MessagePack
    module Extensions # :nodoc:
      extend self

      def configure_factory(factory)
        factory.register_type 0, Symbol,
          packer: :to_msgpack_ext,
          unpacker: :from_msgpack_ext,
          optimized_symbols_parsing: true

        factory.register_type 1, Integer,
          packer: ::MessagePack::Bigint.method(:to_msgpack_ext),
          unpacker: ::MessagePack::Bigint.method(:from_msgpack_ext),
          oversized_integer_extension: true

        factory.register_type 2, BigDecimal,
          packer: :_dump,
          unpacker: :_load

        factory.register_type 3, Rational,
          packer: method(:write_rational),
          unpacker: method(:read_rational),
          recursive: true

        factory.register_type 4, Complex,
          packer: method(:write_complex),
          unpacker: method(:read_complex),
          recursive: true

        factory.register_type 5, Range,
          packer: method(:write_range),
          unpacker: method(:read_range),
          recursive: true

        factory.register_type 6, ActiveSupport::HashWithIndifferentAccess,
          packer: method(:write_hash_with_indifferent_access),
          unpacker: method(:read_hash_with_indifferent_access),
          recursive: true

        factory.register_type 7, Set,
          packer: method(:write_set),
          unpacker: method(:read_set),
          recursive: true

        factory.register_type 8, Time,
          packer: method(:write_time),
          unpacker: method(:read_time),
          recursive: true

        factory.register_type 9, DateTime,
          packer: method(:write_datetime),
          unpacker: method(:read_datetime),
          recursive: true

        factory.register_type 10, Date,
          packer: method(:write_date),
          unpacker: method(:read_date),
          recursive: true

        factory.register_type 11, ActiveSupport::TimeWithZone,
          packer: method(:write_time_with_zone),
          unpacker: method(:read_time_with_zone),
          recursive: true

        factory.register_type 12, ActiveSupport::TimeZone,
          packer: method(:dump_time_zone),
          unpacker: method(:load_time_zone)

        factory.register_type 13, ActiveSupport::Duration,
          packer: method(:write_duration),
          unpacker: method(:read_duration),
          recursive: true

        factory.register_type 14, URI::Generic,
          packer: :to_s,
          unpacker: URI.method(:parse)

        factory.register_type 15, IPAddr,
          packer: :to_s,
          unpacker: :new

        factory.register_type 16, Pathname,
          packer: :to_s,
          unpacker: :new

        factory.register_type 17, Regexp,
          packer: :to_s,
          unpacker: :new

        factory.register_type 18, Module,
          packer: method(:dump_module),
          unpacker: method(:load_module)

        factory.register_type 127, Object,
          packer: method(:write_object),
          unpacker: method(:read_object),
          recursive: true

        factory
      end

      LOAD_WITH_MSGPACK_EXT = 0
      LOAD_WITH_JSON_CREATE = 1

      def write_object(object, packer)
        if object.respond_to?(:to_msgpack_ext)
          if object.class.respond_to?(:from_msgpack_ext)
            packer.write(LOAD_WITH_MSGPACK_EXT)
            write_module(object.class, packer)
          end
          packer.write(object.to_msgpack_ext)
        elsif object.respond_to?(:serializable_hash)
          packer.write(object.serializable_hash)
        elsif object.respond_to?(:as_json)
          if object.class.respond_to?(:json_create)
            packer.write(LOAD_WITH_JSON_CREATE)
            write_module(object.class, packer)
          end
          packer.write(object.as_json)
        else
          raise "Cannot serialize #{object.inspect} due to unrecognized type #{object.class}"
        end
      end

      def read_object(unpacker)
        case (value = unpacker.read)
        when LOAD_WITH_MSGPACK_EXT
          read_module(unpacker).from_msgpack_ext(unpacker.read)
        when LOAD_WITH_JSON_CREATE
          read_module(unpacker).json_create(unpacker.read)
        else
          value
        end
      end

      def write_rational(rational, packer)
        packer.write(rational.numerator)
        packer.write(rational.denominator) unless rational.numerator.zero?
      end

      def read_rational(unpacker)
        numerator = unpacker.read
        Rational(numerator, numerator.zero? ? 1 : unpacker.read)
      end

      def write_complex(complex, packer)
        packer.write(complex.real)
        packer.write(complex.imaginary)
      end

      def read_complex(unpacker)
        Complex(unpacker.read, unpacker.read)
      end

      def write_range(range, packer)
        packer.write(range.begin)
        packer.write(range.end)
        packer.write(range.exclude_end?)
      end

      def read_range(unpacker)
        Range.new(unpacker.read, unpacker.read, unpacker.read)
      end

      def write_hash_with_indifferent_access(hwia, packer)
        packer.write(hwia.to_h)
      end

      def read_hash_with_indifferent_access(unpacker)
        ActiveSupport::HashWithIndifferentAccess.new(unpacker.read)
      end

      def write_set(set, packer)
        packer.write(set.to_a)
      end

      def read_set(unpacker)
        Set.new(unpacker.read)
      end

      def write_time(time, packer)
        packer.write(time.tv_sec)
        packer.write(time.tv_nsec)
        packer.write(time.utc_offset)
      end

      def read_time(unpacker)
        # TODO optimize Time.at
        Time.at_without_coercion(unpacker.read, unpacker.read, :nanosecond, in: unpacker.read)
      end

      def write_datetime(datetime, packer)
        packer.write(datetime.jd)
        packer.write(datetime.hour)
        packer.write(datetime.min)
        packer.write(datetime.sec)
        write_rational(datetime.sec_fraction, packer)
        write_rational(datetime.offset, packer)
      end

      def read_datetime(unpacker)
        DateTime.jd(unpacker.read, unpacker.read, unpacker.read, unpacker.read + read_rational(unpacker), read_rational(unpacker))
      end

      def write_date(date, packer)
        packer.write(date.jd)
      end

      def read_date(unpacker)
        Date.jd(unpacker.read)
      end

      def write_time_with_zone(twz, packer)
        write_time(twz.utc, packer)
        write_time_zone(twz.time_zone, packer)
      end

      def read_time_with_zone(unpacker)
        ActiveSupport::TimeWithZone.new(read_time(unpacker), read_time_zone(unpacker))
      end

      def dump_time_zone(time_zone)
        time_zone.name
      end

      def load_time_zone(name)
        ActiveSupport::TimeZone[name]
      end

      def write_time_zone(time_zone, packer)
        packer.write(dump_time_zone(time_zone))
      end

      def read_time_zone(unpacker)
        load_time_zone(unpacker.read)
      end

      def write_duration(duration, packer)
        packer.write(duration.value)
        packer.write(duration._parts.values_at(*ActiveSupport::Duration::PARTS))
      end

      def read_duration(unpacker)
        value = unpacker.read
        parts = ActiveSupport::Duration::PARTS.zip(unpacker.read).to_h
        parts.compact!
        ActiveSupport::Duration.new(value, parts)
      end

      def dump_module(mod)
        raise "Cannot serialize anonymous module or class" unless mod.name
        mod.name
      end

      def load_module(name)
        Object.const_get(name)
      end

      def write_module(mod, packer)
        packer.write(dump_module(mod))
      end

      def read_module(unpacker)
        load_module(unpacker.read)
      end
    end
  end
end
