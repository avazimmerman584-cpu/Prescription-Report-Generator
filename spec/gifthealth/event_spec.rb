# frozen_string_literal: true

require 'gifthealth/event'

RSpec.describe Gifthealth::Event::Factory do
  describe '.from_line' do
    it 'creates a valid event from a good line' do
      event = described_class.from_line('PatientA DrugX created')
      expect(event).to have_attributes(
        patient_name: 'PatientA',
        drug_name: 'DrugX',
        type: 'created'
      )
    end

    it 'returns nil for a line with a missing part' do
      expect(described_class.from_line('PatientA created')).to be_nil
    end

    it 'returns nil for a line with an invalid event type' do
      expect(described_class.from_line('PatientA DrugX cancelled')).to be_nil
    end

    it 'returns nil for a blank line' do
      expect(described_class.from_line(' ')).to be_nil
    end

    it 'strips leading/trailing whitespace' do
      event = described_class.from_line('  PatientA DrugX filled  ')
      expect(event).to have_attributes(
        patient_name: 'PatientA',
        drug_name: 'DrugX',
        type: 'filled'
      )
    end
  end
end
