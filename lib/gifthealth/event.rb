# frozen_string_literal: true

module Gifthealth
  # A simple data object representing a single prescription event.
  class Event
    attr_reader :patient_name, :drug_name, :type

    def initialize(patient_name:, drug_name:, type:)
      @patient_name = patient_name
      @drug_name = drug_name
      @type = type
      freeze
    end

    # Factory to build an Event from a raw line of text.
    class Factory
      VALID_EVENT_TYPES = %w[created filled returned].freeze
      def self.from_line(line)
        patient_name, drug_name, type = line.strip.split
        return nil unless patient_name && drug_name && type
        return nil unless VALID_EVENT_TYPES.include?(type)

        Event.new(patient_name: patient_name, drug_name: drug_name, type: type)
      end
    end
  end
end
