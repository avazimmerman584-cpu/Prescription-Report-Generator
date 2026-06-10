# frozen_string_literal: true

require_relative 'prescription'

module Gifthealth
  # Manages all prescriptions for a single patient, tracks income, and
  # calculates total fills.
  class Patient
    attr_reader :name, :income

    def initialize(name)
      @name = name
      @income = 0
      @prescriptions = {}
    end

    def process_event(event)
      prescription = find_or_create_prescription(event.drug_name)

      case event.type
      when 'created'
        prescription.create
      when 'filled'
        @income += 5 if prescription.fill
      when 'returned'
        @income -= 6 if prescription.return_fill
      end
    end

    def total_fills
      prescriptions.values.sum(&:fill_count)
    end

    private

    attr_reader :prescriptions

    def find_or_create_prescription(drug_name)
      prescriptions[drug_name] ||= Prescription.new(drug_name)
    end
  end
end
