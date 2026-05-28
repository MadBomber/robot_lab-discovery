# frozen_string_literal: true

module RobotLab
  module Discovery
    Result = Data.define(:name, :hostname, :port, :path) do
      def url = "http://#{hostname}:#{port}#{path}"
    end
  end
end
