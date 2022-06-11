# frozen_string_literal: true

require "tty-runner"

module Iwai
  class Cli < TTY::Runner
    mount Lock

    usage do
      command "lock"
    end

    argument :image do
      required
      desc "The name of the image to use"
    end
  end
end
