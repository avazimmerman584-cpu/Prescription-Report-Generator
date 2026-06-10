# frozen_string_literal: true

module Gifthealth
  # Generates the final report to stdout based on the state of the pharmacy system.
  class Report
    def self.generate(pharmacy_system, io = $stdout)
      pharmacy_system.patients.values.sort_by(&:name).each do |patient|
        io.puts format_line(patient)
      end
    end

    def self.format_line(patient)
      "#{patient.name}: #{patient.total_fills} fills $#{patient.income} income"
    end
  end
end
