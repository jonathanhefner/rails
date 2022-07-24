# frozen_string_literal: true

require "pathname"
require "active_support"
require "rails/command/helpers/editor"

module Rails
  module Command
    class EncryptedCommand < Rails::Command::Base # :nodoc:
      include Helpers::Editor

      class_option :key, aliases: "-k", type: :string,
        default: "config/master.key", desc: "The Rails.root relative path to the encryption key"

      no_commands do
        def help
          say "Usage:\n  #{self.class.banner}"
          say ""
          say self.class.desc
        end
      end

      def edit(*)
        require_application!

        ensure_editor_available(command: "bin/rails encrypted:edit") || (return)
        ensure_encryption_key_has_been_added
        ensure_encrypted_configuration_has_been_added

        catch_editing_exceptions do
          change_encrypted_configuration_in_system_editor
        end

        say "File encrypted and saved."
      rescue ActiveSupport::MessageEncryptor::InvalidMessage
        say "Couldn't decrypt #{content_path}. Perhaps you passed the wrong key?"
      end

      def show(*)
        require_application!

        say encrypted_configuration.read.presence || missing_encrypted_configuration_message
      end

      private
        def content_path
          @content_path ||= args[0]
        end

        def key_path
          options[:key]
        end

        def encrypted_configuration
          @encrypted_configuration ||= Rails.application.encrypted(content_path, key_path: key_path)
        end

        def ensure_encryption_key_has_been_added
          return if encrypted_configuration.key?
          encryption_key_file_generator.add_key_file(key_path)
          encryption_key_file_generator.ignore_key_file(key_path)
        end

        def ensure_encrypted_configuration_has_been_added
          encrypted_file_generator.add_encrypted_file_silently(content_path, key_path)
        end

        def change_encrypted_configuration_in_system_editor
          encrypted_configuration.change do |tmp_path|
            system("#{ENV["EDITOR"]} #{tmp_path}")
          end
        end


        def encryption_key_file_generator
          require "rails/generators"
          require "rails/generators/rails/encryption_key_file/encryption_key_file_generator"

          Rails::Generators::EncryptionKeyFileGenerator.new
        end

        def encrypted_file_generator
          require "rails/generators"
          require "rails/generators/rails/encrypted_file/encrypted_file_generator"

          Rails::Generators::EncryptedFileGenerator.new
        end

        def missing_encrypted_configuration_message
          if !encrypted_configuration.key?
            "Missing '#{key_path}' to decrypt data. See `bin/rails encrypted:help`"
          else
            "File '#{content_path}' does not exist. Use `bin/rails encrypted:edit #{content_path}` to change that."
          end
        end
    end
  end
end
