# frozen_string_literal: true

module Gifthealth
  # Models a single prescription for a specific drug. It tracks its own state,
  # such as whether it has been created and its current fill count.
  class Prescription
    attr_reader :drug_name, :fill_count

    def initialize(drug_name)
      @drug_name = drug_name
      @created = false
      @fill_count = 0
    end

    def created?
      @created
    end

    def create
      @created = true
    end

    def fill
      return false unless created?

      @fill_count += 1
      true
    end

    def return_fill
      return false unless created? && @fill_count.positive?

      @fill_count -= 1
      true
    end
  end
end
