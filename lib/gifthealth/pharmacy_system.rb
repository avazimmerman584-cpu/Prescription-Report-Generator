# frozen_string_literal: true

require_relative 'event'
require_relative 'patient'

module Gifthealth
  # The main system for processing prescription events. It maintains a collection
  # of patients and orchestrates the event processing.
  class PharmacySystem
    attr_reader :patients

    def initialize
      @patients = {}
    end

    def process_stream(io_stream)
      io_stream.each_line do |line|
        event = Event::Factory.from_line(line)
        process_event(event) if event
      end
    end

    private

    def process_event(event)
      patient = find_or_create_patient(event)
      return unless patient

      return if event.type != 'created' && !@patients.key?(event.patient_name)

      patient.process_event(event)
    end

    def find_or_create_patient(event)
      if event.type == 'created'
        @patients[event.patient_name] ||= Patient.new(event.patient_name)
      else
        @patients[event.patient_name]
      end
    end
  end
end
