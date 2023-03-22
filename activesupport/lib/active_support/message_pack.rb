# frozen_string_literal: true

begin
  require "msgpack"
  require "msgpack/bigint"
rescue LoadError => error
  # TODO
end

module ActiveSupport
  module MessagePack
    def self.for_messages # TODO pre allocate?
      @for_messages ||= Serializer.new
    end

    class Serializer
      attr_reader :message_pack_factory # :nodoc:

      def initialize
        @message_pack_factory = MessagePack::Factory.new
        EXTENSIONS.each do |id, extension|
          extension = extension.dup
          @message_pack_factory.register_type(id, extension.delete(:class), **extension)
        end
      end

      def dump(data)
        packer = message_pack_factory.packer
        # RFC: TODO
        packer.write(true)
        packer.write(false)
        packer.write(data)
        packer.full_pack
      end

      def load(serialized)
        unpacker = message_pack_factory.unpacker
        unpacker.feed(serialized)
        unless unpacker.read == true && unpacker.read == false
          raise "TODO"
        end
        unpacker.full_unpack
      end

      # TODO warning
      EXTENSIONS = { # :nodoc:
        0 => {
          class: Symbol,
          optimized_symbols_parsing: true,
        },

        1 => {
          class: Module,

          packer: -> (mod) do
            raise "Cannot serialize anonymous module or class" unless mod.name
            mod.name
          end,

          unpacker: Object.method(:const_get),
        },

        2 => {
          class: Integer,
          packer: MessagePack::Bigint.method(:to_msgpack_ext),
          unpacker: MessagePack::Bigint.method(:from_msgpack_ext),
          oversized_integer_extension: true,
        },

        2 => {
          class: BigDecimal,
          packer: :_dump,
          unpacker: :_load,
        },

        2 => {
          class: Rational,
          recursive: true,

          packer: -> (rational, packer) do
            packer.write(rational.numerator)
            packer.write(rational.denominator)
          end,

          unpacker: -> (unpacker) do
            Rational(unpacker.read, unpacker.read)
          end,
        },

        2 => {
          class: Complex,
          recursive: true,

          packer: -> (complex, packer) do
            packer.write(complex.real)
            packer.write(complex.imaginary)
          end,

          unpacker: -> (unpacker) do
            Complex(unpacker.read, unpacker.read)
          end,
        },

        2 => {
          class: Regexp,
          packer: :to_s,
          unpacker: :new,
        },

        2 => {
          class: Range,
          recursive: true,

          packer: -> (range, packer) do
            packer.write(range.begin)
            packer.write(range.end)
            packer.write(range.exclude_end?)
          end,

          unpacker: -> (unpacker) do
            Range.new(unpacker.read, unpacker.read, unpacker.read)
          end,
        },

        2 => {
          class: Set,
          recursive: true,

          packer: -> (set, packer) do
            packer.write(set.to_a)
          end,

          unpacker: -> (unpacker) do
            Set.new(unpacker.read)
          end,
        },

        2 => {
          class: Pathname,
          packer: :to_s,
          unpacker: :new,
        },

        2 => {
          class: URI::Generic,
          packer: :to_s,
          unpacker: :parse,
        },

        2 => {
          class: IPAddr,
          packer: :to_s,
          unpacker: :new,
        },

        2 => {
          class: Date,
          recursive: true,

          packer: -> (date, packer) do
            packer.write(date.jd)
          end,

          unpacker: -> (unpacker) do
            Date.jd(unpacker.read)
          end,
        },

        2 => {
          class: DateTime,
          recursive: true,

          packer: -> (datetime, packer) do
            packer.write(datetime.jd)
            packer.write(datetime.hour)
            packer.write(datetime.min)
            packer.write(datetime.sec)
            packer.write(datetime.sec_fraction)
            packer.write(datetime.utc_offset)
          end,

          unpacker: -> (unpacker) do
            DateTime.jd(unpacker.read, unpacker.read, unpacker.read, unpacker.read + unpacker.read, unpacker.read)
          end,
        },

        2 => {
          class: Time,
          recursive: true,

          packer: -> (time, packer) do
            packer.write(time.tv_sec)
            packer.write(time.tv_nsec)
            packer.write(time.utc_offset)
          end,

          unpacker: -> (unpacker) do
            Time.at(unpacker.read, unpacker.read, :nanosecond, in: unpacker.read)
          end,
        },

        2 => {
          class: ActiveSupport::TimeWithZone,
          recursive: true,

          packer: -> (twz, packer) do
            packer.write(twz.utc)
            packer.write(twz.time_zone)
          end,

          unpacker: -> (unpacker) do
            ActiveSupport::TimeWithZone.new(unpacker.read, unpacker.read)
          end,
        },

        2 => {
          class: ActiveSupport::TimeZone,
          packer: :name,
          unpacker: :[],
        },

        2 => {
          class: ActiveSupport::Duration,
          recursive: true,

          packer: -> (duration, packer) do
            packer.write(duration.value)
            packer.write(duration._parts.values_at(*ActiveSupport::Duration::PARTS))
          end,

          unpacker: -> (unpacker) do
            value = unpacker.read
            parts = ActiveSupport::Duration::PARTS.zip(unpacker.read).to_h
            parts.compact!
            ActiveSupport::Duration.new(value, parts)
          end,
        },

        2 => {
          class: ActiveSupport::HashWithIndifferentAccess,
          recursive: true,

          packer: -> (hwia, packer) do
            raise "TODO" unless hwia.instance_of?(ActiveSupport::HashWithIndifferentAccess)
            packer.write(hwia.to_h)
          end,

          unpacker -> (unpacker) do
            ActiveSupport::HashWithIndifferentAccess.new(unpacker.read)
          end,
        },


      }
    end



  end
end
