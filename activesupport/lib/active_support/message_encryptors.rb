# frozen_string_literal: true

require "active_support/messages/rotation_coordinator"

module ActiveSupport
  class MessageEncryptors < Messages::RotationCoordinator
    ##
    # :method: initialize
    # :call-seq: initialize(&secret_generator)
    #
    # Initializes a new instance. +secret_generator+ must accept a salt and a
    # secret length, and return a suitable secret (string) or secrets (array
    # of strings).

    ##
    # :method: []
    # :call-seq: [](salt)
    #
    # Returns a MessageEncryptor configured with a secret derived from the
    # given +salt+, and options from #rotate. MessageEncryptor instances will
    # be memoized, so the same +salt+ will return the same instance.

    ##
    # :method: []=
    # :call-seq: []=(salt, encryptor)
    #
    # Overrides a MessageEncryptor instance associated with a given +salt+.

    ##
    # :method: rotate
    # :call-seq: rotate(**options)
    #
    # Adds +options+ to the list of option sets. Messages will be encrypted
    # using the first set in the list. When decrypting, however, each set will
    # be tried, in order, until one succeeds.
    #
    # Notably, the <tt>:secret_generator</tt> option can specify a different
    # secret generator than the one initially specified. The generator must
    # respond to +call+, accept a salt and a secret length, and return a
    # suitable secret (string) or secrets (array of strings).

    ##
    # :method: rotate_defaults
    # :call-seq: rotate_defaults
    #
    # Invokes #rotate with the default options.

    ##
    # :method: clear_rotations
    # :call-seq: clear_rotations
    #
    # Clears the list of option sets.

    ##
    # :method: on_rotation
    # :call-seq: on_rotation(&callback)
    #
    # Sets a callback to invoke when a message is decrypted using an option set
    # other than the first.
    #
    # For example, this callback could log each time it is called, and thus
    # indicate whether old option sets are still in use or can be removed from
    # rotation.

    private
      def build(salt, secret_generator:, **options)
        secret_length = MessageEncryptor.key_len(*options[:cipher])
        MessageEncryptor.new(*secret_generator.call(salt, secret_length), **options)
      end
  end
end
