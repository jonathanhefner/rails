# frozen_string_literal: true

require "shellwords"
require "active_support/encrypted_file"

module Rails
  module Command
    module Helpers
      module Editor
        private
          def check_system_editor_available
            if ENV["EDITOR"].to_s.empty?
              say "No $EDITOR to open file in. Assign one like this:"
              say ""
              say %(EDITOR="mate --wait" #{executable(current_subcommand)})
              say ""
              say "For editors that fork and exit immediately, it's important to pass a wait flag;"
              say "otherwise, the file will be saved immediately with no chance to edit."

              false
            else
              true
            end
          end

          def system_editor(file_path)
            system(*Shellwords.split(ENV["EDITOR"]), file_path.to_s)
          end

          def using_system_editor
            check_system_editor_available && yield
          rescue Interrupt
            say "Aborted changing file: nothing saved."
          end
      end
    end
  end
end
