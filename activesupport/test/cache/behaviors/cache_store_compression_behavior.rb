# frozen_string_literal: true

require "active_support/core_ext/numeric/bytes"
require "active_support/core_ext/object/with"

module CacheStoreCompressionBehavior
  extend ActiveSupport::Concern

  included do
    test "compression works with cache format version > 6.1" do
      @cache = ActiveSupport::Cache.with(format_version: 7.0) do
        lookup_store(compress: true)
      end

      assert_compression true
    end

    test "compression works with cache format version 6.1 (using Cache::Entry#compressed)" do
      @cache = ActiveSupport::Cache.with(format_version: 6.1) do
        lookup_store(compress: true)
      end

      assert_compression true
    end

    test "compression works with custom coder and cache format version >= 7.1" do
      @cache = ActiveSupport::Cache.with(format_version: 7.1) do
        lookup_store(compress: true, coder: Marshal)
      end

      assert_compression true
    end

    test "compression is disabled with custom coder and cache format version < 7.1" do
      @cache = ActiveSupport::Cache.with(format_version: 7.0) do
        lookup_store(coder: Marshal)
      end

      assert_compression false
    end

    test "compression by default" do
      @cache = lookup_store

      assert_compression !compression_always_disabled_by_default?
    end

    test "compression can be disabled" do
      @cache = lookup_store(compress: false)

      assert_uncompressed SMALL_STRING
      assert_uncompressed SMALL_OBJECT
      assert_uncompressed LARGE_STRING
      assert_uncompressed LARGE_OBJECT
    end

    test ":compress method option overrides initializer option" do
      @cache = lookup_store(compress: true)

      assert_uncompressed SMALL_STRING, compress: false
      assert_uncompressed SMALL_OBJECT, compress: false
      assert_uncompressed LARGE_STRING, compress: false
      assert_uncompressed LARGE_OBJECT, compress: false

      @cache = lookup_store(compress: false)

      assert_uncompressed SMALL_STRING, compress: true
      assert_uncompressed SMALL_OBJECT, compress: true
      assert_compressed LARGE_STRING, compress: true
      assert_compressed LARGE_OBJECT, compress: true
    end

    test "low :compress_threshold triggers compression" do
      @cache = lookup_store(compress: true, compress_threshold: 1)

      assert_compressed SMALL_STRING
      assert_compressed SMALL_OBJECT
      assert_compressed LARGE_STRING
      assert_compressed LARGE_OBJECT
    end

    test "high :compress_threshold inhibits compression" do
      @cache = lookup_store(compress: true, compress_threshold: 1.megabyte)

      assert_uncompressed SMALL_STRING
      assert_uncompressed SMALL_OBJECT
      assert_uncompressed LARGE_STRING
      assert_uncompressed LARGE_OBJECT
    end

    test ":compress_threshold method option overrides initializer option" do
      @cache = lookup_store(compress: true, compress_threshold: 1)

      assert_uncompressed SMALL_STRING, compress_threshold: 1.megabyte
      assert_uncompressed SMALL_OBJECT, compress_threshold: 1.megabyte
      assert_uncompressed LARGE_STRING, compress_threshold: 1.megabyte
      assert_uncompressed LARGE_OBJECT, compress_threshold: 1.megabyte

      @cache = lookup_store(compress: true, compress_threshold: 1.megabyte)

      assert_compressed SMALL_STRING, compress_threshold: 1
      assert_compressed SMALL_OBJECT, compress_threshold: 1
      assert_compressed LARGE_STRING, compress_threshold: 1
      assert_compressed LARGE_OBJECT, compress_threshold: 1
    end

    test "compression ignores nil" do
      assert_uncompressed nil
      assert_uncompressed nil, compress: true, compress_threshold: 1
    end

    test "compression ignores incompressible data" do
      assert_uncompressed "", compress: true, compress_threshold: 1
      assert_uncompressed [*0..127].pack("C*"), compress: true, compress_threshold: 1
    end

    test "compressor can be replaced" do
      lossy_compressor = Module.new do
        def self.compress(dumped)
          "yolo"
        end

        def self.decompress(compressed)
          Marshal.dump(ActiveSupport::Cache::Entry.new("lossy!")) if compressed == "yolo"
        end
      end

      cache = lookup_store(compressor: lossy_compressor, compress: true, coder: Marshal)
      key = SecureRandom.uuid

      cache.write(key, LARGE_OBJECT)
      assert_equal "lossy!", cache.read(key)
    end

    test "replacing compressor raises when coder defines its own compression mechanism" do
      passthrough_compressor = Module.new do
        def self.compress(x); x; end
        def self.decompress(x); x; end
      end

      ActiveSupport::Cache.with(format_version: 6.1) do
        assert_raises ArgumentError do
          lookup_store(compressor: passthrough_compressor, compress: true)
        end
      end
    end

    test "dumped values that appear to include compression markers are preserved" do
      dumped_bytes_spy = Module.new do
        def self.dump(entry)
          entry.value.pack("C*") + " was dumped"
        end

        def self.load(dumped)
          ActiveSupport::Cache::Entry.new(dumped)
        end
      end

      cache = lookup_store(coder: dumped_bytes_spy, compress: true)
      key = SecureRandom.uuid

      # Dumped value looks like an already-marked Marshal.dump'd value
      cache.write("#{key}0", [0x00, 0x04, 0x08])
      assert_equal "\x00\x04\x08 was dumped", cache.read("#{key}0")

      # Dumped value looks like an already-marked Zlib.deflate'd value
      cache.write("#{key}1", [0x01, 0x78])
      assert_equal "\x01\x78 was dumped", cache.read("#{key}1")
    end
  end

  private
    # Use strings that are guaranteed to compress well, so we can easily tell if
    # the compression kicked in or not.
    SMALL_STRING = "0" * 100
    LARGE_STRING = "0" * 2.kilobytes

    SMALL_OBJECT = { data: SMALL_STRING }
    LARGE_OBJECT = { data: LARGE_STRING }

    def assert_compressed(value, **options)
      assert_operator compute_entry_size_reduction(value, **options), :>, 0
    end

    def assert_uncompressed(value, **options)
      assert_equal 0, compute_entry_size_reduction(value, **options)
    end

    def assert_compression(compress_large)
      assert_uncompressed SMALL_STRING
      assert_uncompressed SMALL_OBJECT

      if compress_large
        assert_compressed LARGE_STRING
        assert_compressed LARGE_OBJECT
      else
        assert_uncompressed LARGE_STRING
        assert_uncompressed LARGE_OBJECT
      end
    end

    def compute_entry_size_reduction(value, **options)
      entry = ActiveSupport::Cache::Entry.new(value)

      uncompressed = @cache.send(:serialize_entry, entry, **options, compress: false)
      actual = @cache.send(:serialize_entry, entry, **options)

      uncompressed.bytesize - actual.bytesize
    end

    def compression_always_disabled_by_default?
      false
    end
end
