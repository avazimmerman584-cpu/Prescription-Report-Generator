# frozen_string_literal: true

require 'gifthealth/patient'
require 'gifthealth/event'

RSpec.describe Gifthealth::Patient do
  subject(:patient) { described_class.new('TestPatient') }

  let(:created_event) { Gifthealth::Event.new(patient_name: 'TestPatient', drug_name: 'DrugX', type: 'created') }
  let(:filled_event) { Gifthealth::Event.new(patient_name: 'TestPatient', drug_name: 'DrugX', type: 'filled') }
  let(:returned_event) { Gifthealth::Event.new(patient_name: 'TestPatient', drug_name: 'DrugX', type: 'returned') }

  it { is_expected.to have_attributes(name: 'TestPatient', income: 0, total_fills: 0) }

  describe '#process_event' do
    context 'with a "created" event' do
      it 'does not change income or fills' do
        expect { patient.process_event(created_event) }
          .not_to change(patient, :income)
        expect { patient.process_event(created_event) }
          .not_to change(patient, :total_fills)
      end
    end

    context 'with a "filled" event' do
      context 'when prescription is not created first' do
        it 'does not change income or fills' do
          expect { patient.process_event(filled_event) }
            .not_to change(patient, :income)
          expect { patient.process_event(filled_event) }
            .not_to change(patient, :total_fills)
        end
      end

      context 'when prescription is created first' do
        before { patient.process_event(created_event) }

        it 'increases income by 5 and total_fills by 1' do
          expect { patient.process_event(filled_event) }
            .to change(patient, :income).by(5)
            .and change(patient, :total_fills).by(1)
        end
      end
    end

    context 'with a "returned" event' do
      before do
        patient.process_event(created_event)
        patient.process_event(filled_event)
      end

      it 'decreases income by 6 and total_fills by 1' do
        expect { patient.process_event(returned_event) }
          .to change(patient, :income).by(-6)
          .and change(patient, :total_fills).by(-1)
      end
    end

    context 'with multiple drugs' do
      let(:drug_y_created) { Gifthealth::Event.new(patient_name: 'TestPatient', drug_name: 'DrugY', type: 'created') }
      let(:drug_y_filled) { Gifthealth::Event.new(patient_name: 'TestPatient', drug_name: 'DrugY', type: 'filled') }

      before do
        patient.process_event(created_event)
        patient.process_event(filled_event)
        patient.process_event(drug_y_created)
        patient.process_event(drug_y_filled)
      end

      it 'calculates fills and income correctly across all prescriptions' do
        expect(patient.total_fills).to eq(2)
        expect(patient.income).to eq(10)
      end
    end
  end
end
